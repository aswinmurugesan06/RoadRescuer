module.exports = {
  secret: process.env.JWT_SECRET || 'roadrescue_dev_fallback_secret_key_32chars',
  expiresIn: process.env.JWT_EXPIRES_IN || '7d',
};
