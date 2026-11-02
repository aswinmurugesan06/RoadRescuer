/**
 * RoadRescue — Seed Demonstration Pricing Configurations
 *
 * Inserts safe, illustrative pricing configurations for college project review.
 * Idempotent: Can be executed multiple times without generating duplicate active rules.
 *
 * NOTE: These are demonstration values for testing and academic review only,
 * not approved production customer rates.
 */

const { prisma } = require('./src/config/prisma');

const DEMO_CONFIGS = [
  {
    category: 'MECHANIC',
    vehicleType: 'Heavy Vehicle',
    problemCategory: null,
    baseLaborCharge: 500.0,
    includedDistanceKm: 5.0,
    perKmCharge: 25.0,
    additionalCharges: 0.0,
    taxRate: 0.18,
    description: '[DEMO] Heavy Vehicle Mechanic Demonstration Rate - Academic Review Only',
    isActive: true,
  },
  {
    category: 'PUNCTURE',
    vehicleType: 'Heavy Vehicle',
    problemCategory: null,
    baseLaborCharge: 300.0,
    includedDistanceKm: 5.0,
    perKmCharge: 20.0,
    additionalCharges: 0.0,
    taxRate: 0.18,
    description: '[DEMO] Heavy Vehicle Puncture Demonstration Rate - Academic Review Only',
    isActive: true,
  },
  {
    category: 'TOW_TRUCK',
    vehicleType: 'Heavy Vehicle',
    problemCategory: null,
    baseLaborCharge: 1500.0,
    includedDistanceKm: 5.0,
    perKmCharge: 60.0,
    additionalCharges: 0.0,
    taxRate: 0.18,
    description: '[DEMO] Heavy Vehicle Tow Truck Demonstration Rate - Academic Review Only',
    isActive: true,
  },
  {
    category: 'BATTERY',
    vehicleType: 'Heavy Vehicle',
    problemCategory: null,
    baseLaborCharge: 400.0,
    includedDistanceKm: 5.0,
    perKmCharge: 25.0,
    additionalCharges: 0.0,
    taxRate: 0.18,
    description: '[DEMO] Heavy Vehicle Battery Jump-Start Demonstration Rate - Academic Review Only',
    isActive: true,
  },
  {
    category: 'FUEL',
    vehicleType: 'Heavy Vehicle',
    problemCategory: null,
    baseLaborCharge: 250.0,
    includedDistanceKm: 5.0,
    perKmCharge: 20.0,
    additionalCharges: 0.0,
    taxRate: 0.18,
    description: '[DEMO] Heavy Vehicle Emergency Fuel Demonstration Rate - Academic Review Only',
    isActive: true,
  },
];

async function seedDemoPricing() {
  console.log('\n======================================================');
  console.log('🌱 ROADRESCUE DEMO PRICING CONFIGURATION SEED SCRIPT');
  console.log('======================================================\n');

  try {
    for (const item of DEMO_CONFIGS) {
      // Check if an existing configuration exists for this combination
      const existing = await prisma.pricingConfig.findFirst({
        where: {
          category: item.category,
          vehicleType: item.vehicleType,
          problemCategory: item.problemCategory,
        },
      });

      if (existing) {
        // Update existing configuration to ensure it matches the demo specification and is active
        const updated = await prisma.pricingConfig.update({
          where: { id: existing.id },
          data: {
            baseLaborCharge: item.baseLaborCharge,
            includedDistanceKm: item.includedDistanceKm,
            perKmCharge: item.perKmCharge,
            additionalCharges: item.additionalCharges,
            taxRate: item.taxRate,
            description: item.description,
            isActive: true,
          },
        });
        console.log(`  ✓ Updated demo config: ${item.category} (${item.vehicleType}) -> Base: ₹${updated.baseLaborCharge}, Per Km: ₹${updated.perKmCharge}`);
      } else {
        // Create new active configuration
        const created = await prisma.pricingConfig.create({
          data: item,
        });
        console.log(`  + Created demo config: ${item.category} (${item.vehicleType}) -> Base: ₹${created.baseLaborCharge}, Per Km: ₹${created.perKmCharge}`);
      }
    }

    console.log('\n✅ All 5 demonstration pricing configurations are active and ready.\n');
  } catch (error) {
    console.error('❌ Error seeding demo pricing:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  seedDemoPricing();
}

module.exports = { seedDemoPricing, DEMO_CONFIGS };
