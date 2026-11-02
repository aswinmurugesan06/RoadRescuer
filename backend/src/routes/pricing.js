const express = require('express');
const router = express.Router();
const pricingController = require('../controllers/pricingController');
const { authenticateToken } = require('../middleware/auth');

// POST /api/pricing/estimate - Calculate dynamic cost estimate
router.post('/estimate', authenticateToken, pricingController.getEstimate);

module.exports = router;
