const express = require('express');
const router = express.Router();

const providerController = require('../controllers/providerController');
const { authenticateToken, requireRole } = require('../middleware/auth');

// ── Provider-only routes ──────────────────────────────────────────────

// GET /api/providers/profile — Get own profile
router.get(
  '/profile',
  authenticateToken,
  requireRole('PROVIDER'),
  providerController.getProfile
);

// PATCH /api/providers/profile — Update garageName, businessAddress, serviceRadiusKm, category
router.patch(
  '/profile',
  authenticateToken,
  requireRole('PROVIDER'),
  providerController.updateProfile
);

// PATCH /api/providers/availability — Set OFFLINE or AVAILABLE (BUSY is system-controlled)
router.patch(
  '/availability',
  authenticateToken,
  requireRole('PROVIDER'),
  providerController.setAvailability
);

// PATCH /api/providers/location & /api/providers/me/location — Update GPS position
router.patch(
  '/location',
  authenticateToken,
  requireRole('PROVIDER'),
  providerController.updateLocation
);
router.patch(
  '/me/location',
  authenticateToken,
  requireRole('PROVIDER'),
  providerController.updateLocation
);

// GET /api/providers/my-requests — Get all requests assigned to this provider
router.get(
  '/my-requests',
  authenticateToken,
  requireRole('PROVIDER'),
  providerController.getMyRequests
);

// GET /api/providers/earnings — Get real earnings, commission, and payment history
router.get(
  '/earnings',
  authenticateToken,
  requireRole('PROVIDER'),
  providerController.getEarnings
);

// ── Admin-only routes ─────────────────────────────────────────────────

// PATCH /api/providers/:providerId/verification — Admin approves/rejects/suspends provider
router.patch(
  '/:providerId/verification',
  authenticateToken,
  requireRole('ADMIN'),
  providerController.adminSetVerificationStatus
);

module.exports = router;
