const { verifyToken } = require('../utils/jwt');

/**
 * Middleware to authenticate requests using Bearer JWT.
 */
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({
      status: 'error',
      message: 'Access denied: No authorization header provided',
    });
  }

  const parts = authHeader.split(' ');
  if (parts.length !== 2 || parts[0] !== 'Bearer') {
    return res.status(401).json({
      status: 'error',
      message: 'Access denied: Invalid authorization header format. Expected "Bearer <token>"',
    });
  }

  const token = parts[1];

  try {
    const decoded = verifyToken(token);
    req.user = decoded; // { userId, role, email? }
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        status: 'error',
        message: 'Authentication token has expired. Please log in again.',
      });
    }
    return res.status(401).json({
      status: 'error',
      message: 'Invalid authentication token',
    });
  }
}

/**
 * Middleware factory to enforce required role(s).
 * @param  {...string} allowedRoles (e.g. 'CUSTOMER', 'PROVIDER', 'ADMIN')
 */
function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !req.user.role) {
      return res.status(401).json({
        status: 'error',
        message: 'Authentication required before checking role permissions',
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        status: 'error',
        message: `Forbidden: Access restricted to [${allowedRoles.join(', ')}]. Your role is ${req.user.role}.`,
      });
    }

    next();
  };
}

module.exports = {
  authenticateToken,
  requireRole,
};
