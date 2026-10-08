const vehicleService = require('../services/vehicleService');

// ── Validation helper ─────────────────────────────────────────────────
const VALID_TYPES = [
  'Bike',
  'Car',
  'Van',
  'Auto',
  'Bus',
  'Light Commercial Vehicle',
  'Heavy Vehicle',
];

function validateVehicleBody(body) {
  const errors = [];

  if (!body.type || !VALID_TYPES.includes(body.type)) {
    errors.push(`type must be one of: ${VALID_TYPES.join(', ')}`);
  }
  if (!body.manufacturer || typeof body.manufacturer !== 'string' || body.manufacturer.trim().length < 2) {
    errors.push('manufacturer must be at least 2 characters');
  }
  if (!body.model || typeof body.model !== 'string' || body.model.trim().length < 1) {
    errors.push('model is required');
  }
  if (!body.plateNumber || typeof body.plateNumber !== 'string' || body.plateNumber.trim().length < 4) {
    errors.push('plateNumber must be at least 4 characters');
  }
  if (body.year !== undefined && body.year !== null && body.year !== '') {
    const yearNum = parseInt(body.year, 10);
    if (isNaN(yearNum) || yearNum < 1900 || yearNum > new Date().getFullYear() + 1) {
      errors.push('year must be a valid 4-digit year');
    }
  }

  return errors;
}

// ── Controllers ───────────────────────────────────────────────────────

/**
 * POST /api/vehicles
 * Add a new vehicle for the authenticated customer.
 */
async function createVehicle(req, res, next) {
  try {
    const userId = req.user.userId;
    const errors = validateVehicleBody(req.body);
    if (errors.length > 0) {
      return res.status(400).json({ status: 'error', message: 'Validation failed', errors });
    }

    const vehicle = await vehicleService.createVehicle(userId, req.body);
    return res.status(201).json({ status: 'success', data: vehicle });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/vehicles
 * Get all vehicles belonging to the authenticated customer.
 */
async function getMyVehicles(req, res, next) {
  try {
    const userId = req.user.userId;
    const vehicles = await vehicleService.getUserVehicles(userId);
    return res.json({ status: 'success', data: vehicles });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /api/vehicles/:id
 * Get a single vehicle by ID (ownership enforced in service).
 */
async function getVehicleById(req, res, next) {
  try {
    const userId = req.user.userId;
    const vehicle = await vehicleService.getVehicleById(userId, req.params.id);
    return res.json({ status: 'success', data: vehicle });
  } catch (err) {
    next(err);
  }
}

/**
 * PUT /api/vehicles/:id
 * Update a vehicle (ownership enforced in service).
 */
async function updateVehicle(req, res, next) {
  try {
    const userId = req.user.userId;

    // Partial validation — only validate fields that are present
    const errors = [];
    if (req.body.type !== undefined && !VALID_TYPES.includes(req.body.type)) {
      errors.push(`type must be one of: ${VALID_TYPES.join(', ')}`);
    }
    if (req.body.manufacturer !== undefined && req.body.manufacturer.trim().length < 2) {
      errors.push('manufacturer must be at least 2 characters');
    }
    if (req.body.model !== undefined && req.body.model.trim().length < 1) {
      errors.push('model is required');
    }
    if (req.body.plateNumber !== undefined && req.body.plateNumber.trim().length < 4) {
      errors.push('plateNumber must be at least 4 characters');
    }
    if (errors.length > 0) {
      return res.status(400).json({ status: 'error', message: 'Validation failed', errors });
    }

    const updated = await vehicleService.updateVehicle(userId, req.params.id, req.body);
    return res.json({ status: 'success', data: updated });
  } catch (err) {
    next(err);
  }
}

/**
 * DELETE /api/vehicles/:id
 * Delete a vehicle (ownership enforced in service).
 */
async function deleteVehicle(req, res, next) {
  try {
    const userId = req.user.userId;
    const result = await vehicleService.deleteVehicle(userId, req.params.id);
    return res.json({ status: 'success', data: result });
  } catch (err) {
    next(err);
  }
}

/**
 * PATCH /api/vehicles/:id/set-default
 * Set a vehicle as the customer's default vehicle.
 */
async function setDefaultVehicle(req, res, next) {
  try {
    const userId = req.user.userId;
    const vehicle = await vehicleService.setDefaultVehicle(userId, req.params.id);
    return res.json({ status: 'success', data: vehicle });
  } catch (err) {
    next(err);
  }
}

module.exports = {
  createVehicle,
  getMyVehicles,
  getVehicleById,
  updateVehicle,
  deleteVehicle,
  setDefaultVehicle,
};
