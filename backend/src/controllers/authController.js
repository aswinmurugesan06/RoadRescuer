const authService = require('../services/authService');

class AuthController {
  async register(req, res, next) {
    try {
      const result = await authService.register(req.body);
      return res.status(201).json({
        status: 'success',
        message: 'User registered successfully',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async login(req, res, next) {
    try {
      const result = await authService.login(req.body);
      return res.status(200).json({
        status: 'success',
        message: 'Login successful',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async sendOtp(req, res, next) {
    try {
      const result = await authService.sendOtp(req.body);
      return res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }

  async verifyOtp(req, res, next) {
    try {
      const result = await authService.verifyOtp(req.body);
      return res.status(200).json({
        status: 'success',
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async forgotPassword(req, res, next) {
    try {
      const result = await authService.forgotPassword(req.body);
      return res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }

  async resetPassword(req, res, next) {
    try {
      const result = await authService.resetPassword(req.body);
      return res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }

  async getMe(req, res, next) {
    try {
      const userRepository = require('../services/userRepository');
      const user = await userRepository.findById(req.user.userId);
      if (!user) {
        return res.status(404).json({
          status: 'error',
          message: 'User not found',
        });
      }
      return res.status(200).json({
        status: 'success',
        data: {
          user: authService.sanitizeUser(user),
        },
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();
