const express = require('express');
const router = express.Router();

const adminController = require('../controllers/adminController');
const pricingController = require('../controllers/pricingController');
const { authenticateToken, requireRole } = require('../middleware/auth');

// Apply ADMIN authentication and authorization guards to ALL admin routes
router.use(authenticateToken);
router.use(requireRole('ADMIN'));

// ── Dashboard Statistics ───────────────────────────────────────────────
router.get('/stats', adminController.getDashboardStats);

// ── Provider Verification & Management ─────────────────────────────────
router.get('/providers', adminController.listProviders);
router.get('/providers/:providerId', adminController.getProviderDetails);
router.patch('/providers/:providerId/verification', adminController.updateProviderVerification);

// ── Platform Users ─────────────────────────────────────────────────────
router.get('/users', adminController.listUsers);

// ── Service Requests ───────────────────────────────────────────────────
router.get('/service-requests', adminController.listServiceRequests);

// ── Billing & Payments ─────────────────────────────────────────────────
router.get('/bills', adminController.listBills);
router.get('/payments', adminController.listPayments);

// ── Ratings & Reviews Moderation ───────────────────────────────────────
router.get('/ratings', adminController.listRatings);
router.delete('/ratings/:ratingId', adminController.deleteRating);

// ── Pricing Configuration ──────────────────────────────────────────────
router.get('/pricing-configs', pricingController.listPricingConfigs);
router.get('/pricing-configs/:id', pricingController.getPricingConfigById);
router.post('/pricing-configs', pricingController.createPricingConfig);
router.put('/pricing-configs/:id', pricingController.updatePricingConfig);

module.exports = router;
