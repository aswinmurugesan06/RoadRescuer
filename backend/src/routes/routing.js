const express = require('express');
const router = express.Router();

const routingController = require('../controllers/routingController');
const { authenticateToken } = require('../middleware/auth');

// Protected routing endpoint
router.get('/directions', authenticateToken, routingController.getDirections);
router.post('/directions', authenticateToken, routingController.getDirections);

module.exports = router;
