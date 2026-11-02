/**
 * Regression Test Suite for Role Authentication & Authorization Enforcement
 *
 * Verifies:
 *  1. Provider credentials + Provider selection succeeds (200 OK)
 *  2. Admin credentials + Provider selection is rejected (403 Forbidden)
 *  3. Admin credentials + Admin selection succeeds (200 OK)
 *  4. Customer credentials + Provider selection is rejected (403 Forbidden)
 *  5. Provider token cannot access admin-only routes (403 Forbidden)
 *  6. Admin token cannot access provider-only routes (403 Forbidden)
 *  7. Existing valid flows without expectedRole continue working (200 OK)
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
    console.log(`  ✅ [PASS] ${label}`);
    passed++;
  } else {
    console.error(`  ❌ [FAIL] ${label}${details ? ' - ' + details : ''}`);
    failed++;
  }
}

async function runTests() {
  console.log('\n======================================================');
  console.log('🧪 ROADRESCUE ROLE ENFORCEMENT REGRESSION TESTS');
  console.log('======================================================\n');

  await startServer();

  const testProviderEmail = 'reg_provider@roadrescue.in';
  const testProviderMobile = '9840111222';
  const testAdminEmail = 'reg_admin@roadrescue.in';
  const testAdminMobile = '9840333444';
  const testCustomerEmail = 'reg_customer@roadrescue.in';
  const testCustomerMobile = '9840555666';
  const testPassword = 'Password@123';

  let providerToken;
  let adminToken;
  let customerToken;

  try {
    // ── 0. DB Cleanup & Setup ──────────────────────────────────────────
    if (prisma) {
      const emails = [testProviderEmail, testAdminEmail, testCustomerEmail];
      const mobiles = [testProviderMobile, testAdminMobile, testCustomerMobile];

      await prisma.providerProfile.deleteMany({
        where: { user: { email: { in: emails } } },
      });
      await prisma.user.deleteMany({
        where: {
          OR: [
            { email: { in: emails } },
            { mobile: { in: mobiles } },
          ],
        },
      });
    }

    // Register Provider
    const regProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Test Garage Provider',
        mobile: testProviderMobile,
        email: testProviderEmail,
        password: testPassword,
        confirmPassword: testPassword,
        role: 'PROVIDER',
        providerCategory: 'PUNCTURE',
      },
    });
    assert(regProv.status === 201, 'Setup: Register test provider');

    // Register Admin
    const regAdmin = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Test System Admin',
        mobile: testAdminMobile,
        email: testAdminEmail,
        password: testPassword,
        confirmPassword: testPassword,
        role: 'ADMIN',
      },
    });
    assert(regAdmin.status === 201, 'Setup: Register test admin');

    // Register Customer
    const regCust = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Test Customer User',
        mobile: testCustomerMobile,
        email: testCustomerEmail,
        password: testPassword,
        confirmPassword: testPassword,
        role: 'CUSTOMER',
      },
    });
    assert(regCust.status === 201, 'Setup: Register test customer');

    // ── REGRESSION TEST 1: Provider credentials + Provider selection succeeds
    const provLoginSuccess = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: testProviderEmail,
        password: testPassword,
        expectedRole: 'PROVIDER',
      },
    });
    assert(
      provLoginSuccess.status === 200 &&
        provLoginSuccess.data.data.user.role === 'PROVIDER' &&
        provLoginSuccess.data.data.token,
      'Test 1: Provider credentials + Provider selection succeeds (200 OK)',
      JSON.stringify(provLoginSuccess.data)
    );
    providerToken = provLoginSuccess.data?.data?.token;

    // ── REGRESSION TEST 2: Admin credentials + Provider selection is rejected
    const adminAsProvLogin = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: testAdminEmail,
        password: testPassword,
        expectedRole: 'PROVIDER',
      },
    });
    assert(
      adminAsProvLogin.status === 403 &&
        adminAsProvLogin.data.message &&
        adminAsProvLogin.data.message.includes('Platform Admin'),
      'Test 2: Admin credentials + Provider selection is rejected (403 Forbidden)',
      JSON.stringify(adminAsProvLogin.data)
    );

    // ── REGRESSION TEST 3: Admin credentials + Admin selection succeeds
    const adminLoginSuccess = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: testAdminEmail,
        password: testPassword,
        expectedRole: 'ADMIN',
      },
    });
    assert(
      adminLoginSuccess.status === 200 &&
        adminLoginSuccess.data.data.user.role === 'ADMIN' &&
        adminLoginSuccess.data.data.token,
      'Test 3: Admin credentials + Admin selection succeeds (200 OK)',
      JSON.stringify(adminLoginSuccess.data)
    );
    adminToken = adminLoginSuccess.data?.data?.token;

    // ── REGRESSION TEST 4: Customer credentials + Provider selection is rejected
    const custAsProvLogin = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: testCustomerEmail,
        password: testPassword,
        expectedRole: 'PROVIDER',
      },
    });
    assert(
      custAsProvLogin.status === 403 &&
        custAsProvLogin.data.message &&
        custAsProvLogin.data.message.includes('Vehicle User'),
      'Test 4: Customer credentials + Provider selection is rejected (403 Forbidden)',
      JSON.stringify(custAsProvLogin.data)
    );

    // ── REGRESSION TEST 5: Provider token cannot access admin-only routes
    const provOnAdminRoute = await request('/api/admin/stats', {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${providerToken}`,
      },
    });
    assert(
      provOnAdminRoute.status === 403,
      'Test 5: Provider token cannot access admin-only routes (403 Forbidden)',
      JSON.stringify(provOnAdminRoute.data)
    );

    // ── REGRESSION TEST 6: Admin token cannot access provider-only routes
    const adminOnProvRoute = await request('/api/providers/profile', {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${adminToken}`,
      },
    });
    assert(
      adminOnProvRoute.status === 403,
      'Test 6: Admin token cannot access provider-only routes (403 Forbidden)',
      JSON.stringify(adminOnProvRoute.data)
    );

    // ── REGRESSION TEST 7: Existing valid flows continue working (no expectedRole)
    const standardLogin = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: testCustomerEmail,
        password: testPassword,
      },
    });
    assert(
      standardLogin.status === 200 &&
        standardLogin.data.data.user.role === 'CUSTOMER' &&
        standardLogin.data.data.token,
      'Test 7: Standard login without expectedRole continues working (200 OK)',
      JSON.stringify(standardLogin.data)
    );

  } catch (error) {
    console.error('Unhandled test runner error:', error);
    failed++;
  } finally {
    await stopServer();
    console.log('\n======================================================');
    console.log(`📊 RESULTS: ${passed} Passed, ${failed} Failed`);
    console.log('======================================================\n');
    process.exit(failed > 0 ? 1 : 0);
  }
}

runTests();
