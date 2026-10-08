require('dotenv').config();
const http = require('http');
const app = require('./src/app');
const { initSocket } = require('./src/socket/socketManager');

const PORT = process.env.PORT || 3000;

// Create an http.Server so Socket.IO can attach alongside Express
const httpServer = http.createServer(app);

// Initialize Socket.IO with JWT auth and event handlers
initSocket(httpServer);

httpServer.listen(PORT, () => {
  console.log(`\n🚀 RoadRescue Backend running on port ${PORT}`);
  console.log(`   Health check: http://localhost:${PORT}/api/health`);
  console.log(`   Socket.IO:    ws://localhost:${PORT}\n`);
});
