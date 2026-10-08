/**
 * Phase 3C — Vehicle Management Integration Test
 * Run: node test_vehicles.js
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

let TOKEN = '';
let VEHICLE_ID = '';
let VEHICLE_ID_2 = '';
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

// ── Tests ─────────────────────────────────────────────────────────────

async function run() {
  await startServer();
  try {
  console.log('\n═══════════════════════════════════════════════');
  console.log('   RoadRescue Phase 3C — Vehicle API Tests');
  console.log('═══════════════════════════════════════════════\n');

  // 1. Register a customer
  console.log('1. Register customer');
  const ts = Date.now();
  const reg = await request('POST', '/auth/register', {
    name: 'Veh Tester',
    mobile: `9${String(ts).slice(-9)}`,
    email: `veh${ts}@test.com`,
    password: 'Test@1234',
    confirmPassword: 'Test@1234',
    role: 'CUSTOMER',
  });
  check('Register returns 201', reg.status === 201);
  check('Token returned', !!reg.body?.data?.token);
  TOKEN = reg.body?.data?.token || '';

  if (!TOKEN) {
    console.log('\n⚠️  Cannot proceed without a token. Is the backend running?\n');
    return;
  }

  // 2. Add first vehicle
  console.log('\n2. Add first vehicle (should auto-set default)');
  const add1 = await request('POST', '/vehicles', {
    type: 'Car',
    manufacturer: 'Toyota',
    model: 'Fortuner',
    plateNumber: 'TN38AB1234',
    year: '2021',
    color: 'Black',
    isDefault: false,
  }, TOKEN);
  check('Create vehicle returns 201', add1.status === 201, JSON.stringify(add1.body));
  check('Vehicle has id', !!add1.body?.data?.id);
  check('First vehicle auto-set as default', add1.body?.data?.isDefault === true);
  VEHICLE_ID = add1.body?.data?.id;

  // 3. Add second vehicle
  console.log('\n3. Add second vehicle (isDefault: true — should shift default)');
  const add2 = await request('POST', '/vehicles', {
    type: 'Bike',
    manufacturer: 'Honda',
    model: 'CB350',
    plateNumber: 'TN38CD5678',
    year: '2022',
    color: 'Red',
    isDefault: true,
  }, TOKEN);
  check('Create second vehicle returns 201', add2.status === 201, JSON.stringify(add2.body));
  check('Second vehicle isDefault = true', add2.body?.data?.isDefault === true);
  VEHICLE_ID_2 = add2.body?.data?.id;

  // 4. List vehicles
  console.log('\n4. List own vehicles');
  const list = await request('GET', '/vehicles', null, TOKEN);
  check('List returns 200', list.status === 200);
  check('Returns 2 vehicles', list.body?.data?.length === 2);
  const defaultVehicle = list.body?.data?.find((v) => v.isDefault);
  check('Default vehicle is second (most recent default)', defaultVehicle?.id === VEHICLE_ID_2);

  // 5. Get vehicle by ID
  console.log('\n5. Get vehicle by ID');
  const get = await request('GET', `/vehicles/${VEHICLE_ID}`, null, TOKEN);
  check('Get returns 200', get.status === 200);
  check('Returns correct vehicle', get.body?.data?.id === VEHICLE_ID);
  check('First vehicle isDefault = false after shift', get.body?.data?.isDefault === false);

  // 6. Update vehicle
  console.log('\n6. Update vehicle color and year');
  const upd = await request('PUT', `/vehicles/${VEHICLE_ID}`, {
    color: 'Silver',
    year: '2023',
  }, TOKEN);
  check('Update returns 200', upd.status === 200, JSON.stringify(upd.body));
  check('Color updated', upd.body?.data?.color === 'Silver');
  check('Year updated', upd.body?.data?.year === '2023');

  // 7. Set first vehicle as default
  console.log('\n7. Set first vehicle as default via PATCH');
  const setDef = await request('PATCH', `/vehicles/${VEHICLE_ID}/set-default`, null, TOKEN);
  check('Set default returns 200', setDef.status === 200, JSON.stringify(setDef.body));
  check('Vehicle is now default', setDef.body?.data?.isDefault === true);

  // Verify second vehicle is no longer default
  const getV2 = await request('GET', `/vehicles/${VEHICLE_ID_2}`, null, TOKEN);
  check('Second vehicle isDefault = false after shift', getV2.body?.data?.isDefault === false);

  // 8. Ownership: Register a second user and try to access first user's vehicle
  console.log('\n8. Ownership protection test');
  const ts2 = Date.now();
  const reg2 = await request('POST', '/auth/register', {
    name: 'Other User',
    mobile: `8${String(ts2).slice(-9)}`,
    email: `other${ts2}@test.com`,
    password: 'Test@1234',
    confirmPassword: 'Test@1234',
    role: 'CUSTOMER',
  });
  const TOKEN2 = reg2.body?.data?.token || '';
  const accessOther = await request('GET', `/vehicles/${VEHICLE_ID}`, null, TOKEN2);
  check('Access another user\'s vehicle → 403', accessOther.status === 403);

  const deleteOther = await request('DELETE', `/vehicles/${VEHICLE_ID}`, null, TOKEN2);
  check('Delete another user\'s vehicle → 403', deleteOther.status === 403);

  // 9. Validation: Invalid type
  console.log('\n9. Validation tests');
  const bad = await request('POST', '/vehicles', {
    type: 'INVALID_TYPE',
    manufacturer: 'X',
    model: 'Y',
    plateNumber: 'TN00AA0000',
  }, TOKEN);
  check('Invalid type → 400', bad.status === 400);

  const shortPlate = await request('POST', '/vehicles', {
    type: 'Car',
    manufacturer: 'Maruti',
    model: 'Swift',
    plateNumber: 'AB', // too short
  }, TOKEN);
  check('Short plate → 400', shortPlate.status === 400);

  // 10. Unauthenticated request
  console.log('\n10. Auth protection');
  const noAuth = await request('GET', '/vehicles', null, null);
  check('No token → 401', noAuth.status === 401);

  // 11. Service Request Vehicle Integration & Ownership Enforcement
  console.log('\n11. Service Request vehicle ownership enforcement');
  // Customer 1 creates service request with own vehicle
  const srOwn = await request('POST', '/service-requests', {
    serviceType: 'Mechanical Repair',
    problemDescription: 'Engine overheating on expressway',
    customerLatitude: 13.0827,
    customerLongitude: 80.2707,
    vehicleId: VEHICLE_ID,
  }, TOKEN);
  check('Customer creates service request with own vehicle → 201', srOwn.status === 201, JSON.stringify(srOwn.body));
  check('Service request associates vehicleId correctly', srOwn.body?.data?.vehicleId === VEHICLE_ID);
  check('Service request auto-populates vehiclePlate', srOwn.body?.data?.vehiclePlate === 'TN38AB1234');
  check('Service request auto-populates vehicleModel', srOwn.body?.data?.vehicleModel === 'Toyota Fortuner');

  // Customer 2 attempts to create service request with Customer 1's vehicle
  const srOther = await request('POST', '/service-requests', {
    serviceType: 'Mechanical Repair',
    problemDescription: 'Flat tyre attempt with unauthorized vehicle',
    customerLatitude: 13.0827,
    customerLongitude: 80.2707,
    vehicleId: VEHICLE_ID, // Belongs to Customer 1!
  }, TOKEN2);
  check('Customer 2 blocked from using Customer 1 vehicle in request → 403', srOther.status === 403, JSON.stringify(srOther.body));

  // Service request with non-existent vehicleId
  const srFake = await request('POST', '/service-requests', {
    serviceType: 'Mechanical Repair',
    problemDescription: 'Issue with phantom vehicle',
    customerLatitude: 13.0827,
    customerLongitude: 80.2707,
    vehicleId: '00000000-0000-0000-0000-000000000000',
  }, TOKEN);
  check('Service request with non-existent vehicleId → 404', srFake.status === 404, JSON.stringify(srFake.body));

  // 12. Delete vehicle
  console.log('\n12. Delete vehicle');
  const del1 = await request('DELETE', `/vehicles/${VEHICLE_ID}`, null, TOKEN);
  check('Delete returns 200', del1.status === 200);
  check('Deleted message', !!del1.body?.data?.message);

  // After deleting default vehicle, second should become default
  const listAfterDelete = await request('GET', '/vehicles', null, TOKEN);
  check('One vehicle remaining', listAfterDelete.body?.data?.length === 1);
  check('Remaining vehicle promoted to default', listAfterDelete.body?.data?.[0]?.isDefault === true);

  // Delete second
  const del2 = await request('DELETE', `/vehicles/${VEHICLE_ID_2}`, null, TOKEN);
  check('Delete second vehicle returns 200', del2.status === 200);

  const listEmpty = await request('GET', '/vehicles', null, TOKEN);
  check('Vehicle list is now empty', listEmpty.body?.data?.length === 0);

  } finally {
    await stopServer();
  }

  // ── Summary ───────────────────────────────────────────────────────
  console.log('\n───────────────────────────────────────────────');
  console.log(`  Results: ${pass} passed, ${fail} failed`);
  console.log('───────────────────────────────────────────────\n');
  if (fail === 0) {
    console.log('🎉 All Phase 3C vehicle tests passed!\n');
  } else {
    console.log('⚠️  Some tests failed — check output above.\n');
    process.exit(1);
  }
}

run().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
