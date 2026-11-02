const providerService = require('../services/providerService');

/**
 * GET /api/providers/profile
 * Returns the authenticated provider's profile.
 */
async function getProfile(req, res, next) {
  try {
    const profile = await providerService.getProfile(req.user.userId);
    res.json({ status: 'success', data: profile });
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/providers/profile
 * Update garageName, businessAddress, serviceRadiusKm, or category.
 */
async function updateProfile(req, res, next) {
  try {
    const updated = await providerService.updateProfile(req.user.userId, req.body);
    res.json({ status: 'success', data: updated });
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/providers/availability
 * Set availability: OFFLINE or AVAILABLE.
 * Body: { availability: 'OFFLINE' | 'AVAILABLE' }
 */
async function setAvailability(req, res, next) {
  try {
    const { availability } = req.body;
    if (!availability) {
      return res.status(400).json({
        status: 'error',
        message: 'availability field is required (OFFLINE or AVAILABLE)',
      });
    }
    const updated = await providerService.setAvailability(req.user.userId, availability);
    res.json({ status: 'success', data: updated });
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/providers/location
 * Update the provider's last known GPS position.
 * Body: { latitude: number, longitude: number }
 */
async function updateLocation(req, res, next) {
  try {
    const { latitude, longitude } = req.body;
    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        status: 'error',
        message: 'latitude and longitude are required',
      });
    }
    const updated = await providerService.updateLocation(req.user.userId, latitude, longitude);
    res.json({ status: 'success', data: updated });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/providers/my-requests
 * Returns all service requests assigned to this provider.
 */
async function getMyRequests(req, res, next) {
  try {
    const { status } = req.query;
    const requests = await providerService.getMyRequests(req.user.userId, { status });
    res.json({ status: 'success', data: requests });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/providers/history
 * Returns completed service requests for the authenticated provider.
 */
async function getJobHistory(req, res, next) {
  try {
    const history = await providerService.getJobHistory(req.user.userId);
    res.json({ status: 'success', data: history });
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/providers/:providerId/verification  (Admin only)
 * Set provider verificationStatus.
 * Body: { verificationStatus: 'APPROVED' | 'REJECTED' | 'SUSPENDED' | 'PENDING' }
 */
async function adminSetVerificationStatus(req, res, next) {
  try {
    const { verificationStatus } = req.body;
    if (!verificationStatus) {
      return res.status(400).json({
        status: 'error',
        message: 'verificationStatus is required',
      });
    }
    const updated = await providerService.adminSetVerificationStatus(
      req.params.providerId,
      verificationStatus,
      req.user.userId
    );
    res.json({ status: 'success', data: updated });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/providers/earnings
 * Returns calculated earnings, commission, and payment history for the authenticated provider.
 */
async function getEarnings(req, res, next) {
  try {
    const earnings = await providerService.getEarnings(req.user.userId);
    res.json({ status: 'success', data: earnings });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  getProfile,
  updateProfile,
  setAvailability,
  updateLocation,
  getMyRequests,
  getJobHistory,
  adminSetVerificationStatus,
  getEarnings,
};
