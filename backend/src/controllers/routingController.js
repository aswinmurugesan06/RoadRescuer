const routingService = require('../services/routingService');

class RoutingController {
  /**
   * GET /api/routing/directions
   * POST /api/routing/directions
   * Get route geometry, distance, and ETA between origin and destination coordinates.
   */
  async getDirections(req, res, next) {
    try {
      const originLat = req.query.originLat || req.body?.originLat;
      const originLng = req.query.originLng || req.body?.originLng;
      const destLat = req.query.destLat || req.body?.destLat;
      const destLng = req.query.destLng || req.body?.destLng;

      if (originLat === undefined || originLng === undefined || destLat === undefined || destLng === undefined) {
        const error = new Error('originLat, originLng, destLat, and destLng are required');
        error.statusCode = 400;
        throw error;
      }

      const route = await routingService.getDirections({
        originLat,
        originLng,
        destLat,
        destLng,
      });

      return res.status(200).json({
        status: 'success',
        data: route,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new RoutingController();
