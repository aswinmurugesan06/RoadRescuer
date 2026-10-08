const { prisma } = require('../config/prisma');

// In-memory fallback store for OTPs
const memoryOtps = [];

class OtpRepository {
  /**
   * Stores an OTP.
   */
  async create({ userId, identifier, purpose, otpHash, expiresAt }) {
    if (prisma) {
      try {
        return await prisma.otp.create({
          data: {
            userId: userId || null,
            identifier,
            purpose,
            otpHash,
            expiresAt,
            isUsed: false,
            attempts: 0,
            maxAttempts: 3,
          },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB OTP create failed, using in-memory store:', err.message);
      }
    }

    const id = 'otp_' + Math.random().toString(36).substring(2, 10);
    const newOtp = {
      id,
      userId: userId || null,
      identifier,
      purpose,
      otpHash,
      expiresAt,
      isUsed: false,
      attempts: 0,
      maxAttempts: 3,
      createdAt: new Date(),
    };
    memoryOtps.push(newOtp);
    return newOtp;
  }

  /**
   * Finds latest unused OTP for identifier and purpose.
   */
  async findLatestUnused(identifier, purpose) {
    if (prisma) {
      try {
        return await prisma.otp.findFirst({
          where: {
            identifier,
            purpose,
            isUsed: false,
          },
          orderBy: {
            createdAt: 'desc',
          },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB OTP find failed, using in-memory store:', err.message);
      }
    }

    // Filter memory store in reverse
    for (let i = memoryOtps.length - 1; i >= 0; i--) {
      const o = memoryOtps[i];
      if (o.identifier === identifier && o.purpose === purpose && !o.isUsed) {
        return o;
      }
    }
    return null;
  }

  /**
   * Increments attempt count on an OTP.
   */
  async incrementAttempts(id) {
    if (prisma) {
      try {
        return await prisma.otp.update({
          where: { id },
          data: { attempts: { increment: 1 } },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB OTP increment failed, using in-memory store:', err.message);
      }
    }

    const o = memoryOtps.find((item) => item.id === id);
    if (o) {
      o.attempts += 1;
      return o;
    }
    return null;
  }

  /**
   * Marks OTP as used.
   */
  async markAsUsed(id) {
    if (prisma) {
      try {
        return await prisma.otp.update({
          where: { id },
          data: { isUsed: true },
        });
      } catch (err) {
        if (process.env.NODE_ENV === 'production') throw err;
        console.warn('⚠️ DB OTP markAsUsed failed, using in-memory store:', err.message);
      }
    }

    const o = memoryOtps.find((item) => item.id === id);
    if (o) {
      o.isUsed = true;
      return o;
    }
    return null;
  }
}

module.exports = new OtpRepository();
