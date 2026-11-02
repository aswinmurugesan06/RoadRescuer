const pricingService = require('../services/pricingService');

class PricingController {
  /**
   * POST /api/pricing/estimate
   * Authenticated customer requests a real-time dynamic cost estimate.
   */
  async getEstimate(req, res, next) {
    try {
      const {
        category,
        problemCategory,
        vehicleType,
        customerLat,
        customerLng,
        destinationLat,
        destinationLng,
        providerId,
      } = req.body || {};

      if (!category) {
        return res.status(400).json({
          status: 'error',
          message: 'category is required to calculate an estimate.',
        });
      }

      const estimate = await pricingService.calculateEstimate({
        category,
        problemCategory,
        vehicleType,
        customerLat,
        customerLng,
        destinationLat,
        destinationLng,
        providerId,
      });

      return res.status(200).json({
        status: 'success',
        data: estimate,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/admin/pricing-configs
   * Admin lists all platform pricing configurations.
   */
  async listPricingConfigs(req, res, next) {
    try {
      const { category, isActive } = req.query || {};
      const configs = await pricingService.listConfigs({ category, isActive });

      return res.status(200).json({
        status: 'success',
        data: {
          total: configs.length,
          configs,
        },
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/admin/pricing-configs/:id
   * Admin retrieves a specific pricing configuration.
   */
  async getPricingConfigById(req, res, next) {
    try {
      const config = await pricingService.getConfigById(req.params.id);
      return res.status(200).json({
        status: 'success',
        data: config,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/admin/pricing-configs
   * Admin creates a new pricing configuration.
   */
  async createPricingConfig(req, res, next) {
    try {
      const config = await pricingService.createConfig(req.body);
      return res.status(201).json({
        status: 'success',
        message: 'Pricing configuration created successfully',
        data: config,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PUT /api/admin/pricing-configs/:id
   * Admin updates an existing pricing configuration.
   */
  async updatePricingConfig(req, res, next) {
    try {
      const updated = await pricingService.updateConfig(req.params.id, req.body);
      return res.status(200).json({
        status: 'success',
        message: 'Pricing configuration updated successfully',
        data: updated,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PricingController();
