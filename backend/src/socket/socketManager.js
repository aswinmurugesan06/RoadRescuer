/**
 * RoadRescue Phase 6 — Socket.IO Manager
 *
 * Responsibilities:
 *  - Authenticate every connection via Bearer JWT (same verifyToken used by HTTP middleware)
 *  - Assign each socket to identity rooms (user:<id>, role:<CUSTOMER|PROVIDER>)
 *  - Allow request-scoped rooms (request:<id>) joined only by authorized participants
 *  - Route real-time events for service-request lifecycle and provider live GPS
 *
 * Rooms:
 *  user:<userId>       — private channel per user
 *  request:<requestId> — shared by customer + accepted provider only
 *  providers           — all AVAILABLE/APPROVED providers (new request broadcasts)
 *
 * Events emitted to clients:
 *  request:new          — new service request available (→ providers room)
 *  request:accepted     — request was accepted by a provider (→ customer)
 *  request:status       — status changed (→ request room)
 *  request:cancelled    — request cancelled (→ request room)
 *  provider:location    — provider GPS update (→ request room, customers only)
 *
 * Events received from clients:
 *  join:request         — join a request room after authorization check
 *  provider:location    — provider sends GPS update for an active request
 */

const { verifyToken } = require('../utils/jwt');
const { prisma } = require('../config/prisma');

let _io = null;

/**
 * Initialize Socket.IO on the given http.Server.
 * @param {import('http').Server} httpServer
 */
function initSocket(httpServer) {
  const { Server } = require('socket.io');

  _io = new Server(httpServer, {
    cors: {
      origin: '*', // Restrict in production
      methods: ['GET', 'POST'],
    },
    // Transport: websocket + polling fallback
    transports: ['websocket', 'polling'],
  });

  // ── JWT Authentication Middleware ──────────────────────────────────────────
  _io.use((socket, next) => {
    try {
      // Client passes token in auth.token or as query param
      const token =
        socket.handshake.auth?.token ||
        socket.handshake.query?.token;

      if (!token) {
        return next(new Error('Authentication required: no token provided'));
      }

      const decoded = verifyToken(token);
      // Attach identity to socket for use in handlers
      socket.userId = decoded.userId;
      socket.userRole = decoded.role;
      next();
    } catch (err) {
      next(new Error('Authentication failed: invalid or expired token'));
    }
  });

  // ── Connection Handler ─────────────────────────────────────────────────────
  _io.on('connection', (socket) => {
    const { userId, userRole } = socket;

    // Join private identity rooms
    socket.join(`user:${userId}`);
    socket.join(`role:${userRole}`);

    // ── join:request ──────────────────────────────────────────────────────────
    // Client requests to join a request-scoped real-time room.
    // Authorization: customer who owns it OR provider assigned to it.
    socket.on('join:request', async (requestId) => {
      if (!requestId || typeof requestId !== 'string') return;

      try {
        if (!prisma) return;
        const req = await prisma.serviceRequest.findUnique({
          where: { id: requestId },
          select: { customerId: true, providerId: true, status: true },
        });

        if (!req) return;

        const isAuthorized =
          req.customerId === userId ||
          req.providerId === userId;

        if (isAuthorized) {
          socket.join(`request:${requestId}`);
        }
      } catch (_) {
        // DB error — silently ignore to prevent crashing the socket
      }
    });

    // ── provider:location ─────────────────────────────────────────────────────
    // Provider sends a GPS update during an accepted/arriving/in-service request.
    // Only emitted to the customer in the same request room.
    socket.on('provider:location', async (data) => {
      if (userRole !== 'PROVIDER') return;

      const { requestId, latitude, longitude } = data || {};
      if (!requestId || latitude == null || longitude == null) return;

      try {
        if (!prisma) return;
        const req = await prisma.serviceRequest.findUnique({
          where: { id: requestId },
          select: { customerId: true, providerId: true, status: true },
        });

        if (!req || req.providerId !== userId) return;
        if (!['ACCEPTED', 'ARRIVING', 'IN_SERVICE'].includes(req.status)) return;

        // Persist provider location in ProviderProfile
        await prisma.providerProfile.updateMany({
          where: { userId },
          data: {
            latitude: parseFloat(latitude),
            longitude: parseFloat(longitude),
          },
        });

        // Broadcast ONLY to the customer of this request (not to all room members)
        _io.to(`user:${req.customerId}`).emit('provider:location', {
          requestId,
          latitude: parseFloat(latitude),
          longitude: parseFloat(longitude),
          timestamp: new Date().toISOString(),
        });
      } catch (_) {
        // Silently ignore DB errors
      }
    });

    // ── disconnect ────────────────────────────────────────────────────────────
    socket.on('disconnect', () => {
      // Rooms are cleaned up automatically by Socket.IO
    });
  });

  console.log('🔌 Socket.IO initialized');
  return _io;
}

/**
 * Get the initialized Socket.IO instance.
 * @returns {import('socket.io').Server | null}
 */
function getIO() {
  return _io;
}

// ── Event Emitter Helpers ──────────────────────────────────────────────────────
// Called from service-request controllers after DB mutations.

/**
 * Broadcast a new service request to all AVAILABLE providers of the matching category.
 * Emits: request:new → role:PROVIDER room (client filters by category)
 */
