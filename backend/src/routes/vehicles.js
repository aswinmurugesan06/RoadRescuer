const express = require('express');
const router = express.Router();

const vehicleController = require('../controllers/vehicleController');
const { authenticateToken, requireRole } = require('../middleware/auth');

// All vehicle routes require authentication and CUSTOMER role
router.use(authenticateToken);
router.use(requireRole('CUSTOMER'));

// POST   /api/vehicles          — Add a vehicle
router.post('/', vehicleController.createVehicle);

// GET    /api/vehicles          — List own vehicles
router.get('/', vehicleController.getMyVehicles);

// GET    /api/vehicles/:id      — Get vehicle details
router.get('/:id', vehicleController.getVehicleById);

// PUT    /api/vehicles/:id      — Update a vehicle
router.put('/:id', vehicleController.updateVehicle);

// DELETE /api/vehicles/:id      — Delete a vehicle
router.delete('/:id', vehicleController.deleteVehicle);

// PATCH  /api/vehicles/:id/set-default — Set as default vehicle
router.patch('/:id/set-default', vehicleController.setDefaultVehicle);

module.exports = router;
