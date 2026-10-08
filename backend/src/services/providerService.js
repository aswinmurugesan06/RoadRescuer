const { prisma } = require('../config/prisma');

// Valid enums (mirrors Prisma schema)
const VALID_CATEGORIES = ['MECHANIC', 'PUNCTURE', 'TOW_TRUCK', 'BATTERY', 'FUEL'];
const VALID_AVAILABILITY = ['OFFLINE', 'AVAILABLE']; // BUSY is system-controlled

class ProviderService {
  /**
   * 1. Get the authenticated provider's full profile.
   * Returns user + providerProfile data.
   */
  async getProfile(providerUserId) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    const user = await prisma.user.findUnique({
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
        providerProfile: true,
      },
    });

    if (!user || user.role !== 'PROVIDER') {
      const err = new Error('Provider profile not found');
      err.statusCode = 404;
      throw err;
    }

    if (!user.providerProfile) {
      const err = new Error('Provider profile record missing. Please contact support.');
      err.statusCode = 404;
      throw err;
    }

    return user;
  }

  /**
   * 2. Update the provider's profile (garageName, businessAddress, serviceRadiusKm, category).
   * Providers cannot self-modify verificationStatus, rating, or totalJobs.
   */
  async updateProfile(providerUserId, data) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    // Ensure provider exists
    const user = await prisma.user.findUnique({
      where: { id: providerUserId },
      include: { providerProfile: true },
    });

    if (!user || user.role !== 'PROVIDER' || !user.providerProfile) {
      const err = new Error('Provider profile not found');
      err.statusCode = 404;
      throw err;
    }

    // Build safe update payload (no sensitive fields allowed)
    const updateData = {};

    if (data.garageName !== undefined) {
      const name = String(data.garageName).trim();
      if (name.length < 2) {
        const err = new Error('Garage name must be at least 2 characters');
        err.statusCode = 400;
        throw err;
      }
      updateData.garageName = name;
    }

    if (data.businessAddress !== undefined) {
      updateData.businessAddress = String(data.businessAddress).trim() || null;
    }

    if (data.serviceRadiusKm !== undefined) {
      const radius = parseFloat(data.serviceRadiusKm);
      if (isNaN(radius) || radius < 1 || radius > 200) {
        const err = new Error('serviceRadiusKm must be between 1 and 200 km');
        err.statusCode = 400;
        throw err;
      }
      updateData.serviceRadiusKm = radius;
    }

    if (data.category !== undefined) {
      let cat = String(data.category).toUpperCase();
      if (cat === 'TOW') cat = 'TOW_TRUCK';
      if (!VALID_CATEGORIES.includes(cat)) {
        const err = new Error(`category must be one of: ${VALID_CATEGORIES.join(', ')}`);
        err.statusCode = 400;
        throw err;
      }
      updateData.category = cat;
    }

    if (Object.keys(updateData).length === 0) {
      const err = new Error('No valid fields to update. Accepted: garageName, businessAddress, serviceRadiusKm, category');
      err.statusCode = 400;
      throw err;
    }

    const updated = await prisma.providerProfile.update({
      where: { userId: providerUserId },
      data: updateData,
    });

    return updated;
  }

  /**
   * 3. Set provider availability: OFFLINE or AVAILABLE.
   * Rules:
   * - BUSY is never allowed (system-controlled by service request workflow).
   * - Only APPROVED providers can go AVAILABLE.
   * - PENDING / REJECTED / SUSPENDED providers cannot go AVAILABLE.
   */
  async setAvailability(providerUserId, availability) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    const status = String(availability).toUpperCase();

    if (!VALID_AVAILABILITY.includes(status)) {
      const err = new Error(
        `availability must be one of: ${VALID_AVAILABILITY.join(', ')}. BUSY is automatically set by the system.`
      );
      err.statusCode = 400;
      throw err;
    }

    const user = await prisma.user.findUnique({
      where: { id: providerUserId },
      include: { providerProfile: true },
    });

    if (!user || user.role !== 'PROVIDER' || !user.providerProfile) {
      const err = new Error('Provider profile not found');
      err.statusCode = 404;
      throw err;
    }

    const profile = user.providerProfile;

    // Only APPROVED providers can become AVAILABLE
    if (status === 'AVAILABLE' && profile.verificationStatus !== 'APPROVED') {
      const err = new Error(
        `Only APPROVED providers can set themselves as AVAILABLE. Your current verification status is ${profile.verificationStatus}.`
      );
      err.statusCode = 403;
      throw err;
    }

    // Prevent BUSY from being set manually
    if (status === 'BUSY') {
      const err = new Error('BUSY status is managed automatically by the service request system and cannot be set manually.');
      err.statusCode = 400;
      throw err;
    }

    const updated = await prisma.providerProfile.update({
      where: { userId: providerUserId },
      data: { availability: status },
    });

    return updated;
  }

  /**
   * 4. Update provider location (lat/lng) — foundation for map integration.
   * Only AVAILABLE providers should broadcast their location.
   */
  async updateLocation(providerUserId, latitude, longitude) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);

    if (isNaN(lat) || lat < -90 || lat > 90) {
      const err = new Error('latitude must be a valid number between -90 and 90');
      err.statusCode = 400;
      throw err;
    }

    if (isNaN(lng) || lng < -180 || lng > 180) {
      const err = new Error('longitude must be a valid number between -180 and 180');
      err.statusCode = 400;
      throw err;
    }

    // Verify provider exists
    const user = await prisma.user.findUnique({
      where: { id: providerUserId },
      include: { providerProfile: true },
    });

    if (!user || user.role !== 'PROVIDER' || !user.providerProfile) {
      const err = new Error('Provider profile not found');
      err.statusCode = 404;
      throw err;
    }

    const updated = await prisma.providerProfile.update({
      where: { userId: providerUserId },
      data: { latitude: lat, longitude: lng },
    });

    return updated;
  }

  /**
   * 5. Get provider's own active/recent service requests.
   * Returns requests assigned to this provider.
   */
  async getMyRequests(providerUserId) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    return await prisma.serviceRequest.findMany({
      where: { providerId: providerUserId },
      include: {
        customer: {
          select: {
            id: true,
            name: true,
            mobile: true,
            email: true,
          },
        },
        vehicle: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  /**
   * 6. Admin only — update provider verification status.
   * PENDING → APPROVED / REJECTED / SUSPENDED
   */
  async adminSetVerificationStatus(providerUserId, verificationStatus, adminUserId) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    const validStatuses = ['PENDING', 'APPROVED', 'REJECTED', 'SUSPENDED'];
    const status = String(verificationStatus).toUpperCase();
    if (!validStatuses.includes(status)) {
      const err = new Error(`verificationStatus must be one of: ${validStatuses.join(', ')}`);
      err.statusCode = 400;
      throw err;
    }

    // Verify admin
    const admin = await prisma.user.findUnique({ where: { id: adminUserId } });
    if (!admin || admin.role !== 'ADMIN') {
      const err = new Error('Forbidden: Only admins can update provider verification status');
      err.statusCode = 403;
      throw err;
    }

    // Verify target is a provider
    const target = await prisma.user.findUnique({
      where: { id: providerUserId },
      include: { providerProfile: true },
    });

    if (!target || target.role !== 'PROVIDER' || !target.providerProfile) {
      const err = new Error('Provider not found');
      err.statusCode = 404;
      throw err;
    }

    // If suspending/rejecting, force OFFLINE
    const extraData = {};
    if (status === 'REJECTED' || status === 'SUSPENDED') {
      extraData.availability = 'OFFLINE';
    }

    const updated = await prisma.providerProfile.update({
      where: { userId: providerUserId },
      data: { verificationStatus: status, ...extraData },
    });

    return updated;
  }

  /**
   * 7. Get provider earnings & settlement summary.
   * Calculates gross billing, platform commission (10%), net earnings, and payment history
   * from real completed payments/paid bills.
   */
  async getEarnings(providerUserId) {
    if (!prisma) {
      const err = new Error('Database not available');
      err.statusCode = 503;
      throw err;
    }

    // Verify provider exists
    const user = await prisma.user.findUnique({
      where: { id: providerUserId },
      include: { providerProfile: true },
    });

    if (!user || user.role !== 'PROVIDER' || !user.providerProfile) {
      const err = new Error('Provider profile not found');
      err.statusCode = 404;
      throw err;
    }

    // Fetch all completed payments for this provider
    const payments = await prisma.payment.findMany({
      where: {
        providerId: providerUserId,
        status: 'COMPLETED',
      },
      include: {
        bill: {
          include: {
            items: true,
          },
        },
        serviceRequest: {
          include: {
            customer: {
              select: { id: true, name: true, mobile: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    const completedJobsCount = payments.length;
    let grossBilling = 0;

    const history = payments.map((p) => {
      const amount = p.amount;
      grossBilling += amount;
      const commission = Math.round(amount * 0.10 * 100) / 100;
      const netAmount = Math.round((amount - commission) * 100) / 100;

      return {
        id: p.id,
        paymentId: p.id,
        transactionId: p.transactionId,
        receiptNumber: p.receiptNumber || `REC-${p.id.substring(0, 8).toUpperCase()}`,
        amount,
        commission,
        netAmount,
        method: p.method,
        status: p.status,
        paidAt: p.paidAt || p.createdAt,
        createdAt: p.createdAt,
        requestId: p.requestId,
        serviceType: p.serviceRequest?.serviceType || 'Roadside Assistance',
        customerName: p.serviceRequest?.customer?.name || 'Customer',
        billId: p.billId,
        itemsCount: p.bill?.items?.length || 0,
      };
    });

    grossBilling = Math.round(grossBilling * 100) / 100;
    const platformCommission = Math.round(grossBilling * 0.10 * 100) / 100;
    const netEarnings = Math.round((grossBilling - platformCommission) * 100) / 100;

    return {
      totalCompletedServices: completedJobsCount,
      grossServiceBilling: grossBilling,
      commissionRate: 0.10,
      platformCommission,
      netProviderEarnings: netEarnings,
      totalBalance: netEarnings,
      recentPayments: history,
    };
  }
}

module.exports = new ProviderService();
