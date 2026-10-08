const ratingService = require('../services/ratingService');
const notificationService = require('../services/notificationService');

class RatingController {
  /**
   * POST /api/ratings
   * Submit a rating and review for a completed service request.
   */
  async submitRating(req, res, next) {
    try {
      const { requestId, score, review } = req.body;
      const customerId = req.user.userId || req.user.id;
      const userRole = req.user.role;

      const rating = await ratingService.submitRating({
        customerId,
        userRole,
        requestId,
        score,
        review,
      });

      // FCM push notification to provider
      if (rating.providerId) {
        notificationService.notifyRatingReceived(rating.providerId, rating).catch(() => {});
      }

      return res.status(201).json({
        success: true,
        message: 'Rating and review submitted successfully',
        data: rating,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/ratings/request/:requestId
   * Get rating for a specific service request.
   */
  async getRatingByRequestId(req, res, next) {
    try {
      const { requestId } = req.params;
      const userId = req.user.userId || req.user.id;
      const userRole = req.user.role;

      const rating = await ratingService.getRatingByRequestId(userId, userRole, requestId);

      return res.status(200).json({
        success: true,
        data: rating,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/ratings/provider/:providerId
   * Get ratings and reviews for a provider.
   */
  async getProviderRatings(req, res, next) {
    try {
      const { providerId } = req.params;
      const { page, limit } = req.query;

      const result = await ratingService.getProviderRatings(providerId, page, limit);

      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/ratings/me
   * Get own submitted or received ratings.
   */
  async getMyRatings(req, res, next) {
    try {
      const userId = req.user.userId || req.user.id;
      const userRole = req.user.role;
      const { page, limit } = req.query;

      const result = await ratingService.getMyRatings(userId, userRole, page, limit);

      return res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}

module.exports = new RatingController();
