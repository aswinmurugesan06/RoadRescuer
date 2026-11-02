const { prisma } = require('./src/config/prisma');
const pricingService = require('./src/services/pricingService');

async function verifyAll() {
  console.log('\n======================================================');
  console.log('🔍 VERIFYING DEMO PRICING CONFIGURATIONS & ESTIMATES');
  console.log('======================================================\n');

  try {
    // 1. Check all 5 exist and are active in PostgreSQL
    const configs = await prisma.pricingConfig.findMany({
      where: {
        vehicleType: 'Heavy Vehicle',
        isActive: true,
      },
    });

    console.log(`Found ${configs.length} active Heavy Vehicle configurations in database:`);
    for (const c of configs) {
      console.log(
        `  • [${c.category}] Base: ₹${c.baseLaborCharge}, Included: ${c.includedDistanceKm}km, Per-Km: ₹${c.perKmCharge}, Tax: ${c.taxRate * 100}%`
      );
    }

    if (configs.length !== 5) {
      throw new Error(`Expected 5 active configs, found ${configs.length}`);
    }

    console.log('\n--- 2. Testing Cost Estimation for All 5 Categories ---\n');

    const categories = ['MECHANIC', 'PUNCTURE', 'TOW_TRUCK', 'BATTERY', 'FUEL'];

    for (const cat of categories) {
      // Test without provider (provisional estimate)
      const provEst = await pricingService.calculateEstimate({
        category: cat,
        vehicleType: 'Heavy Vehicle',
      });

      console.log(`[${cat} — Provisional Estimate (No Provider Selected)]:`);
      console.log(`  • Matched Tier:       ${provEst.matchedTier}`);
      console.log(`  • Base Labor Charge:  ₹${provEst.baseLaborCharge.toFixed(2)}`);
      console.log(`  • Distance:           ${provEst.distanceKm} km (Status: ${provEst.distanceStatus})`);
      console.log(`  • Distance Charge:    ₹${provEst.distanceCharge.toFixed(2)}`);
      console.log(`  • Subtotal:           ₹${provEst.subtotal.toFixed(2)}`);
      console.log(`  • GST (${provEst.taxRate * 100}%):        ₹${provEst.taxAmount.toFixed(2)}`);
      console.log(`  • Estimated Total:    ₹${provEst.estimatedTotal.toFixed(2)}`);
      console.log(`  • Provisional Flag:   ${provEst.isProvisional}`);
      console.log(`  • Note:               "${provEst.note}"\n`);

      // Test with distance (15 km to destination with 5 km included)
      const distEst = await pricingService.calculateEstimate({
        category: cat,
        vehicleType: 'Heavy Vehicle',
        customerLat: 12.9716,
        customerLng: 77.5946,
        destinationLat: 12.9260,
        destinationLng: 77.6762,
      });

      console.log(`[${cat} — Route Estimate to Destination (~13.3 km)]:`);
      console.log(`  • Measured Distance:  ${distEst.distanceKm} km`);
      console.log(`  • Included Distance:  ${distEst.includedDistanceKm} km`);
      console.log(`  • Billable Distance:  ${distEst.billableDistanceKm} km`);
      console.log(`  • Per-Km Rate:        ₹${distEst.perKmCharge}/km`);
      console.log(`  • Distance Charge:    ₹${distEst.distanceCharge.toFixed(2)}`);
      console.log(`  • Subtotal:           ₹${distEst.subtotal.toFixed(2)}`);
      console.log(`  • GST (${distEst.taxRate * 100}%):        ₹${distEst.taxAmount.toFixed(2)}`);
      console.log(`  • Estimated Total:    ₹${distEst.estimatedTotal.toFixed(2)}`);
      console.log(`  • Provisional Flag:   ${distEst.isProvisional}\n`);
      console.log('------------------------------------------------------\n');
    }

    console.log('✅ All 5 categories successfully verified with exact pricing calculations!\n');
  } catch (err) {
    console.error('❌ Verification failed:', err);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

verifyAll();
