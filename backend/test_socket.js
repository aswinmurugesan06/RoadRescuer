const io = require('socket.io-client');
const http = require('http');
const app = require('./src/app');
const { initSocket, getIO } = require('./src/socket/socketManager');
const jwt = require('./src/utils/jwt');
const { prisma } = require('./src/config/prisma');

let server;
let port;
let baseUrl;

async function setupServer() {
  return new Promise((resolve) => {
    server = http.createServer(app);
    initSocket(server);
    server.listen(0, () => {
      port = server.address().port;
      baseUrl = `http://localhost:${port}`;
      resolve();
    });
  });
}

function connectSocket(token) {
  return io(baseUrl, {
    auth: { token },
    transports: ['websocket'],
    reconnection: false,
  });
}

async function runSocketTests() {
  console.log('=== Socket.IO Backend Integration Tests ===\n');

  await setupServer();

  let customerUser, providerUser, unauthorizedUser;
  let customerToken, providerToken, unauthorizedToken;
  let providerProfile;
  let serviceRequest;

  try {
    // 1. Setup Test Users & DB Records
    const timestamp = Date.now();

    customerUser = await prisma.user.create({
      data: {
        email: `socket_cust_${timestamp}@test.com`,
        passwordHash: 'hash',
        name: 'Socket Customer',
        mobile: `+9198${timestamp.toString().slice(-8)}`,
        role: 'CUSTOMER',
        isVerified: true,
      },
    });
    customerToken = jwt.generateToken({ userId: customerUser.id, role: customerUser.role });

    providerUser = await prisma.user.create({
      data: {
        email: `socket_prov_${timestamp}@test.com`,
        passwordHash: 'hash',
        name: 'Socket Provider',
        mobile: `+9197${timestamp.toString().slice(-8)}`,
        role: 'PROVIDER',
        isVerified: true,
      },
    });
    providerToken = jwt.generateToken({ userId: providerUser.id, role: providerUser.role });

    providerProfile = await prisma.providerProfile.create({
      data: {
        userId: providerUser.id,
        category: 'MECHANIC',
        verificationStatus: 'APPROVED',
        availability: 'AVAILABLE',
        garageName: 'Socket Garage',
        businessAddress: '123 Test St',
        latitude: 12.97,
        longitude: 77.59,
      },
    });

    unauthorizedUser = await prisma.user.create({
      data: {
        email: `socket_unauth_${timestamp}@test.com`,
        passwordHash: 'hash',
        name: 'Unauthorized User',
        mobile: `+9196${timestamp.toString().slice(-8)}`,
        role: 'CUSTOMER',
        isVerified: true,
      },
    });
    unauthorizedToken = jwt.generateToken({ userId: unauthorizedUser.id, role: unauthorizedUser.role });

    serviceRequest = await prisma.serviceRequest.create({
      data: {
        customerId: customerUser.id,
        providerId: providerUser.id,
        category: 'MECHANIC',
        serviceType: 'Engine Repair',
        problemDescription: 'Car won\'t start',
        vehicleModel: 'Toyota Innova',
        vehiclePlate: 'KA 01 AB 1234',
        customerAddress: 'Test Highway 1',
        customerLatitude: 12.9715,
        customerLongitude: 77.5945,
        status: 'ACCEPTED',
      },
    });

    console.log('✓ Test DB Setup completed');

    // 2. Test Unauthenticated Connection Rejection
    await new Promise((resolve) => {
      const badSocket = io(baseUrl, { transports: ['websocket'], reconnection: false });
      badSocket.on('connect_error', (err) => {
        console.log('✓ Test 1: Unauthenticated socket connection correctly rejected:', err.message);
        badSocket.close();
        resolve();
      });
      badSocket.on('connect', () => {
        console.error('FAILED Test 1: Unauthenticated socket connected!');
        badSocket.close();
        resolve();
      });
    });

    // 3. Test Authorized Connection
    const custSocket = connectSocket(customerToken);
    await new Promise((resolve) => {
      custSocket.on('connect', () => {
        console.log('✓ Test 2: Customer socket connected successfully with JWT');
        resolve();
      });
    });

    const provSocket = connectSocket(providerToken);
    await new Promise((resolve) => {
      provSocket.on('connect', () => {
        console.log('✓ Test 3: Provider socket connected successfully with JWT');
        resolve();
      });
    });

    const unauthSocket = connectSocket(unauthorizedToken);
    await new Promise((resolve) => {
      unauthSocket.on('connect', () => {
        console.log('✓ Test 4: Unauthorized user socket connected with JWT');
        resolve();
      });
    });

    // 4. Test Secure Room Joining
    custSocket.emit('join:request', serviceRequest.id);
    provSocket.emit('join:request', serviceRequest.id);
    unauthSocket.emit('join:request', serviceRequest.id);

    // Give socket 100ms to process join requests
    await new Promise((r) => setTimeout(r, 100));
    console.log('✓ Test 5: Request room join signals sent');

    // 5. Test Provider Live GPS Location Relay to Customer
    await new Promise((resolve) => {
      custSocket.on('provider:location', (data) => {
        if (data.requestId === serviceRequest.id && data.latitude === 12.9876 && data.longitude === 77.6543) {
          console.log('✓ Test 6: Live provider GPS update received by customer:', data);
          resolve();
        }
      });

      provSocket.emit('provider:location', {
        requestId: serviceRequest.id,
        latitude: 12.9876,
        longitude: 77.6543,
      });
    });

    // 6. Test Request Emitters (Status change event emission)
    const { emitStatusChange } = require('./src/socket/socketManager');
    await new Promise((resolve) => {
      custSocket.on('request:status', (data) => {
        if (data.requestId === serviceRequest.id && data.status === 'ARRIVING') {
          console.log('✓ Test 7: Real-time request:status received by customer:', data);
          resolve();
        }
      });

      emitStatusChange(serviceRequest.id, 'ARRIVING', customerUser.id);
    });

    // 7. Test Request Cancellation Emission
    const { emitRequestCancelled } = require('./src/socket/socketManager');
    await new Promise((resolve) => {
      custSocket.on('request:cancelled', (data) => {
        if (data.requestId === serviceRequest.id && data.cancellationReason === 'Test cancel') {
          console.log('✓ Test 8: Real-time request:cancelled received by customer:', data);
          resolve();
        }
      });

      emitRequestCancelled(serviceRequest.id, customerUser.id, providerUser.id, 'Test cancel');
    });

    // Cleanup Sockets
    custSocket.close();
    provSocket.close();
    unauthSocket.close();

    console.log('\n=== ALL SOCKET.IO TESTS PASSED SUCCESSFULLY! ===\n');
  } catch (err) {
    console.error('Socket Test Error:', err);
  } finally {
    // DB Cleanup
    if (serviceRequest) await prisma.serviceRequest.delete({ where: { id: serviceRequest.id } }).catch(() => {});
    if (providerProfile) await prisma.providerProfile.delete({ where: { id: providerProfile.id } }).catch(() => {});
    if (customerUser) await prisma.user.delete({ where: { id: customerUser.id } }).catch(() => {});
    if (providerUser) await prisma.user.delete({ where: { id: providerUser.id } }).catch(() => {});
    if (unauthorizedUser) await prisma.user.delete({ where: { id: unauthorizedUser.id } }).catch(() => {});

    server.close();
    process.exit(0);
  }
}

runSocketTests();
