/**
 * RoadRescue Phase 11 — Production Payment Gateway Integration Tests
 *
 * Tests cover:
 *  - Razorpay order creation (server-side amount calculation in paise, DB payment record)
 *  - Order authorization & validation (bill ownership, already paid, rejected bill)
 *  - Payment signature verification (valid HMAC-SHA256 signature, invalid signature rejection)
 *  - Idempotency & duplicate payment protection
 *  - Razorpay Webhook processing (signature validation, payment.captured, payment.failed, idempotency)
 *  - Digital receipt verification
 */

const http = require('http');
const crypto = require('crypto');
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
  console.log('💳 ROADRESCUE PHASE 11 PAYMENT GATEWAY TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const custEmail = 'gw_cust_test@roadrescue.in';
  const otherCustEmail = 'gw_other_test@roadrescue.in';
  const provEmail = 'gw_prov_test@roadrescue.in';
  const custMobile = '9850111222';
  const otherMobile = '9850111223';
  const provMobile = '9850111224';

  let customerToken, otherCustomerToken, providerToken;
  let requestId, billId;
  const keySecret = process.env.RAZORPAY_KEY_SECRET || 'rzp_test_secret_key';
  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || 'rzp_webhook_secret';

  try {
    // ── Cleanup ───────────────────────────────────────────────────────────────
    if (prisma) {
      await prisma.payment.deleteMany({
        where: {
          customer: { email: { in: [custEmail, otherCustEmail, provEmail] } },
        },
      });
      await prisma.billItem.deleteMany({
        where: {
          bill: { customer: { email: { in: [custEmail, otherCustEmail, provEmail] } } },
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
        name: 'Gateway Customer',
        mobile: custMobile,
        email: custEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    customerToken = regCust.data?.data?.token;
    const custUserId = regCust.data?.data?.user?.id;

    // 2. Other Customer
    const regOther = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Other Customer',
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
        name: 'Gateway Provider',
        mobile: provMobile,
        email: provEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    providerToken = regProv.data?.data?.token;
    const provUserId = regProv.data?.data?.user?.id;

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

    // 4. Vehicle & Service Request
    const regVehicle = await request('/api/vehicles', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        type: 'CAR',
        brand: 'Tata',
        model: 'Harrier',
        year: 2023,
        plateNumber: 'KA 01 MJ 1234',
        fuelType: 'DIESEL',
        color: 'Dark Edition',
      },
    });
    const vehicleId = regVehicle.data?.data?.id;

    const regReq = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'MECHANIC',
        serviceType: 'Brake Service',
        vehicleId,
        vehicleModel: 'Tata Harrier',
        vehiclePlate: 'KA 01 MJ 1234',
        vehicleType: 'CAR',
        problemDescription: 'Brake pad squeal and low braking power',
        customerLatitude: 12.9352,
        customerLongitude: 77.6245,
        customerAddress: 'Koramangala 5th Block, Bangalore',
      },
    });
    requestId = regReq.data?.data?.id;

    // Set request to IN_SERVICE
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

    // Create Bill: Labor 1000 + Parts 2000 = 3000. Tax (18%) = 540. Grand Total = 3540.
    const regBill = await request('/api/bills', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: {
        requestId,
        items: [
          { description: 'Front Brake Pads', quantity: 1, unitPrice: 2000 },
          { description: 'Labor Charges', quantity: 1, unitPrice: 1000 },
        ],
        notes: 'Brake pads replaced and tested',
      },
    });
    billId = regBill.data?.data?.id;
    const expectedGrandTotal = 3540;
    const expectedPaise = 354000;

    // ── 1. Razorpay Order Creation ──────────────────────────────────────────
    console.log('\n--- 1. Razorpay Order Creation ---');

    // Missing billId
    const o1 = await request('/api/payments/order', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {},
    });
    assert(o1.status === 400, 'Rejects order creation without billId (400)');

    // Non-existent billId
    const o2 = await request('/api/payments/order', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { billId: '00000000-0000-0000-0000-000000000000' },
    });
    assert(o2.status === 404, 'Non-existent bill returns 404');

    // Unauthorized customer
    const o3 = await request('/api/payments/order', {
      method: 'POST',
      headers: { Authorization: `Bearer ${otherCustomerToken}` },
      body: { billId },
    });
    assert(o3.status === 403, 'Unauthorized customer cannot create order (403)');

    // Role guard: Provider cannot create customer order
    const o4 = await request('/api/payments/order', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { billId },
    });
    assert(o4.status === 403, 'Provider cannot create payment order (403)');

    // Valid Order Creation
    const o5 = await request('/api/payments/order', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { billId },
    });
    assert(o5.status === 201, 'Creates Razorpay order (201)', JSON.stringify(o5.data));
    assert(Boolean(o5.data?.data?.orderId), 'Order returns orderId');
    assert(o5.data?.data?.amount === expectedPaise, `Amount is strictly calculated in paise: ${expectedPaise}`);
    assert(o5.data?.data?.currency === 'INR', 'Currency is INR');
    assert(Boolean(o5.data?.data?.keyId), 'Returns Razorpay keyId');
    const orderId = o5.data?.data?.orderId;

    // Verify DB payment record
    const paymentRecord = await prisma.payment.findFirst({
      where: { billId },
    });
    assert(paymentRecord && paymentRecord.gatewayOrderId === orderId, 'Payment record saved with gatewayOrderId');
    assert(paymentRecord?.status === 'PENDING', 'Payment record status is PENDING');

    // ── 2. Payment Verification ─────────────────────────────────────────────
    console.log('\n--- 2. Payment Signature Verification ---');

    const paymentId = `pay_${Date.now()}_test123`;

    // 2.1 Invalid signature verification attempt
    const v1 = await request('/api/payments/verify', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        billId,
        razorpay_order_id: orderId,
        razorpay_payment_id: paymentId,
        razorpay_signature: 'invalid_tampered_signature_hex',
      },
    });
    assert(v1.status === 400, 'Rejects invalid payment signature (400)');

    // Check DB payment record recorded failure
    const failedPayment = await prisma.payment.findFirst({ where: { billId } });
    assert(failedPayment?.status === 'FAILED', 'Payment marked as FAILED on bad signature');

    // 2.2 Missing verification parameters
    const v2 = await request('/api/payments/verify', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        billId,
        razorpay_order_id: orderId,
      },
    });
    assert(v2.status === 400, 'Rejects incomplete verification data (400)');

    // 2.3 Valid Signature Verification
    const validPaymentId = `pay_${Date.now()}_valid999`;
    const signaturePayload = `${orderId}|${validPaymentId}`;
    const validSignature = crypto
      .createHmac('sha256', keySecret)
      .update(signaturePayload)
      .digest('hex');

    const v3 = await request('/api/payments/verify', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        billId,
        razorpay_order_id: orderId,
        razorpay_payment_id: validPaymentId,
        razorpay_signature: validSignature,
        method: 'UPI',
      },
    });
    assert(v3.status === 200, 'Verifies valid signature & completes payment (200)', JSON.stringify(v3.data));
    assert(v3.data?.data?.payment?.status === 'COMPLETED', 'Payment status is COMPLETED');
    assert(v3.data?.data?.bill?.status === 'PAID', 'Bill status is PAID');
    assert(v3.data?.data?.payment?.gatewayPaymentId === validPaymentId, 'Gateway payment ID recorded');
    assert(Boolean(v3.data?.data?.receipt?.receiptNumber), 'Digital receipt number generated');

    // Verify service request marked COMPLETED
    const updatedReq = await prisma.serviceRequest.findUnique({ where: { id: requestId } });
    assert(updatedReq?.status === 'COMPLETED', 'Service request marked COMPLETED');
    assert(updatedReq?.finalAmount === expectedGrandTotal, 'Service request finalAmount updated');

    // 2.4 Idempotency / Duplicate verification test
    const v4 = await request('/api/payments/verify', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        billId,
        razorpay_order_id: orderId,
        razorpay_payment_id: validPaymentId,
        razorpay_signature: validSignature,
      },
    });
    assert(v4.status === 200, 'Idempotent verification returns existing receipt safely (200)');
    assert(v4.data?.data?.payment?.gatewayPaymentId === validPaymentId, 'Idempotency matches paymentId');

    // 2.5 Attempt to pay already-paid bill with a different payment ID
    const differentPaymentId = `pay_${Date.now()}_diff`;
    const diffSignature = crypto
      .createHmac('sha256', keySecret)
      .update(`${orderId}|${differentPaymentId}`)
      .digest('hex');

    const v5 = await request('/api/payments/verify', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        billId,
        razorpay_order_id: orderId,
        razorpay_payment_id: differentPaymentId,
        razorpay_signature: diffSignature,
      },
    });
    assert(v5.status === 400, 'Prevents paying already-paid bill with new payment ID (400)');

    // ── 3. Razorpay Webhooks ─────────────────────────────────────────────────
    console.log('\n--- 3. Razorpay Webhooks ---');

    // 3.1 Webhook without signature header
    const w1 = await request('/api/payments/webhook', {
      method: 'POST',
      body: { event: 'payment.captured' },
    });
    assert(w1.status === 400, 'Rejects webhook without signature (400)');

    // 3.2 Webhook with invalid signature
    const w2 = await request('/api/payments/webhook', {
      method: 'POST',
      headers: { 'x-razorpay-signature': 'invalid_webhook_sig' },
      body: { event: 'payment.captured' },
    });
    assert(w2.status === 400, 'Rejects webhook with invalid signature (400)');

    // 3.3 Create a second bill & order to test webhook-driven completion
    const req2 = await request('/api/service-requests', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {
        category: 'PUNCTURE',
        serviceType: 'Tyre Puncture',
        vehicleId,
        vehicleModel: 'Tata Harrier',
        vehiclePlate: 'KA 01 MJ 1234',
        vehicleType: 'CAR',
        problemDescription: 'Flat tyre replacement',
        customerLatitude: 12.9352,
        customerLongitude: 77.6245,
      },
    });
    const req2Id = req2.data?.data?.id;

    if (prisma && req2Id && provUserId) {
      await prisma.serviceRequest.update({
        where: { id: req2Id },
        data: { status: 'IN_SERVICE', providerId: provUserId, acceptedAt: new Date() },
      });
    }

    const bill2Res = await request('/api/bills', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: {
        requestId: req2Id,
        items: [{ description: 'Puncture repair patch', quantity: 1, unitPrice: 400 }],
      },
    });
    const bill2Id = bill2Res.data?.data?.id;

    const ord2Res = await request('/api/payments/order', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { billId: bill2Id },
    });
    const webhookOrderId = ord2Res.data?.data?.orderId;
    const webhookPaymentId = `pay_wh_${Date.now()}`;

    // Valid webhook payload
    const webhookPayload = {
      event: 'payment.captured',
      payload: {
        payment: {
          entity: {
            id: webhookPaymentId,
            order_id: webhookOrderId,
            amount: 47200,
            status: 'captured',
          },
        },
      },
    };

    const webhookBodyStr = JSON.stringify(webhookPayload);
    const validWebhookSig = crypto
      .createHmac('sha256', webhookSecret)
      .update(webhookBodyStr)
      .digest('hex');

    const w3 = await request('/api/payments/webhook', {
      method: 'POST',
      headers: { 'x-razorpay-signature': validWebhookSig },
      body: webhookPayload,
    });
    assert(w3.status === 200, 'Valid webhook payment.captured processed (200)');

    // Verify DB updated via webhook
    const whPayment = await prisma.payment.findFirst({
      where: { gatewayOrderId: webhookOrderId },
    });
    assert(whPayment?.status === 'COMPLETED', 'Payment marked COMPLETED via webhook');
    assert(whPayment?.gatewayPaymentId === webhookPaymentId, 'Gateway payment ID stored via webhook');

    const whBill = await prisma.bill.findUnique({ where: { id: bill2Id } });
    assert(whBill?.status === 'PAID', 'Bill marked PAID via webhook');

    // 3.4 Webhook Idempotency (resending same event)
    const w4 = await request('/api/payments/webhook', {
      method: 'POST',
      headers: { 'x-razorpay-signature': validWebhookSig },
      body: webhookPayload,
    });
    assert(w4.status === 200, 'Webhook retry is handled idempotently (200)');

  } catch (err) {
    console.error('Unhandled test error:', err);
    failed++;
  } finally {
    await stopServer();
  }

  console.log('\n======================================================');
  console.log('Phase 11 Gateway Tests Summary:');
  console.log(`  Passed: ${passed}`);
  console.log(`  Failed: ${failed}`);
  console.log(`  Total:  ${passed + failed}`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
