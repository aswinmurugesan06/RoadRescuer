/**
 * RoadRescue Phase 2 — Dynamic Pricing Backend Integration & Calculation Tests
 */

const http = require('http');
const app = require('./src/app');
const { prisma } = require('./src/config/prisma');

let server;
let baseUrl;

async function startServer() {
  return new Promise((resolve) => {
    server = http.createServer(app);
    server.listen(0, () => {
      const port = server.address().port;
      baseUrl = `http://localhost:${port}`;
      resolve();
    });
  });
}

async function stopServer() {
  return new Promise((resolve) => {
    if (server) server.close(resolve);
    else resolve();
  });
}

async function request(path, options = {}) {
  const url = `${baseUrl}${path}`;
  const response = await fetch(url, {
    method: options.method || 'GET',
    headers: {
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const data = await response.json().catch(() => ({}));
  return {
    status: response.status,
    data,
  };
}

let passed = 0;
let failed = 0;

function assert(condition, label, details = '') {
  if (condition) {
    console.log(`  OK   ${label}`);
    passed++;
  } else {
    console.error(`  FAIL ${label}${details ? ' - ' + details : ''}`);
    failed++;
  }
}

async function runTests() {
  console.log('\n======================================================');
  console.log('🧪 ROADRESCUE PHASE 2 DYNAMIC PRICING TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const adminEmail = 'admin_price_test@roadrescue.in';
  const custEmail = 'cust_price_test@roadrescue.in';
  const adminMobile = '9840999001';
  const custMobile = '9840999002';

  let adminToken, customerToken;
  let ruleTier1Id, ruleTier2Id, ruleTier3Id;

  try {
    // ── 0. Cleanup Previous Test Data ──────────────────────────────────────
    if (prisma) {
      await prisma.pricingConfig.deleteMany({
        where: {
          description: { startsWith: '[DEMO TEST]' },
        },
      });
      await prisma.user.deleteMany({
        where: {
          email: { in: [adminEmail, custEmail] },
        },
      });
    }

    // ── 1. Setup Admin and Customer Users ──────────────────────────────────
    const regAdmin = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Pricing Admin',
        mobile: adminMobile,
        email: adminEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'ADMIN',
      },
    });
    adminToken = regAdmin.data?.data?.token;

    const regCust = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Pricing Customer',
        mobile: custMobile,
        email: custEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    customerToken = regCust.data?.data?.token;

    console.log('--- 1. Security & Role Guards ---');
    // Unauthenticated estimate request rejected
    const unauthEst = await request('/api/pricing/estimate', {
      method: 'POST',
      body: { category: 'MECHANIC' },
    });
    assert(unauthEst.status === 401, 'Unauthenticated estimate request rejected (401)');

    // Customer forbidden from admin pricing configs
    const custAdminList = await request('/api/admin/pricing-configs', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(custAdminList.status === 403, 'Customer forbidden from admin pricing configs (403)');

    const custAdminCreate = await request('/api/admin/pricing-configs', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        baseLaborCharge: 500,
      },
    });
    assert(custAdminCreate.status === 403, 'Customer forbidden from creating pricing configs (403)');

    // Admin can access admin pricing configs
    const adminList = await request('/api/admin/pricing-configs', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(adminList.status === 200, 'Admin can list pricing configs (200)');
    assert(Array.isArray(adminList.data?.data?.configs), 'Admin receives configs array');

    console.log('\n--- 2. Admin Pricing Configuration Creation & Validation ---');
    // Input validation: Negative base labor charge
    const negLabor = await request('/api/admin/pricing-configs', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        category: 'MECHANIC',
        baseLaborCharge: -100,
      },
    });
    assert(negLabor.status === 400, 'Rejects negative baseLaborCharge (400)');

    // Create Tier 3: Category default rule for MECHANIC
    const resTier3 = await request('/api/admin/pricing-configs', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        category: 'MECHANIC',
        baseLaborCharge: 400.0,
        perKmCharge: 20.0,
        includedDistanceKm: 5.0,
        additionalCharges: 50.0,
        taxRate: 0.18,
        description: '[DEMO TEST] Mechanic Category Default',
      },
    });
    assert(resTier3.status === 201, 'Admin creates Category Default rule (201)');
    ruleTier3Id = resTier3.data?.data?.id;
    assert(ruleTier3Id !== undefined, 'Returns created pricing rule ID');
    assert(resTier3.data?.data?.baseLaborCharge === 400, 'Numeric decimal serialization verified (400.00)');

    // Create Tier 2: Category + Vehicle Type (Heavy Vehicle)
    const resTier2 = await request('/api/admin/pricing-configs', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        category: 'MECHANIC',
        vehicleType: 'Heavy Vehicle',
        baseLaborCharge: 800.0,
        perKmCharge: 35.0,
        includedDistanceKm: 5.0,
        additionalCharges: 100.0,
        taxRate: 0.18,
        description: '[DEMO TEST] Mechanic Heavy Vehicle Rule',
      },
    });
    assert(resTier2.status === 201, 'Admin creates Category + Vehicle rule (201)');
    ruleTier2Id = resTier2.data?.data?.id;

    // Create Tier 1: Exact match on Category + Problem + Vehicle
    const resTier1 = await request('/api/admin/pricing-configs', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        category: 'MECHANIC',
        problemCategory: 'Engine Seized',
        vehicleType: 'Heavy Vehicle',
        baseLaborCharge: 1500.0,
        perKmCharge: 40.0,
        includedDistanceKm: 0.0,
        additionalCharges: 200.0,
        taxRate: 0.18,
        description: '[DEMO TEST] Mechanic Engine Seized Heavy Vehicle Rule',
      },
    });
    assert(resTier1.status === 201, 'Admin creates Exact Problem + Vehicle rule (201)');
    ruleTier1Id = resTier1.data?.data?.id;

    // Duplicate active rule prevention -> 409 Conflict
    const dupRes = await request('/api/admin/pricing-configs', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        category: 'MECHANIC',
        problemCategory: 'Engine Seized',
        vehicleType: 'Heavy Vehicle',
        baseLaborCharge: 1600.0,
        description: '[DEMO TEST] Duplicate Attempt',
      },
    });
    assert(dupRes.status === 409, 'Rejects duplicate active pricing rule with 409 Conflict');

    console.log('\n--- 3. Deterministic 3-Tier Cascade Rule Matching ---');
    // A: Exact match -> Tier 1
    const estTier1 = await request('/api/pricing/estimate', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        problemCategory: 'Engine Seized',
        vehicleType: 'Heavy Vehicle',
      },
    });
    assert(estTier1.status === 200, 'Customer receives estimate for Tier 1 match (200)');
    assert(
      estTier1.data?.data?.matchedTier === 'EXACT_PROBLEM_AND_VEHICLE',
      'Matched exact Tier 1 rule'
    );
    assert(estTier1.data?.data?.baseLaborCharge === 1500, 'Matched Tier 1 base labor charge (1500)');

    // B: Heavy Vehicle with general problem -> Tier 2
    const estTier2 = await request('/api/pricing/estimate', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        problemCategory: 'Brake Noise',
        vehicleType: 'Heavy Vehicle',
      },
    });
    assert(estTier2.status === 200, 'Customer receives estimate for Tier 2 match (200)');
    assert(
      estTier2.data?.data?.matchedTier === 'CATEGORY_AND_VEHICLE',
      'Matched Tier 2 Category + Vehicle rule'
    );
    assert(estTier2.data?.data?.baseLaborCharge === 800, 'Matched Tier 2 base labor charge (800)');

    // C: Different vehicle (Car) -> Tier 3 Category Default
    const estTier3 = await request('/api/pricing/estimate', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        vehicleType: 'Car',
      },
    });
    assert(estTier3.status === 200, 'Customer receives estimate for Tier 3 match (200)');
    assert(
      estTier3.data?.data?.matchedTier === 'CATEGORY_DEFAULT',
      'Matched Tier 3 Category Default rule'
    );
    assert(estTier3.data?.data?.baseLaborCharge === 400, 'Matched Tier 3 base labor charge (400)');

    // D: Category with no active rule -> 404
    const estMissing = await request('/api/pricing/estimate', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'FUEL',
        vehicleType: 'Bus',
      },
    });
    assert(estMissing.status === 404, 'Returns 404 when no active pricing rule exists');
    assert(
      estMissing.data?.message?.includes('No active pricing configuration found'),
      'Returns descriptive missing configuration message'
    );

    console.log('\n--- 4. Provisional Estimates & Distance Status ---');
    // When no provider or destination is selected -> Provisional estimate
    assert(estTier3.data?.data?.isProvisional === true, 'Provisional flag is true');
    assert(
      estTier3.data?.data?.distanceStatus === 'NO_PROVIDER_AVAILABLE_BASE_ONLY',
      'Distance status is NO_PROVIDER_AVAILABLE_BASE_ONLY'
    );
    assert(estTier3.data?.data?.distanceKm === 0, 'Distance is 0 when no provider/destination');
    assert(estTier3.data?.data?.distanceCharge === 0, 'Distance charge is 0 for base only');
    assert(
      estTier3.data?.data?.note?.includes('Provider travel charges will be calculated after provider assignment'),
      'Includes mandatory provider travel charges disclaimer'
    );

    console.log('\n--- 5. Dynamic Distance & Threshold Calculation ---');
    // Destination supplied: Customer to workshop
    // Coordinates ~ 12 km apart
    const estWithDest = await request('/api/pricing/estimate', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        vehicleType: 'Car',
        customerLat: 12.9716,
        customerLng: 77.5946,
        destinationLat: 12.9260,
        destinationLng: 77.6762,
      },
    });
    assert(estWithDest.status === 200, 'Calculates route estimate to destination (200)');
    assert(
      estWithDest.data?.data?.distanceStatus === 'MEASURED_TO_DESTINATION',
      'Distance status is MEASURED_TO_DESTINATION'
    );
    assert(estWithDest.data?.data?.isProvisional === false, 'Provisional flag is false when destination route is known');
    const actualDist = estWithDest.data?.data?.distanceKm;
    const includedDist = estWithDest.data?.data?.includedDistanceKm;
    const billableDist = estWithDest.data?.data?.billableDistanceKm;
    assert(actualDist > 0, `Measured distance along road network: ${actualDist} km`);
    assert(includedDist === 5, 'Included distance is 5 km');
    assert(billableDist === Number((actualDist - 5).toFixed(2)), 'Billable distance is (actual - included)');
    assert(estWithDest.data?.data?.distanceCharge === Number((billableDist * 20).toFixed(2)), 'Distance charge equals billable * 20/km');

    console.log('\n--- 6. GST Tax & Total Reconciliation ---');
    // Subtotal = Base (400) + DistanceCharge + AdditionalCharges (50)
    const subtotal = estWithDest.data?.data?.subtotal;
    const taxRate = estWithDest.data?.data?.taxRate;
    const taxAmount = estWithDest.data?.data?.taxAmount;
    const estimatedTotal = estWithDest.data?.data?.estimatedTotal;

    assert(taxRate === 0.18, 'Tax rate is 18% GST (0.18)');
    assert(taxAmount === Number((subtotal * 0.18).toFixed(2)), 'Tax amount matches subtotal * 18%');
    assert(estimatedTotal === Number((subtotal + taxAmount).toFixed(2)), 'Estimated total equals subtotal + taxAmount');

    console.log('\n--- 7. Admin Configuration Updates ---');
    // Update rule Tier 3 perKmCharge and verify
    const updateRes = await request(`/api/admin/pricing-configs/${ruleTier3Id}`, {
      method: 'PUT',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: {
        perKmCharge: 25.0,
      },
    });
    assert(updateRes.status === 200, 'Admin successfully updates pricing config (200)');
    assert(updateRes.data?.data?.perKmCharge === 25, 'perKmCharge updated to 25.00');

    // Clean up demo rules
    if (prisma) {
      await prisma.pricingConfig.deleteMany({
        where: { id: { in: [ruleTier1Id, ruleTier2Id, ruleTier3Id] } },
      });
      await prisma.user.deleteMany({
        where: { email: { in: [adminEmail, custEmail] } },
      });
    }

  } catch (err) {
    console.error('Test execution error:', err);
    failed++;
  } finally {
    await stopServer();
  }

  console.log('\n======================================================');
  console.log(`Phase 2 Dynamic Pricing Tests Summary:`);
  console.log(`  Passed: ${passed}`);
  console.log(`  Failed: ${failed}`);
  console.log(`  Total:  ${passed + failed}`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
