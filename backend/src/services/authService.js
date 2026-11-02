const userRepository = require('./userRepository');
const otpRepository = require('./otpRepository');
const { hashPassword, comparePassword } = require('../utils/password');
const { generateToken } = require('../utils/jwt');
const { generateOtp, hashOtp, verifyOtpHash, isDevMode } = require('../utils/otp');

const OTP_EXPIRY_MINUTES = parseInt(process.env.OTP_EXPIRY_MINUTES || '10', 10);

class AuthService {
  /**
   * Registers a new user (Customer or Provider).
   */
  async register({ name, mobile, email, password, role = 'CUSTOMER', providerCategory }) {
    // 1. Check duplicate email
    const existingEmail = await userRepository.findByEmail(email);
    if (existingEmail) {
      const err = new Error('Email is already registered');
      err.statusCode = 409;
      throw err;
    }

    // 2. Check duplicate mobile
    const existingMobile = await userRepository.findByMobile(mobile);
    if (existingMobile) {
      const err = new Error('Mobile number is already registered');
      err.statusCode = 409;
      throw err;
    }

    // 3. Hash password
    const passwordHash = await hashPassword(password);

    // 4. Create user record
    const user = await userRepository.create({
      name: name.trim(),
      mobile,
      email,
      passwordHash,
      role,
      providerCategory,
    });

    // 5. Generate JWT token
    const token = generateToken({
      userId: user.id,
      role: user.role,
      email: user.email,
    });

    return {
      user: this.sanitizeUser(user),
      token,
    };
  }

  /**
   * Authenticates user via email or mobile and password.
   * If expectedRole is specified, verifies that the user belongs to that role.
   */
  async login({ loginIdentifier, password, expectedRole }) {
    // 1. Find user by email or mobile
    const user = await userRepository.findByIdentifier(loginIdentifier);
    if (!user) {
      const err = new Error('Invalid email/mobile or password');
      err.statusCode = 401;
      throw err;
    }

    // 2. Check active status
    if (!user.isActive) {
      const err = new Error('Your account has been deactivated. Please contact support.');
      err.statusCode = 403;
      throw err;
    }

    // 3. Compare password
    const isMatch = await comparePassword(password, user.passwordHash);
    if (!isMatch) {
      const err = new Error('Invalid email/mobile or password');
      err.statusCode = 401;
      throw err;
    }

    // 4. Verify role against expectedRole if specified
    if (expectedRole) {
      const normalizedExpected = String(expectedRole).trim().toUpperCase();
      const userRole = String(user.role).trim().toUpperCase();
      if (userRole !== normalizedExpected) {
        const roleLabels = {
          CUSTOMER: 'Vehicle User',
          PROVIDER: 'Service Provider',
          ADMIN: 'Platform Admin',
        };
        const actualLabel = roleLabels[userRole] || userRole;
        const expectedLabel = roleLabels[normalizedExpected] || normalizedExpected;
        const err = new Error(
          `Access denied: This account is registered as ${actualLabel}. Please select ${actualLabel} on the role selection screen to sign in.`
        );
        err.statusCode = 403;
        throw err;
      }
    }

    // 5. Issue JWT
    const token = generateToken({
      userId: user.id,
      role: user.role,
      email: user.email,
    });

    return {
      user: this.sanitizeUser(user),
      token,
    };
  }

  /**
   * Generates and sends OTP for given purpose.
   */
  async sendOtp({ identifier, purpose = 'LOGIN' }) {
    // Check if user exists (optional, attach userId if found)
    const user = await userRepository.findByIdentifier(identifier);

    // Generate 6-digit OTP
    const plainOtp = generateOtp();
    const otpHash = await hashOtp(plainOtp);

    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

    // Save to repository
    await otpRepository.create({
      userId: user ? user.id : null,
      identifier,
      purpose,
      otpHash,
      expiresAt,
    });

    const response = {
      status: 'success',
      message: `OTP sent successfully to ${identifier}`,
      expiresInMinutes: OTP_EXPIRY_MINUTES,
    };

    // Include plainOtp ONLY in development mode for easy testing
    if (isDevMode()) {
      response.devOtp = plainOtp;
      response.notice = 'devOtp is provided only in development mode';
    }

    return response;
  }

  /**
   * Verifies OTP for given identifier and purpose.
   */
  async verifyOtp({ identifier, otp, purpose = 'LOGIN' }) {
    const record = await otpRepository.findLatestUnused(identifier, purpose);
    if (!record) {
      const err = new Error('No active OTP request found for this identifier and purpose');
      err.statusCode = 400;
      throw err;
    }

    // Check expiration
    if (new Date() > new Date(record.expiresAt)) {
      const err = new Error('OTP has expired. Please request a new code.');
      err.statusCode = 400;
      throw err;
    }

    // Check rate limit / attempts
    if (record.attempts >= record.maxAttempts) {
      const err = new Error('Maximum OTP verification attempts exceeded. Please request a new code.');
      err.statusCode = 429;
      throw err;
    }

    // Compare hash
    const isValid = await verifyOtpHash(otp, record.otpHash);
    if (!isValid) {
      await otpRepository.incrementAttempts(record.id);
      const remaining = record.maxAttempts - (record.attempts + 1);
      const err = new Error(`Invalid OTP. ${remaining > 0 ? `${remaining} attempts remaining.` : 'Code locked.'}`);
      err.statusCode = 400;
      throw err;
    }

    // Mark as used
    await otpRepository.markAsUsed(record.id);

    // If user exists, mark verified
    const user = await userRepository.findByIdentifier(identifier);
    if (user && !user.isVerified) {
      await userRepository.update(user.id, { isVerified: true });
    }

    return {
      verified: true,
      message: 'OTP verified successfully',
      identifier,
      purpose,
    };
  }

  /**
   * Initiates forgot password flow by dispatching OTP.
   */
  async forgotPassword({ identifier }) {
    const user = await userRepository.findByIdentifier(identifier);
    if (!user) {
      // Return generic success to avoid user enumeration
      return {
        status: 'success',
        message: 'If an account is associated with this email or mobile, a password reset code has been sent.',
      };
    }

    // Send reset OTP
    return this.sendOtp({
      identifier,
      purpose: 'PASSWORD_RESET',
    });
  }

  /**
   * Resets password after verifying OTP.
   */
  async resetPassword({ identifier, otp, newPassword }) {
    // 1. Verify OTP first
    await this.verifyOtp({
      identifier,
      otp,
      purpose: 'PASSWORD_RESET',
    });

    // 2. Find user
    const user = await userRepository.findByIdentifier(identifier);
    if (!user) {
      const err = new Error('User not found');
      err.statusCode = 404;
      throw err;
    }

    // 3. Hash new password
    const passwordHash = await hashPassword(newPassword);

    // 4. Update user
    await userRepository.update(user.id, { passwordHash });

    return {
      status: 'success',
      message: 'Password has been reset successfully. You can now log in with your new password.',
    };
  }

  /**
   * Strips sensitive fields like passwordHash.
   */
  sanitizeUser(user) {
    if (!user) return null;
    const { passwordHash, ...safeUser } = user;
    return safeUser;
  }
}

module.exports = new AuthService();
