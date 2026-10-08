const express = require('express');
const router = express.Router();

const notificationController = require('../controllers/notificationController');
const { authenticateToken } = require('../middleware/auth');

// All notification token management routes require authentication
router.use(authenticateToken);

// POST /api/notifications/tokens - Register / update FCM token
router.post('/tokens', notificationController.registerToken);

// DELETE /api/notifications/tokens/:token - Remove FCM token by URL param
router.delete('/tokens/:token', notificationController.removeToken);

// DELETE /api/notifications/tokens - Remove FCM token by body
router.delete('/tokens', notificationController.removeToken);

// GET /api/notifications/tokens - List user's registered FCM tokens
router.get('/tokens', notificationController.getTokens);

module.exports = router;
