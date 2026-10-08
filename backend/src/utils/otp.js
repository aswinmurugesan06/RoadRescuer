const bcrypt = require('bcryptjs');

const OTP_LENGTH = 6;
const SALT_ROUNDS = 8; // Faster salt for transient OTP hashes

/**
 * Generates a random 6-digit numeric OTP.
 * @returns {string}
 */
function generateOtp() {
  const min = Math.pow(10, OTP_LENGTH - 1);
  const max = Math.pow(10, OTP_LENGTH) - 1;
  return Math.floor(min + Math.random() * (max - min + 1)).toString();
}

/**
 * Hashes an OTP using bcrypt before storing in database.
 * @param {string} otp
 * @returns {Promise<string>}
 */
async function hashOtp(otp) {
  return bcrypt.hash(otp, SALT_ROUNDS);
}

/**
 * Compares an incoming plain OTP with its stored hash.
 * @param {string} otp
 * @param {string} hash
 * @returns {Promise<boolean>}
 */
async function verifyOtpHash(otp, hash) {
  if (!otp || !hash) return false;
  return bcrypt.compare(otp, hash);
}

/**
 * Checks if running in development mode for mock OTP inspection.
 * @returns {boolean}
 */
function isDevMode() {
  return (
    process.env.NODE_ENV === 'development' ||
    process.env.OTP_DEV_MODE === 'true'
  );
}

module.exports = {
  generateOtp,
  hashOtp,
  verifyOtpHash,
  isDevMode,
};
