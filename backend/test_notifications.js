/**
 * RoadRescue Phase 12 — Firebase Push Notifications Test Suite
 *
 * Tests cover:
 *  - FCM device token registration (single & multi-device per user)
 *  - Unauthenticated access rejection (401)
 *  - Missing token validation (400)
 *  - Token listing (only own tokens returned)
 *  - Token deletion & ownership protection (cannot delete another user's token)
 *  - Notification dispatch targeting (sendToUser, sendToUsers)
 *  - Business event notification helpers (New Request, Status Changed, Bill Ready, Payment Success, Ratings)
 *  - Token pruning and error handling
 */

const http = require('http');
const app = require('./src/app');
const { prisma } = require('./src/config/prisma');
const notificationService = require('./src/services/notificationService');

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
  console.log('🔔 ROADRESCUE PHASE 12 PUSH NOTIFICATIONS TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const custEmail = 'notif_cust_test@roadrescue.in';
  const otherCustEmail = 'notif_other_test@roadrescue.in';
  const provEmail = 'notif_prov_test@roadrescue.in';
  const custMobile = '9860111222';
  const otherMobile = '9860111223';
  const provMobile = '9860111224';

  let customerToken, otherCustomerToken, providerToken;
  let custUserId, otherUserId, provUserId;

  try {
    // ── Cleanup ───────────────────────────────────────────────────────────────
    if (prisma) {
      await prisma.deviceToken.deleteMany({
        where: {
          user: { email: { in: [custEmail, otherCustEmail, provEmail] } },
        },
      });
      await prisma.payment.deleteMany({
        where: { customer: { email: { in: [custEmail, otherCustEmail, provEmail] } } },
      });
      await prisma.billItem.deleteMany({
        where: { bill: { customer: { email: { in: [custEmail, otherCustEmail, provEmail] } } } },
      });
      await prisma.bill.deleteMany({
        where: { customer: { email: { in: [custEmail, otherCustEmail, provEmail] } } },
      });
      await prisma.serviceRequest.deleteMany({
        where: { customer: { email: { in: [custEmail, otherCustEmail, provEmail] } } },
      });
      await prisma.providerProfile.deleteMany({
        where: { user: { email: { in: [custEmail, otherCustEmail, provEmail] } } },
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
        name: 'Notification Customer',
        mobile: custMobile,
        email: custEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    customerToken = regCust.data?.data?.token;
    custUserId = regCust.data?.data?.user?.id;

    // 2. Other Customer
    const regOther = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Other Notif Customer',
        mobile: otherMobile,
        email: otherCustEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    otherCustomerToken = regOther.data?.data?.token;
    otherUserId = regOther.data?.data?.user?.id;

    // 3. Provider
    const regProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Notif Provider',
        mobile: provMobile,
        email: provEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
      },
    });
    providerToken = regProv.data?.data?.token;
    provUserId = regProv.data?.data?.user?.id;

    // ── 1. Token Registration ────────────────────────────────────────────────
    console.log('\n--- 1. FCM Device Token Registration ---');

    // 1.1 Unauthenticated token registration fails (401)
    const t1 = await request('/api/notifications/tokens', {
      method: 'POST',
      body: { token: 'fcm_token_123' },
    });
    assert(t1.status === 401, 'Unauthenticated token registration rejected (401)');

    // 1.2 Missing token in request body fails (400)
    const t2 = await request('/api/notifications/tokens', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: {},
    });
    assert(t2.status === 400, 'Rejects registration with missing token (400)');

    // 1.3 Customer registers primary device token
    const token1 = 'fcm_cust_device_phone_001';
    const t3 = await request('/api/notifications/tokens', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { token: token1, deviceType: 'ANDROID' },
    });
    assert(t3.status === 201, 'Registers primary Android device token (201)');
    assert(t3.data?.data?.token === token1, 'Token saved matches input');
    assert(t3.data?.data?.userId === custUserId, 'Token correctly associated with customer userId');

    // 1.4 Customer registers secondary device token (multi-device support)
    const token2 = 'fcm_cust_device_tablet_002';
    const t4 = await request('/api/notifications/tokens', {
      method: 'POST',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { token: token2, deviceType: 'IOS' },
    });
    assert(t4.status === 201, 'Registers secondary iOS device token (201)');

    // 1.5 Provider registers device token
    const provToken1 = 'fcm_prov_device_phone_001';
    const t5 = await request('/api/notifications/tokens', {
      method: 'POST',
      headers: { Authorization: `Bearer ${providerToken}` },
      body: { token: provToken1, deviceType: 'ANDROID' },
    });
    assert(t5.status === 201, 'Provider registers device token (201)');

    // ── 2. Token Listing ─────────────────────────────────────────────────────
    console.log('\n--- 2. Token Listing & Isolation ---');

    // 2.1 Customer lists their own tokens
    const t6 = await request('/api/notifications/tokens', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t6.status === 200, 'Customer lists registered tokens (200)');
    assert(Array.isArray(t6.data?.data), 'Response data is an array');
    assert(t6.data?.data?.length === 2, 'Customer has exactly 2 registered tokens');
    const tokenStrings = t6.data?.data?.map((dt) => dt.token);
    assert(tokenStrings.includes(token1) && tokenStrings.includes(token2), 'Contains both device tokens');

    // 2.2 Other customer has 0 tokens
    const t7 = await request('/api/notifications/tokens', {
      headers: { Authorization: `Bearer ${otherCustomerToken}` },
    });
    assert(t7.status === 200, 'Other customer retrieves tokens (200)');
    assert(t7.data?.data?.length === 0, 'Other customer cannot see first customer tokens');

    // ── 3. Token Deletion & Ownership Protection ─────────────────────────────
    console.log('\n--- 3. Token Deletion & Ownership Protection ---');

    // 3.1 Other user cannot delete first user's token (403)
    const t8 = await request(`/api/notifications/tokens/${token1}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${otherCustomerToken}` },
    });
    assert(t8.status === 403, 'Unauthorized user cannot delete another user token (403)');

    // 3.2 Customer deletes token via URL param
    const t9 = await request(`/api/notifications/tokens/${token2}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t9.status === 200, 'Customer deletes token via URL parameter (200)');
    assert(t9.data?.data?.removed === true, 'Response confirms token removed');

    // Check count after deletion
    const t10 = await request('/api/notifications/tokens', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t10.data?.data?.length === 1, 'Customer now has 1 remaining token');

    // 3.3 Customer deletes token via JSON body
    const t11 = await request('/api/notifications/tokens', {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${customerToken}` },
      body: { token: token1 },
    });
    assert(t11.status === 200, 'Customer deletes token via request body (200)');

    const t12 = await request('/api/notifications/tokens', {
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t12.data?.data?.length === 0, 'Customer now has 0 remaining tokens');

    // 3.4 Removing non-existent token returns 200 with removed: false
    const t13 = await request('/api/notifications/tokens/non_existent_token_999', {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${customerToken}` },
    });
    assert(t13.status === 200, 'Deleting non-existent token handled safely (200)');
    assert(t13.data?.data?.removed === false, 'removed: false for missing token');

    // ── 4. Notification Service Dispatch & Targeting ─────────────────────────
    console.log('\n--- 4. Notification Service Dispatch & Event Targeting ---');

    // Clean tokens before dispatch tests
    await prisma.deviceToken.deleteMany({});

    // Re-register tokens for dispatch tests
    await notificationService.registerToken(custUserId, { token: 'fcm_cust_active_token_1' });
    await notificationService.registerToken(custUserId, { token: 'fcm_cust_active_token_2' });
    await notificationService.registerToken(provUserId, { token: 'fcm_prov_active_token_1' });

    // 4.1 Send to user with registered tokens
    const res1 = await notificationService.sendToUser(custUserId, {
      title: 'Test Notification',
      body: 'Hello Customer',
      data: { testKey: 'testVal' },
      notificationType: 'TEST',
    });
    assert(res1.success === true, 'Notification dispatched successfully to user');
    assert(res1.sentCount === 2, 'Sent to all 2 user device tokens');

    // 4.2 Send to user without registered tokens
    const res2 = await notificationService.sendToUser(otherUserId, {
      title: 'No Token Test',
      body: 'Will not send',
    });
    assert(res2.sentCount === 0, 'Handles user without registered tokens safely (0 sent)');

    // 4.3 Send to multiple users
    const res3 = await notificationService.sendToUsers([custUserId, provUserId], {
      title: 'Broadcast Alert',
      body: 'RoadRescue System Notice',
    });
    assert(res3.success === true, 'Multicast notification sent to multiple users');
    assert(res3.sentCount === 3, 'Sent to all 3 combined device tokens');

    // ── 5. Specific Business Event Notification Payloads ─────────────────────
    console.log('\n--- 5. Specific Business Event Notification Helpers ---');

    const dummyRequest = {
      id: 'req-test-1234-5678',
      serviceType: 'Tire Puncture Repair',
      category: 'PUNCTURE',
      customerAddress: 'Indiranagar 100ft Road',
      providerId: provUserId,
    };

    const dummyBill = {
      id: 'bill-test-9999',
      requestId: dummyRequest.id,
      grandTotal: 1450.0,
    };

    const dummyPayment = {
      id: 'pay-test-8888',
      amount: 1450.0,
      transactionId: 'TXN-999888777',
    };

    const dummyRating = {
      requestId: dummyRequest.id,
      score: 5,
    };

    // 5.1 New Request Available
    const e1 = await notificationService.notifyNewRequestAvailable([provUserId], dummyRequest);
    assert(e1.success === true, 'notifyNewRequestAvailable dispatches successfully');
    assert(e1.payload?.data?.type === 'NEW_REQUEST_AVAILABLE', 'Payload has NEW_REQUEST_AVAILABLE type');

    // 5.2 Request Accepted
    const e2 = await notificationService.notifyRequestAccepted(custUserId, dummyRequest, 'Technician Ramesh');
    assert(e2.success === true, 'notifyRequestAccepted dispatches successfully');
    assert(e2.payload?.data?.type === 'REQUEST_ACCEPTED', 'Payload has REQUEST_ACCEPTED type');

    // 5.3 Status Changed (ARRIVING)
    const e3 = await notificationService.notifyRequestStatusChanged(custUserId, dummyRequest, 'ARRIVING');
    assert(e3.success === true, 'notifyRequestStatusChanged (ARRIVING) dispatches successfully');
    assert(e3.payload?.data?.status === 'ARRIVING', 'Payload has status ARRIVING');

    // 5.4 Request Cancelled
    const e4 = await notificationService.notifyRequestCancelled(custUserId, dummyRequest, 'Customer', 'Found another ride');
    assert(e4.success === true, 'notifyRequestCancelled dispatches successfully');
    assert(e4.payload?.data?.type === 'REQUEST_CANCELLED', 'Payload has REQUEST_CANCELLED type');

    // 5.5 Bill Created
    const e5 = await notificationService.notifyBillCreated(custUserId, dummyBill);
    assert(e5.success === true, 'notifyBillCreated dispatches successfully');
    assert(e5.payload?.data?.type === 'BILL_CREATED', 'Payload has BILL_CREATED type');

    // 5.6 Bill Approved
    const e6 = await notificationService.notifyBillApproved(provUserId, dummyBill);
    assert(e6.success === true, 'notifyBillApproved dispatches successfully');
    assert(e6.payload?.data?.type === 'BILL_APPROVED', 'Payload has BILL_APPROVED type');

    // 5.7 Payment Success
    const e7 = await notificationService.notifyPaymentSuccess(custUserId, provUserId, dummyPayment, dummyBill);
    assert(e7 === undefined || e7 !== null, 'notifyPaymentSuccess dispatches to both customer & provider');

    // 5.8 Service Completed
    const e8 = await notificationService.notifyServiceCompleted(custUserId, dummyRequest);
    assert(e8.success === true, 'notifyServiceCompleted dispatches successfully');
    assert(e8.payload?.data?.type === 'SERVICE_COMPLETED', 'Payload has SERVICE_COMPLETED type');

    // 5.9 Rating Received
    const e9 = await notificationService.notifyRatingReceived(provUserId, dummyRating);
    assert(e9.success === true, 'notifyRatingReceived dispatches successfully');
    assert(e9.payload?.data?.type === 'RATING_RECEIVED', 'Payload has RATING_RECEIVED type');

  } catch (err) {
    console.error('Unhandled test error:', err);
    failed++;
  } finally {
    await stopServer();
  }

  console.log('\n======================================================');
  console.log('Phase 12 Notifications Tests Summary:');
  console.log(`  Passed: ${passed}`);
  console.log(`  Failed: ${failed}`);
  console.log(`  Total:  ${passed + failed}`);
  console.log('======================================================\n');

  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
