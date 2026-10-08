const { prisma } = require('../config/prisma');
const { getIO } = require('../socket/socketManager');

// In-memory fallback if database is not available
const memoryRatings = new Map();

class RatingService {
  /**
   * Submit a rating and optional review for a completed service request.
   *
   * Rules:
   * 1. Only the assigned CUSTOMER can submit a rating.
   * 2. Score must be an integer between 1 and 5.
   * 3. Service request must exist and have status COMPLETED.
   * 4. Cannot rate the same request twice (prevent duplicate).
   * 5. Provider cannot rate themselves.
   * 6. Automatically recalculates and updates provider average rating & count.
   */
  async submitRating({ customerId, userRole, requestId, score, review }) {
    if (!requestId) {
      const err = new Error('requestId is required');
      err.statusCode = 400;
      throw err;
    }

    if (userRole !== 'CUSTOMER') {
      const err = new Error('Only customers can submit ratings for roadside assistance services');
      err.statusCode = 403;
      throw err;
    }

    const numScore = Number(score);
    if (!Number.isInteger(numScore) || numScore < 1 || numScore > 5) {
      const err = new Error('Rating score must be an integer between 1 and 5');
      err.statusCode = 400;
      throw err;
    }

    const trimmedReview = typeof review === 'string' ? review.trim() : null;
    if (trimmedReview && trimmedReview.length > 1000) {
      const err = new Error('Review text must not exceed 1000 characters');
      err.statusCode = 400;
      throw err;
    }

    if (prisma) {
      try {
        return await prisma.$transaction(async (tx) => {
          // 1. Fetch service request
          const request = await tx.serviceRequest.findUnique({
            where: { id: requestId },
            include: {
              customer: { select: { id: true, name: true } },
              provider: { select: { id: true, name: true } },
            },
          });

          if (!request) {
            const err = new Error('Service request not found');
            err.statusCode = 404;
            throw err;
          }

          // 2. Ownership check
          if (request.customerId !== customerId) {
            const err = new Error('Access denied: You can only rate your own service requests');
            err.statusCode = 403;
            throw err;
          }

          // 3. Status check: must be COMPLETED
          if (request.status !== 'COMPLETED') {
            const err = new Error(`Cannot rate a service request that is not completed (current status: ${request.status})`);
            err.statusCode = 400;
            throw err;
          }

          // 4. Provider assigned check
          if (!request.providerId) {
            const err = new Error('Service request has no assigned provider to rate');
            err.statusCode = 400;
            throw err;
          }

          // 5. Prevent duplicate ratings
          const existingRating = await tx.rating.findUnique({
            where: { requestId },
          });

          if (existingRating) {
            const err = new Error('A rating has already been submitted for this service request');
            err.statusCode = 400;
            throw err;
          }

          // 6. Create rating
          const newRating = await tx.rating.create({
            data: {
              requestId,
              customerId,
              providerId: request.providerId,
              score: numScore,
              review: trimmedReview,
            },
            include: {
              customer: { select: { id: true, name: true } },
              provider: { select: { id: true, name: true } },
              serviceRequest: { select: { id: true, serviceType: true } },
            },
          });

          // 7. Recalculate provider average rating and count
          const agg = await tx.rating.aggregate({
            where: { providerId: request.providerId },
            _avg: { score: true },
            _count: { score: true },
          });

          const newAvgRating = agg._avg.score ? Math.round(agg._avg.score * 10) / 10 : 5.0;
          const newRatingCount = agg._count.score || 0;

          await tx.providerProfile.updateMany({
            where: { userId: request.providerId },
            data: {
              rating: newAvgRating,
              ratingCount: newRatingCount,
            },
          });

          // 8. Emit real-time notification
          try {
            const io = getIO();
            if (io) {
              io.to(`request:${requestId}`).emit('rating:submitted', {
                requestId,
                rating: newRating,
                providerRating: newAvgRating,
                providerRatingCount: newRatingCount,
                timestamp: new Date().toISOString(),
              });
              io.to(`user:${request.providerId}`).emit('rating:received', {
                requestId,
                score: numScore,
                review: trimmedReview,
                customerName: request.customer?.name,
                newAverageRating: newAvgRating,
                newRatingCount: newRatingCount,
                timestamp: new Date().toISOString(),
              });
            }
          } catch (e) {
            // Sockets are non-critical
          }

          return {
            ...newRating,
            providerAverageRating: newAvgRating,
            providerTotalRatings: newRatingCount,
          };
        });
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB transaction failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const id = `rating_${Date.now()}`;
    const ratingObj = {
      id,
      requestId,
      customerId,
      providerId: 'prov_mem',
      score: numScore,
      review: trimmedReview,
      createdAt: new Date(),
      providerAverageRating: numScore,
      providerTotalRatings: 1,
    };
    memoryRatings.set(requestId, ratingObj);
    return ratingObj;
  }

  /**
   * Get rating by requestId.
   */
  async getRatingByRequestId(userId, userRole, requestId) {
    if (!requestId) {
      const err = new Error('requestId is required');
      err.statusCode = 400;
      throw err;
    }

    if (prisma) {
      try {
        const rating = await prisma.rating.findUnique({
          where: { requestId },
          include: {
            customer: { select: { id: true, name: true } },
            provider: { select: { id: true, name: true } },
            serviceRequest: { select: { id: true, serviceType: true, completedAt: true } },
          },
        });

        if (!rating) {
          const err = new Error('Rating not found for this service request');
          err.statusCode = 404;
          throw err;
        }

        // Authorization: customer who made it, provider who received it, or admin
        if (
          userRole !== 'ADMIN' &&
          rating.customerId !== userId &&
          rating.providerId !== userId
        ) {
          const err = new Error('Access denied: You are not authorized to view this rating');
          err.statusCode = 403;
          throw err;
        }

        return rating;
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
      }
    }

    const r = memoryRatings.get(requestId);
    if (!r) {
      const err = new Error('Rating not found for this service request');
      err.statusCode = 404;
      throw err;
    }
    return r;
  }

  /**
   * Get ratings and stats for a provider.
   */
  async getProviderRatings(providerId, page = 1, limit = 20) {
    if (!providerId) {
      const err = new Error('providerId is required');
      err.statusCode = 400;
      throw err;
    }

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    if (prisma) {
      try {
        const [ratings, totalCount, agg] = await Promise.all([
          prisma.rating.findMany({
            where: { providerId },
            include: {
              customer: { select: { id: true, name: true } },
              serviceRequest: { select: { serviceType: true, completedAt: true } },
            },
            orderBy: { createdAt: 'desc' },
            skip,
            take: limitNum,
          }),
          prisma.rating.count({ where: { providerId } }),
          prisma.rating.aggregate({
            where: { providerId },
            _avg: { score: true },
          }),
        ]);

        const averageRating = agg._avg.score ? Math.round(agg._avg.score * 10) / 10 : 5.0;

        return {
          ratings,
          pagination: {
            total: totalCount,
            page: pageNum,
            limit: limitNum,
            totalPages: Math.ceil(totalCount / limitNum) || 1,
          },
          summary: {
            averageRating,
            totalRatings: totalCount,
          },
        };
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
      }
    }

    return {
      ratings: [],
      pagination: { total: 0, page: 1, limit: limitNum, totalPages: 1 },
      summary: { averageRating: 5.0, totalRatings: 0 },
    };
  }

  /**
   * Get own ratings (submitted for customer, received for provider).
   */
  async getMyRatings(userId, userRole, page = 1, limit = 20) {
    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const whereClause = userRole === 'CUSTOMER' ? { customerId: userId } : { providerId: userId };

    if (prisma) {
      try {
        const [ratings, totalCount] = await Promise.all([
          prisma.rating.findMany({
            where: whereClause,
            include: {
              customer: { select: { id: true, name: true } },
              provider: { select: { id: true, name: true } },
              serviceRequest: { select: { id: true, serviceType: true, vehicleModel: true, completedAt: true } },
            },
            orderBy: { createdAt: 'desc' },
            skip,
            take: limitNum,
          }),
          prisma.rating.count({ where: whereClause }),
        ]);

        return {
          ratings,
          pagination: {
            total: totalCount,
            page: pageNum,
            limit: limitNum,
            totalPages: Math.ceil(totalCount / limitNum) || 1,
          },
        };
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
      }
    }

    return {
      ratings: [],
      pagination: { total: 0, page: 1, limit: limitNum, totalPages: 1 },
    };
  }
}

module.exports = new RatingService();
