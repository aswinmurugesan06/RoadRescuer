const adminService = require('../services/adminService');

class AdminController {
  /**
   * GET /api/admin/stats
   */
  async getDashboardStats(req, res, next) {
    try {
      const stats = await adminService.getDashboardStats();
      return res.status(200).json({
        success: true,
        data: stats,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/admin/providers
   */
  async listProviders(req, res, next) {
    try {
      const { status, category, search, page, limit } = req.query;
      const result = await adminService.listProviders({ status, category, search, page, limit });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/admin/providers/:providerId
   */
  async getProviderDetails(req, res, next) {
    try {
      const { providerId } = req.params;
      const provider = await adminService.getProviderDetails(providerId);
      return res.status(200).json({
        success: true,
        data: provider,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * PATCH /api/admin/providers/:providerId/verification
   */
  async updateProviderVerification(req, res, next) {
    try {
      const { providerId } = req.params;
      const { verificationStatus, reason } = req.body;
      const result = await adminService.updateProviderVerification(providerId, {
        verificationStatus,
        reason,
      });
      return res.status(200).json({
        success: true,
        message: `Provider verification status updated to ${verificationStatus}`,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/admin/users
   */
  async listUsers(req, res, next) {
    try {
      const { role, search, page, limit } = req.query;
      const result = await adminService.listUsers({ role, search, page, limit });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/admin/service-requests
   */
  async listServiceRequests(req, res, next) {
    try {
      const { status, category, search, page, limit } = req.query;
      const result = await adminService.listServiceRequests({ status, category, search, page, limit });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/admin/bills
   */
  async listBills(req, res, next) {
    try {
      const { status, page, limit } = req.query;
      const result = await adminService.listBills({ status, page, limit });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/admin/payments
   */
  async listPayments(req, res, next) {
    try {
      const { status, method, page, limit } = req.query;
      const result = await adminService.listPayments({ status, method, page, limit });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/admin/ratings
   */
  async listRatings(req, res, next) {
    try {
      const { minScore, maxScore, providerId, page, limit } = req.query;
      const result = await adminService.listRatings({ minScore, maxScore, providerId, page, limit });
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * DELETE /api/admin/ratings/:ratingId
   */
  async deleteRating(req, res, next) {
    try {
      const { ratingId } = req.params;
      const result = await adminService.deleteRating(ratingId);
      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new AdminController();