function emitNewRequest(requestData) {
  if (!_io) return;
  _io.to('role:PROVIDER').emit('request:new', {
    id: requestData.id,
    category: requestData.category,
    serviceType: requestData.serviceType,
    problemDescription: requestData.problemDescription,
    status: requestData.status,
    customerAddress: requestData.customerAddress,
    vehicleModel: requestData.vehicleModel,
    vehicleType: requestData.vehicleType,
    // Obfuscated coordinates for privacy
    customerLatitude: Math.round(requestData.customerLatitude * 100) / 100,
    customerLongitude: Math.round(requestData.customerLongitude * 100) / 100,
    createdAt: requestData.createdAt,
  });
}

/**
 * Notify the request's customer that a provider accepted the request.
 * Emits: request:accepted → user:<customerId>
 */
function emitRequestAccepted(request) {
  if (!_io) return;
  const { customerId, providerId } = request;

  // Notify customer with full provider details
  _io.to(`user:${customerId}`).emit('request:accepted', {
    requestId: request.id,
    status: request.status,
    providerId,
    providerName: request.provider?.name,
    providerMobile: request.provider?.mobile,
    acceptedAt: request.acceptedAt,
  });

  // Also emit into the request room (useful if provider is already in the room)
  _io.to(`request:${request.id}`).emit('request:status', {
    requestId: request.id,
    status: request.status,
  });
}

/**
 * Broadcast a status change to all participants in the request room.
 * Emits: request:status → request:<id>
 */
function emitStatusChange(requestId, status, customerId) {
  if (!_io) return;
  _io.to(`request:${requestId}`).emit('request:status', {
    requestId,
    status,
    timestamp: new Date().toISOString(),
  });
  // Also send to the customer's private channel in case they haven't joined the room yet
  if (customerId) {
    _io.to(`user:${customerId}`).emit('request:status', {
      requestId,
      status,
      timestamp: new Date().toISOString(),
    });
  }
}

/**
 * Notify all participants of a cancellation.
 * Emits: request:cancelled → request:<id> + user:<customerId>
 */
function emitRequestCancelled(requestId, customerId, providerId, reason) {
  if (!_io) return;
  const payload = {
    requestId,
    status: 'CANCELLED',
    cancellationReason: reason,
    timestamp: new Date().toISOString(),
  };
  _io.to(`request:${requestId}`).emit('request:cancelled', payload);
  if (customerId) _io.to(`user:${customerId}`).emit('request:cancelled', payload);
  if (providerId) _io.to(`user:${providerId}`).emit('request:cancelled', payload);
}

/**
 * Notify the customer that a bill has been created/updated by the provider.
 * Emits: bill:created → user:<customerId>
 */
function emitBillCreated(bill) {
  if (!_io) return;
  _io.to(`user:${bill.customerId}`).emit('bill:created', {
    billId: bill.id,
    requestId: bill.requestId,
    grandTotal: bill.grandTotal,
    status: bill.status,
    providerName: bill.provider?.name,
    timestamp: new Date().toISOString(),
  });
  // Also notify provider room so UI can reflect sent state
  _io.to(`user:${bill.providerId}`).emit('bill:created', {
    billId: bill.id,
    requestId: bill.requestId,
    grandTotal: bill.grandTotal,
    status: bill.status,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Notify provider that the customer approved or rejected the bill.
 * Emits: bill:status → user:<providerId>
 */
function emitBillStatus(bill) {
  if (!_io) return;
  const payload = {
    billId: bill.id,
    requestId: bill.requestId,
    status: bill.status,
    rejectionReason: bill.rejectionReason,
    timestamp: new Date().toISOString(),
  };
  _io.to(`user:${bill.providerId}`).emit('bill:status', payload);
  _io.to(`user:${bill.customerId}`).emit('bill:status', payload);
}

/**
 * Notify both participants that payment has been completed.
 * Emits: payment:success → request room + individual user channels
 */
function emitPaymentSuccess(payment, bill) {
  if (!_io) return;
  const payload = {
    paymentId: payment.id,
    billId: payment.billId,
    requestId: payment.requestId,
    amount: payment.amount,
    method: payment.method,
    receiptNumber: payment.receiptNumber,
    transactionId: payment.transactionId,
    paidAt: payment.paidAt,
    timestamp: new Date().toISOString(),
  };
  if (bill?.customerId) _io.to(`user:${bill.customerId}`).emit('payment:success', payload);
  if (bill?.providerId) _io.to(`user:${bill.providerId}`).emit('payment:success', payload);
}

/**
 * Notify provider and request room that a rating was submitted.
 * Emits: rating:submitted → request room + provider user channel
 */
function emitRatingSubmitted(rating) {
  if (!_io) return;
  const payload = {
    ratingId: rating.id,
    requestId: rating.requestId,
    score: rating.score,
    review: rating.review,
    customerName: rating.customer?.name,
    providerAverageRating: rating.providerAverageRating,
    providerTotalRatings: rating.providerTotalRatings,
    timestamp: new Date().toISOString(),
  };
  _io.to(`request:${rating.requestId}`).emit('rating:submitted', payload);
  if (rating.providerId) {
    _io.to(`user:${rating.providerId}`).emit('rating:received', payload);
  }
}

module.exports = {
  initSocket,
  getIO,
  emitNewRequest,
  emitRequestAccepted,
  emitStatusChange,
  emitRequestCancelled,
  emitBillCreated,
  emitBillStatus,
  emitPaymentSuccess,
  emitRatingSubmitted,
};
