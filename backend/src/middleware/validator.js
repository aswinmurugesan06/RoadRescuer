/**
 * Input validation helpers and middleware for authentication routes.
 */

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MOBILE_REGEX = /^[6-9]\d{9}$/; // Standard 10-digit Indian mobile number

function validateRegister(req, res, next) {
  const { name, mobile, email, password, confirmPassword, role, providerCategory, category } = req.body;
  const errors = [];

  // Name
  if (!name || typeof name !== 'string' || name.trim().length < 2) {
    errors.push('Name must be at least 2 characters long');
  }

  // Mobile
  const cleanMobile = mobile ? String(mobile).replace(/\D/g, '').slice(-10) : '';
  if (!cleanMobile || !MOBILE_REGEX.test(cleanMobile)) {
    errors.push('Mobile must be a valid 10-digit mobile number');
  } else {
    req.body.mobile = cleanMobile;
  }

  // Email
  if (!email || typeof email !== 'string' || !EMAIL_REGEX.test(email.trim().toLowerCase())) {
    errors.push('A valid email address is required');
  } else {
    req.body.email = email.trim().toLowerCase();
  }

  // Password
  if (!password || typeof password !== 'string' || password.length < 6) {
    errors.push('Password must be at least 6 characters long');
  }

  // Confirm Password
  if (password !== confirmPassword) {
    errors.push('Password and confirm password do not match');
  }

  // Role validation
  const validRoles = ['CUSTOMER', 'PROVIDER', 'ADMIN'];
  const userRole = role ? String(role).toUpperCase() : 'CUSTOMER';
  if (!validRoles.includes(userRole)) {
    errors.push(`Role must be one of: ${validRoles.join(', ')}`);
  } else {
    req.body.role = userRole;
  }

  // Provider category if role is PROVIDER
  const rawCat = providerCategory || category;
  if (userRole === 'PROVIDER' && rawCat) {
    const validCategories = ['MECHANIC', 'PUNCTURE', 'TOW_TRUCK', 'BATTERY', 'FUEL'];
    let cat = String(rawCat).toUpperCase();
    if (cat === 'TOW') cat = 'TOW_TRUCK';
    if (!validCategories.includes(cat)) {
      errors.push(`Provider category must be one of: ${validCategories.join(', ')}`);
    } else {
      req.body.providerCategory = cat;
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({
      status: 'error',
      message: 'Validation failed',
      errors,
    });
  }

  next();
}

function validateLogin(req, res, next) {
  const { identifier, email, mobile, password } = req.body;
  const loginId = identifier || email || mobile;

  if (!loginId || typeof loginId !== 'string' || loginId.trim() === '') {
    return res.status(400).json({
      status: 'error',
      message: 'Email or mobile number is required for login',
    });
  }

  if (!password || typeof password !== 'string') {
    return res.status(400).json({
      status: 'error',
      message: 'Password is required',
    });
  }

  req.body.loginIdentifier = loginId.trim();

  if (req.body.expectedRole) {
    const validRoles = ['CUSTOMER', 'PROVIDER', 'ADMIN'];
    const expected = String(req.body.expectedRole).trim().toUpperCase();
    if (!validRoles.includes(expected)) {
      return res.status(400).json({
        status: 'error',
        message: `expectedRole must be one of: ${validRoles.join(', ')}`,
      });
    }
    req.body.expectedRole = expected;
  }

  next();
}

function validateSendOtp(req, res, next) {
  const { identifier, purpose } = req.body;

  if (!identifier || typeof identifier !== 'string' || identifier.trim() === '') {
    return res.status(400).json({
      status: 'error',
      message: 'Identifier (mobile or email) is required',
    });
  }

  const validPurposes = ['REGISTRATION', 'LOGIN', 'PASSWORD_RESET', 'SERVICE_VERIFICATION'];
  const otpPurpose = purpose ? String(purpose).toUpperCase() : 'LOGIN';
  if (!validPurposes.includes(otpPurpose)) {
    return res.status(400).json({
      status: 'error',
      message: `OTP purpose must be one of: ${validPurposes.join(', ')}`,
    });
  }

  req.body.identifier = identifier.trim();
  req.body.purpose = otpPurpose;
  next();
}

function validateVerifyOtp(req, res, next) {
  const { identifier, otp, purpose } = req.body;

  if (!identifier || !otp) {
    return res.status(400).json({
      status: 'error',
      message: 'Both identifier and OTP are required',
    });
  }

  req.body.identifier = String(identifier).trim();
  req.body.otp = String(otp).trim();
  req.body.purpose = purpose ? String(purpose).toUpperCase() : 'LOGIN';
  next();
}

function validateForgotPassword(req, res, next) {
  const { identifier, email, mobile } = req.body;
  const id = identifier || email || mobile;

  if (!id || typeof id !== 'string' || id.trim() === '') {
    return res.status(400).json({
      status: 'error',
      message: 'Email or mobile is required to request password reset',
    });
  }

  req.body.identifier = id.trim();
  next();
}

function validateResetPassword(req, res, next) {
  const { identifier, otp, newPassword, confirmPassword } = req.body;

  if (!identifier || !otp || !newPassword) {
    return res.status(400).json({
      status: 'error',
      message: 'Identifier, OTP, and new password are required',
    });
  }

  if (newPassword.length < 6) {
    return res.status(400).json({
      status: 'error',
      message: 'New password must be at least 6 characters long',
    });
  }

  if (confirmPassword && newPassword !== confirmPassword) {
    return res.status(400).json({
      status: 'error',
      message: 'New password and confirmation do not match',
    });
  }

  req.body.identifier = String(identifier).trim();
  req.body.otp = String(otp).trim();
  next();
}

function validateCreateServiceRequest(req, res, next) {
  const {
    serviceType,
    problemDescription,
    customerLatitude,
    customerLongitude,
    vehiclePlate,
    vehicleModel,
    category,
  } = req.body;
  const errors = [];

  // Service Type
  if (!serviceType || typeof serviceType !== 'string' || serviceType.trim().length < 2) {
    errors.push('serviceType is required (e.g., Mechanical Repair, Tyre & Puncture, Tow Truck)');
  }

  // Problem Description
  if (!problemDescription || typeof problemDescription !== 'string' || problemDescription.trim().length < 3) {
    errors.push('problemDescription is required and must describe the issue (minimum 3 characters)');
  }

  // Coordinates
  const lat = parseFloat(customerLatitude);
  if (customerLatitude === undefined || customerLatitude === null || isNaN(lat) || lat < -90 || lat > 90) {
    errors.push('customerLatitude must be a valid latitude between -90 and 90');
  }

  const lng = parseFloat(customerLongitude);
  if (customerLongitude === undefined || customerLongitude === null || isNaN(lng) || lng < -180 || lng > 180) {
    errors.push('customerLongitude must be a valid longitude between -180 and 180');
  }

  // Vehicle info (can be auto-populated from vehicleId if provided)
  if (!req.body.vehicleId) {
    if (!vehiclePlate || typeof vehiclePlate !== 'string' || vehiclePlate.trim().length < 2) {
      errors.push('vehiclePlate is required (e.g. TN-01-AB-1234)');
    }

    if (!vehicleModel || typeof vehicleModel !== 'string' || vehicleModel.trim().length < 2) {
      errors.push('vehicleModel is required (e.g. Tata Prima, Ashok Leyland)');
    }
  }

  // Category if explicitly supplied
  if (category) {
    const validCategories = ['MECHANIC', 'PUNCTURE', 'TOW_TRUCK', 'BATTERY', 'FUEL'];
    let cat = String(category).toUpperCase();
    if (cat === 'TOW') cat = 'TOW_TRUCK';
    if (!validCategories.includes(cat)) {
      errors.push(`category must be one of: ${validCategories.join(', ')}`);
    } else {
      req.body.category = cat;
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({
      status: 'error',
      message: 'Validation failed',
      errors,
    });
  }

  req.body.customerLatitude = lat;
  req.body.customerLongitude = lng;
  next();
}

module.exports = {
  validateRegister,
  validateLogin,
  validateSendOtp,
  validateVerifyOtp,
  validateForgotPassword,
  validateResetPassword,
  validateCreateServiceRequest,
};
