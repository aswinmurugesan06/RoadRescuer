/**
 * RoadRescue Phase 8 — Ratings, Reviews & Service Completion Test Suite
 *
 * Tests:
 *  - Service completion transition & authorization
 *  - Rating range and input validation (1-5 stars)
 *  - Status prerequisite validation (must be COMPLETED)
 *  - Role & ownership guards (customer-only, assigned customer only, provider cannot self-rate)
 *  - Duplicate rating prevention (idempotency)
 *  - Provider average rating & count aggregation calculations
 *  - Rating retrieval by requestId and providerId
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
  console.log('🧪 ROADRESCUE PHASE 8 RATINGS & COMPLETION TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const cust1Email = 'cust_rate_1@roadrescue.in';
  const cust2Email = 'cust_rate_2@roadrescue.in';
  const provEmail = 'prov_rate_1@roadrescue.in';
  const otherProvEmail = 'prov_rate_2@roadrescue.in';

  const cust1Mobile = '9840222111';
  const cust2Mobile = '9840222112';
  const provMobile = '9840222113';
  const otherProvMobile = '9840222114';

  let customer1Token, customer2Token, providerToken, otherProviderToken;
  let customer1Id, customer2Id, providerId, otherProviderId;
  let reqCompletedId, reqInProgressId, reqCancelledId;

  try {
    // ── 0. DB Cleanup ────────────────────────────────────────────────────────
    if (prisma) {
      const testEmails = [cust1Email, cust2Email, provEmail, otherProvEmail];
      await prisma.rating.deleteMany({
        where: {
          customer: { email: { in: testEmails } },
        },
      });
      await prisma.payment.deleteMany({
        where: {
          customer: { email: { in: testEmails } },
        },
      });
      await prisma.billItem.deleteMany({
        where: {
          bill: { customer: { email: { in: testEmails } } },
        },
      });
      await prisma.bill.deleteMany({
        where: {
          customer: { email: { in: testEmails } },
        },
      });
      await prisma.serviceRequest.deleteMany({
        where: {
          customer: { email: { in: testEmails } },
        },
      });
      await prisma.vehicle.deleteMany({
        where: {
          user: { email: { in: testEmails } },
        },
      });
      await prisma.providerProfile.deleteMany({
        where: {
          user: { email: { in: testEmails } },
        },
      });
      await prisma.user.deleteMany({
        where: {
          OR: [
            { email: { in: testEmails } },
            { mobile: { in: [cust1Mobile, cust2Mobile, provMobile, otherProvMobile] } },
          ],
        },
      });
    }

    // ── 1. Register Test Users ───────────────────────────────────────────────
    // Customer 1
    const regCust1 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Rating Customer 1',
        mobile: cust1Mobile,
        email: cust1Email,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    customer1Token = regCust1.data?.data?.token;
    customer1Id = regCust1.data?.data?.user?.id;

    // Customer 2
    const regCust2 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Rating Customer 2',
        mobile: cust2Mobile,
        email: cust2Email,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    customer2Token = regCust2.data?.data?.token;
    customer2Id = regCust2.data?.data?.user?.id;

    // Provider 1
    const regProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Super Mechanic Garage',
        mobile: provMobile,
        email: provEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    providerToken = regProv.data?.data?.token;
    providerId = regProv.data?.data?.user?.id;

    // Provider 2 (unassigned)
    const regProv2 = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Other Tow Works',
        mobile: otherProvMobile,
        email: otherProvEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    otherProviderToken = regProv2.data?.data?.token;
    otherProviderId = regProv2.data?.data?.user?.id;

    // Approve providers
    if (prisma) {
      await prisma.providerProfile.updateMany({
        where: { userId: { in: [providerId, otherProviderId] } },
        data: {
          verificationStatus: 'APPROVED',
          availability: 'AVAILABLE',
          category: 'MECHANIC',
        },
      });
    }

    // Customer 1 creates Vehicle
    const regVeh = await request('/api/vehicles', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: {
        type: 'CAR',
        brand: 'Honda',
        model: 'City',
        year: 2023,
        plateNumber: 'TN 07 BE 8888',
        fuelType: 'PETROL',
        color: 'Radiant Red',
      },
    });
    const vehicleId = regVeh.data?.data?.id;

    // Create Request 1 (will be completed)
    const r1 = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: {
        category: 'MECHANIC',
        serviceType: 'Battery Jumpstart',
        vehicleId,
        vehicleModel: 'Honda City',
        vehiclePlate: 'TN 07 BE 8888',
        vehicleType: 'CAR',
        problemDescription: 'Dead battery in parking',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        customerAddress: 'Anna Nagar, Chennai',
      },
    });
    reqCompletedId = r1.data?.data?.id;

    // Create Request 2 (will remain in progress)
    const r2 = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: {
        category: 'MECHANIC',
        serviceType: 'Tyre Puncture',
        vehicleId,
        vehicleModel: 'Honda City',
        vehiclePlate: 'TN 07 BE 8888',
        vehicleType: 'CAR',
        problemDescription: 'Flat front tyre',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        customerAddress: 'Anna Nagar, Chennai',
      },
    });
    reqInProgressId = r2.data?.data?.id;

    // Create Request 3 (will be cancelled)
    const r3 = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: {
        category: 'MECHANIC',
        serviceType: 'Brake Check',
        vehicleId,
        vehicleModel: 'Honda City',
        vehiclePlate: 'TN 07 BE 8888',
        vehicleType: 'CAR',
        problemDescription: 'Squeaking brakes',
        customerLatitude: 13.0827,
        customerLongitude: 80.2707,
        customerAddress: 'Anna Nagar, Chennai',
      },
    });
    reqCancelledId = r3.data?.data?.id;

    // Setup initial statuses in DB
    if (prisma) {
      await prisma.serviceRequest.update({
        where: { id: reqCompletedId },
        data: {
          status: 'IN_SERVICE',
          providerId,
          acceptedAt: new Date(),
        },
      });
      await prisma.serviceRequest.update({
        where: { id: reqInProgressId },
        data: {
          status: 'IN_SERVICE',
          providerId,
          acceptedAt: new Date(),
        },
      });
      await prisma.serviceRequest.update({
        where: { id: reqCancelledId },
        data: {
          status: 'CANCELLED',
          cancellationReason: 'Driver managed to resolve himself',
        },
      });
    }

    // ── 1. Service Completion & Authorization ───────────────────────────────
    console.log('\n--- 1. Service Completion Lifecycle ---');

    // Customer cannot complete the request (role guard)
    const c1 = await request(`/api/service-requests/${reqCompletedId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: { status: 'COMPLETED' },
    });
    assert(c1.status === 403, 'Customer cannot mark service as COMPLETED (403)');

    // Other provider cannot complete this request (ownership guard)
    const c2 = await request(`/api/service-requests/${reqCompletedId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${otherProviderToken}` },
      body: { status: 'COMPLETED' },
    });
    assert(c2.status === 403, 'Unassigned provider cannot mark service as COMPLETED (403)');

    // Assigned provider completes the job
    const c3 = await request(`/api/service-requests/${reqCompletedId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { status: 'COMPLETED' },
    });
    assert(c3.status === 200, 'Assigned provider marks service as COMPLETED (200)', JSON.stringify(c3.data));
    assert(c3.data?.data?.status === 'COMPLETED', 'Request status is COMPLETED');
    assert(c3.data?.data?.completedAt, 'completedAt timestamp is recorded');

    // Provider availability reset to AVAILABLE
    if (prisma) {
      const pProfile = await prisma.providerProfile.findUnique({
        where: { userId: providerId },
      });
      assert(pProfile?.availability === 'AVAILABLE', 'Provider availability reset to AVAILABLE after completion');
    }

    // Cannot re-complete already completed request
    const c4 = await request(`/api/service-requests/${reqCompletedId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { status: 'COMPLETED' },
    });
    assert(c4.status === 400, 'Cannot re-complete already completed request (400)');

    // ── 2. Rating Input & Range Validation ──────────────────────────────────
    console.log('\n--- 2. Rating Range & Input Validation ---');

    // Missing requestId
    const v1 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: { score: 5 },
    });
    assert(v1.status === 400, 'Rejects rating with missing requestId (400)');

    // Score 0 (below min 1)
    const v2 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: { requestId: reqCompletedId, score: 0 },
    });
    assert(v2.status === 400, 'Rejects score < 1 (400)');

    // Score 6 (above max 5)
    const v3 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: { requestId: reqCompletedId, score: 6 },
    });
    assert(v3.status === 400, 'Rejects score > 5 (400)');

    // Non-numeric score
    const v4 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: { requestId: reqCompletedId, score: 'five' },
    });
    assert(v4.status === 400, 'Rejects non-integer score (400)');

    // ── 3. State & Lifecycle Prerequisite Guards ────────────────────────────
    console.log('\n--- 3. State & Lifecycle Prerequisite Guards ---');

    // Cannot rate request that is still IN_SERVICE
    const s1 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: { requestId: reqInProgressId, score: 5, review: 'Great service' },
    });
    assert(s1.status === 400, 'Cannot rate request before it is COMPLETED (400)');

    // Cannot rate CANCELLED request
    const s2 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: { requestId: reqCancelledId, score: 3 },
    });
    assert(s2.status === 400, 'Cannot rate a CANCELLED service request (400)');

    // ── 4. Ownership & Authorization Guards ─────────────────────────────────
    console.log('\n--- 4. Ownership & Authorization Guards ---');

    // Other customer cannot rate someone else's request
    const a1 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer2Token}` },
      body: { requestId: reqCompletedId, score: 5 },
    });
    assert(a1.status === 403, 'Other customer cannot rate someone else\'s request (403)');

    // Provider cannot rate themselves (role guard)
    const a2 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { requestId: reqCompletedId, score: 5 },
    });
    assert(a2.status === 403, 'Provider cannot rate themselves (403)');

    // Unauthenticated request
    const a3 = await request('/api/ratings', {
      method: 'POST',
      body: { requestId: reqCompletedId, score: 5 },
    });
    assert(a3.status === 401, 'Unauthenticated user cannot submit rating (401)');

    // ── 5. Successful Rating Submission & Provider Aggregation ──────────────
    console.log('\n--- 5. Rating Submission & Provider Stats Aggregation ---');

    // Customer 1 submits 5-star rating with review
    const rRes = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: {
        requestId: reqCompletedId,
        score: 5,
        review: 'Super fast arrival and fixed my dead battery in 5 minutes! Highly recommend.',
      },
    });
    assert(rRes.status === 201, 'Customer submits rating & review (201)', JSON.stringify(rRes.data));
    assert(rRes.data?.data?.score === 5, 'Stored rating score is 5');
    assert(rRes.data?.data?.review?.includes('Super fast'), 'Review text is stored');
    assert(rRes.data?.data?.providerAverageRating === 5.0, 'Provider average rating is 5.0');
    assert(rRes.data?.data?.providerTotalRatings === 1, 'Provider ratingCount is 1');

    // Prevent duplicate rating on same request
    const dupRes = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: { requestId: reqCompletedId, score: 4 },
    });
    assert(dupRes.status === 400, 'Duplicate rating submission rejected (400)');

    // Complete second request and submit 3-star rating to verify average calculation
    if (prisma) {
      await prisma.serviceRequest.update({
        where: { id: reqInProgressId },
        data: {
          status: 'COMPLETED',
          completedAt: new Date(),
        },
      });
    }

    const rRes2 = await request('/api/ratings', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customer1Token}` },
      body: {
        requestId: reqInProgressId,
        score: 3,
        review: 'Took a bit longer than expected to replace the tyre.',
      },
    });
    assert(rRes2.status === 201, 'Customer submits second rating (201)');
    // Avg = (5 + 3) / 2 = 4.0
    assert(rRes2.data?.data?.providerAverageRating === 4.0, 'Provider average rating updated to 4.0');
    assert(rRes2.data?.data?.providerTotalRatings === 2, 'Provider total ratings count is 2');

    // Verify Provider Profile in DB has updated rating and ratingCount
    if (prisma) {
      const pProfile = await prisma.providerProfile.findUnique({
        where: { userId: providerId },
      });
      assert(pProfile?.rating === 4.0, `ProviderProfile.rating is 4.0 (got ${pProfile?.rating})`);
      assert(pProfile?.ratingCount === 2, `ProviderProfile.ratingCount is 2 (got ${pProfile?.ratingCount})`);
    }

    // ── 6. Rating Retrieval Endpoints ───────────────────────────────────────
    console.log('\n--- 6. Rating Retrieval Endpoints ---');

    // By requestId (customer)
    const g1 = await request(`/api/ratings/request/${reqCompletedId}`, {
      headers: { Authorization: `Bearer ${customer1Token}` },
    });
    assert(g1.status === 200, 'Customer fetches rating by requestId (200)');
    assert(g1.data?.data?.score === 5, 'Correct score fetched');

    // By requestId (provider)
    const g2 = await request(`/api/ratings/request/${reqCompletedId}`, {
      headers: { Authorization: `Bearer ${providerToken}` },
    });
    assert(g2.status === 200, 'Provider fetches rating by requestId (200)');

    // Other customer cannot view rating by requestId
    const g3 = await request(`/api/ratings/request/${reqCompletedId}`, {
      headers: { Authorization: `Bearer ${customer2Token}` },
    });
    assert(g3.status === 403, 'Other customer cannot view private request rating (403)');

    // Provider ratings list
    const g4 = await request(`/api/ratings/provider/${providerId}`, {
      headers: { Authorization: `Bearer ${customer1Token}` },
    });
    assert(g4.status === 200, 'Fetch provider ratings list (200)');
    assert(Array.isArray(g4.data?.data?.ratings), 'Ratings is an array');
    assert(g4.data?.data?.ratings?.length === 2, 'Provider has 2 ratings listed');
    assert(g4.data?.data?.summary?.averageRating === 4.0, 'Summary shows averageRating 4.0');
    assert(g4.data?.data?.summary?.totalRatings === 2, 'Summary shows totalRatings 2');

    // GET /api/ratings/me
    const g5 = await request('/api/ratings/me', {
      headers: { Authorization: `Bearer ${customer1Token}` },
    });
    assert(g5.status === 200, 'Customer views own submitted ratings via /me (200)');
    assert(g5.data?.data?.ratings?.length === 2, 'Customer has 2 ratings in history');

  } catch (err) {
    console.error('Unhandled test error:', err);
    failed++;
  } finally {
    await stopServer();
  }

  console.log('\n======================================================');
  console.log('Phase 8 Ratings & Completion Tests Summary:');
  console.log(`  Passed: ${passed}`);
  console.log(`  Failed: ${failed}`);
  console.log(`  Total:  ${passed + failed}`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
