/**
 * Phase 3D — Provider Management Integration Test
 * Run: node test_providers.js
 *
 * Tests:
 *  1.  Register provider (auto-creates ProviderProfile, verificationStatus=PENDING)
 *  2.  Provider logs in
 *  3.  Provider cannot go AVAILABLE when PENDING
 *  4.  Provider can go OFFLINE when PENDING
 *  5.  PENDING provider cannot view available service requests
 *  6.  Register admin user for verification workflow
 *  7.  Customer cannot call PATCH /api/providers/availability
 *  8.  Provider can get own profile (GET /api/providers/profile)
 *  9.  Provider can update profile (PATCH /api/providers/profile)
 * 10.  Admin approves the provider
 * 11.  APPROVED provider can set availability to AVAILABLE
 * 12.  APPROVED AVAILABLE provider can view pending service requests
 * 13.  Provider cannot manually set availability to BUSY
 * 14.  Provider can update GPS location
 * 15.  Provider can get own service request list
 * 16.  Admin rejects a separate provider → auto-forced OFFLINE
 * 17.  REJECTED provider cannot set AVAILABLE
 * 18.  Admin suspends the first provider
 * 19.  SUSPENDED provider cannot set AVAILABLE
 * 20.  Provider profile update: invalid serviceRadiusKm is rejected
 */

const http = require('http');
const app = require('./src/app');

let BASE = '';
let server;

