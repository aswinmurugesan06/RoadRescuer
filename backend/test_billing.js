/**
 * RoadRescue Phase 7 — Billing & Payment Integration Tests
 *
 * Tests cover:
 *  - Provider creates bill
 *  - Customer views bill
 *  - Customer approves/rejects bill
 *  - Customer pays bill
 *  - Receipt retrieval (by paymentId and requestId)
 *  - Authorization checks (wrong user, wrong role)
 *  - Idempotency (double-pay prevention)
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
  console.log('🧪 ROADRESCUE PHASE 7 BILLING & PAYMENT TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const custEmail = 'cust_bill_test@roadrescue.in';
  const otherCustEmail = 'other_bill_test@roadrescue.in';
  const provEmail = 'prov_bill_test@roadrescue.in';
  const custMobile = '9840111222';
  const otherMobile = '9840111223';
  const provMobile = '9840111224';

  let customerToken, otherCustomerToken, providerToken;
  let requestId, billId, paymentId;

  try {
    // ── DB Cleanup ───────────────────────────────────────────────────────────
    if (prisma) {
      await prisma.payment.deleteMany({
        where: {
          customer: { email: { in: [custEmail, otherCustEmail, provEmail] } },
        },
      });
      await prisma.billItem.deleteMany({
        where: {
          bill: {
            customer: { email: { in: [custEmail, otherCustEmail, provEmail] } },
          },
        },
      });
      await prisma.bill.deleteMany({
        where: {
          customer: { email: { in: [custEmail, otherCustEmail, provEmail] } },
        },
      });
      await prisma.serviceRequest.deleteMany({
        where: {
          customer: { email: { in: [custEmail, otherCustEmail, provEmail] } },
        },
      });
      await prisma.vehicle.deleteMany({
        where: {
          user: { email: { in: [custEmail, otherCustEmail, provEmail] } },
        },
      });
      await prisma.providerProfile.deleteMany({
        where: {
          user: { email: { in: [custEmail, otherCustEmail, provEmail] } },
        },
      });
      await prisma.user.deleteMany({
        where: {
          OR: [
            { email: { in: [custEmail, otherCustEmail, provEmail] } },
            { mobile: { in: [custMobile, otherMobile, provMobile] } },
          ],
        },
      });
    }

    // ── Setup Users ──────────────────────────────────────────────────────────
    // 1. Customer
    const regCust = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Bill Test Customer',
        mobile: custMobile,
        email: custEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    customerToken = regCust.data?.data?.token;
    const custId = regCust.data?.data?.user?.id;

    // 2. Other Customer
    const regOther = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Other Test Customer',
        mobile: otherMobile,
        email: otherCustEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    otherCustomerToken = regOther.data?.data?.token;

    // 3. Provider
    const regProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Bill Test Provider',
        mobile: provMobile,
        email: provEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    providerToken = regProv.data?.data?.token;
    const provUserId = regProv.data?.data?.user?.id;

    // Approve provider & set active
    if (prisma && provUserId) {
      await prisma.providerProfile.updateMany({
        where: { userId: provUserId },
        data: {
          verificationStatus: 'APPROVED',
          availability: 'AVAILABLE',
          category: 'MECHANIC',
        },
      });
    }

    // 4. Create Vehicle
    const regVehicle = await request('/api/vehicles', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        type: 'CAR',
        brand: 'Hyundai',
        model: 'Creta',
        year: 2022,
        plateNumber: 'TN 09 AZ 9999',
        fuelType: 'PETROL',
        color: 'Polar White',
      },
    });
    const vehicleId = regVehicle.data?.data?.id;

    // 5. Create Service Request
    const regReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        serviceType: 'Engine Repair',
        vehicleId,
        vehicleModel: 'Hyundai Creta',
        vehiclePlate: 'TN 09 AZ 9999',
        vehicleType: 'CAR',
        problemDescription: 'Coolant leak and overheating',
        customerLatitude: 12.9716,
        customerLongitude: 77.5946,
        customerAddress: 'MG Road, Bangalore',
      },
    });
    requestId = regReq.data?.data?.id;

    // Set request to IN_SERVICE with provider assigned
    if (prisma && requestId && provUserId) {
      await prisma.serviceRequest.update({
        where: { id: requestId },
        data: {
          status: 'IN_SERVICE',
          providerId: provUserId,
          acceptedAt: new Date(),
        },
      });
    }

    // ── 1. Bill Creation ────────────────────────────────────────────────────
    console.log('\n--- 1. Bill Creation ---');

    // Missing requestId
    const t1 = await request('/api/bills', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { items: [] },
    });
    assert(t1.status === 400, 'Rejects bill with no requestId (400)');

    // Empty items
    const t2 = await request('/api/bills', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { requestId, items: [] },
    });
    assert(t2.status === 400, 'Rejects bill with empty items (400)');

    // Valid bill creation
    const t3 = await request('/api/bills', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: {
        requestId,
        items: [
          { description: 'Coolant flush', quantity: 1, unitPrice: 500 },
          { description: 'Labor charges', quantity: 2, unitPrice: 300 },
        ],
        notes: 'Check coolant again in 5000 km',
      },
    });
    assert(t3.status === 201, 'Provider creates bill (201)', JSON.stringify(t3.data));
    assert(t3.data?.data?.id, 'Bill has an ID');
    assert(typeof t3.data?.data?.grandTotal === 'number', 'Bill has grandTotal');
    assert(t3.data?.data?.status === 'PENDING', 'Bill status is PENDING');

    // Subtotal = 500 + 600 = 1100. Tax (18%) = 198. GrandTotal = 1298
    const expectedTotal = 1298;
    assert(t3.data?.data?.grandTotal === expectedTotal, `grandTotal is ${expectedTotal} (got ${t3.data?.data?.grandTotal})`);
    billId = t3.data?.data?.id;

    // Verify provider availability was released back to AVAILABLE
    const provProfileRes = await request('/api/providers/profile', {
      headers: { Authorization: `Bearer ${providerToken}` },
    });
    assert(
      provProfileRes.data?.data?.providerProfile?.availability === 'AVAILABLE',
      `Provider is AVAILABLE after sending invoice (got ${provProfileRes.data?.data?.providerProfile?.availability})`
    );

    // Customer cannot create a bill (role guard)
    const t4 = await request('/api/bills', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        requestId,
        items: [{ description: 'Unauthorized', quantity: 1, unitPrice: 100 }],
      },
    });
    assert(t4.status === 403, 'Customer cannot create bill (403)');

    // Unauthenticated
    const t5 = await request('/api/bills', {
      method: 'POST',
      body: { requestId, items: [] },
    });
    assert(t5.status === 401, 'Unauthenticated cannot create bill (401)');

    // ── 2. Bill Retrieval ───────────────────────────────────────────────────
    console.log('\n--- 2. Bill Retrieval ---');

    // By requestId (customer)
    const t6 = await request(`/api/bills/request/${requestId}`, {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t6.status === 200, 'Customer fetches bill by requestId (200)');
    assert(t6.data?.data?.id === billId, 'Fetched correct bill by requestId');

    // By requestId (provider)
    const t7 = await request(`/api/bills/request/${requestId}`, {
      headers: { Authorization: `Bearer ${providerToken}` },
    });
    assert(t7.status === 200, 'Provider fetches bill by requestId (200)');

    // By billId (customer)
    const t8 = await request(`/api/bills/${billId}`, {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t8.status === 200, 'Customer fetches bill by billId (200)');

    // Unauthorized customer
    const t9 = await request(`/api/bills/${billId}`, {
      headers: { Authorization: `Bearer ${otherCustomerToken}` },
    });
    assert(t9.status === 403, 'Other customer cannot view bill (403)');

    // Non-existent bill
    const t10 = await request('/api/bills/00000000-0000-0000-0000-000000000000', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t10.status === 404, 'Non-existent bill returns 404');

    // ── 3. Bill Status Updates ──────────────────────────────────────────────
    console.log('\n--- 3. Bill Status Updates ---');

    // Reject without reason
    const t11 = await request(`/api/bills/${billId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { status: 'REJECTED' },
    });
    assert(t11.status === 400, 'Rejecting without reason returns 400');

    // Wrong customer cannot approve
    const t12 = await request(`/api/bills/${billId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${otherCustomerToken}` },
      body: { status: 'APPROVED' },
    });
    assert(t12.status === 403, 'Other customer cannot change bill status (403)');

    // Provider cannot update status (only customer can approve/reject)
    const t13 = await request(`/api/bills/${billId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { status: 'APPROVED' },
    });
    assert(t13.status === 403, 'Provider cannot update bill status (403)');

    // Invalid status value
    const t14 = await request(`/api/bills/${billId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { status: 'INVALID_STATUS' },
    });
    assert(t14.status === 400, 'Invalid status value returns 400');

    // Customer approves bill
    const t15 = await request(`/api/bills/${billId}/status`, {
      method: 'PATCH',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { status: 'APPROVED' },
    });
    assert(t15.status === 200, 'Customer approves bill (200)');
    assert(t15.data?.data?.status === 'APPROVED', 'Bill status is now APPROVED');

    // ── 4. Payment Processing ───────────────────────────────────────────────
    console.log('\n--- 4. Payment Processing ---');

    // Invalid payment method
    const t16 = await request('/api/payments', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { billId, method: 'BITCOIN' },
    });
    assert(t16.status === 400, 'Invalid payment method returns 400');

    // Provider cannot initiate payment (role guard)
    const t17 = await request('/api/payments', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { billId, method: 'CASH' },
    });
    assert(t17.status === 403, 'Provider cannot initiate payment (403)');

    // Other customer cannot pay someone else's bill
    const t18 = await request('/api/payments', {
      method: 'POST',
      headers: { Authorization: `Bearer ${otherCustomerToken}` },
      body: { billId, method: 'UPI' },
    });
    assert(t18.status === 403, 'Other customer cannot pay (403)');

    // Customer pays bill via UPI
    const t19 = await request('/api/payments', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { billId, method: 'UPI' },
    });
    assert(t19.status === 200, 'Customer pays bill via UPI (200)', JSON.stringify(t19.data));
    assert(t19.data?.data?.payment?.status === 'COMPLETED', 'Payment status is COMPLETED');
    assert(t19.data?.data?.bill?.status === 'PAID', 'Bill status updated to PAID');
    assert(t19.data?.data?.receipt?.receiptNumber, 'Receipt number generated');
    assert(
      t19.data?.data?.receipt?.transactionId?.startsWith('TXN-'),
      'Transaction ID generated with TXN- prefix'
    );
    paymentId = t19.data?.data?.payment?.id;

    // Double-pay prevention (idempotency)
    const t20 = await request('/api/payments', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { billId, method: 'UPI' },
    });
    assert(t20.status === 400, 'Double-pay prevention rejects already paid bill (400)');

    // ── 5. Receipt Retrieval ────────────────────────────────────────────────
    console.log('\n--- 5. Receipt Retrieval ---');

    // By paymentId (customer)
    const t21 = await request(`/api/payments/${paymentId}/receipt`, {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t21.status === 200, 'Customer fetches receipt by paymentId (200)');
    assert(t21.data?.data?.receiptNumber, 'Receipt has receiptNumber');
    assert(typeof t21.data?.data?.grandTotal === 'number', 'Receipt has grandTotal');
    assert(Array.isArray(t21.data?.data?.items), 'Receipt has items array');

    // By requestId (provider)
    const t22 = await request(`/api/payments/request/${requestId}/receipt`, {
      headers: { Authorization: `Bearer ${providerToken}` },
    });
    assert(t22.status === 200, 'Provider fetches receipt by requestId (200)');
    assert(t22.data?.data?.requestId === requestId, 'Receipt links to correct requestId');

    // Unauthorized user cannot view receipt
    const t23 = await request(`/api/payments/${paymentId}/receipt`, {
      headers: { Authorization: `Bearer ${otherCustomerToken}` },
    });
    assert(t23.status === 403, 'Other customer cannot view receipt (403)');

    // Non-existent payment
    const t24 = await request('/api/payments/00000000-0000-0000-0000-000000000000/receipt', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t24.status === 404, 'Non-existent payment returns 404');

    // ── 6. Modify Paid Bill ─────────────────────────────────────────────────
    console.log('\n--- 6. Modify Paid Bill Guard ---');

    // Cannot modify/re-bill a PAID bill
    const t25 = await request('/api/bills', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: {
        requestId,
        items: [{ description: 'Extra charge', quantity: 1, unitPrice: 200 }],
      },
    });
    assert(t25.status === 400, 'Cannot modify PAID bill (400)');

  } catch (err) {
    console.error('Unhandled test error:', err);
    failed++;
  } finally {
    await stopServer();
  }

  console.log('\n======================================================');
  console.log('Phase 7 Billing Tests Summary:');
  console.log(`  Passed: ${passed}`);
  console.log(`  Failed: ${failed}`);
  console.log(`  Total:  ${passed + failed}`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
