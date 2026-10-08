const notificationService = require('../services/notificationService');

class NotificationController {
  /**
   * POST /api/notifications/tokens
   * Register or update FCM device token for authenticated user.
   */
  async registerToken(req, res, next) {
    try {
      const { token, deviceType } = req.body;
      const deviceToken = await notificationService.registerToken(req.user.userId, {
        token,
        deviceType,
      });

      return res.status(201).json({
        status: 'success',
        message: 'Device token registered successfully',
        data: deviceToken,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * DELETE /api/notifications/tokens/:token
   * DELETE /api/notifications/tokens (with body: { token })
   * Remove FCM device token for authenticated user.
   */
  async removeToken(req, res, next) {
    try {
      const token = req.params.token || req.body?.token;
      const result = await notificationService.removeToken(req.user.userId, token);

      return res.status(200).json({
        status: 'success',
        message: 'Device token removed successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/notifications/tokens
   * Get all registered device tokens for authenticated user.
   */
  async getTokens(req, res, next) {
    try {
      const tokens = await notificationService.getUserTokens(req.user.userId);
      return res.status(200).json({
        status: 'success',
        data: tokens,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new NotificationController();
