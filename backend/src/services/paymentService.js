const crypto = require('crypto');
const Razorpay = require('razorpay');
const { prisma } = require('../config/prisma');

class PaymentService {
  /**
   * Initialize Razorpay client with environment credentials.
   */
  _getRazorpayInstance() {
    const key_id = process.env.RAZORPAY_KEY_ID || 'rzp_test_roadrescue';
    const key_secret = process.env.RAZORPAY_KEY_SECRET || 'rzp_test_secret_key';
    return {
      client: new Razorpay({ key_id, key_secret }),
      keyId: key_id,
      keySecret: key_secret,
    };
  }

  /**
   * Create a Razorpay Order for a customer bill.
   * Calculates order amount strictly from the server-side DB bill record in paise (1 INR = 100 paise).
   */
  async createOrder(customerUserId, data) {
    const { billId } = data;

    if (!billId || typeof billId !== 'string') {
      const error = new Error('Valid billId is required');
      error.statusCode = 400;
      throw error;
    }

    const bill = await prisma.bill.findUnique({
      where: { id: billId },
      include: {
        payment: true,
        serviceRequest: true,
        customer: {
          select: { id: true, name: true, mobile: true, email: true },
        },
        provider: {
          select: { id: true, name: true, mobile: true, email: true },
        },
      },
    });

    if (!bill) {
      const error = new Error('Bill not found');
      error.statusCode = 404;
      throw error;
    }

    if (bill.customerId !== customerUserId) {
      const error = new Error('You are not authorized to create a payment order for this bill');
      error.statusCode = 403;
      throw error;
    }

    if (bill.status === 'PAID') {
      const error = new Error('This bill has already been paid');
      error.statusCode = 400;
      throw error;
    }

    if (bill.status === 'REJECTED') {
      const error = new Error('Cannot pay a rejected bill. Please request a revised invoice from the provider.');
      error.statusCode = 400;
      throw error;
    }

    // Amount strictly calculated from server DB in paise (1 INR = 100 paise)
    const amountPaise = Math.round(bill.grandTotal * 100);
    const { keyId, keySecret } = this._getRazorpayInstance();

    let orderId;
    if (process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET && !process.env.RAZORPAY_KEY_ID.startsWith('rzp_test_roadrescue')) {
      try {
        const rzp = new Razorpay({ key_id: keyId, key_secret: keySecret });
        const rzpOrder = await rzp.orders.create({
          amount: amountPaise,
          currency: 'INR',
          receipt: `RCPT-${bill.id.slice(0, 30)}`,
          notes: {
            billId: bill.id,
            customerId: customerUserId,
            requestId: bill.requestId,
          },
        });
        orderId = rzpOrder.id;
      } catch (err) {
        orderId = `order_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
      }
    } else {
      orderId = `order_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    }

    // Upsert Payment record with PENDING / PROCESSING status and gatewayOrderId
    await prisma.$transaction(async (tx) => {
      if (bill.payment) {
        await tx.payment.update({
          where: { id: bill.payment.id },
          data: {
            amount: bill.grandTotal,
            status: 'PENDING',
            gateway: 'RAZORPAY',
            gatewayOrderId: orderId,
            transactionId: orderId,
            failureReason: null,
          },
        });
      } else {
        await tx.payment.create({
          data: {
            billId: bill.id,
            requestId: bill.requestId,
            customerId: customerUserId,
            providerId: bill.providerId,
            amount: bill.grandTotal,
            status: 'PENDING',
            gateway: 'RAZORPAY',
            gatewayOrderId: orderId,
            transactionId: orderId,
          },
        });
      }
    });

    return {
      orderId,
      amount: amountPaise,
      currency: 'INR',
      keyId,
      billId: bill.id,
      grandTotal: bill.grandTotal,
      customer: {
        id: bill.customer.id,
        name: bill.customer.name,
        email: bill.customer.email,
        mobile: bill.customer.mobile,
      },
    };
  }

  /**
   * Verify Razorpay Payment Signature and finalize transaction.
   */
  async verifyPayment(customerUserId, data) {
    const {
      billId,
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      method = 'UPI',
    } = data;

    if (!billId || !razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      const error = new Error('billId, razorpay_order_id, razorpay_payment_id, and razorpay_signature are required');
      error.statusCode = 400;
      throw error;
    }

    const bill = await prisma.bill.findUnique({
      where: { id: billId },
      include: {
        payment: true,
        serviceRequest: true,
        items: true,
        customer: {
          select: { id: true, name: true, mobile: true, email: true },
        },
        provider: {
          select: { id: true, name: true, mobile: true, email: true },
        },
      },
    });

    if (!bill) {
      const error = new Error('Bill not found');
      error.statusCode = 404;
      throw error;
    }

    if (bill.customerId !== customerUserId) {
      const error = new Error('You are not authorized to verify payment for this bill');
      error.statusCode = 403;
      throw error;
    }

    // Idempotency check: if bill is already PAID with same payment ID, return receipt
    if (bill.status === 'PAID') {
      if (bill.payment && bill.payment.gatewayPaymentId === razorpay_payment_id) {
        return {
          payment: bill.payment,
          bill,
          receipt: this._formatReceipt(bill.payment, bill),
        };
      }
      const error = new Error('This bill has already been paid');
      error.statusCode = 400;
      throw error;
    }

    // Verify Razorpay HMAC-SHA256 signature
    const { keySecret } = this._getRazorpayInstance();
    const text = `${razorpay_order_id}|${razorpay_payment_id}`;
    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(text)
      .digest('hex');

    if (expectedSignature !== razorpay_signature) {
      // Record failed verification on payment record if exists
      if (bill.payment) {
        await prisma.payment.update({
          where: { id: bill.payment.id },
          data: {
            status: 'FAILED',
            failureReason: 'Invalid Razorpay signature verification',
            gatewayOrderId: razorpay_order_id,
            gatewayPaymentId: razorpay_payment_id,
            gatewaySignature: razorpay_signature,
          },
        });
      }
      const error = new Error('Invalid payment signature');
      error.statusCode = 400;
      throw error;
    }

    // Generate receipt number
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const receiptNumber = `RR-RCPT-${dateStr}-${Math.floor(1000 + Math.random() * 9000)}`;
    const paidAt = new Date();
    const amount = bill.grandTotal;

    const result = await prisma.$transaction(async (tx) => {
      // 1. Update or create payment
      let payment;
      if (bill.payment) {
        payment = await tx.payment.update({
          where: { id: bill.payment.id },
          data: {
            amount,
            method: method === 'CASH' ? 'CASH' : (method === 'CARD' ? 'CARD' : 'UPI'),
            status: 'COMPLETED',
            transactionId: razorpay_payment_id,
            receiptNumber,
            paidAt,
            gateway: 'RAZORPAY',
            gatewayOrderId: razorpay_order_id,
            gatewayPaymentId: razorpay_payment_id,
            gatewaySignature: razorpay_signature,
            failureReason: null,
          },
        });
      } else {
        payment = await tx.payment.create({
          data: {
            billId: bill.id,
            requestId: bill.requestId,
            customerId: customerUserId,
            providerId: bill.providerId,
            amount,
            method: method === 'CASH' ? 'CASH' : (method === 'CARD' ? 'CARD' : 'UPI'),
            status: 'COMPLETED',
            transactionId: razorpay_payment_id,
            receiptNumber,
            paidAt,
            gateway: 'RAZORPAY',
            gatewayOrderId: razorpay_order_id,
            gatewayPaymentId: razorpay_payment_id,
            gatewaySignature: razorpay_signature,
          },
        });
      }

      // 2. Update Bill status to PAID
      const updatedBill = await tx.bill.update({
        where: { id: bill.id },
        data: { status: 'PAID' },
        include: {
          items: true,
          serviceRequest: true,
          customer: {
            select: { id: true, name: true, mobile: true, email: true },
          },
          provider: {
            select: { id: true, name: true, mobile: true, email: true },
          },
        },
      });

      // 3. Mark service request as COMPLETED
      await tx.serviceRequest.update({
        where: { id: bill.requestId },
        data: {
          status: 'COMPLETED',
          completedAt: paidAt,
          finalAmount: amount,
        },
      });

      // 4. Update provider statistics & make provider available
      await tx.providerProfile.updateMany({
        where: { userId: bill.providerId },
        data: {
          totalJobs: { increment: 1 },
          availability: 'AVAILABLE',
        },
      });

      return { payment, bill: updatedBill };
    });

    const receipt = this._formatReceipt(result.payment, result.bill);

    return {
      payment: result.payment,
      bill: result.bill,
      receipt,
    };
  }

  /**
   * Handle Razorpay Webhook notification.
   * Validates webhook signature and idempotently updates payment/bill.
   */
  async handleWebhook(rawBody, signature) {
    if (!signature) {
      const error = new Error('Missing Razorpay webhook signature');
      error.statusCode = 400;
      throw error;
    }

    const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || 'rzp_webhook_secret';
    const bodyStr = typeof rawBody === 'string' ? rawBody : JSON.stringify(rawBody);

    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(bodyStr)
      .digest('hex');

    if (expectedSignature !== signature) {
      const error = new Error('Invalid webhook signature');
      error.statusCode = 400;
      throw error;
    }

    const payload = typeof rawBody === 'string' ? JSON.parse(rawBody) : rawBody;
    const event = payload.event;

    if (event === 'payment.captured' || event === 'order.paid') {
      const paymentEntity = payload.payload?.payment?.entity;
      const orderId = paymentEntity?.order_id || payload.payload?.order?.entity?.id;
      const paymentId = paymentEntity?.id;

      if (orderId) {
        const paymentRecord = await prisma.payment.findFirst({
          where: { gatewayOrderId: orderId },
          include: {
            bill: {
              include: {
                items: true,
                serviceRequest: true,
                customer: { select: { id: true, name: true, mobile: true, email: true } },
                provider: { select: { id: true, name: true, mobile: true, email: true } },
              },
            },
          },
        });

        if (paymentRecord && paymentRecord.status !== 'COMPLETED') {
          const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
          const receiptNumber = paymentRecord.receiptNumber || `RR-RCPT-${dateStr}-${Math.floor(1000 + Math.random() * 9000)}`;
          const paidAt = new Date();

          await prisma.$transaction(async (tx) => {
            await tx.payment.update({
              where: { id: paymentRecord.id },
              data: {
                status: 'COMPLETED',
                transactionId: paymentId || paymentRecord.transactionId,
                gatewayPaymentId: paymentId || paymentRecord.gatewayPaymentId,
                receiptNumber,
                paidAt,
                failureReason: null,
              },
            });

            await tx.bill.update({
              where: { id: paymentRecord.billId },
              data: { status: 'PAID' },
            });

            await tx.serviceRequest.update({
              where: { id: paymentRecord.requestId },
              data: {
                status: 'COMPLETED',
                completedAt: paidAt,
                finalAmount: paymentRecord.amount,
              },
            });

            await tx.providerProfile.updateMany({
              where: { userId: paymentRecord.providerId },
              data: {
                totalJobs: { increment: 1 },
                availability: 'AVAILABLE',
              },
            });
          });
        }
      }
    } else if (event === 'payment.failed') {
      const paymentEntity = payload.payload?.payment?.entity;
      const orderId = paymentEntity?.order_id;
      const failureReason = paymentEntity?.error_description || 'Payment failed';

      if (orderId) {
        await prisma.payment.updateMany({
          where: { gatewayOrderId: orderId, status: { not: 'COMPLETED' } },
          data: {
            status: 'FAILED',
            failureReason,
          },
        });
      }
    }

    return { received: true, event };
  }

  /**
   * Process a direct customer payment for a bill (e.g. Cash / Direct simulation).
   * Never trusts payment amount from client — uses DB bill.grandTotal.
   */
  async processPayment(customerUserId, data) {
    const { billId, method = 'UPI' } = data;

    if (!billId || typeof billId !== 'string') {
      const error = new Error('Valid billId is required');
      error.statusCode = 400;
      throw error;
    }

    const validMethods = ['UPI', 'CARD', 'CASH', 'NET_BANKING'];
    if (!validMethods.includes(method)) {
      const error = new Error(`Invalid payment method. Allowed: ${validMethods.join(', ')}`);
      error.statusCode = 400;
      throw error;
    }

    const bill = await prisma.bill.findUnique({
      where: { id: billId },
      include: {
        payment: true,
        serviceRequest: true,
        items: true,
        customer: {
          select: { id: true, name: true, mobile: true, email: true },
        },
        provider: {
          select: { id: true, name: true, mobile: true, email: true },
        },
      },
    });

    if (!bill) {
      const error = new Error('Bill not found');
      error.statusCode = 404;
      throw error;
    }

    if (bill.customerId !== customerUserId) {
      const error = new Error('You are not authorized to pay this bill');
      error.statusCode = 403;
      throw error;
    }

    if (bill.status === 'PAID') {
      const error = new Error('This bill has already been paid');
      error.statusCode = 400;
      throw error;
    }

    if (bill.status === 'REJECTED') {
      const error = new Error('Cannot pay a rejected bill. Please request a revised invoice from the provider.');
      error.statusCode = 400;
      throw error;
    }

    if (bill.payment && bill.payment.status === 'COMPLETED') {
      const error = new Error('Payment already completed for this bill');
      error.statusCode = 400;
      throw error;
    }

    // Amount is strictly taken from the DB record
    const amount = bill.grandTotal;

    // Generate unique transaction ID and receipt number
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const randomHex = Math.random().toString(36).substring(2, 7).toUpperCase();
    const transactionId = `TXN-${Date.now()}-${randomHex}`;
    const receiptNumber = `RR-RCPT-${dateStr}-${Math.floor(1000 + Math.random() * 9000)}`;

    const paidAt = new Date();

    // Atomic execution of payment confirmation, bill update, service request completion, and provider stats
    const result = await prisma.$transaction(async (tx) => {
      // 1. Create or update payment record
      let payment;
      if (bill.payment) {
        payment = await tx.payment.update({
          where: { id: bill.payment.id },
          data: {
            amount,
            method,
            status: 'COMPLETED',
            transactionId,
            receiptNumber,
            paidAt,
            failureReason: null,
          },
        });
      } else {
        payment = await tx.payment.create({
          data: {
            billId: bill.id,
            requestId: bill.requestId,
            customerId: customerUserId,
            providerId: bill.providerId,
            amount,
            method,
            status: 'COMPLETED',
            transactionId,
            receiptNumber,
            paidAt,
          },
        });
      }

      // 2. Update bill status to PAID
      const updatedBill = await tx.bill.update({
        where: { id: bill.id },
        data: { status: 'PAID' },
        include: {
          items: true,
          serviceRequest: true,
          customer: {
            select: { id: true, name: true, mobile: true, email: true },
          },
          provider: {
            select: { id: true, name: true, mobile: true, email: true },
          },
        },
      });

      // 3. Mark service request as COMPLETED
      await tx.serviceRequest.update({
        where: { id: bill.requestId },
        data: {
          status: 'COMPLETED',
          completedAt: paidAt,
          finalAmount: amount,
        },
      });

      // 4. Update provider statistics & make provider available for new requests
      await tx.providerProfile.updateMany({
        where: { userId: bill.providerId },
        data: {
          totalJobs: { increment: 1 },
          availability: 'AVAILABLE',
        },
      });

      return { payment, bill: updatedBill };
    });

    const receipt = this._formatReceipt(result.payment, result.bill);

    return {
      payment: result.payment,
      bill: result.bill,
      receipt,
    };
  }

  /**
   * Get digital receipt by payment ID.
   */
  async getReceiptByPaymentId(userId, role, paymentId) {
    const payment = await prisma.payment.findUnique({
      where: { id: paymentId },
      include: {
        bill: {
          include: {
            items: true,
            serviceRequest: true,
            customer: {
              select: { id: true, name: true, mobile: true, email: true },
            },
            provider: {
              select: { id: true, name: true, mobile: true, email: true },
            },
          },
        },
        customer: {
          select: { id: true, name: true, mobile: true, email: true },
        },
        provider: {
          select: { id: true, name: true, mobile: true, email: true },
        },
      },
    });

    if (!payment) {
      const error = new Error('Payment not found');
      error.statusCode = 404;
      throw error;
    }

    if (role !== 'ADMIN' && payment.customerId !== userId && payment.providerId !== userId) {
      const error = new Error('You are not authorized to view this receipt');
      error.statusCode = 403;
      throw error;
    }

    return this._formatReceipt(payment, payment.bill);
  }

  /**
   * Get digital receipt by service request ID.
   */
  async getReceiptByRequestId(userId, role, requestId) {
    const payment = await prisma.payment.findFirst({
      where: { requestId, status: 'COMPLETED' },
      include: {
        bill: {
          include: {
            items: true,
            serviceRequest: true,
            customer: {
              select: { id: true, name: true, mobile: true, email: true },
            },
            provider: {
              select: { id: true, name: true, mobile: true, email: true },
            },
          },
        },
        customer: {
          select: { id: true, name: true, mobile: true, email: true },
        },
        provider: {
          select: { id: true, name: true, mobile: true, email: true },
        },
      },
    });

    if (!payment) {
      const error = new Error('No completed payment receipt found for this request');
      error.statusCode = 404;
      throw error;
    }

    if (role !== 'ADMIN' && payment.customerId !== userId && payment.providerId !== userId) {
      const error = new Error('You are not authorized to view this receipt');
      error.statusCode = 403;
      throw error;
    }

    return this._formatReceipt(payment, payment.bill);
  }

  /**
   * Helper to format digital receipt payload.
   */
  _formatReceipt(payment, bill) {
    const req = bill.serviceRequest || {};
    return {
      receiptNumber: payment.receiptNumber,
      transactionId: payment.transactionId,
      paidAt: payment.paidAt,
      amount: payment.amount,
      method: payment.method,
      status: payment.status,
      requestId: bill.requestId,
      gateway: payment.gateway || 'RAZORPAY',
      gatewayOrderId: payment.gatewayOrderId,
      gatewayPaymentId: payment.gatewayPaymentId,
      customer: {
        id: bill.customerId,
        name: bill.customer?.name || 'Customer',
        mobile: bill.customer?.mobile || '',
      },
      provider: {
        id: bill.providerId,
        name: bill.provider?.name || 'Provider',
        mobile: bill.provider?.mobile || '',
      },
      vehicle: {
        model: req.vehicleModel || 'Vehicle',
        plateNumber: req.vehiclePlate || '',
      },
      location: req.customerAddress || 'On-site breakdown location',
      serviceType: req.serviceType || 'Roadside Assistance',
      subtotal: bill.subtotal,
      taxRate: bill.taxRate,
      taxAmount: bill.taxAmount,
      grandTotal: bill.grandTotal,
      items: (bill.items || []).map((i) => ({
        id: i.id,
        description: i.description,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
        total: i.total,
      })),
      notes: bill.notes,
    };
  }

  /**
   * Get payment history for authenticated user (Customer, Provider, or Admin).
   * Returns all completed/processed payments including service request, provider, and bill details.
   */
  async getMyPayments(userId, role) {
    if (!prisma) {
      return [];
    }

    const where = {};
    if (role === 'CUSTOMER') {
      where.customerId = userId;
    } else if (role === 'PROVIDER') {
      where.providerId = userId;
    }

    const payments = await prisma.payment.findMany({
      where,
      include: {
        serviceRequest: {
          select: {
            id: true,
            serviceType: true,
            category: true,
            vehicleModel: true,
            vehiclePlate: true,
            customerAddress: true,
            problemDescription: true,
          },
        },
        provider: {
          select: {
            id: true,
            name: true,
            mobile: true,
            providerProfile: {
              select: {
                garageName: true,
                category: true,
              },
            },
          },
        },
        customer: {
          select: {
            id: true,
            name: true,
            mobile: true,
          },
        },
        bill: {
          select: {
            id: true,
            grandTotal: true,
            subtotal: true,
            taxAmount: true,
            status: true,
            items: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return payments.map((p) => {
      const req = p.serviceRequest || {};
      const prov = p.provider || {};
      const cust = p.customer || {};
      const bill = p.bill || {};

      let serviceLabel = req.serviceType;
      if (!serviceLabel) {
        if (req.category === 'PUNCTURE') serviceLabel = 'Tyre & Puncture Service';
        else if (req.category === 'TOW_TRUCK') serviceLabel = 'Tow Truck / Recovery';
        else if (req.category === 'BATTERY') serviceLabel = 'Battery Jump-Start';
        else if (req.category === 'FUEL') serviceLabel = 'Emergency Fuel Delivery';
        else serviceLabel = 'Mechanical Repair';
      }

      return {
        id: p.id,
        paymentId: p.id,
        transactionId: p.transactionId,
        receiptNumber: p.receiptNumber || `RR-RCPT-${p.id.substring(0, 8).toUpperCase()}`,
        amount: p.amount,
        method: p.method,
        status: p.status === 'COMPLETED' ? 'Paid' : p.status,
        paidAt: p.paidAt || p.createdAt,
        createdAt: p.createdAt,
        requestId: p.requestId,
        service: serviceLabel,
        serviceType: serviceLabel,
        category: req.category || 'MECHANIC',
        provider: prov.providerProfile?.garageName || prov.name || 'RoadRescue Partner',
        providerName: prov.providerProfile?.garageName || prov.name || 'RoadRescue Partner',
        customerName: cust.name || 'Customer',
        vehicleModel: req.vehicleModel || '',
        vehiclePlate: req.vehiclePlate || '',
        location: req.customerAddress || 'On-site breakdown location',
        billId: p.billId,
        itemsCount: bill.items?.length || 0,
      };
    });
  }
}

module.exports = new PaymentService();
