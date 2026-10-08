const admin = require('firebase-admin');
const { prisma } = require('../config/prisma');

class NotificationService {
  constructor() {
    this.firebaseApp = null;
    this.isInitialized = false;
    this._initFirebase();
  }

  /**
   * Initialize Firebase Admin SDK using environment variables.
   * If credentials are not provided or running in test mode, the service operates
   * in simulated dispatch mode without crashing.
   */
  _initFirebase() {
    try {
      if (admin && Array.isArray(admin.apps) && admin.apps.length > 0) {
        this.firebaseApp = admin.apps[0];
        this.isInitialized = true;
        return;
      }

      const serviceAccountKey = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
      const projectId = process.env.FIREBASE_PROJECT_ID;
      const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
      const privateKey = process.env.FIREBASE_PRIVATE_KEY
        ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n')
        : undefined;

      if (serviceAccountKey) {
        const parsedKey = typeof serviceAccountKey === 'string' ? JSON.parse(serviceAccountKey) : serviceAccountKey;
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert(parsedKey),
        });
        this.isInitialized = true;
      } else if (projectId && clientEmail && privateKey) {
        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert({
            projectId,
            clientEmail,
            privateKey,
          }),
        });
        this.isInitialized = true;
      }
    } catch (error) {
      if (process.env.NODE_ENV !== 'test') {
        console.warn('Firebase Admin SDK initialization skipped/failed (simulated mode):', error.message);
      }
      this.isInitialized = false;
    }
  }

  /**
   * Register or update a device FCM token for a user.
   */
  async registerToken(userId, { token, deviceType = 'ANDROID' }) {
    if (!token || typeof token !== 'string' || token.trim().length === 0) {
      const error = new Error('Valid FCM device token is required');
      error.statusCode = 400;
      throw error;
    }

    const trimmedToken = token.trim();

    // Upsert token record (if token already assigned to another user, reassign to current user)
    const deviceToken = await prisma.deviceToken.upsert({
      where: { token: trimmedToken },
      update: {
        userId,
        deviceType: deviceType.toUpperCase(),
        updatedAt: new Date(),
      },
      create: {
        userId,
        token: trimmedToken,
        deviceType: deviceType.toUpperCase(),
      },
    });

    return deviceToken;
  }

  /**
   * Remove a device FCM token for a user.
   */
  async removeToken(userId, token) {
    if (!token || typeof token !== 'string') {
      const error = new Error('Valid FCM device token is required');
      error.statusCode = 400;
      throw error;
    }

    const trimmedToken = token.trim();

    const existing = await prisma.deviceToken.findFirst({
      where: { token: trimmedToken },
    });

    if (!existing) {
      return { removed: false, message: 'Token not found' };
    }

    if (existing.userId !== userId) {
      const error = new Error('You are not authorized to delete this device token');
      error.statusCode = 403;
      throw error;
    }

    await prisma.deviceToken.delete({
      where: { id: existing.id },
    });

    return { removed: true, token: trimmedToken };
  }

  /**
   * Get all registered device tokens for a user.
   */
  async getUserTokens(userId) {
    return prisma.deviceToken.findMany({
      where: { userId },
      select: {
        id: true,
        token: true,
        deviceType: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  /**
   * Send a push notification to a specific user.
   */
  async sendToUser(userId, { title, body, data = {}, notificationType = 'GENERAL' }) {
    if (!userId) return { success: false, reason: 'No userId provided' };

    const deviceTokens = await prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });

    if (!deviceTokens || deviceTokens.length === 0) {
      return { success: false, sentCount: 0, reason: 'No registered tokens for user' };
    }

    const tokens = deviceTokens.map((dt) => dt.token);
    return this._sendMulticast(tokens, { title, body, data, notificationType });
  }

  /**
   * Send a push notification to multiple users.
   */
  async sendToUsers(userIds, { title, body, data = {}, notificationType = 'GENERAL' }) {
    if (!userIds || userIds.length === 0) return { success: false, sentCount: 0 };

    const deviceTokens = await prisma.deviceToken.findMany({
      where: { userId: { in: userIds } },
      select: { token: true },
    });

    if (!deviceTokens || deviceTokens.length === 0) {
      return { success: false, sentCount: 0, reason: 'No registered tokens for users' };
    }

    const tokens = deviceTokens.map((dt) => dt.token);
    return this._sendMulticast(tokens, { title, body, data, notificationType });
  }

  /**
   * Internal multicast sender with automatic stale token pruning.
   */
  async _sendMulticast(tokens, { title, body, data = {}, notificationType = 'GENERAL' }) {
    if (!tokens || tokens.length === 0) return { success: false, sentCount: 0 };

    // Ensure all data attributes are strings for FCM payload compatibility
    const sanitizedData = {};
    for (const [key, value] of Object.entries(data)) {
      if (value !== null && value !== undefined) {
        sanitizedData[key] = String(value);
      }
    }
    sanitizedData.notificationType = notificationType;
    sanitizedData.timestamp = new Date().toISOString();

    if (this.isInitialized && admin.messaging) {
      try {
        const message = {
          tokens,
          notification: {
            title,
            body,
          },
          data: sanitizedData,
          android: {
            priority: 'high',
            notification: {
              sound: 'default',
              channelId: 'roadrescue_alerts',
            },
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                badge: 1,
              },
            },
          },
        };

        const response = await admin.messaging().sendEachForMulticast(message);

        // Prune unregistered / invalid tokens
        if (response.failureCount > 0) {
          const failedTokens = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const errCode = resp.error?.code;
              if (
                errCode === 'messaging/invalid-registration-token' ||
                errCode === 'messaging/registration-token-not-registered'
              ) {
                failedTokens.push(tokens[idx]);
              }
            }
          });

          if (failedTokens.length > 0) {
            await prisma.deviceToken.deleteMany({
              where: { token: { in: failedTokens } },
            });
          }
        }

        return {
          success: true,
          sentCount: response.successCount,
          failureCount: response.failureCount,
        };
      } catch (err) {
        return { success: false, error: err.message };
      }
    }

    // Simulated dispatch mode (Development / Test)
    return {
      success: true,
      simulated: true,
      sentCount: tokens.length,
      payload: { title, body, data: sanitizedData },
    };
  }

  // ── Specific Event Helpers ──────────────────────────────────────────────────

  /**
   * Notify eligible providers when a new service request is created.
   */
  async notifyNewRequestAvailable(providerUserIds, request) {
    return this.sendToUsers(providerUserIds, {
      title: '🚨 New Roadside Assistance Request',
      body: `New ${request.serviceType || 'assistance'} request nearby (${request.customerAddress || 'Breakdown location'})`,
      data: {
        type: 'NEW_REQUEST_AVAILABLE',
        requestId: request.id,
        category: request.category,
        route: '/provider/job-details',
      },
      notificationType: 'NEW_REQUEST',
    });
  }

  /**
   * Notify customer when a provider accepts their request.
   */
  async notifyRequestAccepted(customerUserId, request, providerName = 'Technician') {
    return this.sendToUser(customerUserId, {
      title: '✅ Assistance On The Way',
      body: `${providerName} has accepted your request and is preparing to arrive.`,
      data: {
        type: 'REQUEST_ACCEPTED',
        requestId: request.id,
        status: 'ACCEPTED',
        route: '/customer/active-request',
      },
      notificationType: 'REQUEST_STATUS',
    });
  }

  /**
   * Notify customer when provider is arriving or service starts.
   */
  async notifyRequestStatusChanged(customerUserId, request, status) {
    let title = 'RoadRescue Update';
    let body = `Your service status has changed to ${status}.`;

    if (status === 'ARRIVING') {
      title = '🚗 Provider is Arriving';
      body = 'Your service provider is near your breakdown location.';
    } else if (status === 'IN_SERVICE') {
      title = '🔧 Service In Progress';
      body = 'The technician has started diagnosing and servicing your vehicle.';
    }

    return this.sendToUser(customerUserId, {
      title,
      body,
      data: {
        type: 'REQUEST_STATUS_CHANGED',
        requestId: request.id,
        status,
        route: '/customer/active-request',
      },
      notificationType: 'REQUEST_STATUS',
    });
  }

  /**
   * Notify user when a service request is cancelled.
   */
  async notifyRequestCancelled(targetUserId, request, cancelledBy = 'User', reason = '') {
    return this.sendToUser(targetUserId, {
      title: '❌ Service Request Cancelled',
      body: `Request #${request.id.slice(0, 8)} was cancelled by ${cancelledBy}${reason ? ': ' + reason : '.'}`,
      data: {
        type: 'REQUEST_CANCELLED',
        requestId: request.id,
        route: '/customer/history',
      },
      notificationType: 'REQUEST_CANCELLED',
    });
  }

  /**
   * Notify customer when a bill is created.
   */
  async notifyBillCreated(customerUserId, bill) {
    return this.sendToUser(customerUserId, {
      title: '📄 Invoice Ready for Review',
      body: `Your service bill for ₹${bill.grandTotal.toFixed(2)} is ready for approval.`,
      data: {
        type: 'BILL_CREATED',
        billId: bill.id,
        requestId: bill.requestId,
        amount: bill.grandTotal,
        route: '/customer/bill',
      },
      notificationType: 'BILL_READY',
    });
  }

  /**
   * Notify provider when customer approves the bill.
   */
  async notifyBillApproved(providerUserId, bill) {
    return this.sendToUser(providerUserId, {
      title: '👍 Bill Approved by Customer',
      body: `Customer approved invoice for ₹${bill.grandTotal.toFixed(2)}. Proceed to payment collection.`,
      data: {
        type: 'BILL_APPROVED',
        billId: bill.id,
        requestId: bill.requestId,
        route: '/provider/job-details',
      },
      notificationType: 'BILL_APPROVED',
    });
  }

  /**
   * Notify customer & provider when payment succeeds.
   */
  async notifyPaymentSuccess(customerUserId, providerUserId, payment, bill) {
    // Notify customer
    await this.sendToUser(customerUserId, {
      title: '🎉 Payment Successful',
      body: `Payment of ₹${payment.amount.toFixed(2)} completed successfully. Digital receipt is available.`,
      data: {
        type: 'PAYMENT_SUCCESS',
        paymentId: payment.id,
        billId: bill.id,
        requestId: bill.requestId,
        transactionId: payment.transactionId,
        route: '/customer/receipt',
      },
      notificationType: 'PAYMENT_SUCCESS',
    });

    // Notify provider
    await this.sendToUser(providerUserId, {
      title: '💰 Payment Received',
      body: `Received ₹${payment.amount.toFixed(2)} for service request #${bill.requestId.slice(0, 8)}.`,
      data: {
        type: 'PAYMENT_RECEIVED',
        paymentId: payment.id,
        billId: bill.id,
        requestId: bill.requestId,
        route: '/provider/job-details',
      },
      notificationType: 'PAYMENT_SUCCESS',
    });
  }

  /**
   * Notify customer when service is marked completed and prompt rating.
   */
  async notifyServiceCompleted(customerUserId, request) {
    return this.sendToUser(customerUserId, {
      title: '🌟 Service Completed',
      body: 'Your roadside assistance is complete. Please rate your experience!',
      data: {
        type: 'SERVICE_COMPLETED',
        requestId: request.id,
        providerId: request.providerId,
        route: '/customer/rate-service',
      },
      notificationType: 'SERVICE_COMPLETED',
    });
  }

  /**
   * Notify provider when a new customer review/rating is submitted.
   */
  async notifyRatingReceived(providerUserId, rating) {
    return this.sendToUser(providerUserId, {
      title: '⭐ New Customer Rating Received',
      body: `A customer gave you a ${rating.score}-star rating!`,
      data: {
        type: 'RATING_RECEIVED',
        requestId: rating.requestId,
        score: rating.score,
        route: '/provider/profile',
      },
      notificationType: 'RATING_RECEIVED',
    });
  }
}

module.exports = new NotificationService();
