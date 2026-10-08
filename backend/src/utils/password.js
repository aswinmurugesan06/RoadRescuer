const bcrypt = require('bcryptjs');

const SALT_ROUNDS = 10;

/**
 * Hashes a plain-text password using bcrypt.
 * @param {string} password
 * @returns {Promise<string>}
 */
async function hashPassword(password) {
  if (!password || typeof password !== 'string') {
    throw new Error('Password must be a valid string');
  }
  return bcrypt.hash(password, SALT_ROUNDS);
}

/**
 * Compares a plain-text password against a hashed password.
 * @param {string} password
 * @param {string} hash
 * @returns {Promise<boolean>}
 */
async function comparePassword(password, hash) {
  if (!password || !hash) return false;
  return bcrypt.compare(password, hash);
}

module.exports = {
  hashPassword,
  comparePassword,
};
