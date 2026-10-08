/**
 * RoadRescue Phase 14 — Smart Provider Discovery & Automatic Dispatch Test Suite
 *
 * Tests cover:
 *  - Nearby provider discovery and proximity filtering
 *  - Category matching (MECHANIC vs PUNCTURE vs TOW_TRUCK)
 *  - Verification status filtering (APPROVED only; rejects PENDING/REJECTED/SUSPENDED)
 *  - Availability status filtering (AVAILABLE only; rejects BUSY/OFFLINE)
 *  - Smart ranking algorithm (distance, rating, workload score)
 *  - Automatic dispatch workflow (candidate notification, atomic acceptance, BUSY update)
 *  - Rejection & immediate reassignment to next candidate
 *  - Candidate timeout and auto-advancement
 *  - Concurrent acceptance protection (409 Conflict)
 *  - Location privacy (obfuscated coordinates in discovery)
 */

const http = require('http');
const app = require('./src/app');
const { prisma } = require('./src/config/prisma');
const dispatchService = require('./src/services/dispatchService');

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
  console.log('⚡ ROADRESCUE PHASE 14 SMART DISPATCH TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const custEmail = 'disp_cust_test@roadrescue.in';
  const provEmail1 = 'disp_prov1_test@roadrescue.in'; // Closer, High Rating
  const provEmail2 = 'disp_prov2_test@roadrescue.in'; // Further away, Good Rating
  const provEmail3 = 'disp_prov3_test@roadrescue.in'; // Wrong Category (TOW_TRUCK)
  const provEmail4 = 'disp_prov4_test@roadrescue.in'; // OFFLINE
  const provEmail5 = 'disp_prov5_test@roadrescue.in'; // PENDING verification

  let customerToken, provToken1, provToken2;
  let custUserId, prov1UserId, prov2UserId, prov3UserId, prov4UserId, prov5UserId;
  let requestId;

  try {
    // ── Cleanup ───────────────────────────────────────────────────────────────
    if (prisma) {
      const testEmails = [custEmail, provEmail1, provEmail2, provEmail3, provEmail4, provEmail5];
      await prisma.payment.deleteMany({
        where: { customer: { email: { in: testEmails } } },
      });
      await prisma.billItem.deleteMany({
        where: { bill: { customer: { email: { in: testEmails } } } },
      });
      await prisma.bill.deleteMany({
        where: { customer: { email: { in: testEmails } } },
      });
      await prisma.serviceRequest.deleteMany({
        where: { customer: { email: { in: testEmails } } },
      });
      await prisma.providerProfile.deleteMany({
        where: { user: { email: { in: testEmails } } },
      });
      await prisma.user.deleteMany({
        where: { email: { in: testEmails } },
      });

      // Isolate test: set any existing background providers to OFFLINE
      await prisma.providerProfile.updateMany({
        data: { availability: 'OFFLINE' },
      });
    }

    // ── Setup Users ──────────────────────────────────────────────────────────
    // 1. Customer at Bangalore MG Road (12.9716, 77.5946)
    const regCust = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Dispatch Customer',
        mobile: '9880111220',
        email: custEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    customerToken = regCust.data?.data?.token;
    custUserId = regCust.data?.data?.user?.id;

    // 2. Provider 1: MECHANIC, 2km away at Richmond Town (12.9600, 77.6000), Rating 4.9, 20 jobs
    const regP1 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Mechanic Ramesh (Close)',
        mobile: '9880111221',
        email: provEmail1,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    provToken1 = regP1.data?.data?.token;
    prov1UserId = regP1.data?.data?.user?.id;

    await prisma.providerProfile.updateMany({
      where: { userId: prov1UserId },
      data: {
        category: 'MECHANIC',
        verificationStatus: 'APPROVED',
        availability: 'AVAILABLE',
        latitude: 12.9600,
        longitude: 77.6000,
        rating: 4.9,
        totalJobs: 20,
        serviceRadiusKm: 25.0,
      },
    });

    // 3. Provider 2: MECHANIC, 8km away at Indiranagar (12.9783, 77.6408), Rating 4.5, 5 jobs
    const regP2 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Mechanic Suresh (Far)',
        mobile: '9880111222',
        email: provEmail2,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    provToken2 = regP2.data?.data?.token;
    prov2UserId = regP2.data?.data?.user?.id;

    await prisma.providerProfile.updateMany({
      where: { userId: prov2UserId },
      data: {
        category: 'MECHANIC',
        verificationStatus: 'APPROVED',
        availability: 'AVAILABLE',
        latitude: 12.9783,
        longitude: 77.6408,
        rating: 4.5,
        totalJobs: 5,
        serviceRadiusKm: 25.0,
      },
    });

    // 4. Provider 3: TOW_TRUCK (Different category), Close (12.9650, 77.5980)
    const regP3 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Tow Truck Ganesh',
        mobile: '9880111223',
        email: provEmail3,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    prov3UserId = regP3.data?.data?.user?.id;

    await prisma.providerProfile.updateMany({
      where: { userId: prov3UserId },
      data: {
        category: 'TOW_TRUCK',
        verificationStatus: 'APPROVED',
        availability: 'AVAILABLE',
        latitude: 12.9650,
        longitude: 77.5980,
      },
    });

    // 5. Provider 4: MECHANIC, but OFFLINE
    const regP4 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Offline Mechanic',
        mobile: '9880111224',
        email: provEmail4,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    prov4UserId = regP4.data?.data?.user?.id;

    await prisma.providerProfile.updateMany({
      where: { userId: prov4UserId },
      data: {
        category: 'MECHANIC',
        verificationStatus: 'APPROVED',
        availability: 'OFFLINE',
        latitude: 12.9620,
        longitude: 77.5990,
      },
    });

    // 6. Provider 5: MECHANIC, but PENDING Verification
    const regP5 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Unverified Mechanic',
        mobile: '9880111225',
        email: provEmail5,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    prov5UserId = regP5.data?.data?.user?.id;

    await prisma.providerProfile.updateMany({
      where: { userId: prov5UserId },
      data: {
        category: 'MECHANIC',
        verificationStatus: 'PENDING',
        availability: 'AVAILABLE',
        latitude: 12.9610,
        longitude: 77.5980,
      },
    });

    // Create Customer Service Request: Category = MECHANIC
    const regReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        serviceType: 'Engine Diagnostics',
        problemDescription: 'Car engine stalled at signal',
        customerLatitude: 12.9716,
        customerLongitude: 77.5946,
        customerAddress: 'MG Road Metro Station, Bangalore',
        vehiclePlate: 'KA 03 MB 1111',
        vehicleModel: 'Honda City',
      },
    });
    assert(regReq.status === 201, 'Customer creates roadside assistance request (201)');
    requestId = regReq.data?.data?.id;

    // ── 1. Nearby Provider Discovery & Filtering ─────────────────────────────
    console.log('\n--- 1. Nearby Provider Discovery & Capability Filtering ---');

    const discRes = await request(`/api/service-requests/${requestId}/discover`, {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(discRes.status === 200, 'Customer discovers nearby ranked providers (200)');
    const candidates = discRes.data?.data?.candidates || [];

    // Should ONLY match Provider 1 and Provider 2 (APPROVED, AVAILABLE, MECHANIC)
    assert(candidates.length === 2, `Discovered exactly 2 eligible candidates (got ${candidates.length})`);
    const candidateIds = candidates.map((c) => c.userId);
    assert(candidateIds.includes(prov1UserId), 'Includes closer approved mechanic (Provider 1)');
    assert(candidateIds.includes(prov2UserId), 'Includes secondary approved mechanic (Provider 2)');
    assert(!candidateIds.includes(prov3UserId), 'Excludes wrong category (Tow Truck Provider 3)');
    assert(!candidateIds.includes(prov4UserId), 'Excludes OFFLINE provider (Provider 4)');
    assert(!candidateIds.includes(prov5UserId), 'Excludes PENDING unverified provider (Provider 5)');

    // Location privacy: Coordinates should not be exposed in public candidate preview
    assert(candidates[0].latitude === undefined, 'Exact candidate latitude is not leaked in discovery');

    // ── 2. Smart Ranking Algorithm ───────────────────────────────────────────
    console.log('\n--- 2. Deterministic Ranking & Scoring ---');

    // Candidate 1 (closer, higher rating, more jobs) MUST be ranked #1
    assert(candidates[0].userId === prov1UserId, 'Candidate 1 is ranked #1 (Best candidate)');
    assert(candidates[0].score > candidates[1].score, `Candidate 1 score (${candidates[0].score}) > Candidate 2 score (${candidates[1].score})`);
    assert(candidates[0].distanceKm < candidates[1].distanceKm, 'Candidate 1 is physically closer');
    assert(typeof candidates[0].etaMinutes === 'number' && candidates[0].etaMinutes > 0, `Candidate 1 has ETA: ${candidates[0].etaMinutes} min`);

    // ── 3. Automatic Dispatch Workflow ───────────────────────────────────────
    console.log('\n--- 3. Automatic Dispatch Engine ---');

    const dispRes = await request(`/api/service-requests/${requestId}/dispatch`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { timeoutMs: 15000, radiusKm: 25.0 },
    });
    assert(dispRes.status === 200, 'Triggers automatic dispatch workflow (200)');
    assert(dispRes.data?.data?.status === 'DISPATCHED', 'Dispatch status is DISPATCHED');
    assert(dispRes.data?.data?.candidate?.userId === prov1UserId, 'Dispatched to Candidate 1 (Provider 1)');

    // ── 4. Rejection & Immediate Re-dispatch ──────────────────────────────────
    console.log('\n--- 4. Provider Rejection & Automatic Reassignment ---');

    // Provider 1 rejects the request
    const rejRes = await request(`/api/service-requests/${requestId}/reject`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${provToken1}` },
      body: { reason: 'Busy on another job' },
    });
    assert(rejRes.status === 200, 'Provider 1 rejects dispatched job (200)');
    assert(rejRes.data?.data?.nextDispatch?.candidate?.userId === prov2UserId, 'Engine automatically advances to Candidate 2 (Provider 2)');

    // ── 5. Provider Acceptance & Atomic Locking ──────────────────────────────
    console.log('\n--- 5. Provider Acceptance & Atomic Concurrency Safety ---');

    // Provider 2 accepts the request
    const accRes = await request(`/api/service-requests/${requestId}/accept`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${provToken2}` },
    });
    assert(accRes.status === 200, 'Provider 2 accepts service request (200)');
    assert(accRes.data?.data?.status === 'ACCEPTED', 'Request status updated to ACCEPTED');
    assert(accRes.data?.data?.providerId === prov2UserId, 'Provider 2 assigned to request');

    // Check Provider 2 availability automatically set to BUSY
    const p2Profile = await prisma.providerProfile.findUnique({ where: { userId: prov2UserId } });
    assert(p2Profile?.availability === 'BUSY', 'Provider availability updated to BUSY upon acceptance');

    // 5.2 Concurrency check: Provider 1 attempts to accept already-accepted request -> 409 Conflict
    const confRes = await request(`/api/service-requests/${requestId}/accept`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${provToken1}` },
    });
    assert(confRes.status === 409 || confRes.status === 403, 'Concurrent accept rejected with 409/403 Conflict');

    // ── 6. Candidate Timeout & Advancement Simulation ────────────────────────
    console.log('\n--- 6. Candidate Timeout Handling Simulation ---');

    // Create Request 2
    const req2 = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        serviceType: 'Battery Jumpstart',
        problemDescription: 'Dead car battery',
        customerLatitude: 12.9716,
        customerLongitude: 77.5946,
        customerAddress: 'MG Road, Bangalore',
        vehiclePlate: 'KA 03 MB 1111',
        vehicleModel: 'Honda City',
      },
    });
    const req2Id = req2.data?.data?.id;

    // Reset Provider 1 to AVAILABLE
    await prisma.providerProfile.updateMany({
      where: { userId: prov1UserId },
      data: { availability: 'AVAILABLE' },
    });

    // Start dispatch with short 500ms timeout
    await dispatchService.startDispatch(req2Id, { timeoutMs: 300 });

    // Manually trigger candidate timeout
    const timeoutAdvancement = await dispatchService.handleCandidateTimeout(req2Id, prov1UserId);
    assert(timeoutAdvancement?.status === 'DISPATCHED' || timeoutAdvancement?.status === 'NO_PROVIDER_AVAILABLE', 'Timeout handling successfully advances candidate');

  } catch (err) {
    console.error('Unhandled test error:', err);
    failed++;
  } finally {
    await stopServer();
  }

  console.log('\n======================================================');
  console.log('Phase 14 Smart Dispatch Tests Summary:');
  console.log(`  Passed: ${passed}`);
  console.log(`  Failed: ${failed}`);
  console.log(`  Total:  ${passed + failed}`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
