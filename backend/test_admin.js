/**
 * RoadRescue Phase 9 — Admin Dashboard & Platform Management Integration Tests
 *
 * Tests cover:
 *  - ADMIN role authorization and 403 enforcement for CUSTOMER and PROVIDER
 *  - Dashboard statistics aggregation
 *  - Provider verification management (APPROVE, REJECT, SUSPEND, RE-ACTIVATE)
 *  - User listing without exposing credentials
 *  - Service requests listing and filtering
 *  - Billing and payment records inspection
 *  - Ratings listing and moderation
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
  console.log('🧪 ROADRESCUE PHASE 9 ADMIN PLATFORM TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const adminEmail = 'admin_9@roadrescue.in';
  const custEmail = 'cust_9@roadrescue.in';
  const provEmail = 'prov_9@roadrescue.in';

  const adminMobile = '9840333001';
  const custMobile = '9840333002';
  const provMobile = '9840333003';

  let adminToken, customerToken, providerToken;
  let adminId, customerId, providerId;
  let testRatingId;

  try {
    // ── 0. DB Cleanup ────────────────────────────────────────────────────────
    if (prisma) {
      const emails = [adminEmail, custEmail, provEmail];
      await prisma.rating.deleteMany({
        where: { customer: { email: { in: emails } } },
      });
      await prisma.payment.deleteMany({
        where: { customer: { email: { in: emails } } },
      });
      await prisma.billItem.deleteMany({
        where: { bill: { customer: { email: { in: emails } } } },
      });
      await prisma.bill.deleteMany({
        where: { customer: { email: { in: emails } } },
      });
      await prisma.serviceRequest.deleteMany({
        where: { customer: { email: { in: emails } } },
      });
      await prisma.vehicle.deleteMany({
        where: { user: { email: { in: emails } } },
      });
      await prisma.providerProfile.deleteMany({
        where: { user: { email: { in: emails } } },
      });
      await prisma.user.deleteMany({
        where: {
          OR: [
            { email: { in: emails } },
            { mobile: { in: [adminMobile, custMobile, provMobile] } },
          ],
        },
      });
    }

    // ── 1. Setup Admin, Customer, and Provider Users ─────────────────────────
    // 1. Admin
    const regAdmin = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Platform Admin',
        mobile: adminMobile,
        email: adminEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'ADMIN',
      },
    });
    adminToken = regAdmin.data?.data?.token;
    adminId = regAdmin.data?.data?.user?.id;

    // 2. Customer
    const regCust = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Regular Customer',
        mobile: custMobile,
        email: custEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    customerToken = regCust.data?.data?.token;
    customerId = regCust.data?.data?.user?.id;

    // 3. Provider
    const regProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Test Garage Specialist',
        mobile: provMobile,
        email: provEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    providerToken = regProv.data?.data?.token;
    providerId = regProv.data?.data?.user?.id;

    // ── 1. ADMIN Authentication & Role Authorization Guards ──────────────────
    console.log('\n--- 1. Admin Authorization Guards ---');

    // Admin can access stats
    const a1 = await request('/api/admin/stats', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(a1.status === 200, 'Admin can access /api/admin/stats (200)');

    // Customer receives 403
    const a2 = await request('/api/admin/stats', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(a2.status === 403, 'Customer receives 403 Forbidden for admin stats (403)');

    // Provider receives 403
    const a3 = await request('/api/admin/stats', {
      headers: { Authorization: `Bearer ${providerToken}` },
    });
    assert(a3.status === 403, 'Provider receives 403 Forbidden for admin stats (403)');

    // Unauthenticated receives 401
    const a4 = await request('/api/admin/stats');
    assert(a4.status === 401, 'Unauthenticated user receives 401 (401)');

    // ── 2. Dashboard Statistics ──────────────────────────────────────────────
    console.log('\n--- 2. Dashboard Statistics ---');

    const s = a1.data?.data;
    assert(typeof s?.totalCustomers === 'number' && s.totalCustomers >= 1, 'Stats includes totalCustomers count');
    assert(typeof s?.totalProviders === 'number' && s.totalProviders >= 1, 'Stats includes totalProviders count');
    assert(typeof s?.pendingVerifications === 'number', 'Stats includes pendingVerifications count');
    assert(typeof s?.approvedProviders === 'number', 'Stats includes approvedProviders count');
    assert(typeof s?.activeRequests === 'number', 'Stats includes activeRequests count');
    assert(typeof s?.totalRevenue === 'number', 'Stats includes totalRevenue number');
    assert(typeof s?.averageRating === 'number', 'Stats includes averageRating number');

    // ── 3. Provider Verification Workflow ────────────────────────────────────
    console.log('\n--- 3. Provider Verification Management ---');

    // List providers as admin
    const p1 = await request('/api/admin/providers', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(p1.status === 200, 'Admin lists providers (200)');
    assert(Array.isArray(p1.data?.data?.providers), 'Providers list is an array');

    // Filter providers by status=PENDING
    const p2 = await request('/api/admin/providers?status=PENDING', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(p2.status === 200, 'Admin filters providers by status=PENDING (200)');

    // Get provider details
    const p3 = await request(`/api/admin/providers/${providerId}`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(p3.status === 200, 'Admin gets provider details (200)');
    assert(p3.data?.data?.id === providerId, 'Provider details ID matches');

    // Admin APPROVES provider
    const pApprove = await request(`/api/admin/providers/${providerId}/verification`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { verificationStatus: 'APPROVED' },
    });
    assert(pApprove.status === 200, 'Admin approves provider (200)');
    assert(pApprove.data?.data?.providerProfile?.verificationStatus === 'APPROVED', 'Provider status is APPROVED');

    // Admin SUSPENDS provider with reason (forces OFFLINE)
    const pSuspend = await request(`/api/admin/providers/${providerId}/verification`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { verificationStatus: 'SUSPENDED', reason: 'Audit pending' },
    });
    assert(pSuspend.status === 200, 'Admin suspends provider (200)');
    assert(pSuspend.data?.data?.providerProfile?.verificationStatus === 'SUSPENDED', 'Provider status is SUSPENDED');
    assert(pSuspend.data?.data?.providerProfile?.availability === 'OFFLINE', 'Suspended provider forced OFFLINE');

    // Admin RE-APPROVES provider
    const pReApprove = await request(`/api/admin/providers/${providerId}/verification`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { verificationStatus: 'APPROVED' },
    });
    assert(pReApprove.status === 200, 'Admin re-approves provider (200)');
    assert(pReApprove.data?.data?.providerProfile?.verificationStatus === 'APPROVED', 'Provider status is APPROVED again');

    // Invalid verificationStatus rejected
    const pInvalid = await request(`/api/admin/providers/${providerId}/verification`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${adminToken}` },
      body: { verificationStatus: 'INVALID_STATUS' },
    });
    assert(pInvalid.status === 400, 'Rejects invalid verificationStatus (400)');

    // ── 4. Platform User Management ──────────────────────────────────────────
    console.log('\n--- 4. User Management ---');

    const u1 = await request('/api/admin/users', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(u1.status === 200, 'Admin lists platform users (200)');
    assert(Array.isArray(u1.data?.data?.users), 'Users is an array');

    // Verify passwords and secrets are NOT exposed
    const sampleUser = u1.data?.data?.users?.[0];
    assert(!sampleUser?.passwordHash, 'User passwordHash is NOT exposed');
    assert(!sampleUser?.otpHash, 'User OTP hash is NOT exposed');

    // Filter users by role=CUSTOMER
    const u2 = await request('/api/admin/users?role=CUSTOMER', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(u2.status === 200, 'Admin filters users by role=CUSTOMER (200)');

    // ── 5. Service Requests & Billing Management ─────────────────────────────
    console.log('\n--- 5. Service Requests & Billing Management ---');

    // List service requests
    const srList = await request('/api/admin/service-requests', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(srList.status === 200, 'Admin lists service requests (200)');
    assert(Array.isArray(srList.data?.data?.requests), 'Service requests is an array');

    // List bills
    const bList = await request('/api/admin/bills', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(bList.status === 200, 'Admin lists bills (200)');
    assert(Array.isArray(bList.data?.data?.bills), 'Bills is an array');

    // List payments
    const payList = await request('/api/admin/payments', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(payList.status === 200, 'Admin lists payments (200)');
    assert(Array.isArray(payList.data?.data?.payments), 'Payments is an array');

    // ── 6. Ratings & Reviews Moderation ──────────────────────────────────────
    console.log('\n--- 6. Ratings & Reviews Moderation ---');

    // Create a mock service request & rating in DB to test moderation
    if (prisma) {
      const sr = await prisma.serviceRequest.create({
        data: {
          customerId,
          providerId,
          serviceType: 'Towing',
          problemDescription: 'Admin test towing',
          status: 'COMPLETED',
          customerLatitude: 12.9716,
          customerLongitude: 77.5946,
          vehiclePlate: 'TN 01 AA 1111',
          vehicleModel: 'Toyota Innova',
          completedAt: new Date(),
        },
      });

      const rating = await prisma.rating.create({
        data: {
          requestId: sr.id,
          customerId,
          providerId,
          score: 1,
          review: 'Spam / abusive comment to be moderated',
        },
      });
      testRatingId = rating.id;
    }

    // List ratings as admin
    const rList = await request('/api/admin/ratings', {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    assert(rList.status === 200, 'Admin lists ratings (200)');
    assert(Array.isArray(rList.data?.data?.ratings), 'Ratings is an array');

    // Delete / moderate rating
    if (testRatingId) {
      const rDel = await request(`/api/admin/ratings/${testRatingId}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${adminToken}` },
      });
      assert(rDel.status === 200, 'Admin moderates/deletes abusive rating (200)');
    }

  } catch (err) {
    console.error('Unhandled test error:', err);
    failed++;
  } finally {
    await stopServer();
  }

  console.log('\n======================================================');
  console.log('Phase 9 Admin Tests Summary:');
  console.log(`  Passed: ${passed}`);
  console.log(`  Failed: ${failed}`);
  console.log(`  Total:  ${passed + failed}`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
