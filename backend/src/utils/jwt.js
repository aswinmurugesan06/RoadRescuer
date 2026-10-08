const jwt = require('jsonwebtoken');
const { secret, expiresIn } = require('../config/jwt');

/**
 * Generates a signed JWT with minimal required identity information.
 * @param {Object} payload
 * @param {string} payload.userId
 * @param {string} payload.role
 * @param {string} [payload.email]
 * @returns {string}
 */
function generateToken(payload) {
  const sanitized = {
    userId: payload.userId,
    role: payload.role,
  };
  if (payload.email) sanitized.email = payload.email;

  return jwt.sign(sanitized, secret, { expiresIn });
}

/**
 * Verifies a JWT token and returns decoded payload.
 * @param {string} token
 * @returns {Object}
 */
function verifyToken(token) {
  return jwt.verify(token, secret);
}

module.exports = {
  generateToken,
  verifyToken,
};
