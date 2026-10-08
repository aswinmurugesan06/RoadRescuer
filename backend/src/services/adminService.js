const { prisma } = require('../config/prisma');

class AdminService {
  /**
   * 1. Get platform-wide dashboard overview metrics.
   */
  async getDashboardStats() {
    if (!prisma) {
      return {
        totalCustomers: 0,
        totalProviders: 0,
        pendingVerifications: 0,
        approvedProviders: 0,
        activeRequests: 0,
        completedRequests: 0,
        cancelledRequests: 0,
        totalRevenue: 0,
        averageRating: 5.0,
      };
    }

    const [
      totalCustomers,
      totalProviders,
      pendingVerifications,
      approvedProviders,
      activeRequests,
      completedRequests,
      cancelledRequests,
      revenueAgg,
      ratingAgg,
    ] = await Promise.all([
      prisma.user.count({ where: { role: 'CUSTOMER' } }),
      prisma.user.count({ where: { role: 'PROVIDER' } }),
      prisma.providerProfile.count({ where: { verificationStatus: 'PENDING' } }),
      prisma.providerProfile.count({ where: { verificationStatus: 'APPROVED' } }),
      prisma.serviceRequest.count({
        where: {
          status: { in: ['PENDING', 'SEARCHING', 'ACCEPTED', 'ARRIVING', 'IN_SERVICE'] },
        },
      }),
      prisma.serviceRequest.count({ where: { status: 'COMPLETED' } }),
      prisma.serviceRequest.count({ where: { status: 'CANCELLED' } }),
      prisma.payment.aggregate({
        where: { status: 'COMPLETED' },
        _sum: { amount: true },
      }),
      prisma.providerProfile.aggregate({
        where: { verificationStatus: 'APPROVED' },
        _avg: { rating: true },
      }),
    ]);

    const totalRevenue = revenueAgg._sum.amount || 0;
    const averageRating = ratingAgg._avg.rating
      ? Math.round(ratingAgg._avg.rating * 10) / 10
      : 5.0;

    return {
      totalCustomers,
      totalProviders,
      pendingVerifications,
      approvedProviders,
      activeRequests,
      completedRequests,
      cancelledRequests,
      totalRevenue,
      averageRating,
    };
  }

