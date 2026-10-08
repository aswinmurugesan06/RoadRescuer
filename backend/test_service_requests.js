/**
 * Phase 3B Automated Service Request Foundation Test Suite
 * Tests creation, customer retrieval, provider visibility, authorization guards,
 * atomic acceptance, location privacy, and PostgreSQL persistence.
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

  const data = await response.json();
  return {
    status: response.status,
    data,
  };
}

async function runTests() {
  console.log('\n======================================================');
  console.log('🧪 ROADRESCUE PHASE 3B SERVICE REQUEST TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  let passed = 0;
  let failed = 0;

  function assert(condition, testName, details = '') {
    if (condition) {
      console.log(`✅ [PASS] Test: ${testName}`);
      passed++;
    } else {
      console.error(`❌ [FAIL] Test: ${testName} - ${details}`);
      failed++;
    }
  }

  try {
    // ── Setup: Clean & Register Test Entities ─────────────────────────
    const testCustomerEmail = 'customer_3b@roadrescue.in';
    const testCustomer2Email = 'customer2_3b@roadrescue.in';
    const testProviderMechEmail = 'provider_mech_3b@roadrescue.in';
    const testProviderTowEmail = 'provider_tow_3b@roadrescue.in';
    const testProviderMech2Email = 'provider_mech2_3b@roadrescue.in';

    const testEmails = [
      testCustomerEmail,
      testCustomer2Email,
      testProviderMechEmail,
      testProviderTowEmail,
      testProviderMech2Email,
    ];
    const testMobiles = [
      '9841122334',
      '9841122335',
      '9841122336',
      '9841122337',
      '9841122338',
    ];

    if (prisma) {
      // Clean up previous test runs
      await prisma.serviceRequest.deleteMany({
        where: {
          customer: {
            email: { in: testEmails },
          },
        },
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

    // 1. Register Customer 1
    const regCust1 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Ramesh Heavy Driver',
        mobile: '9841122334',
        email: testCustomerEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    const cust1Token = regCust1.data.data.token;
    const cust1Id = regCust1.data.data.user.id;

    // 2. Register Customer 2
    const regCust2 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Suresh Lorry Owner',
        mobile: '9841122335',
        email: testCustomer2Email,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    const cust2Token = regCust2.data.data.token;

    // 3. Register Mechanic Provider
    const regMech = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Guru Express Garage',
        mobile: '9841122336',
        email: testProviderMechEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
        providerCategory: 'MECHANIC',
      },
    });
    const mechToken = regMech.data.data.token;
    const mechUserId = regMech.data.data.user.id;

    // 4. Register Tow Truck Provider
    const regTow = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Highways Towing Service',
        mobile: '9841122337',
        email: testProviderTowEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
        providerCategory: 'TOW_TRUCK',
      },
    });
    const towToken = regTow.data.data.token;

    // 5. Register Mechanic Provider 2 (Competitor / Alternate Provider)
    const regMech2 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Speedy Diesel Works',
        mobile: '9841122338',
        email: testProviderMech2Email,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
        providerCategory: 'MECHANIC',
      },
    });
    const mech2Token = regMech2.data.data.token;
    const mech2UserId = regMech2.data.data.user.id;

    if (prisma) {
      await prisma.providerProfile.update({
        where: { userId: mech2UserId },
        data: { verificationStatus: 'APPROVED', availability: 'AVAILABLE' },
      });
    }

    // ── Test 1: Create Service Request (Customer) ────────────────────
    const createRes = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${cust1Token}` },
      body: {
        serviceType: 'Mechanical Repair',
        problemDescription: 'Clutch failure on highway NH44 near Toll Plaza',
        customerLatitude: 12.971598,
        customerLongitude: 77.594562,
        customerAddress: 'NH44, Krishnagiri Highway, Km 42',
        vehiclePlate: 'TN-22-CY-8899',
        vehicleModel: 'BharatBenz 2823R Heavy Truck',
        vehicleType: 'Heavy Vehicle',
        category: 'MECHANIC',
      },
    });

    assert(
      createRes.status === 201 &&
        createRes.data.data.status === 'PENDING' &&
        createRes.data.data.category === 'MECHANIC' &&
        createRes.data.data.vehiclePlate === 'TN-22-CY-8899' &&
        createRes.data.data.customerId === cust1Id,
      '1. Customer Creates Roadside Assistance Request',
      JSON.stringify(createRes.data)
    );
    const createdRequestId = createRes.data.data.id;

    // ── Test 2: Input Validation on Request Creation ─────────────────
    const invalidReqRes = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${cust1Token}` },
      body: {
        serviceType: '', // Empty
        customerLatitude: 195.0, // Invalid latitude > 90
      },
    });

    assert(
      invalidReqRes.status === 400 &&
        invalidReqRes.data.errors &&
        invalidReqRes.data.errors.length >= 2,
      '2. Input Validation Rejects Malformed Request',
      JSON.stringify(invalidReqRes.data)
    );

    // ── Test 3: Customer Can Fetch Their Own Requests ────────────────
    const myReqsRes = await request('/api/service-requests/my-requests', {
      headers: { Authorization: `Bearer ${cust1Token}` },
    });

    assert(
      myReqsRes.status === 200 &&
        Array.isArray(myReqsRes.data.data) &&
        myReqsRes.data.data.length >= 1 &&
        myReqsRes.data.data[0].id === createdRequestId,
      '3. Customer Fetches Own Requests',
      `Count: ${myReqsRes.data.count}`
    );

    // ── Test 4: Provider Cannot Create Requests (Role Guard) ─────────
    const providerCreateRes = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${mechToken}` },
      body: {
        serviceType: 'Mechanical Repair',
        problemDescription: 'Test issue',
        customerLatitude: 13.0,
        customerLongitude: 80.0,
        vehiclePlate: 'TN-01-AA-1111',
        vehicleModel: 'Truck',
      },
    });

    assert(
      providerCreateRes.status === 403,
      '4. Provider Forbidden From Creating Requests (Role Guard)',
      `Status: ${providerCreateRes.status}`
    );

    // ── Test 5: Pending Provider Blocked From Available Requests ──────
    // By default, a newly registered provider has verificationStatus = PENDING
    const pendingProviderRes = await request('/api/service-requests/available', {
      headers: { Authorization: `Bearer ${mechToken}` },
    });

    assert(
      pendingProviderRes.status === 403 &&
        pendingProviderRes.data.message.includes('PENDING'),
      '5. Unapproved (PENDING) Provider Blocked From Viewing Requests',
      pendingProviderRes.data.message
    );

    // ── Test 6: Offline Provider Blocked Even If Approved ─────────────
    // Approve the mechanic provider, but leave availability = OFFLINE
    if (prisma) {
      await prisma.providerProfile.update({
        where: { userId: mechUserId },
        data: {
          verificationStatus: 'APPROVED',
          availability: 'OFFLINE',
        },
      });
    }

    const offlineProviderRes = await request('/api/service-requests/available', {
      headers: { Authorization: `Bearer ${mechToken}` },
    });

    assert(
      offlineProviderRes.status === 403 &&
        offlineProviderRes.data.message.includes('OFFLINE'),
      '6. Approved but OFFLINE Provider Blocked From Viewing Requests',
      offlineProviderRes.data.message
    );

    // ── Test 7: Approved & AVAILABLE Provider Sees Requests with Privacy
    // Set mechanic availability to AVAILABLE
    if (prisma) {
      await prisma.providerProfile.update({
        where: { userId: mechUserId },
        data: {
          verificationStatus: 'APPROVED',
          availability: 'AVAILABLE',
        },
      });
    }

    const availableRes = await request('/api/service-requests/available', {
      headers: { Authorization: `Bearer ${mechToken}` },
    });

    assert(
      availableRes.status === 200 &&
        Array.isArray(availableRes.data.data) &&
        availableRes.data.data.length >= 1 &&
        availableRes.data.data[0].id === createdRequestId &&
        // Verify privacy: exact coordinates rounded to 2 decimals (~1km)
        availableRes.data.data[0].customerLatitude === 12.97 &&
        availableRes.data.data[0].customerLongitude === 77.59 &&
        !availableRes.data.data[0].customerMobile, // Customer phone is masked before acceptance
      '7. Approved & AVAILABLE Provider Views Requests (Location Privacy Enforced)',
      JSON.stringify(availableRes.data.data[0])
    );

    // ── Test 8: Category Matching (Tow Truck Does Not See Mechanic Req)
    // Approve Tow truck provider and make available
    if (prisma) {
      const towUser = await prisma.user.findUnique({
        where: { email: testProviderTowEmail },
      });
      await prisma.providerProfile.update({
        where: { userId: towUser.id },
        data: {
          verificationStatus: 'APPROVED',
          availability: 'AVAILABLE',
        },
      });
    }

    const towAvailableRes = await request('/api/service-requests/available', {
      headers: { Authorization: `Bearer ${towToken}` },
    });

    assert(
      towAvailableRes.status === 200 &&
        towAvailableRes.data.data.filter((r) => r.id === createdRequestId).length === 0,
      '8. Category Isolation: Tow Truck Provider Does Not See Mechanic Request',
      `Found: ${towAvailableRes.data.count}`
    );

    // ── Test 9: Category Mismatch Rejection on Accept ────────────────
    const mismatchAcceptRes = await request(
      `/api/service-requests/${createdRequestId}/accept`,
      {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${towToken}` },
      }
    );

    assert(
      mismatchAcceptRes.status === 400 &&
        mismatchAcceptRes.data.message.includes('category'),
      '9. Category Mismatch Rejection on Acceptance',
      mismatchAcceptRes.data.message
    );

    // ── Test 10: Authorized Provider Accepts Request ─────────────────
    const acceptRes = await request(
      `/api/service-requests/${createdRequestId}/accept`,
      {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${mechToken}` },
      }
    );

    assert(
      acceptRes.status === 200 &&
        acceptRes.data.data.status === 'ACCEPTED' &&
        acceptRes.data.data.providerId === mechUserId &&
        acceptRes.data.data.acceptedAt &&
        // Customer contact unveiled upon acceptance
        acceptRes.data.data.customer.mobile === '9841122334',
      '10. Authorized Provider Accepts Request (Customer Contact Unveiled)',
      JSON.stringify(acceptRes.data.data)
    );

    // ── Test 11: Duplicate Acceptance Rejection (409 Conflict) ────────
    // Available Provider 2 attempts to accept the already-accepted request
    const duplicateAcceptRes = await request(
      `/api/service-requests/${createdRequestId}/accept`,
      {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${mech2Token}` },
      }
    );

    assert(
      duplicateAcceptRes.status === 409 &&
        duplicateAcceptRes.data.message.includes('already been accepted'),
      '11. Duplicate Acceptance Rejection (409 Conflict)',
      duplicateAcceptRes.data.message
    );

    // ── Test 12: Customer Access Control (Cannot View Others' Requests)
    const unauthorizedViewRes = await request(
      `/api/service-requests/${createdRequestId}`,
      {
        headers: { Authorization: `Bearer ${cust2Token}` }, // Customer 2 trying to view Customer 1's request
      }
    );

    assert(
      unauthorizedViewRes.status === 403,
      '12. Customer Access Control (Customer 2 Blocked From Customer 1 Request)',
      `Status: ${unauthorizedViewRes.status}`
    );

    // ── Test 13: Authorized Parties View Request Details ──────────────
    const cust1ViewRes = await request(
      `/api/service-requests/${createdRequestId}`,
      {
        headers: { Authorization: `Bearer ${cust1Token}` },
      }
    );

    assert(
      cust1ViewRes.status === 200 &&
        cust1ViewRes.data.data.id === createdRequestId &&
        cust1ViewRes.data.data.status === 'ACCEPTED' &&
        cust1ViewRes.data.data.provider.name === 'Guru Express Garage',
      '13. Owner Customer Views Full Request Details With Assigned Provider',
      `Assigned: ${cust1ViewRes.data.data.provider?.name}`
    );

    // ── Test 14: Direct PostgreSQL Verification ──────────────────────
    if (prisma) {
      const dbRecord = await prisma.serviceRequest.findUnique({
        where: { id: createdRequestId },
        include: {
          customer: true,
          provider: { include: { providerProfile: true } },
        },
      });

      const providerProfile = await prisma.providerProfile.findUnique({
        where: { userId: mechUserId },
      });

      assert(
        dbRecord &&
          dbRecord.status === 'ACCEPTED' &&
          dbRecord.providerId === mechUserId &&
          dbRecord.customer.email === testCustomerEmail &&
          providerProfile.availability === 'BUSY',
        '14. Direct PostgreSQL Verification: Request & Provider State Persisted',
        `DB Status: ${dbRecord?.status}, Provider Availability: ${providerProfile?.availability}`
      );
    }

    // ── Test 15: Provider Updates Status (ARRIVING -> IN_SERVICE) ──
    const arrivingRes = await request(`/api/service-requests/${createdRequestId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${mechToken}` },
      body: { status: 'ARRIVING' },
    });

    const inServiceRes = await request(`/api/service-requests/${createdRequestId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${mechToken}` },
      body: { status: 'IN_SERVICE' },
    });

    assert(
      arrivingRes.status === 200 &&
        arrivingRes.data.data.status === 'ARRIVING' &&
        inServiceRes.status === 200 &&
        inServiceRes.data.data.status === 'IN_SERVICE',
      '15. Provider Updates Request Status (ARRIVING -> IN_SERVICE)',
      `Arriving: ${arrivingRes.data.data?.status}, In Service: ${inServiceRes.data.data?.status}`
    );

    // ── Test 16: Provider Completes Job (COMPLETED) & Availability Reset ──
    const completeRes = await request(`/api/service-requests/${createdRequestId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${mechToken}` },
      body: { status: 'COMPLETED' },
    });

    let mechProfileAfterComplete = null;
    if (prisma) {
      mechProfileAfterComplete = await prisma.providerProfile.findUnique({
        where: { userId: mechUserId },
      });
    }

    assert(
      completeRes.status === 200 &&
        completeRes.data.data.status === 'COMPLETED' &&
        (!mechProfileAfterComplete || mechProfileAfterComplete.availability === 'AVAILABLE'),
      '16. Provider Completes Job & Availability Resets to AVAILABLE',
      `Status: ${completeRes.data.data?.status}, Provider Availability: ${mechProfileAfterComplete?.availability || 'AVAILABLE'}`
    );

    // ── Test 17: Customer Creates Request & Transitions to SEARCHING ──
    const cust2ReqRes = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${cust1Token}` },
      body: {
        serviceType: 'Tyre & Puncture',
        problemDescription: 'Rear left tyre burst on highway',
        customerLatitude: 12.9200,
        customerLongitude: 77.6100,
        vehiclePlate: 'TN-01-AB-1234',
        vehicleModel: 'Ashok Leyland 2820',
        category: 'PUNCTURE',
      },
    });

    const cust2ReqId = cust2ReqRes.data.data.id;
    const searchingRes = await request(`/api/service-requests/${cust2ReqId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${cust1Token}` },
      body: { status: 'SEARCHING' },
    });

    assert(
      cust2ReqRes.status === 201 &&
        searchingRes.status === 200 &&
        searchingRes.data.data.status === 'SEARCHING',
      '17. Customer Creates Second Request and Transitions to SEARCHING',
      `Created: ${cust2ReqRes.status}, Status: ${searchingRes.data.data?.status}`
    );

    // ── Test 18: Customer Cancels Request (CANCELLED) ────────────────
    const cancelRes = await request(`/api/service-requests/${cust2ReqId}/cancel`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${cust1Token}` },
      body: { cancellationReason: 'Spare tyre fitted by driver' },
    });

    assert(
      cancelRes.status === 200 &&
        cancelRes.data.data.status === 'CANCELLED' &&
        cancelRes.data.data.cancellationReason === 'Spare tyre fitted by driver',
      '18. Customer Cancels Request With Reason (Status CANCELLED)',
      `Status: ${cancelRes.data.data?.status}, Reason: ${cancelRes.data.data?.cancellationReason}`
    );
  } catch (err) {
    console.error('Test execution error:', err);
    failed++;
  } finally {
    await stopServer();
    console.log('\n------------------------------------------------------');
    console.log(
      `📊 Test Summary: Total: ${passed + failed} | Passed: ${passed} | Failed: ${failed}`
    );
    console.log('------------------------------------------------------\n');
    process.exit(failed > 0 ? 1 : 0);
  }
}

runTests();
