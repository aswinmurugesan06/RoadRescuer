const express = require('express');
const router = express.Router();

const paymentController = require('../controllers/paymentController');
const { authenticateToken, requireRole } = require('../middleware/auth');

// ── Webhook Route (Public, verified via signature header) ─────────────
// POST /api/payments/webhook
router.post(
  '/webhook',
  paymentController.handleWebhook
);

// ── Customer Gateway Routes ───────────────────────────────────────────

// POST /api/payments/order - Create Razorpay order on server
router.post(
  '/order',
  authenticateToken,
  requireRole('CUSTOMER'),
  paymentController.createOrder
);

// POST /api/payments/verify - Verify Razorpay signature and complete payment
router.post(
  '/verify',
  authenticateToken,
  requireRole('CUSTOMER'),
  paymentController.verifyPayment
);

// POST /api/payments - Customer executes direct payment for bill (Cash, etc.)
router.post(
  '/',
  authenticateToken,
  requireRole('CUSTOMER'),
  paymentController.processPayment
);

// ── Shared Routes ─────────────────────────────────────────────────────

// GET /api/payments/my-payments - Get user's payment history
router.get(
  '/my-payments',
  authenticateToken,
  paymentController.getMyPayments
);

// GET /api/payments/:paymentId/receipt - Get digital receipt by payment ID
router.get(
  '/:paymentId/receipt',
  authenticateToken,
  paymentController.getReceipt
);

// GET /api/payments/request/:requestId/receipt - Get digital receipt by request ID
router.get(
  '/request/:requestId/receipt',
  authenticateToken,
  paymentController.getReceiptByRequestId
);

module.exports = router;
