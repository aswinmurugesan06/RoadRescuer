const express = require('express');
const router = express.Router();

const billingController = require('../controllers/billingController');
const { authenticateToken, requireRole } = require('../middleware/auth');

// ── Provider Routes ───────────────────────────────────────────────────

// POST /api/bills - Provider creates or updates invoice
router.post(
  '/',
  authenticateToken,
  requireRole('PROVIDER'),
  billingController.createBill
);

// ── Customer Routes ───────────────────────────────────────────────────

// PATCH /api/bills/:billId/status - Customer approves or rejects bill
router.patch(
  '/:billId/status',
  authenticateToken,
  requireRole('CUSTOMER'),
  billingController.updateBillStatus
);

// ── Shared Routes ─────────────────────────────────────────────────────

// GET /api/bills/request/:requestId - View bill by request ID
router.get(
  '/request/:requestId',
  authenticateToken,
  billingController.getBillByRequestId
);

// GET /api/bills/:billId - View bill by bill ID
router.get(
  '/:billId',
  authenticateToken,
  billingController.getBillById
);

module.exports = router;