async function startServer() {
  return new Promise((resolve) => {
    server = http.createServer(app);
    server.listen(0, () => {
      const port = server.address().port;
      BASE = `http://localhost:${port}/api`;
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

let PROVIDER_TOKEN = '';
let PROVIDER_ID = '';
let PROVIDER2_TOKEN = '';
let CUSTOMER_TOKEN = '';
let ADMIN_TOKEN = '';
let ADMIN_ID = '';

let pass = 0;
let fail = 0;

// ── HTTP helpers ──────────────────────────────────────────────────────

function request(method, path, body, token) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const url = new URL(BASE + path);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
      },
    };

    const req = http.request(options, (res) => {
      let raw = '';
      res.on('data', (chunk) => (raw += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(raw) });
        } catch {
          resolve({ status: res.statusCode, body: raw });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

function check(name, condition, details = '') {
  if (condition) {
    console.log(`  ✅ ${name}`);
    pass++;
  } else {
    console.log(`  ❌ ${name}${details ? ': ' + details : ''}`);
    fail++;
  }
}

// ── Unique test identifiers ───────────────────────────────────────────

const ts = Date.now();
const PROVIDER_EMAIL = `prov3d_${ts}@test.com`;
const PROVIDER_MOBILE = `7${String(ts).slice(-9)}`;
const PROVIDER2_EMAIL = `prov3d2_${ts}@test.com`;
const PROVIDER2_MOBILE = `8${String(ts).slice(-9)}`;
const CUSTOMER_EMAIL = `cust3d_${ts}@test.com`;
const CUSTOMER_MOBILE = `9${String(ts).slice(-9)}`;
const ADMIN_EMAIL = `admin3d_${ts}@test.com`;
const ADMIN_MOBILE = `6${String(ts).slice(-9)}`;

// ── Tests ─────────────────────────────────────────────────────────────

async function runTests() {
  await startServer();
  try {
  console.log('\n══════════════════════════════════════════════════');
  console.log('  Phase 3D — Provider Management Integration Test');
  console.log('══════════════════════════════════════════════════\n');

  // ── Test 1: Register provider ───────────────────────────────────────
  console.log('── Test 1: Register provider ──');
  {
    const r = await request('POST', '/auth/register', {
      name: 'Rajan Provider',
      mobile: PROVIDER_MOBILE,
      email: PROVIDER_EMAIL,
      password: 'Test@1234',
      confirmPassword: 'Test@1234',
      role: 'PROVIDER',
      providerCategory: 'MECHANIC',
    });
    check('Status 201', r.status === 201, `got ${r.status}`);
    check('Role is PROVIDER', r.body?.data?.user?.role === 'PROVIDER', JSON.stringify(r.body?.data?.user?.role));
    check('verificationStatus is PENDING', r.body?.data?.user?.providerProfile?.verificationStatus === 'PENDING',
      JSON.stringify(r.body?.data?.user?.providerProfile?.verificationStatus));
    check('availability is OFFLINE', r.body?.data?.user?.providerProfile?.availability === 'OFFLINE',
      JSON.stringify(r.body?.data?.user?.providerProfile?.availability));
    PROVIDER_TOKEN = r.body?.data?.token;
    PROVIDER_ID = r.body?.data?.user?.id;
  }

  // ── Test 2: Provider logs in ────────────────────────────────────────
  console.log('\n── Test 2: Provider login ──');
  {
    const r = await request('POST', '/auth/login', {
      identifier: PROVIDER_EMAIL,
      password: 'Test@1234',
    });
    check('Status 200', r.status === 200, `got ${r.status}`);
    check('Token received', !!r.body?.data?.token);
    if (r.body?.data?.token) PROVIDER_TOKEN = r.body.data.token;
  }

  // ── Test 3: PENDING provider cannot set AVAILABLE ──────────────────
  console.log('\n── Test 3: PENDING provider cannot go AVAILABLE ──');
  {
    const r = await request('PATCH', '/providers/availability', { availability: 'AVAILABLE' }, PROVIDER_TOKEN);
    check('Status 403', r.status === 403, `got ${r.status}`);
    check('Error message mentions PENDING', r.body?.message?.includes('PENDING'),
      r.body?.message);
  }

  // ── Test 4: PENDING provider can set OFFLINE ────────────────────────
  console.log('\n── Test 4: PENDING provider can set OFFLINE ──');
  {
    const r = await request('PATCH', '/providers/availability', { availability: 'OFFLINE' }, PROVIDER_TOKEN);
    check('Status 200', r.status === 200, `got ${r.status}`);
    check('availability is OFFLINE', r.body?.data?.availability === 'OFFLINE',
      JSON.stringify(r.body?.data?.availability));
  }

  // ── Test 5: PENDING provider cannot view service requests ───────────
  console.log('\n── Test 5: PENDING provider cannot view available requests ──');
  {
    const r = await request('GET', '/service-requests/available', null, PROVIDER_TOKEN);
    check('Status 403', r.status === 403, `got ${r.status}`);
    check('Error mentions verification', r.body?.message?.toLowerCase().includes('pending') ||
      r.body?.message?.toLowerCase().includes('approved'),
      r.body?.message);
  }

  // ── Test 6: Register customer and admin ─────────────────────────────
  console.log('\n── Test 6: Register customer + admin ──');
  {
    // Customer
    const rc = await request('POST', '/auth/register', {
      name: 'Test Customer3D',
      mobile: CUSTOMER_MOBILE,
      email: CUSTOMER_EMAIL,
      password: 'Test@1234',
      confirmPassword: 'Test@1234',
      role: 'CUSTOMER',
    });
    check('Customer registered (201)', rc.status === 201, `got ${rc.status}`);
    CUSTOMER_TOKEN = rc.body?.data?.token;

    // Admin
    const ra = await request('POST', '/auth/register', {
      name: 'Test Admin3D',
      mobile: ADMIN_MOBILE,
      email: ADMIN_EMAIL,
      password: 'Admin@1234',
      confirmPassword: 'Admin@1234',
      role: 'ADMIN',
    });
    check('Admin registered (201)', ra.status === 201, `got ${ra.status}`);
    ADMIN_TOKEN = ra.body?.data?.token;
    ADMIN_ID = ra.body?.data?.user?.id;
  }

  // ── Test 7: Customer cannot access provider availability endpoint ────
  console.log('\n── Test 7: Customer forbidden from provider endpoint ──');
  {
    const r = await request('PATCH', '/providers/availability', { availability: 'AVAILABLE' }, CUSTOMER_TOKEN);
    check('Status 403', r.status === 403, `got ${r.status}`);
    check('Error mentions role', r.body?.message?.toLowerCase().includes('provider') ||
      r.body?.message?.toLowerCase().includes('forbidden'),
      r.body?.message);
  }

  // ── Test 8: Provider can get own profile ────────────────────────────
  console.log('\n── Test 8: Provider can get own profile ──');
  {
    const r = await request('GET', '/providers/profile', null, PROVIDER_TOKEN);
    check('Status 200', r.status === 200, `got ${r.status}`);
    check('Has providerProfile', !!r.body?.data?.providerProfile);
    check('verificationStatus is PENDING', r.body?.data?.providerProfile?.verificationStatus === 'PENDING',
      JSON.stringify(r.body?.data?.providerProfile?.verificationStatus));
    check('category is MECHANIC', r.body?.data?.providerProfile?.category === 'MECHANIC',
      JSON.stringify(r.body?.data?.providerProfile?.category));
  }

  // ── Test 9: Provider can update profile ─────────────────────────────
  console.log('\n── Test 9: Provider can update profile fields ──');
  {
    const r = await request('PATCH', '/providers/profile', {
      garageName: 'Rajan Auto Works',
      businessAddress: 'NH-44, Krishnagiri',
      serviceRadiusKm: 30,
    }, PROVIDER_TOKEN);
    check('Status 200', r.status === 200, `got ${r.status}`);
    check('garageName updated', r.body?.data?.garageName === 'Rajan Auto Works',
      JSON.stringify(r.body?.data?.garageName));
    check('serviceRadiusKm updated', r.body?.data?.serviceRadiusKm === 30,
      JSON.stringify(r.body?.data?.serviceRadiusKm));
  }

  // ── Test 10: Admin approves provider ───────────────────────────────
  console.log('\n── Test 10: Admin approves provider ──');
  {
    const r = await request('PATCH', `/providers/${PROVIDER_ID}/verification`, {
      verificationStatus: 'APPROVED',
    }, ADMIN_TOKEN);
    check('Status 200', r.status === 200, `got ${r.status}: ${r.body?.message || ''}`);
    check('verificationStatus is APPROVED', r.body?.data?.verificationStatus === 'APPROVED',
      JSON.stringify(r.body?.data?.verificationStatus));
  }

  // ── Test 11: APPROVED provider can set AVAILABLE ────────────────────
  console.log('\n── Test 11: APPROVED provider can set AVAILABLE ──');
  {
    const r = await request('PATCH', '/providers/availability', { availability: 'AVAILABLE' }, PROVIDER_TOKEN);
    check('Status 200', r.status === 200, `got ${r.status}`);
    check('availability is AVAILABLE', r.body?.data?.availability === 'AVAILABLE',
      JSON.stringify(r.body?.data?.availability));
  }

  // ── Test 12: APPROVED+AVAILABLE provider can view service requests ──
  console.log('\n── Test 12: APPROVED AVAILABLE provider can view pending requests ──');
  {
    // First create a request as customer
    await request('POST', '/service-requests', {
      serviceType: 'Mechanical Repair',
      problemDescription: 'Engine overheating badly',
      customerLatitude: 12.9716,
      customerLongitude: 77.5946,
      customerAddress: 'Bangalore',
      vehiclePlate: 'KA-01-AB-1234',
      vehicleModel: 'Tata Prima',
      vehicleType: 'Heavy Vehicle',
      category: 'MECHANIC',
    }, CUSTOMER_TOKEN);

    const r = await request('GET', '/service-requests/available', null, PROVIDER_TOKEN);
    check('Status 200', r.status === 200, `got ${r.status}`);
    check('Returns array', Array.isArray(r.body?.data), JSON.stringify(r.body?.data));
  }

  // ── Test 13: Provider cannot manually set BUSY ──────────────────────
  console.log('\n── Test 13: Provider cannot manually set BUSY ──');
  {
    const r = await request('PATCH', '/providers/availability', { availability: 'BUSY' }, PROVIDER_TOKEN);
    check('Status 400', r.status === 400, `got ${r.status}`);
    check('Error mentions BUSY is system-controlled', r.body?.message?.toLowerCase().includes('busy'),
      r.body?.message);
  }

  // ── Test 14: Provider can update GPS location ───────────────────────
  console.log('\n── Test 14: Provider can update GPS location ──');
  {
    const r = await request('PATCH', '/providers/location', {
      latitude: 12.9716,
      longitude: 77.5946,
    }, PROVIDER_TOKEN);
    check('Status 200 (/location)', r.status === 200, `got ${r.status}`);
    check('latitude stored', r.body?.data?.latitude === 12.9716,
      JSON.stringify(r.body?.data?.latitude));
    check('longitude stored', r.body?.data?.longitude === 77.5946,
      JSON.stringify(r.body?.data?.longitude));

    // Also verify /me/location alias
    const rMe = await request('PATCH', '/providers/me/location', {
      latitude: 13.0827,
      longitude: 80.2707,
    }, PROVIDER_TOKEN);
    check('Status 200 (/me/location)', rMe.status === 200, `got ${rMe.status}`);
    check('updated latitude via /me/location', rMe.body?.data?.latitude === 13.0827,
      JSON.stringify(rMe.body?.data?.latitude));
    check('updated longitude via /me/location', rMe.body?.data?.longitude === 80.2707,
      JSON.stringify(rMe.body?.data?.longitude));
  }

  // ── Test 15: Provider can get own request list ──────────────────────
  console.log('\n── Test 15: Provider can get own service request list ──');
  {
    const r = await request('GET', '/providers/my-requests', null, PROVIDER_TOKEN);
    check('Status 200', r.status === 200, `got ${r.status}`);
    check('Returns array', Array.isArray(r.body?.data), JSON.stringify(r.body?.data));
  }

  // ── Test 16: Admin rejects separate provider → auto-forced OFFLINE ──
  console.log('\n── Test 16: Admin rejects provider → forced OFFLINE ──');
  {
    // Register provider 2
    const rp2 = await request('POST', '/auth/register', {
      name: 'Provider Two',
      mobile: PROVIDER2_MOBILE,
      email: PROVIDER2_EMAIL,
      password: 'Test@1234',
      confirmPassword: 'Test@1234',
      role: 'PROVIDER',
      providerCategory: 'PUNCTURE',
    });
    check('Provider2 registered', rp2.status === 201, `got ${rp2.status}`);
    PROVIDER2_TOKEN = rp2.body?.data?.token;
    const provider2Id = rp2.body?.data?.user?.id;

    // Admin rejects provider 2
    const rr = await request('PATCH', `/providers/${provider2Id}/verification`, {
      verificationStatus: 'REJECTED',
    }, ADMIN_TOKEN);
    check('Admin reject status 200', rr.status === 200, `got ${rr.status}: ${rr.body?.message || ''}`);
    check('verificationStatus REJECTED', rr.body?.data?.verificationStatus === 'REJECTED',
      JSON.stringify(rr.body?.data?.verificationStatus));
    check('Forced OFFLINE on reject', rr.body?.data?.availability === 'OFFLINE',
      JSON.stringify(rr.body?.data?.availability));
  }

  // ── Test 17: REJECTED provider cannot set AVAILABLE ─────────────────
  console.log('\n── Test 17: REJECTED provider cannot go AVAILABLE ──');
  {
    const r = await request('PATCH', '/providers/availability', { availability: 'AVAILABLE' }, PROVIDER2_TOKEN);
    check('Status 403', r.status === 403, `got ${r.status}`);
    check('Error mentions REJECTED', r.body?.message?.includes('REJECTED'),
      r.body?.message);
  }

  // ── Test 18: Admin suspends provider 1 ─────────────────────────────
  console.log('\n── Test 18: Admin suspends provider ──');
  {
    const r = await request('PATCH', `/providers/${PROVIDER_ID}/verification`, {
      verificationStatus: 'SUSPENDED',
    }, ADMIN_TOKEN);
    check('Status 200', r.status === 200, `got ${r.status}: ${r.body?.message || ''}`);
    check('verificationStatus SUSPENDED', r.body?.data?.verificationStatus === 'SUSPENDED',
      JSON.stringify(r.body?.data?.verificationStatus));
    check('Forced OFFLINE on suspend', r.body?.data?.availability === 'OFFLINE',
      JSON.stringify(r.body?.data?.availability));
  }

  // ── Test 19: SUSPENDED provider cannot set AVAILABLE ────────────────
  console.log('\n── Test 19: SUSPENDED provider cannot go AVAILABLE ──');
  {
    const r = await request('PATCH', '/providers/availability', { availability: 'AVAILABLE' }, PROVIDER_TOKEN);
    check('Status 403', r.status === 403, `got ${r.status}`);
    check('Error mentions SUSPENDED', r.body?.message?.includes('SUSPENDED'),
      r.body?.message);
  }

  // ── Test 20: Invalid serviceRadiusKm is rejected ─────────────────────
  console.log('\n── Test 20: Invalid serviceRadiusKm rejected ──');
  {
    const r = await request('PATCH', '/providers/profile', { serviceRadiusKm: 999 }, PROVIDER_TOKEN);
    check('Status 400', r.status === 400, `got ${r.status}`);
    check('Error mentions serviceRadiusKm range', r.body?.message?.toLowerCase().includes('serviceradiuskm') ||
      r.body?.message?.toLowerCase().includes('200'),
      r.body?.message);
  }

  } finally {
    await stopServer();
  }

  // ── Summary ───────────────────────────────────────────────────────────
  console.log('\n══════════════════════════════════════════════════');
  console.log(`  Results: ✅ ${pass} passed  ❌ ${fail} failed`);
  console.log('══════════════════════════════════════════════════\n');

  if (fail > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error('❌ Test runner crashed:', err.message);
  process.exit(1);
});
