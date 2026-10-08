const express = require('express');
const router = express.Router();

const ratingController = require('../controllers/ratingController');
const { authenticateToken, requireRole } = require('../middleware/auth');

// POST /api/ratings - Customer submits a rating & review
router.post(
  '/',
  authenticateToken,
  requireRole('CUSTOMER'),
  ratingController.submitRating
);

// GET /api/ratings/me - View own submitted/received ratings
router.get(
  '/me',
  authenticateToken,
  ratingController.getMyRatings
);

// GET /api/ratings/request/:requestId - View rating for a specific request
router.get(
  '/request/:requestId',
  authenticateToken,
  ratingController.getRatingByRequestId
);

// GET /api/ratings/provider/:providerId - View ratings and reviews for a provider
router.get(
  '/provider/:providerId',
  authenticateToken,
  ratingController.getProviderRatings
);

module.exports = router;
