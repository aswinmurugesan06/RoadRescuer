import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/rr_text_field.dart';
import '../../../widgets/rr_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushNamed(context, AppRoutes.otp, arguments: {'phone': _phoneCtrl.text});
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const BackButton(),
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded, size: 36, color: AppColors.warning),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Enter your registered phone number.\nWe\'ll send you an OTP to reset your password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight, height: 1.5),
                  ),
                ),
                const SizedBox(height: 40),
                RRTextField(
                  label: 'Phone Number',
                  hint: '9876543210',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: Validators.phone,
                  maxLength: 10,
                ),
                const SizedBox(height: 28),
                RRButton(label: 'Send OTP', onPressed: _sendOtp, isLoading: _isLoading),
                const SizedBox(height: 20),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reset Password Screen ─────────────────────────────────────────────
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;

  void _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset successfully!')),
    );
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (r) => false);
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const BackButton(),
                const SizedBox(height: 32),
                const Text(
                  'Reset Password',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create a new password for your account',
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 36),
                RRTextField(
                  label: 'New Password',
                  controller: _passwordCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: Validators.password,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RRTextField(
                  label: 'Confirm New Password',
                  controller: _confirmCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _reset(),
                ),
                const SizedBox(height: 28),
                RRButton(label: 'Reset Password', onPressed: _reset, isLoading: _isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
