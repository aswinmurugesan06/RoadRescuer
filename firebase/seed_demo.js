#!/usr/bin/env node
/*
 * RoadRescue demo seed.
 *
 * Creates three Firebase Auth users and populates Cloud Firestore with demo
 * data for the customer, provider, and admin experiences.
 *
 * Prerequisites:
 *   npx firebase-tools projects:list   # refreshes the cached CLI login
 *
 * Run:
 *   node firebase/seed_demo.js
 *
 * Optional:
 *   FIREBASE_ACCESS_TOKEN=... node firebase/seed_demo.js
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'road-rescuer';
const PASSWORD = 'RoadRescue@123';
const API_KEY = 'AIzaSyCD0OXoxyPvejSVc7cYws0KH16OJMyCPCc';
const DB_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const AUTH_BASE = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}`;

function readAccessToken() {
  if (process.env.FIREBASE_ACCESS_TOKEN) return process.env.FIREBASE_ACCESS_TOKEN;
  const cfgPath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json',
  );
  if (!fs.existsSync(cfgPath)) {
    throw new Error(
      'No Firebase CLI login found. Run: npx firebase-tools projects:list',
    );
  }
  const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
  const token = cfg.tokens?.access_token;
  if (!token) {
    throw new Error(
      'No cached Firebase access token. Run: npx firebase-tools projects:list',
    );
  }
  if (cfg.tokens.expires_at && Date.now() > cfg.tokens.expires_at - 60_000) {
    throw new Error(
      'The cached Firebase token has expired. Run: npx firebase-tools projects:list',
    );
  }
  return token;
}

const TOKEN = readAccessToken();

async function api(method, url, body) {
  const response = await fetch(url, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await response.text();
  let json;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }
  return { ok: response.ok, status: response.status, body: json };
}

const S = (value) => ({ stringValue: String(value) });
const D = (value) => ({ doubleValue: Number(value) });
const I = (value) => ({ integerValue: String(value) });
const B = (value) => ({ booleanValue: Boolean(value) });
const T = (value) => ({
  timestampValue: value instanceof Date ? value.toISOString() : String(value),
});
const NULL = () => ({ nullValue: null });
const M = (fields) => ({ mapValue: { fields } });
const A = (values) => ({ arrayValue: { values } });

async function writeDoc(docPath, fields) {
  const result = await api('PATCH', `${DB_BASE}/${docPath}`, { fields });
  if (!result.ok) {
    throw new Error(
      `Firestore write failed for ${docPath}: ${result.status} ${JSON.stringify(result.body)}`,
    );
  }
  console.log(`  ✓ ${docPath}`);
}

async function ensureAuthUser({ email, displayName }) {
  const create = await api('POST', `${AUTH_BASE}/accounts`, {
    email,
    password: PASSWORD,
    displayName,
    emailVerified: true,
  });

  if (create.ok && create.body.localId) {
    console.log(`  ✓ created ${email}`);
    return create.body.localId;
  }

  const lookup = await api('POST', `${AUTH_BASE}/accounts:lookup`, {
    email: [email],
  });
  const existing = lookup.body?.users?.[0];
  if (!lookup.ok || !existing) {
    throw new Error(
      `Could not create/look up ${email}: ${JSON.stringify(create.body)}`,
    );
  }

  const update = await api('POST', `${AUTH_BASE}/accounts:update`, {
    localId: existing.localId,
    password: PASSWORD,
    displayName,
    emailVerified: true,
    disabled: false,
  });
  if (!update.ok) {
    throw new Error(
      `Could not update ${email}: ${JSON.stringify(update.body)}`,
    );
  }
  console.log(`  ✓ updated ${email}`);
  return existing.localId;
}

function dateDaysAgo(days, hour = 10) {
  const d = new Date();
  d.setDate(d.getDate() - days);
  d.setHours(hour, 30, 0, 0);
  return d.toISOString();
}

async function main() {
  console.log(`\nSeeding RoadRescue demo data into ${PROJECT_ID}\n`);

  // ── Auth users ────────────────────────────────────────────────────────
  console.log('Firebase Authentication:');
  const customerUid = await ensureAuthUser({
    email: 'demo.customer@roadrescue.in',
    displayName: 'Aarav Sharma',
  });
  const providerUid = await ensureAuthUser({
    email: 'demo.provider@roadrescue.in',
    displayName: 'Rajan Auto Works',
  });
  const adminUid = await ensureAuthUser({
    email: 'demo.admin@roadrescue.in',
    displayName: 'RoadRescue Admin',
  });

  // ── Profiles ──────────────────────────────────────────────────────────
  console.log('\nFirestore users:');
  const created = dateDaysAgo(30);
  const updated = dateDaysAgo(0);

  await writeDoc(`users/${customerUid}`, {
    uid: S(customerUid),
    name: S('Aarav Sharma'),
    mobile: S('9876543210'),
    email: S('demo.customer@roadrescue.in'),
    role: S('CUSTOMER'),
    isVerified: B(true),
    isActive: B(true),
    createdAt: T(created),
    updatedAt: T(updated),
  });

  await writeDoc(`users/${providerUid}`, {
    uid: S(providerUid),
    name: S('Rajan Auto Works'),
    mobile: S('9876543211'),
    email: S('demo.provider@roadrescue.in'),
    role: S('PROVIDER'),
    providerCategory: S('MECHANIC'),
    category: S('MECHANIC'),
    garageName: S('Rajan Auto Works'),
    businessAddress: S('Outer Ring Road, Bengaluru'),
    serviceRadiusKm: D(25),
    latitude: D(12.9716),
    longitude: D(77.5946),
    verificationStatus: S('APPROVED'),
    availability: S('AVAILABLE'),
    rating: D(5),
    ratingCount: I(3),
    totalJobs: I(3),
    isVerified: B(true),
    isActive: B(true),
    createdAt: T(created),
    updatedAt: T(updated),
  });

  await writeDoc(`users/${adminUid}`, {
    uid: S(adminUid),
    name: S('RoadRescue Admin'),
    mobile: S('9876543212'),
    email: S('demo.admin@roadrescue.in'),
    role: S('ADMIN'),
    isVerified: B(true),
    isActive: B(true),
    createdAt: T(created),
    updatedAt: T(updated),
  });

  // ── Vehicles ──────────────────────────────────────────────────────────
  console.log('\nFirestore vehicles:');
  await writeDoc(`users/${customerUid}/vehicles/demo-vehicle-car`, {
    type: S('Car'),
    manufacturer: S('Hyundai'),
    model: S('Creta'),
    plateNumber: S('KA01AB1234'),
    year: S('2024'),
    color: S('White'),
    isDefault: B(true),
    createdAt: T(dateDaysAgo(28)),
    updatedAt: T(dateDaysAgo(28)),
  });
  await writeDoc(`users/${customerUid}/vehicles/demo-vehicle-bike`, {
    type: S('Bike'),
    manufacturer: S('Royal Enfield'),
    model: S('Classic 350'),
    plateNumber: S('KA05CD5678'),
    year: S('2023'),
    color: S('Black'),
    isDefault: B(false),
    createdAt: T(dateDaysAgo(25)),
    updatedAt: T(dateDaysAgo(25)),
  });

  const customer = {
    id: S(customerUid),
    name: S('Aarav Sharma'),
    mobile: S('9876543210'),
  };
  const provider = {
    id: S(providerUid),
    name: S('Rajan Auto Works'),
    mobile: S('9876543211'),
  };

  // ── Completed requests + bills + payments + ratings ───────────────────
  console.log('\nFirestore service requests, bills, payments, ratings:');

  const completed = [
    {
      id: 'demo-request-completed-1',
      serviceType: 'Mechanic',
      category: 'MECHANIC',
      problem: 'Engine overheating on Outer Ring Road',
      vehicleId: 'demo-vehicle-car',
      vehicleModel: 'Hyundai Creta',
      vehiclePlate: 'KA01AB1234',
      vehicleType: 'Car',
      lat: 12.9352,
      lng: 77.6245,
      address: 'Outer Ring Road, Bengaluru — near Marathahalli bridge',
      days: 12,
      items: [
        ['Engine inspection & diagnosis', 1, 500],
        ['Coolant replacement', 1, 480],
        ['Thermostat replacement', 1, 500],
      ],
      method: 'UPI',
      rating: 5,
      review: 'Reached quickly and fixed the overheating issue on the spot.',
    },
    {
      id: 'demo-request-completed-2',
      serviceType: 'Puncture',
      category: 'PUNCTURE',
      problem: 'Rear tyre puncture near Electronic City',
      vehicleId: 'demo-vehicle-bike',
      vehicleModel: 'Royal Enfield Classic 350',
      vehiclePlate: 'KA05CD5678',
      vehicleType: 'Bike',
      lat: 12.8452,
      lng: 77.6602,
      address: 'Electronic City Phase 1, Bengaluru',
      days: 8,
      items: [
        ['Tyre puncture repair', 1, 450],
        ['Wheel balancing', 1, 300],
      ],
      method: 'CASH',
      rating: 5,
      review: 'Professional puncture repair and a fair price.',
    },
    {
      id: 'demo-request-completed-3',
      serviceType: 'Battery',
      category: 'BATTERY',
      problem: 'Battery jump-start required at Whitefield',
      vehicleId: 'demo-vehicle-car',
      vehicleModel: 'Hyundai Creta',
      vehiclePlate: 'KA01AB1234',
      vehicleType: 'Car',
      lat: 12.9698,
      lng: 77.7499,
      address: 'Whitefield Main Road, Bengaluru',
      days: 3,
      items: [
        ['Battery jump-start', 1, 400],
        ['Battery terminal cleaning', 1, 250],
      ],
      method: 'CARD',
      rating: 5,
      review: 'Back on the road within 20 minutes. Highly recommended.',
    },
  ];

  for (let index = 0; index < completed.length; index++) {
    const item = completed[index];
    const requestNumber = index + 1;
    const createdAt = dateDaysAgo(item.days, 9);
    const completedAt = dateDaysAgo(item.days, 11);

    let subtotal = 0;
    const billItems = item.items.map((entry, itemIndex) => {
      const [description, quantity, unitPrice] = entry;
      const total = quantity * unitPrice;
      subtotal += total;
      return {
        id: S(`demo-item-${requestNumber}-${itemIndex + 1}`),
        description: S(description),
        quantity: I(quantity),
        unitPrice: D(unitPrice),
        total: D(total),
      };
    });
    const taxAmount = Number((subtotal * 0.18).toFixed(2));
    const grandTotal = Number((subtotal + taxAmount).toFixed(2));

    await writeDoc(`serviceRequests/${item.id}`, {
      customerId: S(customerUid),
      customerName: S('Aarav Sharma'),
      customerMobile: S('9876543210'),
      providerId: S(providerUid),
      providerName: S('Rajan Auto Works'),
      providerMobile: S('9876543211'),
      providerCategory: S('MECHANIC'),
      category: S(item.category),
      serviceType: S(item.serviceType),
      problemDescription: S(item.problem),
      status: S('COMPLETED'),
      customerLatitude: D(item.lat),
      customerLongitude: D(item.lng),
      customerAddress: S(item.address),
      vehicleId: S(item.vehicleId),
      vehicleModel: S(item.vehicleModel),
      vehiclePlate: S(item.vehiclePlate),
      vehicleType: S(item.vehicleType),
      estimatedAmount: D(grandTotal),
      finalAmount: D(grandTotal),
      providerLatitude: D(12.9716),
      providerLongitude: D(77.5946),
      acceptedAt: T(dateDaysAgo(item.days, 9.5)),
      completedAt: T(completedAt),
      createdAt: T(createdAt),
      updatedAt: T(completedAt),
    });

    const billId = `demo-bill-${requestNumber}`;
    await writeDoc(`bills/${billId}`, {
      requestId: S(item.id),
      providerId: S(providerUid),
      customerId: S(customerUid),
      status: S('PAID'),
      items: A(billItems.map((fields) => M(fields))),
      subtotal: D(subtotal),
      taxRate: D(0.18),
      taxAmount: D(taxAmount),
      grandTotal: D(grandTotal),
      notes: S('Thank you for choosing RoadRescue.'),
      provider: M(provider),
      customer: M(customer),
      createdAt: T(createdAt),
      updatedAt: T(completedAt),
    });

    await writeDoc(`payments/demo-payment-${requestNumber}`, {
      billId: S(billId),
      requestId: S(item.id),
      customerId: S(customerUid),
      providerId: S(providerUid),
      amount: D(grandTotal),
      method: S(item.method),
      status: S('COMPLETED'),
      transactionId: S(`TXN-DEMO-${String(requestNumber).padStart(4, '0')}`),
      receiptNumber: S(`RR-2026-DEMO0${requestNumber}`),
      paidAt: T(completedAt),
      customerName: S('Aarav Sharma'),
      providerName: S('Rajan Auto Works'),
      vehicleModel: S(item.vehicleModel),
      vehiclePlate: S(item.vehiclePlate),
      location: S(item.address),
      serviceType: S(item.serviceType),
      category: S(item.category),
      createdAt: T(completedAt),
      updatedAt: T(completedAt),
    });

    await writeDoc(`ratings/demo-rating-${requestNumber}`, {
      requestId: S(item.id),
      customerId: S(customerUid),
      providerId: S(providerUid),
      score: I(item.rating),
      review: S(item.review),
      customer: M(customer),
      provider: M(provider),
      createdAt: T(dateDaysAgo(item.days, 12)),
      updatedAt: T(dateDaysAgo(item.days, 12)),
    });
  }

  // ── Active request assigned to the provider ───────────────────────────
  await writeDoc('serviceRequests/demo-request-active', {
    customerId: S(customerUid),
    customerName: S('Aarav Sharma'),
    customerMobile: S('9876543210'),
    providerId: S(providerUid),
    providerName: S('Rajan Auto Works'),
    providerMobile: S('9876543211'),
    providerCategory: S('MECHANIC'),
    category: S('MECHANIC'),
    serviceType: S('Mechanic'),
    problemDescription: S('Brake pedal feels soft — needs inspection'),
    status: S('IN_SERVICE'),
    customerLatitude: D(12.9250),
    customerLongitude: D(77.5938),
    customerAddress: S('Jayanagar 4th Block, Bengaluru'),
    vehicleId: S('demo-vehicle-car'),
    vehicleModel: S('Hyundai Creta'),
    vehiclePlate: S('KA01AB1234'),
    vehicleType: S('Car'),
    estimatedAmount: D(1200),
    providerLatitude: D(12.9340),
    providerLongitude: D(77.6100),
    acceptedAt: T(dateDaysAgo(0, 8)),
    createdAt: T(dateDaysAgo(0, 7.5)),
    updatedAt: T(dateDaysAgo(0, 9)),
  });

  // ── Pending request visible to the provider ───────────────────────────
  await writeDoc('serviceRequests/demo-request-pending', {
    customerId: S(customerUid),
    customerName: S('Aarav Sharma'),
    customerMobile: S('9876543210'),
    category: S('MECHANIC'),
    serviceType: S('Mechanic'),
    problemDescription: S('Strange noise from the engine at idle'),
    status: S('PENDING'),
    customerLatitude: D(12.9550),
    customerLongitude: D(77.5850),
    customerAddress: S('MG Road, Bengaluru'),
    vehicleId: S('demo-vehicle-car'),
    vehicleModel: S('Hyundai Creta'),
    vehiclePlate: S('KA01AB1234'),
    vehicleType: S('Car'),
    estimatedAmount: D(800),
    createdAt: T(dateDaysAgo(0, 6.5)),
    updatedAt: T(dateDaysAgo(0, 6.5)),
  });

  // ── Cancelled request for history ─────────────────────────────────────
  await writeDoc('serviceRequests/demo-request-cancelled', {
    customerId: S(customerUid),
    customerName: S('Aarav Sharma'),
    customerMobile: S('9876543210'),
    category: S('FUEL'),
    serviceType: S('Fuel'),
    problemDescription: S('Out of fuel on the ORR shoulder'),
    status: S('CANCELLED'),
    customerLatitude: D(12.9800),
    customerLongitude: D(77.6400),
    customerAddress: S('Outer Ring Road, Bengaluru'),
    vehicleId: S('demo-vehicle-car'),
    vehicleModel: S('Hyundai Creta'),
    vehiclePlate: S('KA01AB1234'),
    vehicleType: S('Car'),
    estimatedAmount: D(500),
    cancellationReason: S('Arranged fuel from a nearby station.'),
    createdAt: T(dateDaysAgo(18, 14)),
    updatedAt: T(dateDaysAgo(18, 14.2)),
  });

  console.log('\nSeed complete.\n');
  console.log('Demo logins:');
  console.log('  Vehicle User     demo.customer@roadrescue.in  /  RoadRescue@123');
  console.log('  Service Provider demo.provider@roadrescue.in  /  RoadRescue@123');
  console.log('  Platform Admin   demo.admin@roadrescue.in     /  RoadRescue@123');
  console.log('');
}

main().catch((error) => {
  console.error('\nSeed failed:', error.message);
  process.exit(1);
});
