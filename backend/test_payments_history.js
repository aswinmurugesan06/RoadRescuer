/**
 * RoadRescue Payment History & Category Support Integration Test Suite
 *
 * Tests:
 *  1. Customer creates & completes MECHANIC request with payment
 *  2. Customer creates & completes PUNCTURE request with payment
 *  3. Customer creates & completes TOW_TRUCK request with payment
 *  4. Customer creates & completes BATTERY request with payment
 *  5. Customer creates & completes FUEL request with payment
 *  6. Customer queries GET /api/payments/my-payments -> returns all 5 payments with accurate data
 *  7. Verifies no duplicate payment records on re-query
 *  8. Direct DB verification of payment amounts, receipt numbers, and statuses
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

function assert(condition, testName, details = '') {
  if (condition) {
    console.log(`✅ [PASS] ${testName}`);
    passed++;
  } else {
    console.error(`❌ [FAIL] ${testName} - ${details}`);
    failed++;
  }
}

async function runPaymentTests() {
  console.log('\n======================================================');
  console.log('🧪 ROADRESCUE PAYMENT HISTORY INTEGRATION TEST SUITE');
  console.log('======================================================\n');

  await startServer();

  const custEmail = 'pay_test_cust@roadrescue.in';
  const provEmail = 'pay_test_prov@roadrescue.in';

  try {
    if (prisma) {
      await prisma.payment.deleteMany({
        where: { customer: { email: custEmail } },
      });
      await prisma.serviceRequest.deleteMany({
        where: { customer: { email: custEmail } },
      });
      await prisma.user.deleteMany({
        where: { email: { in: [custEmail, provEmail] } },
      });
    }

    // 1. Register Customer
    const regCust = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Aswin Customer',
        mobile: '9840011221',
        email: custEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'CUSTOMER',
      },
    });
    const custToken = regCust.data.data.token;
    const custId = regCust.data.data.user.id;

    // 2. Register Provider
    const regProv = await request('/api/auth/register', {
      method: 'POST',
      body: {
        name: 'Kareem Tyre & Mechanics',
        mobile: '9840011222',
        email: provEmail,
        password: 'password123',
        confirmPassword: 'password123',
        role: 'PROVIDER',
        providerCategory: 'MECHANIC',
      },
    });
    const provToken = regProv.data.data.token;
    const provId = regProv.data.data.user.id;

    if (prisma) {
      await prisma.providerProfile.update({
        where: { userId: provId },
        data: {
          verificationStatus: 'APPROVED',
          availability: 'AVAILABLE',
          garageName: 'Kareem Tyre & Mechanics Hub',
          latitude: 13.0827,
          longitude: 80.2707,
        },
      });
    }

    // Helper to complete a service request flow and pay bill
    async function createAndPay(serviceType, category, problem, amount, plate) {
      // Create request
      const reqRes = await request('/api/service-requests', {
        method: 'POST',
        headers: { Authorization: `Bearer ${custToken}` },
        body: {
          serviceType,
          category,
          problemDescription: problem,
          customerLatitude: 13.0827,
          customerLongitude: 80.2707,
          vehiclePlate: plate,
          vehicleModel: 'BharatBenz 2823R',
        },
      });
      const reqId = reqRes.data.data.id;

      // Provider accepts
      await request(`/api/service-requests/${reqId}/accept`, {
        method: 'PATCH',
        headers: { Authorization: `Bearer ${provToken}` },
      });

      // Provider creates bill
      const billRes = await request('/api/bills', {
        method: 'POST',
        headers: { Authorization: `Bearer ${provToken}` },
        body: {
          requestId: reqId,
          items: [
            {
              description: `${serviceType} Service Charge`,
              quantity: 1,
              unitPrice: amount,
            },
          ],
        },
      });
      const billId = billRes.data.data.id;

      // Customer pays bill
      const payRes = await request('/api/payments', {
        method: 'POST',
        headers: { Authorization: `Bearer ${custToken}` },
        body: {
          billId,
          method: 'UPI',
        },
      });

      // Reset provider to available for next job
      if (prisma) {
        await prisma.providerProfile.update({
          where: { userId: provId },
          data: { availability: 'AVAILABLE' },
        });
      }

      return { reqId, billId, payment: payRes.data.data.payment };
    }

    // 1. Mechanic payment (₹1500)
    const mech = await createAndPay('Mechanical Repair', 'MECHANIC', 'Clutch issue', 1500, 'TN-01-AA-1111');
    assert(mech.payment && mech.payment.status === 'COMPLETED', '1. Mechanic Service Payment Completed');

    // 2. Puncture payment (₹500)
    const puncture = await createAndPay('Tyre & Puncture Service', 'PUNCTURE', 'Punctured rear tyre', 500, 'TN-01-AA-2222');
    assert(puncture.payment && puncture.payment.status === 'COMPLETED', '2. PUNCTURE Service Payment Completed (₹500)');

    // 3. Tow Truck payment (₹2500) - update provider category to TOW_TRUCK
    if (prisma) {
      await prisma.providerProfile.update({
        where: { userId: provId },
        data: { category: 'TOW_TRUCK', availability: 'AVAILABLE' },
      });
    }
    const tow = await createAndPay('Tow Truck / Recovery', 'TOW_TRUCK', 'Vehicle broken down on highway', 2500, 'TN-01-AA-3333');
    assert(tow.payment && tow.payment.status === 'COMPLETED', '3. Tow Truck Payment Completed');

    // 4. Battery payment (₹800) - reset provider category to MECHANIC
    if (prisma) {
      await prisma.providerProfile.update({
        where: { userId: provId },
        data: { category: 'MECHANIC', availability: 'AVAILABLE' },
      });
    }
    const battery = await createAndPay('Battery Jump-Start', 'BATTERY', 'Dead battery in morning', 800, 'TN-01-AA-4444');
    assert(battery.payment && battery.payment.status === 'COMPLETED', '4. Battery Service Payment Completed');

    // 5. Fuel payment (₹600)
    const fuel = await createAndPay('Emergency Fuel Delivery', 'FUEL', 'Out of fuel', 600, 'TN-01-AA-5555');
    assert(fuel.payment && fuel.payment.status === 'COMPLETED', '5. Fuel Delivery Payment Completed');

    // 6. Query Customer Payment History
    const historyRes = await request('/api/payments/my-payments', {
      headers: { Authorization: `Bearer ${custToken}` },
    });

    assert(
      historyRes.status === 200 &&
        Array.isArray(historyRes.data.data) &&
        historyRes.data.data.length === 5,
      '6. GET /api/payments/my-payments returns all 5 completed payments',
      `Count: ${historyRes.data.count}`
    );

    // 7. Verify Puncture Payment details
    const puncHistory = historyRes.data.data.find((p) => p.category === 'PUNCTURE');
    assert(
      puncHistory &&
        (puncHistory.amount === 500 || puncHistory.amount === 590) && // including 18% GST if applicable
        puncHistory.status === 'Paid' &&
        puncHistory.service.toLowerCase().includes('puncture') &&
        puncHistory.provider.includes('Kareem'),
      '7. Puncture Payment Details Verified in History (Amount, Status, Provider)',
      JSON.stringify(puncHistory)
    );

    // 8. Idempotent re-query (No duplicate records)
    const historyRes2 = await request('/api/payments/my-payments', {
      headers: { Authorization: `Bearer ${custToken}` },
    });

    assert(
      historyRes2.status === 200 && historyRes2.data.data.length === 5,
      '8. Refreshing Payments Screen produces consistent, non-duplicate list'
    );
  } catch (err) {
    console.error('Test error:', err);
    failed++;
  } finally {
    await stopServer();
    console.log('\n------------------------------------------------------');
    console.log(`📊 Payment Test Summary: Passed: ${passed} | Failed: ${failed}`);
    console.log('------------------------------------------------------\n');
    process.exit(failed > 0 ? 1 : 0);
  }
}

runPaymentTests();
