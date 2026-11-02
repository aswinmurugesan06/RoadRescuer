const { prisma } = require('../config/prisma');
const routingService = require('./routingService');
const DistanceUtil = {
  calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth radius in km
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Number((R * c).toFixed(2));
  },
};

/**
 * Normalizes input category to valid ProviderCategory enum.
 */
function normalizeCategory(category) {
  if (!category) return 'MECHANIC';
  let upper = String(category).trim().toUpperCase();
  if (upper === 'TOW') upper = 'TOW_TRUCK';
  const valid = ['MECHANIC', 'PUNCTURE', 'TOW_TRUCK', 'BATTERY', 'FUEL'];
  if (valid.includes(upper)) return upper;
  return 'MECHANIC';
}

/**
 * Safe conversion of Prisma Decimal / numeric to clean 2-decimal JS Number.
 */
function round2(val) {
  if (val === null || val === undefined || isNaN(Number(val))) return 0.0;
  return Number(Number(val).toFixed(2));
}

class PricingService {
  /**
   * Deterministic 3-Tier cascade rule matching:
   * Tier 1: Exact (category, problemCategory, vehicleType)
   * Tier 2: Category + vehicleType (problemCategory IS NULL)
   * Tier 3: Category default (problemCategory IS NULL, vehicleType IS NULL)
   */
  async findMatchingRule({ category, problemCategory, vehicleType }) {
    const normCategory = normalizeCategory(category);
    const normProblem = problemCategory ? String(problemCategory).trim() : null;
    const normVehicle = vehicleType ? String(vehicleType).trim() : null;

    // Tier 1: Exact match on Category + Problem + Vehicle
    if (normProblem && normVehicle) {
      const tier1 = await prisma.pricingConfig.findFirst({
        where: {
          category: normCategory,
          problemCategory: { equals: normProblem, mode: 'insensitive' },
          vehicleType: { equals: normVehicle, mode: 'insensitive' },
          isActive: true,
        },
      });
      if (tier1) return { rule: tier1, matchedTier: 'EXACT_PROBLEM_AND_VEHICLE' };
    }

    // Tier 2: Category + Vehicle Type (general problem for vehicle)
    if (normVehicle) {
      const tier2 = await prisma.pricingConfig.findFirst({
        where: {
          category: normCategory,
          problemCategory: null,
          vehicleType: { equals: normVehicle, mode: 'insensitive' },
          isActive: true,
        },
      });
      if (tier2) return { rule: tier2, matchedTier: 'CATEGORY_AND_VEHICLE' };
    }

    // Tier 3: Category-wide default rule
    const tier3 = await prisma.pricingConfig.findFirst({
      where: {
        category: normCategory,
        problemCategory: null,
        vehicleType: null,
        isActive: true,
      },
    });
    if (tier3) return { rule: tier3, matchedTier: 'CATEGORY_DEFAULT' };

    // No active rule found -> fail explicitly
    const err = new Error(
      `No active pricing configuration found for service category: ${normCategory}${
        normVehicle ? ', vehicle: ' + normVehicle : ''
      }. Please configure pricing rules before requesting an estimate.`
    );
    err.statusCode = 404;
    throw err;
  }

