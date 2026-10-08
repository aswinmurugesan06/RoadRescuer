const { prisma } = require('../config/prisma');
const notificationService = require('./notificationService');
const { getIO } = require('../socket/socketManager');

const DistanceUtil = {
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in km
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Number((R * c).toFixed(2));
  },

  estimateEtaMinutes(distanceKm) {
    if (distanceKm <= 0) return 2;
    const avgSpeedKmH = 30.0;
    const minutes = Math.round((distanceKm / avgSpeedKmH) * 60);
    return Math.max(minutes, 2);
  },
};

// In-memory active dispatch tracker: requestId -> { currentCandidateId, excludedProviderIds: Set, timeoutTimer, radiusKm }
const activeDispatches = new Map();

class DispatchService {
  /**
   * Smart ranking scoring weights.
   * Proximity: 50%, Rating: 30%, Experience/Workload: 20%.
   */
  calculateRankingScore(distanceKm, rating = 5.0, totalJobs = 0) {
    const proximityScore = Math.max(0, 100 - distanceKm * 3);
    const ratingScore = ((rating || 5.0) / 5.0) * 100;
    const experienceScore = Math.min(100, 50 + (totalJobs || 0) * 2);

    const totalScore = proximityScore * 0.5 + ratingScore * 0.3 + experienceScore * 0.2;
    return Number(totalScore.toFixed(2));
  }

  /**
   * Returns list of provider categories eligible to service a request category.
   * PUNCTURE requests can be handled by PUNCTURE specialists and MECHANIC providers.
   * BATTERY requests can be handled by BATTERY specialists and MECHANIC providers.
   * FUEL requests can be handled by FUEL specialists and MECHANIC providers.
   * MECHANIC requests are handled by MECHANIC providers.
   * TOW_TRUCK requests are handled by TOW_TRUCK providers.
   */
  getEligibleProviderCategoriesForRequest(requestCategory) {
    if (requestCategory === 'PUNCTURE') {
      return ['PUNCTURE', 'MECHANIC'];
    }
    if (requestCategory === 'BATTERY') {
      return ['BATTERY', 'MECHANIC'];
    }
    if (requestCategory === 'FUEL') {
      return ['FUEL', 'MECHANIC'];
    }
    if (requestCategory === 'MECHANIC') {
      return ['MECHANIC'];
    }
    if (requestCategory === 'TOW_TRUCK') {
      return ['TOW_TRUCK'];
    }
    return [requestCategory, 'MECHANIC'];
  }

  /**
   * Helper to check if a provider category is compatible with a request category.
   */
  isCategoryCompatible(providerCategory, requestCategory) {
    if (providerCategory === requestCategory) return true;
    if (providerCategory === 'MECHANIC' && ['PUNCTURE', 'BATTERY', 'FUEL'].includes(requestCategory)) return true;
    return false;
  }

