const { prisma } = require('../config/prisma');

class BillingService {
  /**
   * Create or update a bill for a service request.
   * Only the assigned provider can create/update the bill.
   */
  async createOrUpdateBill(providerUserId, data) {
    const { requestId, items, notes } = data;

    if (!requestId || typeof requestId !== 'string') {
      const error = new Error('Valid requestId is required');
      error.statusCode = 400;
      throw error;
    }

    if (!Array.isArray(items) || items.length === 0) {
      const error = new Error('At least one bill item is required');
      error.statusCode = 400;
      throw error;
    }

    // Validate item contents
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      if (!item.description || typeof item.description !== 'string' || item.description.trim() === '') {
        const error = new Error(`Item ${i + 1} must have a valid description`);
        error.statusCode = 400;
        throw error;
      }
      const qty = parseInt(item.quantity, 10);
      if (isNaN(qty) || qty <= 0) {
        const error = new Error(`Item ${i + 1} quantity must be greater than 0`);
        error.statusCode = 400;
        throw error;
      }
      const price = parseFloat(item.unitPrice);
      if (isNaN(price) || price < 0) {
        const error = new Error(`Item ${i + 1} unitPrice must be non-negative`);
        error.statusCode = 400;
        throw error;
      }
    }

    // Verify service request exists and is assigned to this provider
    const request = await prisma.serviceRequest.findUnique({
      where: { id: requestId },
      include: { bill: true },
    });

    if (!request) {
      const error = new Error('Service request not found');
      error.statusCode = 404;
      throw error;
    }

    if (request.providerId !== providerUserId) {
      const error = new Error('You are not authorized to bill this service request');
      error.statusCode = 403;
      throw error;
    }

    if (request.status === 'CANCELLED') {
      const error = new Error('Cannot generate a bill for a cancelled service request');
      error.statusCode = 400;
      throw error;
    }

    if (request.bill && request.bill.status === 'PAID') {
      const error = new Error('Cannot modify a bill that has already been paid');
      error.statusCode = 400;
      throw error;
    }

    // Calculate subtotal, tax, and grand total strictly on the backend
    let subtotal = 0;
    const formattedItems = items.map((item) => {
      const quantity = parseInt(item.quantity, 10);
      const unitPrice = parseFloat(item.unitPrice);
      const total = Math.round(quantity * unitPrice * 100) / 100;
      subtotal += total;
      return {
        description: item.description.trim(),
        quantity,
        unitPrice,
        total,
      };
    });

    subtotal = Math.round(subtotal * 100) / 100;
    const taxRate = 0.18; // Standard 18% GST
    const taxAmount = Math.round(subtotal * taxRate * 100) / 100;
    const grandTotal = Math.round((subtotal + taxAmount) * 100) / 100;

    let bill;

    if (request.bill) {
      // Update existing bill
      bill = await prisma.$transaction(async (tx) => {
        // Delete old items
        await tx.billItem.deleteMany({
          where: { billId: request.bill.id },
        });

        // Update bill and create new items
        const updated = await tx.bill.update({
          where: { id: request.bill.id },
          data: {
            status: 'PENDING',
            subtotal,
            taxRate,
            taxAmount,
            grandTotal,
            notes: notes ? notes.trim() : null,
            rejectionReason: null,
            items: {
              create: formattedItems,
            },
          },
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

        await tx.serviceRequest.update({
          where: { id: requestId },
          data: { finalAmount: grandTotal },
        });

        // Release provider back to AVAILABLE upon finishing repair and sending bill
        await tx.providerProfile.updateMany({
          where: {
            userId: providerUserId,
            verificationStatus: 'APPROVED',
          },
          data: { availability: 'AVAILABLE' },
        });

        return updated;
      });
    } else {
      // Create new bill
      bill = await prisma.$transaction(async (tx) => {
        const created = await tx.bill.create({
          data: {
            requestId,
            providerId: providerUserId,
            customerId: request.customerId,
            status: 'PENDING',
            subtotal,
            taxRate,
            taxAmount,
            grandTotal,
            notes: notes ? notes.trim() : null,
            items: {
              create: formattedItems,
            },
          },
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

        await tx.serviceRequest.update({
          where: { id: requestId },
          data: { finalAmount: grandTotal },
        });

        // Release provider back to AVAILABLE upon finishing repair and sending bill
        await tx.providerProfile.updateMany({
          where: {
            userId: providerUserId,
            verificationStatus: 'APPROVED',
          },
          data: { availability: 'AVAILABLE' },
        });

        return created;
      });
    }

    return bill;
  }

  /**
   * Get bill by service request ID.
   */
  async getBillByRequestId(userId, role, requestId) {
    const bill = await prisma.bill.findUnique({
      where: { requestId },
      include: {
        items: true,
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
      const error = new Error('Bill not found for this service request');
      error.statusCode = 404;
      throw error;
    }

    // Verify participant ownership
    if (role !== 'ADMIN' && bill.customerId !== userId && bill.providerId !== userId) {
      const error = new Error('You are not authorized to view this bill');
      error.statusCode = 403;
      throw error;
    }

    return bill;
  }

  /**
   * Get bill by bill ID.
   */
  async getBillById(userId, role, billId) {
    const bill = await prisma.bill.findUnique({
      where: { id: billId },
      include: {
        items: true,
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

    // Verify participant ownership
    if (role !== 'ADMIN' && bill.customerId !== userId && bill.providerId !== userId) {
      const error = new Error('You are not authorized to view this bill');
      error.statusCode = 403;
      throw error;
    }

    return bill;
  }

  /**
   * Customer approves or rejects a bill.
   */
  async updateBillStatus(customerUserId, billId, status, rejectionReason) {
    if (!['APPROVED', 'REJECTED'].includes(status)) {
      const error = new Error('Status must be either APPROVED or REJECTED');
      error.statusCode = 400;
      throw error;
    }

    const bill = await prisma.bill.findUnique({
      where: { id: billId },
    });

    if (!bill) {
      const error = new Error('Bill not found');
      error.statusCode = 404;
      throw error;
    }

    if (bill.customerId !== customerUserId) {
      const error = new Error('Only the assigned customer can approve or reject this bill');
      error.statusCode = 403;
      throw error;
    }

    if (bill.status === 'PAID') {
      const error = new Error('Cannot change status of an already paid bill');
      error.statusCode = 400;
      throw error;
    }

    if (status === 'REJECTED' && (!rejectionReason || rejectionReason.trim() === '')) {
      const error = new Error('Rejection reason is required when rejecting a bill');
      error.statusCode = 400;
      throw error;
    }

    const updated = await prisma.bill.update({
      where: { id: billId },
      data: {
        status,
        rejectionReason: status === 'REJECTED' ? rejectionReason.trim() : null,
      },
      include: {
        items: true,
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

    return updated;
  }
}

module.exports = new BillingService();
