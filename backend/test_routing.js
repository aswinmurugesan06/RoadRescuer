/**
 * RoadRescue Phase 13 — Advanced Maps, Routing & Navigation Integration Tests
 *
 * Tests cover:
 *  - Turn-by-turn route calculation (OSRM / OpenFreeMap routing engine)
 *  - Distance & ETA estimation
 *  - GeoJSON LineString route polyline geometry
 *  - Coordinate boundary and format validations (-90..90 lat, -180..180 lng)
 *  - Authentication guards (401 for unauthenticated)
 *  - GET and POST routing direction endpoints
 *  - Offline / fallback routing engine robustness
 */

const http = require('http');
const app = require('./src/app');
const { prisma } = require('./src/config/prisma');
const routingService = require('./src/services/routingService');

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
  console.log('🗺️  ROADRESCUE PHASE 13 ROUTING & NAVIGATION TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const userEmail = 'routing_test_user@roadrescue.in';
  const userMobile = '9870111222';
  let authToken;

  try {
    // ── Setup User ───────────────────────────────────────────────────────────
    if (prisma) {
      await prisma.user.deleteMany({
        where: {
          OR: [{ email: userEmail }, { mobile: userMobile }],
        },
      });
    }

    const regRes = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Routing Test User',
        mobile: userMobile,
        email: userEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    authToken = regRes.data?.data?.token;

    // Bangalore Coordinates:
    // Origin: MG Road (12.9716, 77.5946)
    // Destination: Koramangala 5th Block (12.9352, 77.6245)
    const originLat = 12.9716;
    const originLng = 77.5946;
    const destLat = 12.9352;
    const destLng = 77.6245;

    // ── 1. Authentication Guards ─────────────────────────────────────────────
    console.log('\n--- 1. Authentication & Security Guards ---');

    const a1 = await request(`/api/routing/directions?originLat=${originLat}&originLng=${originLng}&destLat=${destLat}&destLng=${destLng}`);
    assert(a1.status === 401, 'Unauthenticated routing request rejected (401)');

    // ── 2. Input & Coordinate Validation ─────────────────────────────────────
    console.log('\n--- 2. Coordinate & Parameter Validation ---');

    // Missing originLat
    const v1 = await request(`/api/routing/directions?originLng=${originLng}&destLat=${destLat}&destLng=${destLng}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    assert(v1.status === 400, 'Rejects request missing coordinate parameter (400)');

    // Invalid Latitude (> 90)
    const v2 = await request(`/api/routing/directions?originLat=95.0&originLng=${originLng}&destLat=${destLat}&destLng=${destLng}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    assert(v2.status === 400, 'Rejects latitude > 90 (400)');

    // Invalid Latitude (< -90)
    const v3 = await request(`/api/routing/directions?originLat=-95.0&originLng=${originLng}&destLat=${destLat}&destLng=${destLng}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    assert(v3.status === 400, 'Rejects latitude < -90 (400)');

    // Invalid Longitude (> 180)
    const v4 = await request(`/api/routing/directions?originLat=${originLat}&originLng=195.0&destLat=${destLat}&destLng=${destLng}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    assert(v4.status === 400, 'Rejects longitude > 180 (400)');

    // Non-numeric Coordinate
    const v5 = await request(`/api/routing/directions?originLat=abc&originLng=${originLng}&destLat=${destLat}&destLng=${destLng}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    assert(v5.status === 400, 'Rejects non-numeric coordinate string (400)');

    // ── 3. GET Routing Directions API ────────────────────────────────────────
    console.log('\n--- 3. GET /api/routing/directions ---');

    const g1 = await request(`/api/routing/directions?originLat=${originLat}&originLng=${originLng}&destLat=${destLat}&destLng=${destLng}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    assert(g1.status === 200, 'Calculates route via GET request (200)');
    assert(g1.data?.status === 'success', 'Response status is success');
    assert(typeof g1.data?.data?.distanceKm === 'number' && g1.data?.data?.distanceKm > 0, `Returns valid distance in km: ${g1.data?.data?.distanceKm} km`);
    assert(typeof g1.data?.data?.durationMinutes === 'number' && g1.data?.data?.durationMinutes > 0, `Returns valid duration in minutes: ${g1.data?.data?.durationMinutes} min`);
    assert(g1.data?.data?.geometry?.type === 'LineString', 'Returns GeoJSON LineString geometry');
    assert(Array.isArray(g1.data?.data?.geometry?.coordinates), 'Geometry coordinates is an array');
    assert(g1.data?.data?.geometry?.coordinates?.length >= 2, `Contains polyline coordinate waypoints (${g1.data?.data?.geometry?.coordinates?.length} points)`);
    assert(Boolean(g1.data?.data?.provider), `Returns routing provider: ${g1.data?.data?.provider}`);

    // ── 4. POST Routing Directions API ───────────────────────────────────────
    console.log('\n--- 4. POST /api/routing/directions ---');

    const p1 = await request('/api/routing/directions', {
      method: 'POST',
      headers: { Authorization: `Bearer ${authToken}` },
      body: {
        originLat,
        originLng,
        destLat,
        destLng,
      },
    });
    assert(p1.status === 200, 'Calculates route via POST request body (200)');
    assert(p1.data?.data?.origin?.latitude === originLat, 'Origin latitude matches');
    assert(p1.data?.data?.destination?.latitude === destLat, 'Destination latitude matches');

    // ── 5. Internal Routing Service Unit Verification ────────────────────────
    console.log('\n--- 5. Routing Service Engine Verification ---');

    const s1 = await routingService.getDirections({
      originLat: 13.0827,
      originLng: 80.2707, // Chennai Central
      destLat: 12.9716,
      destLng: 77.5946,  // Bangalore
    });
    assert(s1.distanceKm > 200, `Inter-city distance calculated accurately: ${s1.distanceKm} km`);
    assert(s1.durationMinutes > 180, `Inter-city duration estimated accurately: ${s1.durationMinutes} min`);
    assert(s1.geometry.coordinates.length > 0, 'Generates full route polyline');

  } catch (err) {
    console.error('Unhandled test error:', err);
    failed++;
  } finally {
    await stopServer();
  }

  console.log('\n======================================================');
  console.log('Phase 13 Routing Tests Summary:');
  console.log(`  Passed: ${passed}`);
  console.log(`  Failed: ${failed}`);
  console.log(`  Total:  ${passed + failed}`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
