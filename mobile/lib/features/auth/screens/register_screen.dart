import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/rr_text_field.dart';
import '../../../widgets/rr_button.dart';
import '../../../widgets/app_logo.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_client.dart';

class RegisterScreen extends StatefulWidget {
  final String? initialRole;

  const RegisterScreen({super.key, this.initialRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _garageNameCtrl = TextEditingController();
  bool _isLoading = false;
  bool _googleLoading = false;
  late String _role;
  String _category = 'MECHANIC';

  @override
  void initState() {
    super.initState();
    final init = (widget.initialRole ?? 'customer').toLowerCase();
    _role = (init == 'provider' || init == 'service provider')
        ? 'provider'
        : 'customer';
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final isProvider = _role == 'provider';
      final targetRole = isProvider ? 'PROVIDER' : 'CUSTOMER';

      final res = await AuthService.register(
        name: _nameCtrl.text.trim(),
        mobile: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmCtrl.text,
        role: targetRole,
        category: isProvider ? _category : null,
        garageName: isProvider && _garageNameCtrl.text.trim().isNotEmpty
            ? _garageNameCtrl.text.trim()
            : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final user = res['user'] as Map<String, dynamic>?;
      final role = (user?['role'] as String? ?? targetRole).toUpperCase();

      if (role == 'PROVIDER') {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.provider, (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.customer, (r) => false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration failed. Please check your details and connection.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _googleSignUp() async {
    setState(() => _googleLoading = true);
    try {
      final isProvider = _role == 'provider';
      final targetRole = isProvider ? 'PROVIDER' : 'CUSTOMER';
      final res = await AuthService.signInWithGoogle(
        role: targetRole,
        mobile: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        providerCategory: isProvider ? _category : null,
        garageName: isProvider && _garageNameCtrl.text.trim().isNotEmpty
            ? _garageNameCtrl.text.trim()
            : null,
      );

      if (!mounted) return;
      final user = res['user'] as Map<String, dynamic>?;
      final role = (user?['role'] as String? ?? targetRole).toUpperCase();

      if (role == 'PROVIDER') {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.provider, (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.customer, (r) => false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-up failed: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _garageNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isProvider = _role == 'provider';
    final String title;
    final String subtitle;
    final Color accentColor;
    final String roleLabel;

    if (isProvider) {
      title = 'Create Provider Account';
      subtitle = 'Join RoadRescue as a verified service partner';
      accentColor = AppColors.secondary;
      roleLabel = 'Service Provider';
    } else {
      title = 'Create Customer Account';
      subtitle = 'Join RoadRescue for fast 24/7 roadside assistance';
      accentColor = AppColors.primary;
      roleLabel = 'Vehicle User';
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
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
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondaryLight),
                ),
                const SizedBox(height: 28),
                // Role selector
                const Text('Account Type:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RoleOption(
                        label: 'Vehicle User',
                        icon: '🚛',
                        selected: _role == 'customer',
                        activeColor: AppColors.primary,
                        onTap: () => setState(() => _role = 'customer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RoleOption(
                        label: 'Service Provider',
                        icon: '🔧',
                        selected: _role == 'provider',
                        activeColor: AppColors.secondary,
                        onTap: () => setState(() => _role = 'provider'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                RRTextField(
                  label: isProvider
                      ? 'Contact Person / Owner Name'
                      : 'Full Name',
                  prefixIcon: Icons.person_outline_rounded,
                  controller: _nameCtrl,
                  validator: Validators.name,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RRTextField(
                  label: 'Phone Number',
                  hint: '9876543210',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: Validators.phone,
                  textInputAction: TextInputAction.next,
                  maxLength: 10,
                ),
                const SizedBox(height: 16),
                RRTextField(
                  label: 'Email Address',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: Validators.email,
                  textInputAction: TextInputAction.next,
                ),
                if (isProvider) ...[
                  const SizedBox(height: 16),
                  RRTextField(
                    label: 'Garage / Service Center Name',
                    controller: _garageNameCtrl,
                    prefixIcon: Icons.storefront_rounded,
                    hint: 'e.g. Metro Auto Recovery Garage',
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your garage or service center name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: 'Primary Service Capability',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MECHANIC', child: Text('Mechanic Service')),
                      DropdownMenuItem(value: 'PUNCTURE', child: Text('Tyre & Puncture Service')),
                      DropdownMenuItem(value: 'TOW_TRUCK', child: Text('Tow Truck / Recovery')),
                      DropdownMenuItem(value: 'BATTERY', child: Text('Battery Jump-Start Service')),
                      DropdownMenuItem(value: 'FUEL', child: Text('Emergency Fuel Delivery')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ],
                const SizedBox(height: 16),
                RRTextField(
                  label: 'Password',
                  controller: _passwordCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: Validators.password,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                RRTextField(
                  label: 'Confirm Password',
                  controller: _confirmCtrl,
                  obscureText: true,
                  prefixIcon: Icons.lock_outline_rounded,
                  validator: (v) => Validators.confirmPassword(v, _passwordCtrl.text),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                ),
                const SizedBox(height: 8),
                Text(
                  'By registering you agree to our Terms & Privacy Policy.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 24),
                RRButton(
                  label: isProvider ? 'Register as Provider' : 'Create Account',
                  onPressed: _register,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _googleLoading ? null : _googleSignUp,
                    icon: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Center(
                        child: Text(
                          'G',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF4285F4),
                          ),
                        ),
                      ),
                    ),
                    label: Text(
                      _googleLoading
                          ? 'Connecting to Google…'
                          : 'Sign up with Google',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimaryLight,
                      side: const BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 2,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.login,
                          arguments: {'role': _role.toUpperCase()},
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Sign In as $roleLabel',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: accentColor,
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
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final String icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : AppColors.dividerLight,
            width: selected ? 2 : 1,
          ),
          color: selected ? activeColor.withOpacity(0.06) : Colors.white,
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? activeColor : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
