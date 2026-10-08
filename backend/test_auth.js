/**
 * Phase 3A Automated Authentication & Authorization Test Suite
 * Tests all 12 verification scenarios required for RoadRescue.
 */

const http = require('http');
const app = require('./src/app');

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

let customerToken = null;
let providerToken = null;
let testDevOtp = null;

async function runTests() {
  console.log('\n======================================================');
  console.log('🧪 ROADRESCUE PHASE 3A BACKEND AUTHENTICATION TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  // Clean up any test users from PostgreSQL before running tests
  const { prisma } = require('./src/config/prisma');
  if (prisma) {
    try {
      await prisma.otp.deleteMany({
        where: { identifier: { in: ['aswin@roadrescue.in', '9876543210', 'rajan@autoworks.in', '9123456780'] } }
      });
      await prisma.user.deleteMany({
        where: { email: { in: ['aswin@roadrescue.in', 'rajan@autoworks.in'] } }
      });
    } catch (e) {
      // Ignore if DB is not populated yet
    }
  }

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
    // ── Test 1: Register Customer ────────────────────────────────────
    const regCustomerRes = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Aswin Kumar',
        mobile: '9876543210',
        email: 'aswin@roadrescue.in',
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });

    assert(
      regCustomerRes.status === 201 &&
        regCustomerRes.data.data.user.email === 'aswin@roadrescue.in' &&
        regCustomerRes.data.data.user.role === 'CUSTOMER' &&
        regCustomerRes.data.data.token &&
        !regCustomerRes.data.data.user.passwordHash,
      '1. Register Customer',
      JSON.stringify(regCustomerRes.data)
    );
    customerToken = regCustomerRes.data.data.token;

    // ── Test 2: Register Provider ────────────────────────────────────
    const regProviderRes = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Rajan Auto Works',
        mobile: '9123456780',
        email: 'rajan@autoworks.in',
        password: 'providerPass123',
        confirmPassword: 'providerPass123',
        role: 'PROVIDER',
        providerCategory: 'MECHANIC',
      },
    });

    assert(
      regProviderRes.status === 201 &&
        regProviderRes.data.data.user.role === 'PROVIDER' &&
        regProviderRes.data.data.user.providerProfile &&
        regProviderRes.data.data.user.providerProfile.category === 'MECHANIC',
      '2. Register Provider',
      JSON.stringify(regProviderRes.data)
    );
    providerToken = regProviderRes.data.data.token;

    // ── Test 3: Duplicate Email Validation ───────────────────────────
    const dupEmailRes = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Another User',
        mobile: '9988776655',
        email: 'aswin@roadrescue.in', // Existing email
        password: 'password123',
        confirmPassword: 'password123',
      },
    });

    assert(
      dupEmailRes.status === 409 &&
        dupEmailRes.data.message.includes('Email is already registered'),
      '3. Duplicate Email Rejection (409 Conflict)',
      JSON.stringify(dupEmailRes.data)
    );

    // ── Test 4: Duplicate Mobile Validation ──────────────────────────
    const dupMobileRes = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Another User',
        mobile: '9876543210', // Existing mobile
        email: 'newuser@roadrescue.in',
        password: 'password123',
        confirmPassword: 'password123',
      },
    });

    assert(
      dupMobileRes.status === 409 &&
        dupMobileRes.data.message.includes('Mobile number is already registered'),
      '4. Duplicate Mobile Rejection (409 Conflict)',
      JSON.stringify(dupMobileRes.data)
    );

    // ── Test 5: Invalid Password Validation ──────────────────────────
    const invalidPassRes = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Weak Pass User',
        mobile: '9777888999',
        email: 'weak@roadrescue.in',
        password: '123', // < 6 chars
        confirmPassword: '123',
      },
    });

    const mismatchPassRes = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Mismatch User',
        mobile: '9777888998',
        email: 'mismatch@roadrescue.in',
        password: 'password123',
        confirmPassword: 'password456', // Mismatch
      },
    });

    assert(
      invalidPassRes.status === 400 && mismatchPassRes.status === 400,
      '5. Invalid Password & Confirmation Check (400 Bad Request)',
      `Short: ${invalidPassRes.status}, Mismatch: ${mismatchPassRes.status}`
    );

    // ── Test 6: Successful Login ─────────────────────────────────────
    const loginEmailRes = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: 'aswin@roadrescue.in',
        password: 'password123',
      },
    });

    const loginMobileRes = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: '9876543210',
        password: 'password123',
      },
    });

    assert(
      loginEmailRes.status === 200 &&
        loginEmailRes.data.data.token &&
        loginMobileRes.status === 200 &&
        loginMobileRes.data.data.token,
      '6. Login with Email or Mobile',
      JSON.stringify(loginEmailRes.data)
    );

    // ── Test 7: Invalid Login ────────────────────────────────────────
    const invalidLoginRes = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: 'aswin@roadrescue.in',
        password: 'wrongpassword',
      },
    });

    assert(
      invalidLoginRes.status === 401 &&
        invalidLoginRes.data.message.includes('Invalid email/mobile or password'),
      '7. Invalid Login Rejection (401 Unauthorized)',
      JSON.stringify(invalidLoginRes.data)
    );

    // ── Test 8: JWT Authentication ───────────────────────────────────
    const meAuthedRes = await request('/api/auth/me', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });

    const meUnauthedRes = await request('/api/auth/me');

    assert(
      meAuthedRes.status === 200 &&
        meAuthedRes.data.data.user.email === 'aswin@roadrescue.in' &&
        meUnauthedRes.status === 401,
      '8. JWT Authentication Middleware (Protected Route)',
      `Authed: ${meAuthedRes.status}, Unauthed: ${meUnauthedRes.status}`
    );

    // ── Test 9: Role-Based Authorization ─────────────────────────────
    // Customer accessing customer endpoint -> 200
    const custOnCust = await request('/api/auth/customer-only', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    // Customer accessing provider endpoint -> 403 Forbidden
    const custOnProv = await request('/api/auth/provider-only', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    // Provider accessing provider endpoint -> 200
    const provOnProv = await request('/api/auth/provider-only', {
      headers: { Authorization: `Bearer ${providerToken}` },
    });

    assert(
      custOnCust.status === 200 &&
        custOnProv.status === 403 &&
        provOnProv.status === 200,
      '9. Role-Based Authorization Guards (CUSTOMER vs PROVIDER)',
      `Cust->Cust: ${custOnCust.status}, Cust->Prov: ${custOnProv.status}, Prov->Prov: ${provOnProv.status}`
    );

    // ── Test 10: OTP Development Flow ────────────────────────────────
    const sendOtpRes = await request('/api/auth/send-otp', {
      method: 'POST',
      body: {
        identifier: '9876543210',
        purpose: 'LOGIN',
      },
    });

    testDevOtp = sendOtpRes.data.devOtp;

    const verifyOtpRes = await request('/api/auth/verify-otp', {
      method: 'POST',
      body: {
        identifier: '9876543210',
        otp: testDevOtp,
        purpose: 'LOGIN',
      },
    });

    const badOtpRes = await request('/api/auth/verify-otp', {
      method: 'POST',
      body: {
        identifier: '9876543210',
        otp: '000000',
        purpose: 'LOGIN',
      },
    });

    assert(
      sendOtpRes.status === 200 &&
        testDevOtp &&
        verifyOtpRes.status === 200 &&
        verifyOtpRes.data.data.verified === true &&
        badOtpRes.status === 400,
      '10. OTP Send, Dev Inspection, & Secure Verification',
      `Sent: ${sendOtpRes.status}, Verified: ${verifyOtpRes.status}, Bad: ${badOtpRes.status}`
    );

    // ── Test 11: Forgot Password ─────────────────────────────────────
    const forgotRes = await request('/api/auth/forgot-password', {
      method: 'POST',
      body: {
        identifier: 'aswin@roadrescue.in',
      },
    });

    const resetOtp = forgotRes.data.devOtp;

    assert(
      forgotRes.status === 200 && resetOtp,
      '11. Forgot Password (OTP Generation)',
      JSON.stringify(forgotRes.data)
    );

    // ── Test 12: Password Reset & Login with New Password ────────────
    const resetRes = await request('/api/auth/reset-password', {
      method: 'POST',
      body: {
        identifier: 'aswin@roadrescue.in',
        otp: resetOtp,
        newPassword: 'newSuperPassword2026',
        confirmPassword: 'newSuperPassword2026',
      },
    });

    const loginWithNewPassRes = await request('/api/auth/login', {
      method: 'POST',
      body: {
        identifier: 'aswin@roadrescue.in',
        password: 'newSuperPassword2026',
      },
    });

    assert(
      resetRes.status === 200 &&
        loginWithNewPassRes.status === 200 &&
        loginWithNewPassRes.data.data.token,
      '12. Password Reset & Verification with New Password',
      `Reset: ${resetRes.status}, Login: ${loginWithNewPassRes.status}`
    );
  } catch (err) {
    console.error('Test execution error:', err);
    failed++;
  } finally {
    await stopServer();
    console.log('\n------------------------------------------------------');
    console.log(`📊 Test Summary: Total: ${passed + failed} | Passed: ${passed} | Failed: ${failed}`);
    console.log('------------------------------------------------------\n');
    process.exit(failed > 0 ? 1 : 0);
  }
}

runTests();
