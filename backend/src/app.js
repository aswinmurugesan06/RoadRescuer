const express = require('express');
const cors = require('cors');

const healthRoutes = require('./routes/health');
const authRoutes = require('./routes/auth');
const serviceRequestRoutes = require('./routes/serviceRequests');
const vehicleRoutes = require('./routes/vehicles');
const providerRoutes = require('./routes/providers');
const billRoutes = require('./routes/bills');
const paymentRoutes = require('./routes/payments');
const ratingRoutes = require('./routes/ratings');
const adminRoutes = require('./routes/admin');
const notificationRoutes = require('./routes/notifications');
const routingRoutes = require('./routes/routing');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/service-requests', serviceRequestRoutes);
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/providers', providerRoutes);
app.use('/api/bills', billRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/routing', routingRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: `Route ${req.method} ${req.originalUrl} not found`,
  });
});

// Global error handler
app.use((err, req, res, next) => {
  const statusCode = err.statusCode || (res.statusCode >= 400 ? res.statusCode : 500);

  if (process.env.NODE_ENV !== 'test') {
    if (statusCode >= 500) {
      console.error('Server Error:', err);
    }
  }

  res.status(statusCode).json({
    status: 'error',
    message: err.message || 'Internal server error',
    ...(err.errors ? { errors: err.errors } : {}),
  });
});

module.exports = app;
