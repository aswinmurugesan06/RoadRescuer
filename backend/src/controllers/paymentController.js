const paymentService = require('../services/paymentService');
const notificationService = require('../services/notificationService');
const { emitPaymentSuccess } = require('../socket/socketManager');

class PaymentController {
  /**
   * POST /api/payments/order
   * Create Razorpay order on backend for a bill.
   */
  async createOrder(req, res, next) {
    try {
      const order = await paymentService.createOrder(req.user.userId, req.body);
      return res.status(201).json({
        status: 'success',
        message: 'Payment order created successfully',
        data: order,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/payments/verify
   * Verify Razorpay payment signature and complete payment.
   */
  async verifyPayment(req, res, next) {
    try {
      const result = await paymentService.verifyPayment(req.user.userId, req.body);

      // Emit real-time payment success event
      emitPaymentSuccess(result.payment, result.bill);

      // FCM push notification to customer & provider
      notificationService
        .notifyPaymentSuccess(
          result.bill.customerId,
          result.bill.providerId,
          result.payment,
          result.bill
        )
        .catch(() => {});

      return res.status(200).json({
        status: 'success',
        message: 'Payment verified and completed successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/payments/webhook
   * Handle Razorpay Webhooks (order.paid, payment.captured, payment.failed).
   */
  async handleWebhook(req, res, next) {
    try {
      const signature = req.headers['x-razorpay-signature'];
      const result = await paymentService.handleWebhook(req.body, signature);
      return res.status(200).json({
        status: 'success',
        message: 'Webhook processed successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/payments
   * Customer pays a bill directly (e.g. cash on service or direct completion).
   */
  async processPayment(req, res, next) {
    try {
      const result = await paymentService.processPayment(req.user.userId, req.body);

      // Emit real-time payment success event
      emitPaymentSuccess(result.payment, result.bill);

      // FCM push notification to customer & provider
      notificationService
        .notifyPaymentSuccess(
          result.bill.customerId,
          result.bill.providerId,
          result.payment,
          result.bill
        )
        .catch(() => {});

      return res.status(200).json({
        status: 'success',
        message: 'Payment completed successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/payments/:paymentId/receipt
   * Get digital receipt by payment ID.
   */
  async getReceipt(req, res, next) {
    try {
      const receipt = await paymentService.getReceiptByPaymentId(
        req.user.userId,
        req.user.role,
        req.params.paymentId
      );
      return res.status(200).json({
        status: 'success',
        data: receipt,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/payments/request/:requestId/receipt
   * Get receipt by request ID.
   */
  async getReceiptByRequestId(req, res, next) {
    try {
      const receipt = await paymentService.getReceiptByRequestId(
        req.user.userId,
        req.user.role,
        req.params.requestId
      );
      return res.status(200).json({
        status: 'success',
        data: receipt,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/payments/my-payments
   * Get authenticated user's payment history.
   */
  async getMyPayments(req, res, next) {
    try {
      const payments = await paymentService.getMyPayments(
        req.user.userId,
        req.user.role
      );
      return res.status(200).json({
        status: 'success',
        count: payments.length,
        data: payments,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new PaymentController();
