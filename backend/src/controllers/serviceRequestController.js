const serviceRequestService = require('../services/serviceRequestService');
const dispatchService = require('../services/dispatchService');
const notificationService = require('../services/notificationService');
const { prisma } = require('../config/prisma');
const {
  emitNewRequest,
  emitRequestAccepted,
  emitStatusChange,
  emitRequestCancelled,
} = require('../socket/socketManager');

class ServiceRequestController {
  /**
   * POST /api/service-requests
   * Customer creates a roadside assistance request.
   */
  async create(req, res, next) {
    try {
      const result = await serviceRequestService.createRequest(req.user.userId, req.body);

      // Broadcast new request to connected providers
      emitNewRequest(result);

      // Trigger Smart Automatic Dispatch in background
      dispatchService.startDispatch(result.id).catch(() => {});

      return res.status(201).json({
        status: 'success',
        message: 'Roadside assistance request created successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/service-requests/:id/discover
   * Customer/Admin discovers and ranks nearby providers for a request.
   */
  async discoverNearbyProviders(req, res, next) {
    try {
      const radius = req.query.radius ? parseFloat(req.query.radius) : 25.0;
      const result = await dispatchService.discoverAndRankProviders(req.params.id, {
        maxRadiusKm: radius,
      });

      // Obfuscate exact coordinates for client preview
      const sanitizedCandidates = result.candidates.map((c) => ({
        userId: c.userId,
        name: c.name,
        garageName: c.garageName,
        category: c.category,
        distanceKm: c.distanceKm,
        rating: c.rating,
        totalJobs: c.totalJobs,
        score: c.score,
        etaMinutes: c.etaMinutes,
      }));

      return res.status(200).json({
        status: 'success',
        data: {
          requestId: req.params.id,
          searchRadiusKm: result.searchRadiusKm,
          totalFound: sanitizedCandidates.length,
          candidates: sanitizedCandidates,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/service-requests/:id/dispatch
   * Trigger automatic dispatch workflow for a service request.
   */
  async dispatch(req, res, next) {
    try {
      const { timeoutMs, radiusKm } = req.body || {};
      const result = await dispatchService.startDispatch(req.params.id, {
        timeoutMs: timeoutMs ? parseInt(timeoutMs, 10) : undefined,
        initialRadiusKm: radiusKm ? parseFloat(radiusKm) : undefined,
      });

      return res.status(200).json({
        status: 'success',
        message: 'Automatic dispatch initiated',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /api/service-requests/:id/reject
   * Provider rejects an incoming dispatched request -> advances to next candidate.
   */
  async rejectRequest(req, res, next) {
    try {
      const result = await dispatchService.rejectDispatchedRequest(
        req.user.userId,
        req.params.id,
        req.body?.reason
      );

      return res.status(200).json({
        status: 'success',
        message: 'Request rejected. Auto-dispatching to next available candidate.',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/service-requests/my-requests
   * Customer fetches their own service requests.
   */
  async getMyRequests(req, res, next) {
    try {
      const results = await serviceRequestService.getCustomerRequests(req.user.userId);
      return res.status(200).json({
        status: 'success',
        count: results.length,
        data: results,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/service-requests/available
   * Approved & available provider views suitable incoming pending requests.
   */
  async getAvailableRequests(req, res, next) {
    try {
      const results = await serviceRequestService.getAvailableRequestsForProvider(req.user.userId);
      return res.status(200).json({
        status: 'success',
        count: results.length,
        data: results,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /api/service-requests/:id/accept
   * Authorized provider accepts a pending service request.
   */
  async acceptRequest(req, res, next) {
    try {
      // Use atomic accept and clear dispatch tracker
      const result = await dispatchService.acceptDispatchedRequest(req.user.userId, req.params.id);

      return res.status(200).json({
        status: 'success',
        message: 'Service request accepted successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/service-requests/:id
   * Get single service request details with role-based access control.
   */
  async getById(req, res, next) {
    try {
      const result = await serviceRequestService.getRequestById(
        req.user.userId,
        req.user.role,
        req.params.id
      );
      return res.status(200).json({
        status: 'success',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /api/service-requests/:id/cancel
   * Cancel a roadside assistance request.
   */
  async cancelRequest(req, res, next) {
    try {
      const result = await serviceRequestService.cancelRequest(
        req.user.userId,
        req.user.role,
        req.params.id,
        req.body?.cancellationReason
      );

      // Clear any pending dispatch timers
      dispatchService.clearDispatch(req.params.id);

      // Notify all participants
      emitRequestCancelled(
        result.id,
        result.customerId,
        result.providerId,
        result.cancellationReason
      );

      // FCM push notification to the other party
      const targetUserId =
        req.user.userId === result.customerId ? result.providerId : result.customerId;
      if (targetUserId) {
        notificationService
          .notifyRequestCancelled(
            targetUserId,
            result,
            req.user.role === 'CUSTOMER' ? 'Customer' : 'Provider',
            result.cancellationReason
          )
          .catch(() => {});
      }

      return res.status(200).json({
        status: 'success',
        message: 'Service request cancelled successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /api/service-requests/:id/status
   * Update request status (e.g., SEARCHING, ARRIVING, IN_SERVICE, COMPLETED).
   */
  async updateStatus(req, res, next) {
    try {
      const result = await serviceRequestService.updateStatus(
        req.user.userId,
        req.user.role,
        req.params.id,
        req.body?.status
      );

      // Emit status change to all request participants
      emitStatusChange(result.id, result.status, result.customerId);

      // FCM push notification to customer
      if (result.status === 'COMPLETED') {
        notificationService.notifyServiceCompleted(result.customerId, result).catch(() => {});
      } else if (result.status === 'ARRIVING' || result.status === 'IN_SERVICE') {
        notificationService
          .notifyRequestStatusChanged(result.customerId, result, result.status)
          .catch(() => {});
      }

      return res.status(200).json({
        status: 'success',
        message: `Service request status updated to ${req.body?.status}`,
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ServiceRequestController();
