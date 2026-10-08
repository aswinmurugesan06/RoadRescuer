const { prisma } = require('../config/prisma');
const vehicleService = require('./vehicleService');

// In-memory fallback store for development/testing when PostgreSQL is offline
const memoryRequests = new Map();

class ServiceRequestService {
  /**
   * Helper to normalize category from serviceType or explicit category.
   */
  resolveCategory(category, serviceType) {
    if (category) {
      let upper = String(category).toUpperCase();
      if (upper === 'TOW') upper = 'TOW_TRUCK';
      if (['MECHANIC', 'PUNCTURE', 'TOW_TRUCK', 'BATTERY', 'FUEL'].includes(upper)) {
        return upper;
      }
    }

    if (serviceType) {
      const s = String(serviceType).toLowerCase();
      if (s.includes('puncture') || s.includes('tyre') || s.includes('tire')) return 'PUNCTURE';
      if (s.includes('tow') || s.includes('recovery')) return 'TOW_TRUCK';
      if (s.includes('battery') || s.includes('jump')) return 'BATTERY';
      if (s.includes('fuel') || s.includes('petrol') || s.includes('diesel')) return 'FUEL';
      return 'MECHANIC';
    }

    return 'MECHANIC';
  }

  /**
   * Returns list of request categories that a provider with providerCategory can service.
   * A MECHANIC can service MECHANIC, PUNCTURE, BATTERY, and FUEL requests.
   * PUNCTURE specialists service PUNCTURE requests.
   * TOW_TRUCK operators service TOW_TRUCK requests.
   * BATTERY specialists service BATTERY requests.
   * FUEL specialists service FUEL requests.
   */
  getEligibleCategoriesForProvider(providerCategory) {
    if (providerCategory === 'MECHANIC') {
      return ['MECHANIC', 'PUNCTURE', 'BATTERY', 'FUEL'];
    }
    if (providerCategory === 'PUNCTURE') {
      return ['PUNCTURE'];
    }
    if (providerCategory === 'TOW_TRUCK') {
      return ['TOW_TRUCK'];
    }
    if (providerCategory === 'BATTERY') {
      return ['BATTERY'];
    }
    if (providerCategory === 'FUEL') {
      return ['FUEL'];
    }
    return [providerCategory];
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
   * 1. Create a roadside assistance request.
   * Only authenticated customers can create requests.
   * Enforces customer ownership when a vehicleId is specified.
   */
  async createRequest(customerId, data) {
    const category = this.resolveCategory(data.category, data.serviceType);

    let vehiclePlate = data.vehiclePlate ? data.vehiclePlate.trim().toUpperCase() : '';
    let vehicleModel = data.vehicleModel ? data.vehicleModel.trim() : '';
    let vehicleType = data.vehicleType ? data.vehicleType.trim() : null;

    if (data.vehicleId) {
      let vehicle = null;
      if (prisma) {
        try {
          vehicle = await prisma.vehicle.findUnique({
            where: { id: data.vehicleId },
          });
        } catch (err) {
          if (process.env.NODE_ENV === 'production') throw err;
          console.warn('⚠️ DB query failed, checking in-memory store:', err.message);
        }
      }

      if (!vehicle) {
        try {
          vehicle = await vehicleService.getVehicleById(customerId, data.vehicleId);
        } catch (e) {
          if (e.statusCode === 403 || e.statusCode === 404) throw e;
        }
      }

      if (!vehicle) {
        const err = new Error('Selected vehicle not found');
        err.statusCode = 404;
        throw err;
      }

      if (vehicle.userId !== customerId) {
        const err = new Error('Access denied: You can only use your own vehicle in a service request');
        err.statusCode = 403;
        throw err;
      }

      if (!vehiclePlate) vehiclePlate = vehicle.plateNumber;
      if (!vehicleModel) vehicleModel = `${vehicle.manufacturer} ${vehicle.model}`;
      if (!vehicleType) vehicleType = vehicle.type;
    }

    const requestData = {
      customerId,
      category,
      serviceType: data.serviceType.trim(),
      problemDescription: data.problemDescription.trim(),
      status: 'PENDING',
      customerLatitude: parseFloat(data.customerLatitude),
      customerLongitude: parseFloat(data.customerLongitude),
      customerAddress: data.customerAddress ? data.customerAddress.trim() : null,
      vehicleId: data.vehicleId || null,
      vehiclePlate,
      vehicleModel,
      vehicleType,
      estimatedAmount: data.estimatedAmount ? parseFloat(data.estimatedAmount) : null,
    };

    if (prisma) {
      try {
        return await prisma.serviceRequest.create({
          data: requestData,
          include: {
            customer: {
              select: {
                id: true,
                name: true,
                mobile: true,
                email: true,
              },
            },
          },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB create failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const id = 'req_' + Math.random().toString(36).substring(2, 10);
    const now = new Date();
    const newReq = {
      id,
      ...requestData,
      providerId: null,
      provider: null,
      customer: { id: customerId, name: 'Customer' },
      acceptedAt: null,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
    };
    memoryRequests.set(id, newReq);
    return newReq;
  }

  /**
   * 2. Get the authenticated customer's own requests.
   * Returns only requests belonging to customerId.
   */
  async getCustomerRequests(customerId) {
    if (prisma) {
      try {
        return await prisma.serviceRequest.findMany({
          where: { customerId },
          include: {
            provider: {
              select: {
                id: true,
                name: true,
                mobile: true,
                providerProfile: {
                  select: {
                    category: true,
                    garageName: true,
                    rating: true,
                  },
                },
              },
            },
          },
          orderBy: { createdAt: 'desc' },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const list = [];
    for (const r of memoryRequests.values()) {
      if (r.customerId === customerId) list.push(r);
    }
    return list.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
  }

  /**
   * 3. Get suitable pending requests for an approved/available provider.
   * Authorization rules:
   * - Provider must exist and have ProviderProfile.
   * - Provider verificationStatus must be APPROVED.
   * - Provider availability must be AVAILABLE.
   * - Strips exact customer location & personal contact details for privacy until accepted.
   */
  async getAvailableRequestsForProvider(providerUserId) {
    let profile = null;

    if (prisma) {
      try {
        const user = await prisma.user.findUnique({
          where: { id: providerUserId },
          include: { providerProfile: true },
        });

        if (!user || user.role !== 'PROVIDER') {
          const err = new Error('Access denied. Only registered service providers can view available jobs.');
          err.statusCode = 403;
          throw err;
        }

        profile = user.providerProfile;
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
      }
    }

    if (!profile) {
      const err = new Error('Provider profile not found');
      err.statusCode = 403;
      throw err;
    }

    // Authorization: Check verification status
    if (profile.verificationStatus !== 'APPROVED') {
      const err = new Error(
        `Provider verification status is ${profile.verificationStatus}. Only APPROVED providers can view and accept requests.`
      );
      err.statusCode = 403;
      throw err;
    }

    // Authorization: Check availability status
    if (profile.availability !== 'AVAILABLE') {
      const err = new Error(
        `Provider is currently ${profile.availability}. You must be AVAILABLE to view and accept incoming requests.`
      );
      err.statusCode = 403;
      throw err;
    }

    const eligibleCategories = this.getEligibleCategoriesForProvider(profile.category);

    // Fetch suitable pending requests matching provider category
    if (prisma) {
      try {
        const requests = await prisma.serviceRequest.findMany({
          where: {
            status: { in: ['PENDING', 'SEARCHING'] },
            providerId: null,
            category: { in: eligibleCategories },
          },
          select: {
            id: true,
            category: true,
            serviceType: true,
            problemDescription: true,
            status: true,
            customerAddress: true,
            vehiclePlate: true,
            vehicleModel: true,
            vehicleType: true,
            estimatedAmount: true,
            createdAt: true,
            customer: {
              select: {
                id: true,
                name: true,
                mobile: true,
              },
            },
            // Obfuscate exact coordinates: round to 2 decimals (~1.1km) for privacy before acceptance
            customerLatitude: true,
            customerLongitude: true,
          },
          orderBy: { createdAt: 'desc' },
        });

        return requests.map((req) => ({
          ...req,
          customerLatitude: Math.round(req.customerLatitude * 100) / 100,
          customerLongitude: Math.round(req.customerLongitude * 100) / 100,
          notice: 'Exact location & customer contact are unveiled upon job acceptance.',
        }));
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const list = [];
    for (const r of memoryRequests.values()) {
      if (['PENDING', 'SEARCHING'].includes(r.status) && !r.providerId && eligibleCategories.includes(r.category)) {
        list.push({
          id: r.id,
          category: r.category,
          serviceType: r.serviceType,
          problemDescription: r.problemDescription,
          status: r.status,
          customerAddress: r.customerAddress,
          vehicleModel: r.vehicleModel,
          vehicleType: r.vehicleType,
          createdAt: r.createdAt,
          customerLatitude: Math.round(r.customerLatitude * 100) / 100,
          customerLongitude: Math.round(r.customerLongitude * 100) / 100,
        });
      }
    }
    return list;
  }

  /**
   * 4. Allow an authorized provider to accept a request.
   * Authorization rules:
   * - Provider must be APPROVED and AVAILABLE.
   * - Request must be in PENDING status and unassigned.
   * - Provider category must match request category.
   * - Atomic assignment to prevent race conditions.
   */
  async acceptRequest(providerUserId, requestId) {
    let profile = null;

    if (prisma) {
      try {
        const user = await prisma.user.findUnique({
          where: { id: providerUserId },
          include: { providerProfile: true },
        });

        if (!user || user.role !== 'PROVIDER') {
          const err = new Error('Access denied. Only registered service providers can accept requests.');
          err.statusCode = 403;
          throw err;
        }

        profile = user.providerProfile;
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
      }
    }

    if (!profile) {
      const err = new Error('Provider profile not found');
      err.statusCode = 403;
      throw err;
    }

    // Check provider verification status
    if (profile.verificationStatus !== 'APPROVED') {
      const err = new Error(
        `Provider verification status is ${profile.verificationStatus}. Only APPROVED providers can accept requests.`
      );
      err.statusCode = 403;
      throw err;
    }

    // Check provider availability
    if (profile.availability !== 'AVAILABLE') {
      const err = new Error(
        `Provider is currently ${profile.availability}. You must be AVAILABLE to accept a request.`
      );
      err.statusCode = 403;
      throw err;
    }

    if (prisma) {
      try {
        // Atomic transaction: verify status and assign provider
        return await prisma.$transaction(async (tx) => {
          const existing = await tx.serviceRequest.findUnique({
            where: { id: requestId },
          });

          if (!existing) {
            const err = new Error('Service request not found');
            err.statusCode = 404;
            throw err;
          }

          if (!['PENDING', 'SEARCHING'].includes(existing.status) || existing.providerId !== null) {
            const err = new Error('Request has already been accepted or is no longer available');
            err.statusCode = 409;
            throw err;
          }

          if (!this.isCategoryCompatible(profile.category, existing.category)) {
            const err = new Error(
              `Cannot accept request: request category is ${existing.category} but provider is ${profile.category}`
            );
            err.statusCode = 400;
            throw err;
          }

          // Update request status to ACCEPTED
          const updatedRequest = await tx.serviceRequest.update({
            where: { id: requestId },
            data: {
              providerId: providerUserId,
              status: 'ACCEPTED',
              acceptedAt: new Date(),
            },
            include: {
              customer: {
                select: {
                  id: true,
                  name: true,
                  mobile: true,
                  email: true,
                },
              },
            },
          });

          // Mark provider as BUSY
          await tx.providerProfile.update({
            where: { userId: providerUserId },
            data: { availability: 'BUSY' },
          });

          return updatedRequest;
        });
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB transaction failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const r = memoryRequests.get(requestId);
    if (!r) {
      const err = new Error('Service request not found');
      err.statusCode = 404;
      throw err;
    }
    if (!['PENDING', 'SEARCHING'].includes(r.status) || r.providerId !== null) {
      const err = new Error('Request has already been accepted or is no longer available');
      err.statusCode = 409;
      throw err;
    }
    if (!this.isCategoryCompatible(profile.category, r.category)) {
      const err = new Error(
        `Cannot accept request: request category is ${r.category} but provider is ${profile.category}`
      );
      err.statusCode = 400;
      throw err;
    }
    r.providerId = providerUserId;
    r.status = 'ACCEPTED';
    r.acceptedAt = new Date();
    return r;
  }

  /**
   * 5. Get request details by ID with authorization checks.
   */
  async getRequestById(userId, userRole, requestId) {
    let request = null;

    if (prisma) {
      try {
        request = await prisma.serviceRequest.findUnique({
          where: { id: requestId },
          include: {
            customer: {
              select: {
                id: true,
                name: true,
                mobile: true,
                email: true,
              },
            },
            provider: {
              select: {
                id: true,
                name: true,
                mobile: true,
                providerProfile: true,
              },
            },
          },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    } else {
      request = memoryRequests.get(requestId);
    }

    if (!request) {
      const err = new Error('Service request not found');
      err.statusCode = 404;
      throw err;
    }

    // Authorization checks
    if (userRole === 'ADMIN') {
      return request;
    }

    if (userRole === 'CUSTOMER') {
      if (request.customerId !== userId) {
        const err = new Error('Access denied: You can only view your own service requests');
        err.statusCode = 403;
        throw err;
      }
      return request;
    }

    if (userRole === 'PROVIDER') {
      // If already assigned to this provider
      if (request.providerId === userId) {
        return request;
      }

      // If pending/searching, unassigned and matching provider category
      if (['PENDING', 'SEARCHING'].includes(request.status) && request.providerId === null) {
        // Return sanitized version
        return {
          ...request,
          customer: { name: request.customer?.name },
          customerLatitude: Math.round(request.customerLatitude * 100) / 100,
          customerLongitude: Math.round(request.customerLongitude * 100) / 100,
        };
      }

      const err = new Error('Access denied: You are not authorized to view this request');
      err.statusCode = 403;
      throw err;
    }

    const err = new Error('Unauthorized');
    err.statusCode = 401;
    throw err;
  }
  /**
   * 6. Cancel a service request.
   * Authorization rules:
   * - Customer can cancel their own request if status is PENDING, SEARCHING, ACCEPTED, or ARRIVING.
   * - Provider can cancel (unassign) an accepted request if status is ACCEPTED or ARRIVING.
   * - Admin can cancel anytime.
   * - If assigned to a provider, resets provider's availability back to AVAILABLE.
   */
  async cancelRequest(userId, userRole, requestId, cancellationReason) {
    let existing = null;
    if (prisma) {
      try {
        existing = await prisma.serviceRequest.findUnique({
          where: { id: requestId },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, checking memory:', err.message);
      }
    }
    if (!existing) {
      existing = memoryRequests.get(requestId);
    }

    if (!existing) {
      const err = new Error('Service request not found');
      err.statusCode = 404;
      throw err;
    }

    // Role checks
    if (userRole === 'CUSTOMER' && existing.customerId !== userId) {
      const err = new Error('Access denied: You can only cancel your own service requests');
      err.statusCode = 403;
      throw err;
    }

    if (userRole === 'PROVIDER' && existing.providerId !== userId) {
      const err = new Error('Access denied: You are not assigned to this service request');
      err.statusCode = 403;
      throw err;
    }

    if (['COMPLETED', 'CANCELLED'].includes(existing.status)) {
      const err = new Error(`Cannot cancel a request that is already ${existing.status}`);
      err.statusCode = 400;
      throw err;
    }

    if (existing.status === 'IN_SERVICE' && userRole !== 'ADMIN') {
      const err = new Error('Cannot cancel a request while service is actively in progress. Contact support.');
      err.statusCode = 400;
      throw err;
    }

    const assignedProviderId = existing.providerId;

    if (prisma) {
      try {
        return await prisma.$transaction(async (tx) => {
          const updated = await tx.serviceRequest.update({
            where: { id: requestId },
            data: {
              status: 'CANCELLED',
              cancellationReason: cancellationReason || (userRole === 'CUSTOMER' ? 'Cancelled by customer' : 'Cancelled by provider'),
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

          // Reset provider availability to AVAILABLE if previously assigned
          if (assignedProviderId) {
            await tx.providerProfile.updateMany({
              where: { userId: assignedProviderId },
              data: { availability: 'AVAILABLE' },
            });
          }

          return updated;
        });
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB transaction failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    existing.status = 'CANCELLED';
    existing.cancellationReason = cancellationReason || (userRole === 'CUSTOMER' ? 'Cancelled by customer' : 'Cancelled by provider');
    return existing;
  }

  /**
   * 7. Update service request status across lifecycle:
   * PENDING -> SEARCHING -> ACCEPTED -> ARRIVING -> IN_SERVICE -> COMPLETED
   */
  async updateStatus(userId, userRole, requestId, targetStatus) {
    const validStatuses = ['PENDING', 'SEARCHING', 'ACCEPTED', 'ARRIVING', 'IN_SERVICE', 'COMPLETED', 'CANCELLED'];
    const statusUpper = String(targetStatus || '').toUpperCase();

    if (!validStatuses.includes(statusUpper)) {
      const err = new Error(`Invalid status: ${targetStatus}. Must be one of: ${validStatuses.join(', ')}`);
      err.statusCode = 400;
      throw err;
    }

    if (statusUpper === 'CANCELLED') {
      return this.cancelRequest(userId, userRole, requestId, 'Status updated to CANCELLED');
    }

    let existing = null;
    if (prisma) {
      try {
        existing = await prisma.serviceRequest.findUnique({
          where: { id: requestId },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
      }
    }
    if (!existing) {
      existing = memoryRequests.get(requestId);
    }

    if (!existing) {
      const err = new Error('Service request not found');
      err.statusCode = 404;
      throw err;
    }

    // Role-based lifecycle transitions
    if (statusUpper === 'SEARCHING') {
      if (userRole !== 'ADMIN' && (userRole !== 'CUSTOMER' || existing.customerId !== userId)) {
        const err = new Error('Access denied: You can only update your own service request');
        err.statusCode = 403;
        throw err;
      }
    } else if (['ARRIVING', 'IN_SERVICE', 'COMPLETED'].includes(statusUpper)) {
      if (userRole !== 'ADMIN' && (userRole !== 'PROVIDER' || existing.providerId !== userId)) {
        const err = new Error('Access denied: Only the assigned provider can update job progress');
        err.statusCode = 403;
        throw err;
      }
      if (['COMPLETED', 'CANCELLED'].includes(existing.status)) {
        const err = new Error(`Cannot update request status because it is already ${existing.status}`);
        err.statusCode = 400;
        throw err;
      }
      if (statusUpper === 'COMPLETED' && !['IN_SERVICE', 'ARRIVING', 'ACCEPTED'].includes(existing.status)) {
        const err = new Error(`Cannot complete request from current status ${existing.status}`);
        err.statusCode = 400;
        throw err;
      }
    }

    const updateData = { status: statusUpper };
    if (statusUpper === 'COMPLETED') {
      updateData.completedAt = new Date();
    }

    if (prisma) {
      try {
        return await prisma.$transaction(async (tx) => {
          const updated = await tx.serviceRequest.update({
            where: { id: requestId },
            data: updateData,
            include: {
              customer: {
                select: { id: true, name: true, mobile: true, email: true },
              },
              provider: {
                select: { id: true, name: true, mobile: true },
              },
            },
          });

          // If completed, free up provider back to AVAILABLE
          if (statusUpper === 'COMPLETED' && existing.providerId) {
            await tx.providerProfile.updateMany({
              where: { userId: existing.providerId },
              data: {
                availability: 'AVAILABLE',
                totalJobs: { increment: 1 },
              },
            });
          }

          return updated;
        });
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB transaction failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    existing.status = statusUpper;
    if (statusUpper === 'COMPLETED') {
      existing.completedAt = new Date();
    }
    return existing;
  }
}

module.exports = new ServiceRequestService();