  /**
   * Calculate dynamic cost estimate.
   * Handles distance calculation and provisional estimates when no provider is assigned.
   */
  async calculateEstimate({
    category,
    problemCategory,
    vehicleType,
    customerLat,
    customerLng,
    destinationLat,
    destinationLng,
    providerId,
  }) {
    const normCategory = normalizeCategory(category);
    const { rule, matchedTier } = await this.findMatchingRule({
      category: normCategory,
      problemCategory,
      vehicleType,
    });

    const cLat = customerLat !== undefined && customerLat !== null ? parseFloat(customerLat) : null;
    const cLng = customerLng !== undefined && customerLng !== null ? parseFloat(customerLng) : null;
    const dLat = destinationLat !== undefined && destinationLat !== null ? parseFloat(destinationLat) : null;
    const dLng = destinationLng !== undefined && destinationLng !== null ? parseFloat(destinationLng) : null;

    let distanceKm = 0.0;
    let distanceStatus = 'NO_PROVIDER_AVAILABLE_BASE_ONLY';
    let isProvisional = true;
    let isDistanceEstimated = false;
    let note =
      'Provisional estimate based on base service labor. Provider travel charges will be calculated after provider assignment.';

    // Case 1: Specific destination coordinates supplied (e.g., Tow Truck to workshop)
    if (
      cLat !== null &&
      cLng !== null &&
      dLat !== null &&
      dLng !== null &&
      !isNaN(cLat) &&
      !isNaN(cLng) &&
      !isNaN(dLat) &&
      !isNaN(dLng)
    ) {
      try {
        const directions = await routingService.getDirections({
          originLat: cLat,
          originLng: cLng,
          destLat: dLat,
          destLng: dLng,
        });
        distanceKm = directions.distanceKm || 0.0;
        distanceStatus = 'MEASURED_TO_DESTINATION';
        isProvisional = false;
        isDistanceEstimated = false;
        note = 'Distance measured along road network to designated destination.';
      } catch (_) {
        distanceKm = DistanceUtil.calculateDistance(cLat, cLng, dLat, dLng);
        distanceStatus = 'MEASURED_TO_DESTINATION';
        isProvisional = false;
        isDistanceEstimated = true;
        note = 'Direct travel distance to designated destination.';
      }
    }
    // Case 2: Specific assigned provider ID supplied
    else if (providerId && cLat !== null && cLng !== null && !isNaN(cLat) && !isNaN(cLng)) {
      const providerProfile = await prisma.providerProfile.findUnique({
        where: { userId: providerId },
      });
      if (providerProfile && providerProfile.latitude !== null && providerProfile.longitude !== null) {
        try {
          const directions = await routingService.getDirections({
            originLat: providerProfile.latitude,
            originLng: providerProfile.longitude,
            destLat: cLat,
            destLng: cLng,
          });
          distanceKm = directions.distanceKm || 0.0;
          distanceStatus = 'MEASURED_FROM_ASSIGNED_PROVIDER';
          isProvisional = false;
          isDistanceEstimated = true;
          note = 'Distance measured from assigned provider location to your breakdown spot.';
        } catch (_) {
          distanceKm = DistanceUtil.calculateDistance(
            providerProfile.latitude,
            providerProfile.longitude,
            cLat,
            cLng
          );
          distanceStatus = 'MEASURED_FROM_ASSIGNED_PROVIDER';
          isProvisional = false;
          isDistanceEstimated = true;
          note = 'Direct travel distance from assigned provider.';
        }
      }
    }
    // Case 3: Customer coordinates provided, search for nearest active available provider in category
    else if (cLat !== null && cLng !== null && !isNaN(cLat) && !isNaN(cLng)) {
      const candidates = await prisma.providerProfile.findMany({
        where: {
          category: normCategory,
          availability: 'AVAILABLE',
          verificationStatus: 'APPROVED',
          latitude: { not: null },
          longitude: { not: null },
        },
      });

      if (candidates.length > 0) {
        let nearest = null;
        let minDistance = Infinity;

        for (const candidate of candidates) {
          const dist = DistanceUtil.calculateDistance(
            candidate.latitude,
            candidate.longitude,
            cLat,
            cLng
          );
          if (dist < minDistance && dist <= candidate.serviceRadiusKm) {
            minDistance = dist;
            nearest = candidate;
          }
        }

        if (nearest) {
          try {
            const directions = await routingService.getDirections({
              originLat: nearest.latitude,
              originLng: nearest.longitude,
              destLat: cLat,
              destLng: cLng,
            });
            distanceKm = directions.distanceKm || minDistance;
          } catch (_) {
            distanceKm = minDistance;
          }
          distanceStatus = 'MEASURED_FROM_NEAREST_PROVIDER';
          isProvisional = true;
          isDistanceEstimated = true;
          note =
            'Provisional estimate measured from the nearest available provider. Travel charges will be finalized once a specific provider accepts.';
        }
      }
    }

    // Rate calculations
    const baseLaborCharge = round2(rule.baseLaborCharge);
    const perKmCharge = round2(rule.perKmCharge);
    const includedDistanceKm = round2(rule.includedDistanceKm);
    const additionalCharges = round2(rule.additionalCharges);
    const taxRate = Number(Number(rule.taxRate).toFixed(4)) || 0.18;

    const actualDistance = round2(distanceKm);
    const billableDistanceKm = round2(Math.max(0, actualDistance - includedDistanceKm));
    const distanceCharge = round2(billableDistanceKm * perKmCharge);
    const subtotal = round2(baseLaborCharge + distanceCharge + additionalCharges);
    const taxAmount = round2(subtotal * taxRate);
    const estimatedTotal = round2(subtotal + taxAmount);

    return {
      pricingConfigId: rule.id,
      matchedTier,
      category: normCategory,
      problemCategory: rule.problemCategory,
      vehicleType: rule.vehicleType,
      currency: 'INR',
      baseLaborCharge,
      distanceKm: actualDistance,
      includedDistanceKm,
      billableDistanceKm,
      perKmCharge,
      distanceCharge,
      additionalCharges,
      subtotal,
      taxRate,
      taxAmount,
      estimatedTotal,
      isProvisional,
      isDistanceEstimated,
      distanceStatus,
      note,
      calculatedAt: new Date().toISOString(),
    };
  }

