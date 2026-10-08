const billingService = require('../services/billingService');
const notificationService = require('../services/notificationService');
const { emitBillCreated, emitBillStatus } = require('../socket/socketManager');

class BillingController {
  /**
   * POST /api/bills
   * Provider creates or updates invoice.
   */
  async createBill(req, res, next) {
    try {
      const bill = await billingService.createOrUpdateBill(req.user.userId, req.body);

      // Emit real-time bill creation notification
      emitBillCreated(bill);

      // FCM push notification to customer
      notificationService.notifyBillCreated(bill.customerId, bill).catch(() => {});

      return res.status(201).json({
        status: 'success',
        message: 'Bill created and sent to customer successfully',
        data: bill,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/bills/request/:requestId
   * Get bill for a specific service request.
   */
  async getBillByRequestId(req, res, next) {
    try {
      const bill = await billingService.getBillByRequestId(
        req.user.userId,
        req.user.role,
        req.params.requestId
      );
      return res.status(200).json({
        status: 'success',
        data: bill,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/bills/:billId
   * Get bill by billId.
   */
  async getBillById(req, res, next) {
    try {
      const bill = await billingService.getBillById(
        req.user.userId,
        req.user.role,
        req.params.billId
      );
      return res.status(200).json({
        status: 'success',
        data: bill,
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * PATCH /api/bills/:billId/status
   * Customer approves or rejects bill.
   */
  async updateBillStatus(req, res, next) {
    try {
      const { status, rejectionReason } = req.body;
      const bill = await billingService.updateBillStatus(
        req.user.userId,
        req.params.billId,
        status,
        rejectionReason
      );

      // Emit real-time bill status change to provider
      emitBillStatus(bill);

      // FCM push notification to provider when approved
      if (status === 'APPROVED') {
        notificationService.notifyBillApproved(bill.providerId, bill).catch(() => {});
      }

      return res.status(200).json({
        status: 'success',
        message: `Bill ${status.toLowerCase()} successfully`,
        data: bill,
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new BillingController();
