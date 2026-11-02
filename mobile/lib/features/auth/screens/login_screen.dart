import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/rr_text_field.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/app_logo.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_client.dart';

class LoginScreen extends StatefulWidget {
  final String? initialRole;

  const LoginScreen({super.key, this.initialRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late String _role;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _role = (widget.initialRole ?? 'CUSTOMER').toUpperCase();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await AuthService.login(
        identifier: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        expectedRole: _role,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final user = res['user'] as Map<String, dynamic>?;
      final actualRole = (user?['role'] as String? ?? '').toUpperCase();

      if (actualRole.isNotEmpty && actualRole != _role) {
        await AuthService.clearSession();
        if (!mounted) return;
        final actualName = _getRoleDisplayName(actualRole);
        final expectedName = _getRoleDisplayName(_role);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Access denied: This account is registered as $actualName. Please select $actualName to sign in instead of $expectedName.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      if (_role == 'PROVIDER') {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.provider, (r) => false);
      } else if (_role == 'ADMIN') {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.adminDashboard, (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.customer, (r) => false);
      }
    } on ApiException catch (e) {
      await AuthService.clearSession();
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      await AuthService.clearSession();
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please check your credentials and network.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toUpperCase()) {
      case 'PROVIDER':
        return 'Service Provider';
      case 'ADMIN':
        return 'Platform Admin';
      case 'CUSTOMER':
        return 'Vehicle User';
      default:
        return role;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProvider = _role == 'PROVIDER';
    final isAdmin = _role == 'ADMIN';
    final String roleLabel;
    final Color accentColor;
    final IconData roleIcon;

    if (isAdmin) {
      roleLabel = 'Platform Admin';
      accentColor = const Color(0xFF6366F1);
      roleIcon = Icons.admin_panel_settings_rounded;
    } else if (isProvider) {
      roleLabel = 'Service Provider';
      accentColor = AppColors.secondary;
      roleIcon = Icons.build_rounded;
    } else {
      roleLabel = 'Vehicle User';
      accentColor = AppColors.primary;
      roleIcon = Icons.directions_car_rounded;
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Back
                  const BackButton(),
                  const SizedBox(height: 16),
                  // Official RoadRescue Logo & Role Badge Header
                  Row(
                    children: [
                      const AppLogo.authHeader(
                        height: 52,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(roleIcon, color: accentColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome back 👋',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to your $roleLabel account',
                    style: const TextStyle(fontSize: 15, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(height: 32),
                  RRTextField(
                    label: 'Phone Number or Email',
                    hint: '9876543210 or user@example.com',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.text,
                    prefixIcon: Icons.person_outline_rounded,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter your phone or email';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  RRTextField(
                    label: 'Password',
                    controller: _passwordCtrl,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    validator: Validators.password,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RRButton(
                    label: 'Sign In',
                    onPressed: _login,
                    isLoading: _isLoading,
                    icon: Icons.login_rounded,
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 2,
                      children: [
                        const Text(
                          "Don't have an account?",
                          style: TextStyle(fontSize: 14),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.register,
                            arguments: {'role': _role},
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Register as $roleLabel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