  /**
   * Admin: List all pricing configurations.
   */
  async listConfigs(filter = {}) {
    const where = {};
    if (filter.category) {
      where.category = normalizeCategory(filter.category);
    }
    if (filter.isActive !== undefined && filter.isActive !== null && filter.isActive !== '') {
      where.isActive = filter.isActive === true || filter.isActive === 'true';
    }

    const configs = await prisma.pricingConfig.findMany({
      where,
      orderBy: [{ category: 'asc' }, { vehicleType: 'asc' }, { problemCategory: 'asc' }],
    });

    return configs.map((c) => this.formatConfig(c));
  }

  /**
   * Admin: Get single pricing config by ID.
   */
  async getConfigById(id) {
    const config = await prisma.pricingConfig.findUnique({
      where: { id },
    });
    if (!config) {
      const err = new Error('Pricing configuration not found');
      err.statusCode = 404;
      throw err;
    }
    return this.formatConfig(config);
  }

  /**
   * Admin: Create a new pricing configuration with transactional duplicate prevention.
   */
  async createConfig(data) {
    const category = normalizeCategory(data.category);
    const problemCategory = data.problemCategory ? String(data.problemCategory).trim() : null;
    const vehicleType = data.vehicleType ? String(data.vehicleType).trim() : null;

    const baseLabor = parseFloat(data.baseLaborCharge);
    if (isNaN(baseLabor) || baseLabor < 0) {
      const err = new Error('baseLaborCharge must be a non-negative number');
      err.statusCode = 400;
      throw err;
    }

    const perKm = data.perKmCharge !== undefined ? parseFloat(data.perKmCharge) : 0.0;
    if (isNaN(perKm) || perKm < 0) {
      const err = new Error('perKmCharge must be a non-negative number');
      err.statusCode = 400;
      throw err;
    }

    const includedDist =
      data.includedDistanceKm !== undefined ? parseFloat(data.includedDistanceKm) : 0.0;
    if (isNaN(includedDist) || includedDist < 0) {
      const err = new Error('includedDistanceKm must be a non-negative number');
      err.statusCode = 400;
      throw err;
    }

    const addCharges =
      data.additionalCharges !== undefined ? parseFloat(data.additionalCharges) : 0.0;
    if (isNaN(addCharges) || addCharges < 0) {
      const err = new Error('additionalCharges must be a non-negative number');
      err.statusCode = 400;
      throw err;
    }

    const tax = data.taxRate !== undefined ? parseFloat(data.taxRate) : 0.18;
    if (isNaN(tax) || tax < 0 || tax > 1) {
      const err = new Error('taxRate must be a decimal number between 0 and 1 (e.g. 0.18 for 18% GST)');
      err.statusCode = 400;
      throw err;
    }

    const isActive = data.isActive !== undefined ? Boolean(data.isActive) : true;
    const description = data.description ? String(data.description).trim() : null;

    // Transactional check and create
    const created = await prisma.$transaction(async (tx) => {
      if (isActive) {
        const existing = await tx.pricingConfig.findFirst({
          where: {
            category,
            problemCategory: problemCategory ? { equals: problemCategory, mode: 'insensitive' } : null,
            vehicleType: vehicleType ? { equals: vehicleType, mode: 'insensitive' } : null,
            isActive: true,
          },
        });
        if (existing) {
          const err = new Error(
            `An active pricing configuration already exists for category '${category}', problem '${
              problemCategory || 'ALL'
            }', and vehicle '${vehicleType || 'ALL'}'. Deactivate the existing rule first.`
          );
          err.statusCode = 409;
          throw err;
        }
      }

      return tx.pricingConfig.create({
        data: {
          category,
          problemCategory,
          vehicleType,
          baseLaborCharge: baseLabor,
          perKmCharge: perKm,
          includedDistanceKm: includedDist,
          additionalCharges: addCharges,
          taxRate: tax,
          description,
          isActive,
        },
      });
    });

    return this.formatConfig(created);
  }