  /**
   * Discover and rank all eligible nearby providers for a service request.
   */
  async discoverAndRankProviders(requestId, options = {}) {
    const {
      maxRadiusKm = 25.0,
      excludedUserIds = [],
      allowFallbackExpansion = true,
    } = options;

    const request = await prisma.serviceRequest.findUnique({
      where: { id: requestId },
      include: {
        customer: { select: { id: true, name: true, mobile: true } },
      },
    });

    if (!request) {
      const error = new Error('Service request not found');
      error.statusCode = 404;
      throw error;
    }

    const { customerLatitude, customerLongitude, category } = request;

    if (customerLatitude == null || customerLongitude == null) {
      const error = new Error('Service request has missing location coordinates');
      error.statusCode = 400;
      throw error;
    }

    const eligibleProviderCategories = this.getEligibleProviderCategoriesForRequest(category);

    // 1. Query all APPROVED, AVAILABLE providers matching requested category with valid GPS
    const providers = await prisma.user.findMany({
      where: {
        role: 'PROVIDER',
        isActive: true,
        id: { notIn: excludedUserIds },
        providerProfile: {
          verificationStatus: 'APPROVED',
          availability: 'AVAILABLE',
          category: { in: eligibleProviderCategories },
          latitude: { not: null },
          longitude: { not: null },
        },
      },
      include: {
        providerProfile: true,
      },
    });

    // 2. Calculate distance and filter within radius
    const candidates = [];
    for (const prov of providers) {
      const pLat = prov.providerProfile.latitude;
      const pLng = prov.providerProfile.longitude;
      const distanceKm = DistanceUtil.calculateDistance(
        customerLatitude,
        customerLongitude,
        pLat,
        pLng
      );

      const effectiveRadius = Math.max(
        maxRadiusKm,
        prov.providerProfile.serviceRadiusKm || 25.0
      );

      if (distanceKm <= effectiveRadius) {
        const rating = prov.providerProfile.rating || 5.0;
        const totalJobs = prov.providerProfile.totalJobs || 0;
        const score = this.calculateRankingScore(distanceKm, rating, totalJobs);
        const etaMinutes = DistanceUtil.estimateEtaMinutes(distanceKm);

        candidates.push({
          userId: prov.id,
          name: prov.name,
          category: prov.providerProfile.category,
          garageName: prov.providerProfile.garageName || prov.name,
          distanceKm,
          rating,
          totalJobs,
          score,
          etaMinutes,
          latitude: pLat,
          longitude: pLng,
        });
      }
    }

    // 3. Sort candidates descending by ranking score
    candidates.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if (a.distanceKm !== b.distanceKm) return a.distanceKm - b.distanceKm;
      return b.rating - a.rating;
    });

    return {
      request,
      candidates,
      searchRadiusKm: maxRadiusKm,
      totalFound: candidates.length,
    };
  }

  /**
   * Start automatic dispatch workflow for a service request.
   */
  async startDispatch(requestId, options = {}) {
    const {
      timeoutMs = 30000,
      initialRadiusKm = 15.0,
      maxExpansionRadiusKm = 50.0,
    } = options;

    let dispatchState = activeDispatches.get(requestId);
    if (!dispatchState) {
      dispatchState = {
        requestId,
        excludedProviderIds: new Set(),
        currentRadiusKm: initialRadiusKm,
        maxExpansionRadiusKm,
        timeoutMs,
        currentCandidate: null,
      };
      activeDispatches.set(requestId, dispatchState);
    } else if (dispatchState.currentCandidate) {
      return {
        status: 'DISPATCHED',
        requestId,
        candidate: dispatchState.currentCandidate,
        timeoutMs: dispatchState.timeoutMs,
      };
    }

    // Discover candidates excluding already rejected/timed-out providers
    const { request, candidates } = await this.discoverAndRankProviders(requestId, {
      maxRadiusKm: dispatchState.currentRadiusKm,
      excludedUserIds: Array.from(dispatchState.excludedProviderIds),
    });

    const io = getIO();

    if (candidates.length === 0) {
      // Try expanding search radius if permitted
      if (dispatchState.currentRadiusKm < dispatchState.maxExpansionRadiusKm) {
        dispatchState.currentRadiusKm = Math.min(
          dispatchState.currentRadiusKm * 2,
          dispatchState.maxExpansionRadiusKm
        );
        return this.startDispatch(requestId, options);
      }

      // No providers available
      if (io) {
        io.to(`user:${request.customerId}`).emit('request:no_provider', {
          requestId,
          message: 'No available providers found nearby. Please try again in a few minutes.',
          timestamp: new Date().toISOString(),
        });
      }
      activeDispatches.delete(requestId);
      return { status: 'NO_PROVIDER_AVAILABLE', candidatesCount: 0 };
    }

    // Select top candidate
    const topCandidate = candidates[0];
    dispatchState.currentCandidate = topCandidate;
    dispatchState.excludedProviderIds.add(topCandidate.userId);

    // Update request status to SEARCHING if still PENDING
    await prisma.serviceRequest.updateMany({
      where: { id: requestId, status: 'PENDING' },
      data: { status: 'SEARCHING' },
    });

    // Emit real-time dispatch alerts
    if (io) {
      // 1. Alert candidate provider
      io.to(`user:${topCandidate.userId}`).emit('request:dispatched', {
        requestId: request.id,
        category: request.category,
        serviceType: request.serviceType,
        problemDescription: request.problemDescription,
        vehicleModel: request.vehicleModel,
        distanceKm: topCandidate.distanceKm,
        etaMinutes: topCandidate.etaMinutes,
        customerAddress: request.customerAddress,
        createdAt: request.createdAt,
      });

      // 2. Inform customer that a candidate provider was notified
      io.to(`user:${request.customerId}`).emit('request:status', {
        requestId,
        status: 'PROVIDER_NOTIFIED',
        message: 'A nearby technician was notified and is responding...',
        candidateEtaMinutes: topCandidate.etaMinutes,
        timestamp: new Date().toISOString(),
      });
    }

    // Push notification to candidate provider
    notificationService.notifyNewRequestAvailable([topCandidate.userId], request).catch(() => {});

    // Set auto-reassignment timer on timeout
    if (dispatchState.timeoutTimer) {
      clearTimeout(dispatchState.timeoutTimer);
    }

    dispatchState.timeoutTimer = setTimeout(async () => {
      await this.handleCandidateTimeout(requestId, topCandidate.userId);
    }, timeoutMs);

    return {
      status: 'DISPATCHED',
      candidate: topCandidate,
      searchRadiusKm: dispatchState.currentRadiusKm,
      remainingCandidatesCount: candidates.length - 1,
    };
  }

  /**
   * Handle candidate timeout: automatically advance to the next best provider candidate.
   */
  async handleCandidateTimeout(requestId, timedOutProviderId) {
    const req = await prisma.serviceRequest.findUnique({
      where: { id: requestId },
      select: { id: true, status: true, providerId: true },
    });

    // If request has already been accepted or cancelled, stop dispatching
    if (!req || req.providerId || !['PENDING', 'SEARCHING'].includes(req.status)) {
      this.clearDispatch(requestId);
      return;
    }

    const dispatchState = activeDispatches.get(requestId);
    if (dispatchState) {
      dispatchState.currentCandidate = null;
    }

    // Advance to next candidate
    return this.startDispatch(requestId);
  }

  /**
   * Provider rejects an incoming dispatched request -> re-dispatch immediately to next candidate.
   */
  async rejectDispatchedRequest(providerUserId, requestId, reason = 'Provider unavailable') {
    const dispatchState = activeDispatches.get(requestId);
    if (dispatchState) {
      dispatchState.excludedProviderIds.add(providerUserId);
      dispatchState.currentCandidate = null;
      if (dispatchState.timeoutTimer) {
        clearTimeout(dispatchState.timeoutTimer);
        dispatchState.timeoutTimer = null;
      }
    }

    // Re-dispatch to next candidate
    const nextDispatch = await this.startDispatch(requestId);

    return {
      success: true,
      message: 'Request rejected. Re-dispatching to next available provider.',
      nextDispatch,
    };
  }

  /**
   * Provider accepts a dispatched request (atomic assignment).
   */
  async acceptDispatchedRequest(providerUserId, requestId) {
    const profile = await prisma.providerProfile.findUnique({
      where: { userId: providerUserId },
    });

    if (!profile || profile.verificationStatus !== 'APPROVED') {
      const error = new Error('Only APPROVED providers can accept service requests');
      error.statusCode = 403;
      throw error;
    }

    if (profile.availability !== 'AVAILABLE') {
      const error = new Error('You must be AVAILABLE to accept requests');
      error.statusCode = 403;
      throw error;
    }

    // Atomic assignment using transaction
    const result = await prisma.$transaction(async (tx) => {
      const existing = await tx.serviceRequest.findUnique({
        where: { id: requestId },
      });

      if (!existing) {
        const error = new Error('Service request not found');
        error.statusCode = 404;
        throw error;
      }

      if (!['PENDING', 'SEARCHING'].includes(existing.status) || existing.providerId !== null) {
        const error = new Error('This service request has already been accepted or is no longer available');
        error.statusCode = 409;
        throw error;
      }

      if (!this.isCategoryCompatible(profile.category, existing.category)) {
        const error = new Error(`Cannot accept request: request category is ${existing.category} but provider is ${profile.category}`);
        error.statusCode = 400;
        throw error;
      }

      // Update Service Request
      const updated = await tx.serviceRequest.update({
        where: { id: requestId },
        data: {
          providerId: providerUserId,
          status: 'ACCEPTED',
          acceptedAt: new Date(),
        },
        include: {
          customer: {
            select: { id: true, name: true, mobile: true, email: true },
          },
          provider: {
            select: { id: true, name: true, mobile: true },
          },
        },
      });

      // Update Provider availability to BUSY
      await tx.providerProfile.update({
        where: { userId: providerUserId },
        data: { availability: 'BUSY' },
      });

      return updated;
    });

    // Clear dispatch timer and active state
    this.clearDispatch(requestId);

    // Socket.IO notification
    const io = getIO();
    if (io) {
      io.to(`user:${result.customerId}`).emit('request:accepted', {
        requestId: result.id,
        status: 'ACCEPTED',
        providerId: providerUserId,
        providerName: result.provider?.name,
        providerMobile: result.provider?.mobile,
        acceptedAt: result.acceptedAt,
      });

      io.to(`request:${result.id}`).emit('request:status', {
        requestId: result.id,
        status: 'ACCEPTED',
      });
    }

    // Push notification to customer
    notificationService.notifyRequestAccepted(result.customerId, result, result.provider?.name).catch(() => {});

    return result;
  }

  /**
   * Clear active dispatch tracker and timer for a request.
   */
  clearDispatch(requestId) {
    const dispatchState = activeDispatches.get(requestId);
    if (dispatchState?.timeoutTimer) {
      clearTimeout(dispatchState.timeoutTimer);
    }
    activeDispatches.delete(requestId);
  }
}

module.exports = new DispatchService();
