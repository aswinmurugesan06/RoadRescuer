const express = require('express');
const router = express.Router();

const serviceRequestController = require('../controllers/serviceRequestController');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { validateCreateServiceRequest } = require('../middleware/validator');

// ── Customer Routes ───────────────────────────────────────────────────

// POST /api/service-requests - Create a roadside assistance request
router.post(
  '/',
  authenticateToken,
  requireRole('CUSTOMER'),
  validateCreateServiceRequest,
  serviceRequestController.create
);

// GET /api/service-requests/my-requests - Get authenticated customer's requests
router.get(
  '/my-requests',
  authenticateToken,
  requireRole('CUSTOMER'),
  serviceRequestController.getMyRequests
);

// GET /api/service-requests/:id/discover - Discover and rank nearby providers
router.get(
  '/:id/discover',
  authenticateToken,
  serviceRequestController.discoverNearbyProviders
);

// POST /api/service-requests/:id/dispatch - Trigger automatic dispatch
router.post(
  '/:id/dispatch',
  authenticateToken,
  serviceRequestController.dispatch
);

// ── Provider Routes ───────────────────────────────────────────────────

// GET /api/service-requests/available - Get suitable pending requests for approved/available provider
router.get(
  '/available',
  authenticateToken,
  requireRole('PROVIDER'),
  serviceRequestController.getAvailableRequests
);

// PATCH /api/service-requests/:id/accept - Authorized provider accepts a request
router.patch(
  '/:id/accept',
  authenticateToken,
  requireRole('PROVIDER'),
  serviceRequestController.acceptRequest
);

// PATCH /api/service-requests/:id/reject - Provider rejects candidate request
router.patch(
  '/:id/reject',
  authenticateToken,
  requireRole('PROVIDER'),
  serviceRequestController.rejectRequest
);

// ── Shared/Details Route ──────────────────────────────────────────────

// GET /api/service-requests/:id - View single request with role-based access control
router.get(
  '/:id',
  authenticateToken,
  serviceRequestController.getById
);

// PATCH /api/service-requests/:id/cancel - Cancel request (Customer/Provider/Admin)
router.patch(
  '/:id/cancel',
  authenticateToken,
  serviceRequestController.cancelRequest
);

// PATCH /api/service-requests/:id/status - Update request status across lifecycle
router.patch(
  '/:id/status',
  authenticateToken,
  serviceRequestController.updateStatus
);

module.exports = router;
