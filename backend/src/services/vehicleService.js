const { prisma } = require('../config/prisma');

// In-memory fallback store for development/testing when PostgreSQL is offline
const memoryVehicles = new Map();

class VehicleService {
  /**
   * 1. Add a vehicle.
   * Derives customer exclusively from authenticated userId.
   * If isDefault is true, all other vehicles of this user become isDefault = false.
   */
  async createVehicle(userId, data) {
    const isDefault = Boolean(data.isDefault);

    if (prisma) {
      try {
        return await prisma.$transaction(async (tx) => {
          // Check if this is the user's first vehicle
          const existingCount = await tx.vehicle.count({
            where: { userId },
          });

          // If user has no vehicles yet, make it default automatically
          const shouldBeDefault = isDefault || existingCount === 0;

          if (shouldBeDefault) {
            // Unset default on all other vehicles for this user
            await tx.vehicle.updateMany({
              where: { userId, isDefault: true },
              data: { isDefault: false },
            });
          }

          return await tx.vehicle.create({
            data: {
              userId,
              type: data.type.trim(),
              manufacturer: data.manufacturer.trim(),
              model: data.model.trim(),
              plateNumber: data.plateNumber.trim().toUpperCase(),
              year: data.year ? String(data.year).trim() : null,
              color: data.color ? data.color.trim() : null,
              isDefault: shouldBeDefault,
            },
          });
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB create failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const id = 'veh_' + Math.random().toString(36).substring(2, 10);
    const now = new Date();
    let hasDefault = false;
    for (const v of memoryVehicles.values()) {
      if (v.userId === userId && v.isDefault) hasDefault = true;
    }
    const shouldBeDefault = isDefault || !hasDefault;
    if (shouldBeDefault) {
      for (const v of memoryVehicles.values()) {
        if (v.userId === userId) v.isDefault = false;
      }
    }
    const newVeh = {
      id,
      userId,
      type: data.type.trim(),
      manufacturer: data.manufacturer.trim(),
      model: data.model.trim(),
      plateNumber: data.plateNumber.trim().toUpperCase(),
      year: data.year ? String(data.year).trim() : null,
      color: data.color ? data.color.trim() : null,
      isDefault: shouldBeDefault,
      createdAt: now,
      updatedAt: now,
    };
    memoryVehicles.set(id, newVeh);
    return newVeh;
  }

  /**
   * 2. View only the customer's own vehicles.
   */
  async getUserVehicles(userId) {
    if (prisma) {
      try {
        return await prisma.vehicle.findMany({
          where: { userId },
          orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    }

    const list = [];
    for (const v of memoryVehicles.values()) {
      if (v.userId === userId) list.push(v);
    }
    return list.sort((a, b) => {
      if (b.isDefault !== a.isDefault) return b.isDefault ? 1 : -1;
      return new Date(b.createdAt) - new Date(a.createdAt);
    });
  }

  /**
   * 3. Get single vehicle by ID.
   * Enforces that customer can only view their own vehicle.
   */
  async getVehicleById(userId, vehicleId) {
    let vehicle = null;

    if (prisma) {
      try {
        vehicle = await prisma.vehicle.findUnique({
          where: { id: vehicleId },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    } else {
      vehicle = memoryVehicles.get(vehicleId);
    }

    if (!vehicle) {
      const err = new Error('Vehicle not found');
      err.statusCode = 404;
      throw err;
    }

    // Ownership authorization check
    if (vehicle.userId !== userId) {
      const err = new Error('Access denied: You cannot view another customer’s vehicle');
      err.statusCode = 403;
      throw err;
    }

    return vehicle;
  }

  /**
   * 4. Update a vehicle.
   * Enforces customer ownership.
   * If isDefault is updated to true, resets all other vehicles of this user.
   */
  async updateVehicle(userId, vehicleId, data) {
    if (prisma) {
      try {
        return await prisma.$transaction(async (tx) => {
          const existing = await tx.vehicle.findUnique({
            where: { id: vehicleId },
          });

          if (!existing) {
            const err = new Error('Vehicle not found');
            err.statusCode = 404;
            throw err;
          }

          if (existing.userId !== userId) {
            const err = new Error('Access denied: You cannot update another customer’s vehicle');
            err.statusCode = 403;
            throw err;
          }

          const isDefault = data.isDefault !== undefined ? Boolean(data.isDefault) : existing.isDefault;

          if (isDefault && !existing.isDefault) {
            // Unset default on all other vehicles for this user
            await tx.vehicle.updateMany({
              where: { userId, isDefault: true, id: { not: vehicleId } },
              data: { isDefault: false },
            });
          }

          return await tx.vehicle.update({
            where: { id: vehicleId },
            data: {
              ...(data.type ? { type: data.type.trim() } : {}),
              ...(data.manufacturer ? { manufacturer: data.manufacturer.trim() } : {}),
              ...(data.model ? { model: data.model.trim() } : {}),
              ...(data.plateNumber ? { plateNumber: data.plateNumber.trim().toUpperCase() } : {}),
              ...(data.year !== undefined ? { year: data.year ? String(data.year).trim() : null } : {}),
              ...(data.color !== undefined ? { color: data.color ? data.color.trim() : null } : {}),
              isDefault,
            },
          });
        });
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB update failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const v = memoryVehicles.get(vehicleId);
    if (!v) {
      const err = new Error('Vehicle not found');
      err.statusCode = 404;
      throw err;
    }
    if (v.userId !== userId) {
      const err = new Error('Access denied: You cannot update another customer’s vehicle');
      err.statusCode = 403;
      throw err;
    }
    const isDefault = data.isDefault !== undefined ? Boolean(data.isDefault) : v.isDefault;
    if (isDefault) {
      for (const item of memoryVehicles.values()) {
        if (item.userId === userId) item.isDefault = false;
      }
    }
    const updated = {
      ...v,
      ...(data.type ? { type: data.type.trim() } : {}),
      ...(data.manufacturer ? { manufacturer: data.manufacturer.trim() } : {}),
      ...(data.model ? { model: data.model.trim() } : {}),
      ...(data.plateNumber ? { plateNumber: data.plateNumber.trim().toUpperCase() } : {}),
      ...(data.year !== undefined ? { year: data.year ? String(data.year).trim() : null } : {}),
      ...(data.color !== undefined ? { color: data.color ? data.color.trim() : null } : {}),
      isDefault,
      updatedAt: new Date(),
    };
    memoryVehicles.set(vehicleId, updated);
    return updated;
  }

  /**
   * 5. Delete a vehicle.
   * Enforces customer ownership.
   */
  async deleteVehicle(userId, vehicleId) {
    if (prisma) {
      try {
        return await prisma.$transaction(async (tx) => {
          const existing = await tx.vehicle.findUnique({
            where: { id: vehicleId },
          });

          if (!existing) {
            const err = new Error('Vehicle not found');
            err.statusCode = 404;
            throw err;
          }

          if (existing.userId !== userId) {
            const err = new Error('Access denied: You cannot delete another customer’s vehicle');
            err.statusCode = 403;
            throw err;
          }

          await tx.vehicle.delete({
            where: { id: vehicleId },
          });

          // If deleted vehicle was default, promote another vehicle to default if available
          if (existing.isDefault) {
            const nextVehicle = await tx.vehicle.findFirst({
              where: { userId },
              orderBy: { createdAt: 'desc' },
            });
            if (nextVehicle) {
              await tx.vehicle.update({
                where: { id: nextVehicle.id },
                data: { isDefault: true },
              });
            }
          }

          return { message: 'Vehicle deleted successfully', id: vehicleId };
        });
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB delete failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const v = memoryVehicles.get(vehicleId);
    if (!v) {
      const err = new Error('Vehicle not found');
      err.statusCode = 404;
      throw err;
    }
    if (v.userId !== userId) {
      const err = new Error('Access denied: You cannot delete another customer’s vehicle');
      err.statusCode = 403;
      throw err;
    }
    memoryVehicles.delete(vehicleId);
    return { message: 'Vehicle deleted successfully', id: vehicleId };
  }

  /**
   * 6. Set one vehicle as the customer's default vehicle.
   * Ensures previous default becomes false.
   */
  async setDefaultVehicle(userId, vehicleId) {
    if (prisma) {
      try {
        return await prisma.$transaction(async (tx) => {
          const target = await tx.vehicle.findUnique({
            where: { id: vehicleId },
          });

          if (!target) {
            const err = new Error('Vehicle not found');
            err.statusCode = 404;
            throw err;
          }

          if (target.userId !== userId) {
            const err = new Error('Access denied: You cannot modify another customer’s vehicle');
            err.statusCode = 403;
            throw err;
          }

          // Unset all existing defaults for this customer
          await tx.vehicle.updateMany({
            where: { userId, isDefault: true },
            data: { isDefault: false },
          });

          // Set this vehicle as default
          return await tx.vehicle.update({
            where: { id: vehicleId },
            data: { isDefault: true },
          });
        });
      } catch (err) {
        if (err.statusCode) throw err;
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB update failed, using in-memory store:', err.message);
      }
    }

    // In-memory fallback
    const v = memoryVehicles.get(vehicleId);
    if (!v) {
      const err = new Error('Vehicle not found');
      err.statusCode = 404;
      throw err;
    }
    if (v.userId !== userId) {
      const err = new Error('Access denied: You cannot modify another customer’s vehicle');
      err.statusCode = 403;
      throw err;
    }
    for (const item of memoryVehicles.values()) {
      if (item.userId === userId) item.isDefault = false;
    }
    v.isDefault = true;
    v.updatedAt = new Date();
    return v;
  }
}

module.exports = new VehicleService();