  /**
   * 2. List providers with filtering by verification status, category, or search query.
   */
  async listProviders({ status, category, search, page = 1, limit = 20 }) {
    if (!prisma) return { providers: [], pagination: { total: 0, page: 1, limit: 20, totalPages: 1 } };

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const where = { role: 'PROVIDER' };

    if (status) {
      where.providerProfile = {
        ...(where.providerProfile || {}),
        verificationStatus: status.toUpperCase(),
      };
    }

    if (category) {
      where.providerProfile = {
        ...(where.providerProfile || {}),
        category: category.toUpperCase(),
      };
    }

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
        { mobile: { contains: search, mode: 'insensitive' } },
        {
          providerProfile: {
            garageName: { contains: search, mode: 'insensitive' },
          },
        },
      ];
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        select: {
          id: true,
          name: true,
          email: true,
          mobile: true,
          role: true,
          isVerified: true,
          isActive: true,
          createdAt: true,
          providerProfile: true,
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.user.count({ where }),
    ]);

    return {
      providers: users,
      pagination: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum) || 1,
      },
    };
  }

  /**
   * 3. Get detailed provider profile by ID.
   */
  async getProviderDetails(providerUserId) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    const provider = await prisma.user.findUnique({
      where: { id: providerUserId },
      select: {
        id: true,
        name: true,
        email: true,
        mobile: true,
        role: true,
        isVerified: true,
        isActive: true,
        createdAt: true,
        updatedAt: true,
        providerProfile: true,
        assignedRequests: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          include: {
            customer: { select: { id: true, name: true, mobile: true } },
          },
        },
        providerRatings: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          include: {
            customer: { select: { id: true, name: true } },
          },
        },
      },
    });

    if (!provider || provider.role !== 'PROVIDER') {
      const err = new Error('Provider not found');
      err.statusCode = 404;
      throw err;
    }

    return provider;
  }

  /**
   * 4. Update provider verification status (APPROVED, REJECTED, SUSPENDED).
   */
  async updateProviderVerification(providerUserId, { verificationStatus, reason }) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    const validStatuses = ['APPROVED', 'REJECTED', 'SUSPENDED', 'PENDING'];
    const targetStatus = String(verificationStatus || '').toUpperCase();

    if (!validStatuses.includes(targetStatus)) {
      const err = new Error(`verificationStatus must be one of: ${validStatuses.join(', ')}`);
      err.statusCode = 400;
      throw err;
    }

    const provider = await prisma.user.findUnique({
      where: { id: providerUserId },
      include: { providerProfile: true },
    });

    if (!provider || provider.role !== 'PROVIDER' || !provider.providerProfile) {
      const err = new Error('Provider not found');
      err.statusCode = 404;
      throw err;
    }

    const extraData = {};
    if (targetStatus === 'REJECTED' || targetStatus === 'SUSPENDED') {
      extraData.availability = 'OFFLINE';
    }

    const updated = await prisma.providerProfile.update({
      where: { userId: providerUserId },
      data: {
        verificationStatus: targetStatus,
        ...extraData,
      },
    });

    return {
      userId: providerUserId,
      providerProfile: updated,
      reason: reason || null,
    };
  }

  /**
   * 5. List platform users (Customers, Providers, Admins) safely.
   */
  async listUsers({ role, search, page = 1, limit = 20 }) {
    if (!prisma) return { users: [], pagination: { total: 0, page: 1, limit: 20, totalPages: 1 } };

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const where = {};
    if (role) {
      where.role = role.toUpperCase();
    }

    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
        { mobile: { contains: search, mode: 'insensitive' } },
      ];
    }

    const [users, total] = await Promise.all([
      prisma.user.findMany({
        where,
        select: {
          id: true,
          name: true,
          email: true,
          mobile: true,
          role: true,
          isVerified: true,
          isActive: true,
          createdAt: true,
          providerProfile: true,
          _count: {
            select: {
              vehicles: true,
              customerRequests: true,
              assignedRequests: true,
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.user.count({ where }),
    ]);

    return {
      users,
      pagination: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum) || 1,
      },
    };
  }

  /**
   * 6. List service requests with filters for status, category, date.
   */
  async listServiceRequests({ status, category, search, page = 1, limit = 20 }) {
    if (!prisma) return { requests: [], pagination: { total: 0, page: 1, limit: 20, totalPages: 1 } };

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const where = {};
    if (status) {
      where.status = status.toUpperCase();
    }
    if (category) {
      where.category = category.toUpperCase();
    }
    if (search) {
      where.OR = [
        { vehiclePlate: { contains: search, mode: 'insensitive' } },
        { vehicleModel: { contains: search, mode: 'insensitive' } },
        { serviceType: { contains: search, mode: 'insensitive' } },
        { customer: { name: { contains: search, mode: 'insensitive' } } },
      ];
    }

    const [requests, total] = await Promise.all([
      prisma.serviceRequest.findMany({
        where,
        include: {
          customer: { select: { id: true, name: true, mobile: true, email: true } },
          provider: { select: { id: true, name: true, mobile: true, email: true } },
          bill: { select: { id: true, grandTotal: true, status: true } },
          rating: { select: { id: true, score: true, review: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.serviceRequest.count({ where }),
    ]);

    return {
      requests,
      pagination: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum) || 1,
      },
    };
  }

  /**
   * 7. List billing records.
   */
  async listBills({ status, page = 1, limit = 20 }) {
    if (!prisma) return { bills: [], pagination: { total: 0, page: 1, limit: 20, totalPages: 1 } };

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const where = {};
    if (status) where.status = status.toUpperCase();

    const [bills, total] = await Promise.all([
      prisma.bill.findMany({
        where,
        include: {
          customer: { select: { id: true, name: true, mobile: true } },
          provider: { select: { id: true, name: true, mobile: true } },
          payment: { select: { id: true, transactionId: true, receiptNumber: true, status: true, paidAt: true } },
          items: true,
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.bill.count({ where }),
    ]);

    return {
      bills,
      pagination: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum) || 1,
      },
    };
  }

  /**
   * 8. List payments across the platform.
   */
  async listPayments({ status, method, page = 1, limit = 20 }) {
    if (!prisma) return { payments: [], pagination: { total: 0, page: 1, limit: 20, totalPages: 1 } };

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const where = {};
    if (status) where.status = status.toUpperCase();
    if (method) where.method = method.toUpperCase();

    const [payments, total] = await Promise.all([
      prisma.payment.findMany({
        where,
        include: {
          customer: { select: { id: true, name: true, mobile: true } },
          provider: { select: { id: true, name: true, mobile: true } },
          serviceRequest: { select: { id: true, serviceType: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.payment.count({ where }),
    ]);

    return {
      payments,
      pagination: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum) || 1,
      },
    };
  }

  /**
   * 9. List and moderate ratings & reviews.
   */
  async listRatings({ minScore, maxScore, providerId, page = 1, limit = 20 }) {
    if (!prisma) return { ratings: [], pagination: { total: 0, page: 1, limit: 20, totalPages: 1 } };

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
    const skip = (pageNum - 1) * limitNum;

    const where = {};
    if (providerId) where.providerId = providerId;
    if (minScore || maxScore) {
      where.score = {};
      if (minScore) where.score.gte = parseInt(minScore, 10);
      if (maxScore) where.score.lte = parseInt(maxScore, 10);
    }

    const [ratings, total] = await Promise.all([
      prisma.rating.findMany({
        where,
        include: {
          customer: { select: { id: true, name: true, mobile: true } },
          provider: { select: { id: true, name: true, mobile: true } },
          serviceRequest: { select: { id: true, serviceType: true } },
        },
        orderBy: { createdAt: 'desc' },
        skip,
        take: limitNum,
      }),
      prisma.rating.count({ where }),
    ]);

    return {
      ratings,
      pagination: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum) || 1,
      },
    };
  }

  /**
   * 10. Delete/moderate an abusive rating and recalculate provider's average score.
   */
  async deleteRating(ratingId) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    const rating = await prisma.rating.findUnique({
      where: { id: ratingId },
    });

    if (!rating) {
      const err = new Error('Rating not found');
      err.statusCode = 404;
      throw err;
    }

    const providerId = rating.providerId;

    await prisma.rating.delete({
      where: { id: ratingId },
    });

    // Recalculate provider rating
    const agg = await prisma.rating.aggregate({
      where: { providerId },
      _avg: { score: true },
      _count: { score: true },
    });

    const newAvg = agg._avg.score ? Math.round(agg._avg.score * 10) / 10 : 5.0;
    const newCount = agg._count.score || 0;

    await prisma.providerProfile.updateMany({
      where: { userId: providerId },
      data: {
        rating: newAvg,
        ratingCount: newCount,
      },
    });

    return {
      message: 'Rating removed and provider stats updated',
      ratingId,
      newProviderRating: newAvg,
      newProviderRatingCount: newCount,
    };
  }
}

module.exports = new AdminService();