  /**
   * Admin: Update an existing pricing configuration.
   */
  async updateConfig(id, data) {
    const existing = await prisma.pricingConfig.findUnique({
      where: { id },
    });
    if (!existing) {
      const err = new Error('Pricing configuration not found');
      err.statusCode = 404;
      throw err;
    }

    const category = data.category ? normalizeCategory(data.category) : existing.category;
    const problemCategory =
      data.problemCategory !== undefined
        ? data.problemCategory
          ? String(data.problemCategory).trim()
          : null
        : existing.problemCategory;
    const vehicleType =
      data.vehicleType !== undefined
        ? data.vehicleType
          ? String(data.vehicleType).trim()
          : null
        : existing.vehicleType;

    const baseLabor =
      data.baseLaborCharge !== undefined
        ? parseFloat(data.baseLaborCharge)
        : Number(existing.baseLaborCharge);
    if (isNaN(baseLabor) || baseLabor < 0) {
      const err = new Error('baseLaborCharge must be a non-negative number');
      err.statusCode = 400;
      throw err;
    }

    const perKm =
      data.perKmCharge !== undefined
        ? parseFloat(data.perKmCharge)
        : Number(existing.perKmCharge);
    if (isNaN(perKm) || perKm < 0) {
      const err = new Error('perKmCharge must be a non-negative number');
      err.statusCode = 400;
      throw err;
    }

    const includedDist =
      data.includedDistanceKm !== undefined
        ? parseFloat(data.includedDistanceKm)
        : Number(existing.includedDistanceKm);
    if (isNaN(includedDist) || includedDist < 0) {
      const err = new Error('includedDistanceKm must be a non-negative number');
      err.statusCode = 400;
      throw err;
    }

    const addCharges =
      data.additionalCharges !== undefined
        ? parseFloat(data.additionalCharges)
        : Number(existing.additionalCharges);
    if (isNaN(addCharges) || addCharges < 0) {
      const err = new Error('additionalCharges must be a non-negative number');
      err.statusCode = 400;
      throw err;
    }

    const tax =
      data.taxRate !== undefined ? parseFloat(data.taxRate) : Number(existing.taxRate);
    if (isNaN(tax) || tax < 0 || tax > 1) {
      const err = new Error('taxRate must be a decimal number between 0 and 1');
      err.statusCode = 400;
      throw err;
    }

    const isActive = data.isActive !== undefined ? Boolean(data.isActive) : existing.isActive;
    const description =
      data.description !== undefined
        ? data.description
          ? String(data.description).trim()
          : null
        : existing.description;

    const updated = await prisma.$transaction(async (tx) => {
      if (isActive) {
        const conflict = await tx.pricingConfig.findFirst({
          where: {
            id: { not: id },
            category,
            problemCategory: problemCategory ? { equals: problemCategory, mode: 'insensitive' } : null,
            vehicleType: vehicleType ? { equals: vehicleType, mode: 'insensitive' } : null,
            isActive: true,
          },
        });
        if (conflict) {
          const err = new Error(
            `Another active pricing configuration already exists for category '${category}', problem '${
              problemCategory || 'ALL'
            }', and vehicle '${vehicleType || 'ALL'}'.`
          );
          err.statusCode = 409;
          throw err;
        }
      }

      return tx.pricingConfig.update({
        where: { id },
        data: {
          category,
          problemCategory,
          vehicleType,
          baseLaborCharge: baseLabor,
          perKmCharge: perKm,
          includedDistanceKm: includedDist,
          additionalCharges: addCharges,
          taxRate: tax,
          description,
          isActive,
        },
      });
    });

    return this.formatConfig(updated);
  }

  /**
   * Helper to serialize Prisma Decimal fields to clean JSON objects.
   */
  formatConfig(config) {
    if (!config) return null;
    return {
      id: config.id,
      category: config.category,
      problemCategory: config.problemCategory,
      vehicleType: config.vehicleType,
      baseLaborCharge: round2(config.baseLaborCharge),
      perKmCharge: round2(config.perKmCharge),
      includedDistanceKm: round2(config.includedDistanceKm),
      additionalCharges: round2(config.additionalCharges),
      taxRate: Number(Number(config.taxRate).toFixed(4)),
      description: config.description,
      isActive: config.isActive,
      createdAt: config.createdAt,
      updatedAt: config.updatedAt,
    };
  }
}

module.exports = new PricingService();
