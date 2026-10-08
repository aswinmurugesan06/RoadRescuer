/**
 * RoadRescue Service Categories & Multi-Service Request Validation Test Suite
 *
 * Tests cover:
 *  1. Create MECHANIC service request -> 201 Created & category=MECHANIC
 *  2. Create PUNCTURE service request -> 201 Created & category=PUNCTURE
 *  3. Create TOW_TRUCK service request -> 201 Created & category=TOW_TRUCK
 *  4. Create BATTERY service request -> 201 Created & category=BATTERY
 *  5. Create FUEL service request -> 201 Created & category=FUEL
 *  6. Create request with invalid category -> 400 Bad Request (Validation failed)
 *  7. Register BATTERY provider -> 201 Created & ProviderProfile category=BATTERY
 *  8. Register FUEL provider -> 201 Created & ProviderProfile category=FUEL
 *  9. Provider Category compatibility & discovery tests for BATTERY & FUEL
 * 10. Direct PostgreSQL verification of all 5 categories
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

function assert(condition, testName, details = '') {
  if (condition) {
    console.log(`✅ [PASS] ${testName}`);
    passed++;
  } else {
    console.error(`❌ [FAIL] ${testName} - ${details}`);
    failed++;
  }
}

async function runCategoryTests() {
  console.log('\n======================================================');
  console.log('🧪 ROADRESCUE 5-CATEGORY VALIDATION & DISPATCH TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const custEmail = 'cat_cust_test@roadrescue.in';
  const batteryProvEmail = 'battery_prov_test@roadrescue.in';
  const fuelProvEmail = 'fuel_prov_test@roadrescue.in';
  const mechProvEmail = 'mech_prov_test@roadrescue.in';

  const testEmails = [custEmail, batteryProvEmail, fuelProvEmail, mechProvEmail];
  const testMobiles = ['9811001101', '9811001102', '9811001103', '9811001104'];

  try {
    // ── 0. Cleanup ─────────────────────────────────────────────────────────────
    if (prisma) {
      await prisma.serviceRequest.deleteMany({
        where: { customer: { email: { in: testEmails } } },
      });
      await prisma.user.deleteMany({
        where: {
          OR: [
            { email: { in: testEmails } },
            { mobile: { in: testMobiles } },
          ],
        },
      });
    }

    // ── 1. Register Customer ───────────────────────────────────────────────────
    const regCust = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Aswin Customer',
        mobile: '9811001101',
        email: custEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });

    const custToken = regCust.data.data.token;
    const custId = regCust.data.data.user.id;

    assert(regCust.status === 201 && custToken, '1. Register Customer for Category Tests');

    // ── 2. Create MECHANIC Service Request ────────────────────────────────────
    const mechReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${custToken}` },
      body: {
        serviceType: 'Mechanical Repair',
        problemDescription: 'Engine overheating on highway',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        customerAddress: 'Chennai Central Highway',
        vehiclePlate: 'TN-01-AB-1001',
        vehicleModel: 'Tata Prima 4028',
        category: 'MECHANIC',
      },
    });

    assert(
      mechReq.status === 201 &&
        mechReq.data.data.category === 'MECHANIC' &&
        mechReq.data.data.status === 'PENDING',
      '2. Create MECHANIC Service Request',
      JSON.stringify(mechReq.data)
    );

    // ── 3. Create PUNCTURE Service Request ────────────────────────────────────
    const puncReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${custToken}` },
      body: {
        serviceType: 'Tyre & Puncture Service',
        problemDescription: 'Front tyre blowout',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        customerAddress: 'Chennai Port Road',
        vehiclePlate: 'TN-01-AB-1002',
        vehicleModel: 'Ashok Leyland 2820',
        category: 'PUNCTURE',
      },
    });

    assert(
      puncReq.status === 201 &&
        puncReq.data.data.category === 'PUNCTURE' &&
        puncReq.data.data.status === 'PENDING',
      '3. Create PUNCTURE Service Request',
      JSON.stringify(puncReq.data)
    );

    // ── 4. Create TOW_TRUCK Service Request ──────────────────────────────────
    const towReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${custToken}` },
      body: {
        serviceType: 'Tow Truck / Recovery',
        problemDescription: 'Transmission failure, needs flatbed tow',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        customerAddress: 'GST Road Km 28',
        vehiclePlate: 'TN-01-AB-1003',
        vehicleModel: 'Eicher Pro 6028',
        category: 'TOW_TRUCK',
      },
    });

    assert(
      towReq.status === 201 &&
        towReq.data.data.category === 'TOW_TRUCK' &&
        towReq.data.data.status === 'PENDING',
      '4. Create TOW_TRUCK Service Request',
      JSON.stringify(towReq.data)
    );

    // ── 5. Create BATTERY Service Request ─────────────────────────────────────
    const batteryReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${custToken}` },
      body: {
        serviceType: 'Battery Jump-Start',
        problemDescription: '24V Truck battery dead after overnight halt',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        customerAddress: 'Madhavaram Truck Terminal',
        vehiclePlate: 'TN-01-AB-1004',
        vehicleModel: 'BharatBenz 3528C',
        category: 'BATTERY',
      },
    });

    assert(
      batteryReq.status === 201 &&
        batteryReq.data.data.category === 'BATTERY' &&
        batteryReq.data.data.status === 'PENDING',
      '5. Create BATTERY Service Request',
      JSON.stringify(batteryReq.data)
    );
    const batteryReqId = batteryReq.data.data.id;

    // ── 6. Create FUEL Service Request ────────────────────────────────────────
    const fuelReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${custToken}` },
      body: {
        serviceType: 'Emergency Fuel Delivery',
        problemDescription: 'Ran out of diesel on highway bypass',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        customerAddress: 'Outer Ring Road Exit 4',
        vehiclePlate: 'TN-01-AB-1005',
        vehicleModel: 'Mahindra Blazo X',
        category: 'FUEL',
      },
    });

    assert(
      fuelReq.status === 201 &&
        fuelReq.data.data.category === 'FUEL' &&
        fuelReq.data.data.status === 'PENDING',
      '6. Create FUEL Service Request',
      JSON.stringify(fuelReq.data)
    );
    const fuelReqId = fuelReq.data.data.id;

    // ── 7. Rejection of Invalid Category ──────────────────────────────────────
    const invalidCatReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${custToken}` },
      body: {
        serviceType: 'Air Conditioner Repair',
        problemDescription: 'AC cooling not working',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        vehiclePlate: 'TN-01-AB-9999',
        vehicleModel: 'Truck',
        category: 'INVALID_CATEGORY',
      },
    });

    assert(
      invalidCatReq.status === 400 &&
        invalidCatReq.data.message === 'Validation failed' &&
        invalidCatReq.data.errors.some((e) => e.includes('category must be one of:')),
      '7. Rejection of Invalid Category (Validation Error 400)',
      JSON.stringify(invalidCatReq.data)
    );

    // ── 8. Register BATTERY Provider & Verification ───────────────────────────
    const regBatteryProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'SuperPower Battery Hub',
        mobile: '9811001102',
        email: batteryProvEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
        providerCategory: 'BATTERY',
      },
    });

    assert(
      regBatteryProv.status === 201 &&
        regBatteryProv.data.data.user.providerProfile.category === 'BATTERY',
      '8. Register BATTERY Provider with category=BATTERY',
      JSON.stringify(regBatteryProv.data)
    );
    const batteryProvToken = regBatteryProv.data.data.token;
    const batteryProvUserId = regBatteryProv.data.data.user.id;

    // Approve & make available
    if (prisma) {
      await prisma.providerProfile.update({
        where: { userId: batteryProvUserId },
        data: {
          verificationStatus: 'APPROVED',
          availability: 'AVAILABLE',
          latitude: 13.0830,
          longitude: 80.2710,
        },
      });
    }

    // ── 9. BATTERY Provider Views Available Requests ──────────────────────────
    const batteryAvailRes = await request('/api/service-requests/available', {
      headers: { Authorization: `Bearer ${batteryProvToken}` },
    });

    const hasBatteryReq = batteryAvailRes.data.data?.some((r) => r.id === batteryReqId);
    const hasFuelReq = batteryAvailRes.data.data?.some((r) => r.id === fuelReqId);

    assert(
      batteryAvailRes.status === 200 && hasBatteryReq && !hasFuelReq,
      '9. BATTERY Provider sees BATTERY request and is isolated from FUEL request',
      `Found items: ${batteryAvailRes.data.data?.map((r) => r.category).join(', ')}`
    );

    // ── 10. BATTERY Provider Accepts BATTERY Request ──────────────────────────
    const batteryAcceptRes = await request(
      `/api/service-requests/${batteryReqId}/accept`,
      {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${batteryProvToken}` },
      }
    );

    assert(
      batteryAcceptRes.status === 200 &&
        batteryAcceptRes.data.data.status === 'ACCEPTED' &&
        batteryAcceptRes.data.data.providerId === batteryProvUserId,
      '10. BATTERY Provider Accepts BATTERY Request',
      JSON.stringify(batteryAcceptRes.data)
    );

    // ── 11. Register FUEL Provider ────────────────────────────────────────────
    const regFuelProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Express Highway Fuel Support',
        mobile: '9811001103',
        email: fuelProvEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
        providerCategory: 'FUEL',
      },
    });

    assert(
      regFuelProv.status === 201 &&
        regFuelProv.data.data.user.providerProfile.category === 'FUEL',
      '11. Register FUEL Provider with category=FUEL',
      JSON.stringify(regFuelProv.data)
    );
    const fuelProvToken = regFuelProv.data.data.token;
    const fuelProvUserId = regFuelProv.data.data.user.id;

    if (prisma) {
      await prisma.providerProfile.update({
        where: { userId: fuelProvUserId },
        data: {
          verificationStatus: 'APPROVED',
          availability: 'AVAILABLE',
          latitude: 13.0830,
          longitude: 80.2710,
        },
      });
    }

    // ── 12. FUEL Provider Accepts FUEL Request ────────────────────────────────
    const fuelAcceptRes = await request(
      `/api/service-requests/${fuelReqId}/accept`,
      {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${fuelProvToken}` },
      }
    );

    assert(
      fuelAcceptRes.status === 200 &&
        fuelAcceptRes.data.data.status === 'ACCEPTED' &&
        fuelAcceptRes.data.data.providerId === fuelProvUserId,
      '12. FUEL Provider Accepts FUEL Request',
      JSON.stringify(fuelAcceptRes.data)
    );

    // ── 13. Direct Database Verification of All 5 Categories ───────────────────
    if (prisma) {
      const allFive = await prisma.serviceRequest.findMany({
        where: { customerId: custId },
        select: { id: true, category: true, serviceType: true, status: true },
      });

      const categoriesFound = new Set(allFive.map((r) => r.category));
      const expected = ['MECHANIC', 'PUNCTURE', 'TOW_TRUCK', 'BATTERY', 'FUEL'];
      const allPresent = expected.every((c) => categoriesFound.has(c));

      assert(
        allPresent && allFive.length === 5,
        '13. Direct PostgreSQL Verification: All 5 categories stored in DB',
        `Categories in DB: ${Array.from(categoriesFound).join(', ')}`
      );
    }
  } catch (err) {
    console.error('Test execution error:', err);
    failed++;
  } finally {
    await stopServer();
    console.log('\n------------------------------------------------------');
    console.log(
      `📊 Category Test Summary: Total: ${passed + failed} | Passed: ${passed} | Failed: ${failed}`
    );
    console.log('------------------------------------------------------\n');
    process.exit(failed > 0 ? 1 : 0);
  }
}

runCategoryTests();
