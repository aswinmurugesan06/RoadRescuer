/**
 * Integration Test: Provider Job History & Completed Filtering
 * Run: node test_provider_history.js
 */

const http = require('http');
const app = require('./src/app');
const { prisma } = require('./src/config/prisma');

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

async function request(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(`${BASE}${path}`);
    const payload = body ? JSON.stringify(body) : null;
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        let parsed = data;
        try {
          parsed = JSON.parse(data);
        } catch (_) {}
        resolve({ status: res.statusCode, body: parsed });
      });
    });

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

let pass = 0;
let fail = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  PASS: ${message}`);
    pass++;
  } else {
    console.error(`  FAIL: ${message}`);
    fail++;
  }
}

async function runTests() {
  console.log('\n=== Provider Job History Integration Test ===\n');
  await startServer();

  const ts = Date.now();
  const provider1Email = `prov_hist_${ts}@test.com`;
  const provider2Email = `prov2_hist_${ts}@test.com`;
  const customerEmail = `cust_hist_${ts}@test.com`;
  const p1Mobile = `7${String(ts).slice(-9)}`;
  const p2Mobile = `8${String(ts).slice(-9)}`;
  const custMobile = `9${String(ts).slice(-9)}`;

  try {
    // 1. Register Provider 1
    const p1Reg = await request('POST', '/auth/register', {
      name: 'History Provider 1',
      email: provider1Email,
      mobile: p1Mobile,
      password: 'Test@1234',
      confirmPassword: 'Test@1234',
      role: 'PROVIDER',
      providerCategory: 'MECHANIC',
    });
    assert(p1Reg.status === 201, `Provider 1 registered successfully (status ${p1Reg.status})`);
    const p1Token = p1Reg.body.data.token;
    const p1Id = p1Reg.body.data.user.id;

    // 2. Register Provider 2
    const p2Reg = await request('POST', '/auth/register', {
      name: 'History Provider 2',
      email: provider2Email,
      mobile: p2Mobile,
      password: 'Test@1234',
      confirmPassword: 'Test@1234',
      role: 'PROVIDER',
      providerCategory: 'MECHANIC',
    });
    assert(p2Reg.status === 201, `Provider 2 registered successfully (status ${p2Reg.status})`);
    const p2Token = p2Reg.body.data.token;
    const p2Id = p2Reg.body.data.user.id;

    // 3. Register Customer
    const custReg = await request('POST', '/auth/register', {
      name: 'Customer Hist',
      email: customerEmail,
      mobile: custMobile,
      password: 'Test@1234',
      confirmPassword: 'Test@1234',
      role: 'CUSTOMER',
    });
    assert(custReg.status === 201, `Customer registered successfully (status ${custReg.status})`);
    const custToken = custReg.body.data.token;
    const custId = custReg.body.data.user.id;

    // 4. Test unauthenticated call to /history
    const unauthRes = await request('GET', '/providers/history');
    assert(unauthRes.status === 401, 'Unauthenticated GET /api/providers/history rejected with 401');

    // 5. Test Customer calling /history (role mismatch)
    const custRoleRes = await request('GET', '/providers/history', null, custToken);
    assert(custRoleRes.status === 403, 'Customer role calling GET /api/providers/history rejected with 403 Forbidden');

    // 6. Provider 1 checks history initially — should be empty array
    const p1InitialHist = await request('GET', '/providers/history', null, p1Token);
    assert(p1InitialHist.status === 200, 'Provider 1 can call GET /api/providers/history (200 OK)');
    assert(
      Array.isArray(p1InitialHist.body.data) && p1InitialHist.body.data.length === 0,
      'Provider 1 initially has empty history array'
    );

    // 7. Create real database records:
    //    Job A: COMPLETED job assigned to Provider 1
    //    Job B: IN_SERVICE job assigned to Provider 1 (active, not completed)
    //    Job D: COMPLETED job assigned to Provider 2
    const completedAt1 = new Date();
    const jobA = await prisma.serviceRequest.create({
      data: {
        customerId: custId,
        providerId: p1Id,
        category: 'MECHANIC',
        serviceType: 'Mechanical Repair',
        problemDescription: 'Alternator malfunction and belt replacement',
        status: 'COMPLETED',
        customerLatitude: 12.9716,
        customerLongitude: 77.5946,
        customerAddress: 'MG Road, Bangalore',
        vehiclePlate: 'KA 01 AB 1234',
        vehicleModel: 'Maruti Swift',
        vehicleType: 'Car',
        finalAmount: 1850.0,
        estimatedAmount: 1500.0,
        completedAt: completedAt1,
      },
    });

    // Create a bill and payment for Job A
    const billA = await prisma.bill.create({
      data: {
        requestId: jobA.id,
        providerId: p1Id,
        customerId: custId,
        status: 'PAID',
        subtotal: 1567.8,
        taxRate: 0.18,
        taxAmount: 282.2,
        grandTotal: 1850.0,
        notes: 'Alternator service completed',
      },
    });

    await prisma.payment.create({
      data: {
        billId: billA.id,
        requestId: jobA.id,
        customerId: custId,
        providerId: p1Id,
        amount: 1850.0,
        status: 'COMPLETED',
        transactionId: `txn_test_${ts}_a`,
        receiptNumber: `rec_${ts}_a`,
        paidAt: completedAt1,
      },
    });

    // Job B: IN_SERVICE for Provider 1 (must NOT appear in history!)
    const jobB = await prisma.serviceRequest.create({
      data: {
        customerId: custId,
        providerId: p1Id,
        category: 'PUNCTURE',
        serviceType: 'Tyre & Puncture Service',
        problemDescription: 'Rear tyre puncture',
        status: 'IN_SERVICE',
        customerLatitude: 12.9720,
        customerLongitude: 77.5950,
        customerAddress: 'Brigade Road, Bangalore',
        vehiclePlate: 'KA 01 CD 5678',
        vehicleModel: 'Hyundai Creta',
        vehicleType: 'Car',
      },
    });

    // Job D: COMPLETED for Provider 2 (must NOT appear in Provider 1's history!)
    const jobD = await prisma.serviceRequest.create({
      data: {
        customerId: custId,
        providerId: p2Id,
        category: 'BATTERY',
        serviceType: 'Battery Jump-Start',
        problemDescription: 'Dead battery',
        status: 'COMPLETED',
        customerLatitude: 12.9730,
        customerLongitude: 77.5960,
        customerAddress: 'Indiranagar, Bangalore',
        vehiclePlate: 'KA 02 EF 9012',
        vehicleModel: 'Tata Nexon',
        vehicleType: 'Car',
        finalAmount: 650.0,
        completedAt: new Date(),
      },
    });

    // 8. Test Provider 1's history
    const p1HistRes = await request('GET', '/providers/history', null, p1Token);
    assert(p1HistRes.status === 200, 'Provider 1 history fetched successfully');
    const p1Jobs = p1HistRes.body.data;
    assert(p1Jobs.length === 1, `Provider 1 has exactly 1 completed job (got ${p1Jobs.length})`);

    const p1FirstJob = p1Jobs[0];
    assert(p1FirstJob.id === jobA.id, `Job ID matches completed job A (${p1FirstJob.id})`);
    assert(p1FirstJob.status === 'COMPLETED', 'Job status is COMPLETED');
    assert(p1FirstJob.vehicleModel === 'Maruti Swift', 'Vehicle model matches Maruti Swift');
    assert(p1FirstJob.vehiclePlate === 'KA 01 AB 1234', 'Vehicle plate matches KA 01 AB 1234');
    assert(p1FirstJob.serviceType === 'Mechanical Repair', 'Service type matches Mechanical Repair');
    assert(p1FirstJob.problemDescription === 'Alternator malfunction and belt replacement', 'Problem description matches');
    assert(p1FirstJob.totalAmount === 1850.0, `Total amount paid matches ₹1850 (got ${p1FirstJob.totalAmount})`);
    assert(p1FirstJob.customerAddress === 'MG Road, Bangalore', 'Address matches');

    // Confirm Provider 1 cannot see Job B (IN_SERVICE) or Job D (belonging to Provider 2)
    const hasJobB = p1Jobs.some((j) => j.id === jobB.id);
    assert(!hasJobB, 'IN_SERVICE job B is NOT included in history');

    const hasJobD = p1Jobs.some((j) => j.id === jobD.id);
    assert(!hasJobD, 'Provider 2 job D is NOT visible to Provider 1');

    // 9. Test Provider 2's history isolation
    const p2HistRes = await request('GET', '/providers/history', null, p2Token);
    assert(p2HistRes.status === 200, 'Provider 2 history fetched successfully');
    const p2Jobs = p2HistRes.body.data;
    assert(p2Jobs.length === 1, `Provider 2 has exactly 1 completed job (got ${p2Jobs.length})`);
    assert(p2Jobs[0].id === jobD.id, 'Provider 2 job is Job D');
    assert(!p2Jobs.some((j) => j.id === jobA.id), 'Provider 2 cannot see Provider 1 completed job A');

    // 10. Clean up created test data
    await prisma.payment.deleteMany({ where: { requestId: { in: [jobA.id, jobB.id, jobD.id] } } }).catch(() => {});
    await prisma.bill.deleteMany({ where: { requestId: { in: [jobA.id, jobB.id, jobD.id] } } }).catch(() => {});
    await prisma.serviceRequest.deleteMany({ where: { id: { in: [jobA.id, jobB.id, jobD.id] } } }).catch(() => {});
    await prisma.providerProfile.deleteMany({ where: { userId: { in: [p1Id, p2Id] } } }).catch(() => {});
    await prisma.user.deleteMany({ where: { id: { in: [p1Id, p2Id, custId] } } }).catch(() => {});
  } catch (err) {
    console.error('Test execution error:', err);
    fail++;
  } finally {
    await stopServer();
    console.log(`\nResults: ${pass} passed, ${fail} failed\n`);
    if (fail > 0) process.exit(1);
  }
}

runTests();
