/**
 * RoadRescue — Provider Earnings API Test Suite
 *
 * Tests cover:
 *  - Provider fetches real earnings & settlement breakdown
 *  - Verification that completed ₹590 payment is included with 10% commission (₹59) and net earnings (₹531)
 *  - RBAC guards (unauthenticated -> 401, customer -> 403)
 *  - Empty state for provider with zero completed jobs
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
    console.error(`  FAIL ${label} — ${details}`);
    failed++;
  }
}

async function runTests() {
  console.log('\n======================================================');
  console.log('🧪 ROADRESCUE PROVIDER EARNINGS TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const timestamp = Date.now();
  const providerPhone = `+9198765${String(timestamp).slice(-5)}`;
  const providerEmail = `prov_earn_${timestamp}@example.com`;
  const customerPhone = `+9187654${String(timestamp).slice(-5)}`;
  const customerEmail = `cust_earn_${timestamp}@example.com`;

  try {
    // ── Setup Provider ────────────────────────────────────────────────────────
    const regProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Auto Fixers Garage',
        mobile: providerPhone,
        email: providerEmail,
        password: 'Password@123',
        confirmPassword: 'Password@123',
        role: 'PROVIDER',
        garageName: 'Auto Fixers Pro',
        category: 'MECHANIC',
      },
    });
    const providerToken = regProv.data?.data?.token;
    const providerUserId = regProv.data?.data?.user?.id;

    // Approve provider
    await prisma.providerProfile.update({
      where: { userId: providerUserId },
      data: { verificationStatus: 'APPROVED', availability: 'AVAILABLE' },
    });

    // ── Setup Customer ────────────────────────────────────────────────────────
    const regCust = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Aswin Kumar',
        mobile: customerPhone,
        email: customerEmail,
        password: 'Password@123',
        confirmPassword: 'Password@123',
        role: 'CUSTOMER',
      },
    });
    const customerToken = regCust.data?.data?.token;

    console.log('--- 1. RBAC & Auth Guard Checks ---');
    const unauthRes = await request('/api/providers/earnings');
    assert(unauthRes.status === 401, 'Unauthenticated request returns 401');

    const custRes = await request('/api/providers/earnings', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(custRes.status === 403, 'Customer role blocked from provider earnings (403)');

    console.log('\n--- 2. Empty State (Zero Completed Jobs) ---');
    const emptyRes = await request('/api/providers/earnings', {
      headers: { Authorization: `Bearer ${providerToken}` },
    });
    assert(emptyRes.status === 200, 'Provider fetches own earnings endpoint (200)');
    assert(emptyRes.data?.data?.totalCompletedServices === 0, 'Total completed services is 0');
    assert(emptyRes.data?.data?.grossServiceBilling === 0, 'Gross service billing is 0');
    assert(emptyRes.data?.data?.platformCommission === 0, 'Platform commission is 0');
    assert(emptyRes.data?.data?.netProviderEarnings === 0, 'Net provider earnings is 0');
    assert(Array.isArray(emptyRes.data?.data?.recentPayments) && emptyRes.data?.data?.recentPayments.length === 0, 'Recent payments array is empty');

    console.log('\n--- 3. Create Service Job & Complete ₹590 Bill Payment ---');
    // Customer creates vehicle
    const regVeh = await request('/api/vehicles', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        type: 'Car',
        manufacturer: 'Hyundai',
        model: 'i20',
        plateNumber: 'KA 01 AB 1234',
        color: 'White',
      },
    });
    const vehicleId = regVeh.data?.data?.id;

    // Customer creates service request
    const createReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        serviceType: 'Mechanical Repair',
        problemDescription: 'Alternator belt snapped and engine died',
        category: 'MECHANIC',
        customerLatitude: 12.9716,
        customerLongitude: 77.5946,
        customerAddress: 'MG Road, Bangalore',
        vehiclePlate: 'KA 01 AB 1234',
        vehicleModel: 'Hyundai i20',
        vehicleType: 'Car',
        vehicleId,
      },
    });
    const requestId = createReq.data?.data?.id;

    // Assign provider and set status to IN_SERVICE
    await prisma.serviceRequest.update({
      where: { id: requestId },
      data: {
        status: 'IN_SERVICE',
        providerId: providerUserId,
        acceptedAt: new Date(),
      },
    });

    // Provider creates bill for ₹500 subtotal + 18% GST = ₹590 total
    const createBill = await request('/api/bills', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: {
        requestId,
        items: [
          { description: 'Alternator Belt Replacement', quantity: 1, unitPrice: 350 },
          { description: 'Roadside Diagnostic & Labour Charge', quantity: 1, unitPrice: 150 },
        ],
        notes: 'Belt replaced and tested. Battery recharged.',
      },
    });
    const billId = createBill.data?.data?.id;
    assert(createBill.status === 201, 'Provider creates bill (201)');
    assert(createBill.data?.data?.grandTotal === 590, 'Bill grandTotal is strictly ₹590 (₹500 + 18% GST)');

    // Customer approves bill
    const approveRes = await request(`/api/bills/${billId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { status: 'APPROVED' },
    });
    assert(approveRes.status === 200, 'Customer approves bill (200)');

    // Customer pays ₹590 via UPI
    const payRes = await request('/api/payments', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { billId, method: 'UPI' },
    });
    assert(payRes.status === 200, 'Customer completes ₹590 payment via UPI');
    assert(payRes.data?.data?.payment?.status === 'COMPLETED', 'Payment status is COMPLETED');

    console.log('\n--- 4. Verify Real Provider Earnings Calculation ---');
    const earnRes = await request('/api/providers/earnings', {
      headers: { Authorization: `Bearer ${providerToken}` },
    });
    const earnData = earnRes.data?.data;

    assert(earnRes.status === 200, 'Provider successfully fetches updated earnings (200)');
    assert(earnData?.totalCompletedServices === 1, `totalCompletedServices is 1 (got ${earnData?.totalCompletedServices})`);
    assert(earnData?.grossServiceBilling === 590, `grossServiceBilling is ₹590 (got ${earnData?.grossServiceBilling})`);
    assert(earnData?.commissionRate === 0.10, 'commissionRate is 10% (0.10)');
    assert(earnData?.platformCommission === 59, `platformCommission is ₹59 (got ${earnData?.platformCommission})`);
    assert(earnData?.netProviderEarnings === 531, `netProviderEarnings is ₹531 (got ${earnData?.netProviderEarnings})`);
    assert(earnData?.totalBalance === 531, `totalBalance is ₹531 (got ${earnData?.totalBalance})`);
    assert(earnData?.recentPayments?.length === 1, 'recentPayments contains 1 completed record');

    const paymentRecord = earnData?.recentPayments?.[0];
    assert(paymentRecord?.amount === 590, 'Payment record gross amount is 590');
    assert(paymentRecord?.commission === 59, 'Payment record commission is 59');
    assert(paymentRecord?.netAmount === 531, 'Payment record net amount is 531');
    assert(paymentRecord?.customerName === 'Aswin Kumar', `Customer name is Aswin Kumar (got ${paymentRecord?.customerName})`);
    assert(paymentRecord?.serviceType === 'Mechanical Repair', `Service type matches (got ${paymentRecord?.serviceType})`);
    assert(paymentRecord?.status === 'COMPLETED', 'Payment record status is COMPLETED');
    assert(paymentRecord?.transactionId && paymentRecord.transactionId.startsWith('TXN-'), 'Valid transactionId present');

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
