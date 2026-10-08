const express = require('express');
const router = express.Router();

const authController = require('../controllers/authController');
const {
  validateRegister,
  validateLogin,
  validateSendOtp,
  validateVerifyOtp,
  validateForgotPassword,
  validateResetPassword,
} = require('../middleware/validator');
const { authenticateToken, requireRole } = require('../middleware/auth');

// ── Public Authentication Endpoints ───────────────────────────────────

// POST /api/auth/register
router.post('/register', validateRegister, authController.register);

// POST /api/auth/login
router.post('/login', validateLogin, authController.login);

// POST /api/auth/send-otp
router.post('/send-otp', validateSendOtp, authController.sendOtp);

// POST /api/auth/verify-otp
router.post('/verify-otp', validateVerifyOtp, authController.verifyOtp);

// POST /api/auth/forgot-password
router.post('/forgot-password', validateForgotPassword, authController.forgotPassword);

// POST /api/auth/reset-password
router.post('/reset-password', validateResetPassword, authController.resetPassword);

// ── Protected User & Role Verification Endpoints ──────────────────────

// GET /api/auth/me (authenticated user profile)
router.get('/me', authenticateToken, authController.getMe);

// Role-enforced testing endpoints
router.get('/customer-only', authenticateToken, requireRole('CUSTOMER'), (req, res) => {
  res.json({ status: 'success', message: 'Welcome to Customer area', user: req.user });
});

router.get('/provider-only', authenticateToken, requireRole('PROVIDER'), (req, res) => {
  res.json({ status: 'success', message: 'Welcome to Provider area', user: req.user });
});

router.get('/admin-only', authenticateToken, requireRole('ADMIN'), (req, res) => {
  res.json({ status: 'success', message: 'Welcome to Admin area', user: req.user });
});

module.exports = router;
