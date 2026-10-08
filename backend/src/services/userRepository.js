const { prisma } = require('../config/prisma');

// In-memory fallback store for development/testing when PostgreSQL is offline
const memoryUsers = new Map();
const memoryProfiles = new Map();

class UserRepository {
  /**
   * Finds a user by email or mobile.
   * @param {string} identifier (email or mobile)
   */
  async findByIdentifier(identifier) {
    if (prisma) {
      try {
        return await prisma.user.findFirst({
          where: {
            OR: [{ email: identifier }, { mobile: identifier }],
          },
          include: {
            providerProfile: true,
          },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        // Fallback to memory store if PostgreSQL connection fails in development
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    }

    // Memory store fallback
    for (const user of memoryUsers.values()) {
      if (user.email === identifier || user.mobile === identifier) {
        const profile = memoryProfiles.get(user.id);
        return { ...user, providerProfile: profile || null };
      }
    }
    return null;
  }

  /**
   * Finds a user by email.
   * @param {string} email
   */
  async findByEmail(email) {
    if (prisma) {
      try {
        return await prisma.user.findUnique({
          where: { email },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    }

    for (const user of memoryUsers.values()) {
      if (user.email === email) return user;
    }
    return null;
  }

  /**
   * Finds a user by mobile.
   * @param {string} mobile
   */
  async findByMobile(mobile) {
    if (prisma) {
      try {
        return await prisma.user.findUnique({
          where: { mobile },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    }

    for (const user of memoryUsers.values()) {
      if (user.mobile === mobile) return user;
    }
    return null;
  }

  /**
   * Finds user by ID.
   * @param {string} id
   */
  async findById(id) {
    if (prisma) {
      try {
        return await prisma.user.findUnique({
          where: { id },
          include: { providerProfile: true },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB query failed, using in-memory store:', err.message);
      }
    }

    const user = memoryUsers.get(id);
    if (!user) return null;
    const profile = memoryProfiles.get(id);
    return { ...user, providerProfile: profile || null };
  }

  /**
   * Creates a new user and optional provider profile.
   */
  async create({ name, mobile, email, passwordHash, role, providerCategory }) {
    if (prisma) {
      try {
        return await prisma.user.create({
          data: {
            name,
            mobile,
            email,
            passwordHash,
            role,
            isVerified: false,
            isActive: true,
            ...(role === 'PROVIDER'
              ? {
                  providerProfile: {
                    create: {
                      category: providerCategory || 'MECHANIC',
                      verificationStatus: 'PENDING',
                      availability: 'OFFLINE',
                    },
                  },
                }
              : {}),
          },
          include: {
            providerProfile: true,
          },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB create failed, using in-memory store:', err.message);
      }
    }

    // Memory store fallback
    const id = 'usr_' + Math.random().toString(36).substring(2, 10);
    const now = new Date();
    const newUser = {
      id,
      name,
      mobile,
      email,
      passwordHash,
      role,
      isVerified: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };
    memoryUsers.set(id, newUser);

    let providerProfile = null;
    if (role === 'PROVIDER') {
      const profId = 'prof_' + Math.random().toString(36).substring(2, 10);
      providerProfile = {
        id: profId,
        userId: id,
        category: providerCategory || 'MECHANIC',
        verificationStatus: 'PENDING',
        availability: 'OFFLINE',
        garageName: null,
        businessAddress: null,
        serviceRadiusKm: 25.0,
        latitude: null,
        longitude: null,
        rating: 5.0,
        totalJobs: 0,
        createdAt: now,
        updatedAt: now,
      };
      memoryProfiles.set(id, providerProfile);
    }

    return { ...newUser, providerProfile };
  }

  /**
   * Updates user fields.
   */
  async update(id, data) {
    if (prisma) {
      try {
        return await prisma.user.update({
          where: { id },
          data: {
            ...data,
            updatedAt: new Date(),
          },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB update failed, using in-memory store:', err.message);
      }
    }

    const existing = memoryUsers.get(id);
    if (!existing) return null;
    const updated = { ...existing, ...data, updatedAt: new Date() };
    memoryUsers.set(id, updated);
    return updated;
  }
}

module.exports = new UserRepository();
