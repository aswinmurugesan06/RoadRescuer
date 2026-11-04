import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../routes/app_routes.dart';
import '../../../services/api_client.dart';
import '../../../services/auth_service.dart';
import '../../../services/phone_service.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/glass.dart';
import '../../../widgets/google_logo.dart';

// Design tokens mirrored from the RoadRescue auth mockup.
const Color _surfaceContainer = Color(0xFFE9EDFF);
const Color _surfaceContainerLow = Color(0xFFF2F3FF);
const Color _surfaceContainerHigh = Color(0xFFE1E8FF);
const Color _outlineVariant = Color(0xFFC3C5D9);
const Color _onSurfaceVariant = Color(0xFF434656);
const Color _primaryFixed = Color(0xFFDCE1FF);
const Color _onPrimaryFixed = Color(0xFF001550);
const Color _secondaryContainer = Color(0xFFFE5D35);
const Color _onSecondaryContainer = Color(0xFF5A0F00);
const Color _secondaryText = Color(0xFFB42901);

class LoginScreen extends StatefulWidget {
  final String? initialRole;

  const LoginScreen({super.key, this.initialRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late String _role;
  bool _isEmailMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _googleLoading = false;

  bool get _isProvider => _role == 'PROVIDER';

  String get _heading => _isProvider ? 'Fleet Dispatch Sign-In' : 'Welcome back';

  String get _subheading => _isProvider
      ? 'Authorized technician telemetry & route mission terminal'
      : 'Sign in to access emergency dispatch & vehicle telemetry protection';

  String get _roleQuery => _isProvider ? 'PROVIDER' : 'CUSTOMER';

  @override
  void initState() {
    super.initState();
    _role = (widget.initialRole ?? 'CUSTOMER').toUpperCase();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : AppColors.primary,
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final res = await AuthService.login(
        identifier: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: _role,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      final user = res['user'] as Map<String, dynamic>?;
      final role = (user?['role'] as String? ?? _role).toUpperCase();

      if (role == 'ADMIN') {
        await AuthService.clearSession();
        if (!mounted) return;
        _showMessage(
          'Admin access is available on the RoadRescue web admin dashboard.',
          error: true,
        );
        return;
      }

      if (role == 'PROVIDER') {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.provider, (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.customer, (r) => false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        'Login failed. Please check your credentials and network.',
        error: true,
      );
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    try {
      final res = await AuthService.signInWithGoogle(role: _role);
      if (!mounted) return;
      final user = res['user'] as Map<String, dynamic>?;
      final role = (user?['role'] as String? ?? _role).toUpperCase();

      if (role == 'ADMIN') {
        await AuthService.clearSession();
        if (!mounted) return;
        _showMessage(
          'Admin access is available on the RoadRescue web admin dashboard.',
          error: true,
        );
        return;
      }

      if (role == 'PROVIDER') {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.provider, (r) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.customer, (r) => false);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, error: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Google sign-in failed. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEmailMode) {
      final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
      Navigator.pushNamed(
        context,
        AppRoutes.otp,
        arguments: {'phone': phone},
      );
      return;
    }

    _login();
  }

  Future<void> _showEmergencyDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.crisis_alert_rounded,
                color: _secondaryContainer, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Emergency SOS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          'For immediate danger, call 112. For roadside dispatch, continue with '
          'Google or OTP sign-in so we can verify you and send the nearest team.',
          style: TextStyle(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final opened = await PhoneService.call('112');
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!opened) {
                _showMessage('Could not open the phone dialer.', error: true);
              }
            },
            child: const Text('Call 112'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _googleSignIn();
            },
            child: const Text('Google Sign-In'),
          ),
        ],
      ),
    );
  }

  void _showInfo(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: GlassBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          MediaQuery.of(context).viewInsets.bottom + 28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildTopBar(context),
                            const SizedBox(height: 18),
                            _buildBrandHeader(),
                            const SizedBox(height: 20),
                            _buildRoleToggle(),
                            const SizedBox(height: 18),
                            _buildAuthCard(),
                            const SizedBox(height: 18),
                            _buildSosCallout(),
                            const SizedBox(height: 18),
                            _buildTrustFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Top status pill ───────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Navigator.canPop(context)
                ? _roundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.maybePop(context),
                  )
                : const SizedBox(width: 36, height: 36),
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _surfaceContainer.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PulseDot(),
                    const SizedBox(width: 7),
                    const Text(
                      'NETWORK ACTIVE',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '  •  ',
                      style: TextStyle(
                        fontSize: 8.5,
                        color: _outlineVariant.withValues(alpha: 0.9),
                      ),
                    ),
                    const Text(
                      'AVG. 11.4 MIN ARRIVAL',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: _onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.75),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 18, color: AppColors.textPrimaryLight),
        ),
      ),
    );
  }

  // ── Brand header ──────────────────────────────────────────────────────

  Widget _buildBrandHeader() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.26),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const AppLogo.appBar(
                width: 58,
                height: 58,
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  color: _secondaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _secondaryContainer.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'RoadRescue',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _primaryFixed,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: _onPrimaryFixed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Instant Roadside Assistance & Fleet Telemetry',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  // ── Role segmented toggle ─────────────────────────────────────────────

  Widget _buildRoleToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _roleButton(
              label: 'Vehicle Driver',
              icon: Icons.directions_car_filled_rounded,
              value: 'CUSTOMER',
            ),
          ),
          Expanded(
            child: _roleButton(
              label: 'Service Tech',
              icon: Icons.build_rounded,
              value: 'PROVIDER',
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleButton({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 40,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? AppColors.primary : _onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? AppColors.primary : _onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Auth card ─────────────────────────────────────────────────────────

  Widget _buildAuthCard() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      color: Colors.white.withValues(alpha: 0.84),
      borderColor: Colors.white.withValues(alpha: 0.92),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _heading,
              style: const TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _subheading,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            _buildOAuthGrid(),
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 14),
            _buildInputHeader(),
            const SizedBox(height: 8),
            _buildIdentifierField(),
            if (_isEmailMode) ...[
              const SizedBox(height: 10),
              _buildPasswordField(),
            ],
            const SizedBox(height: 11),
            _buildSecurityRow(),
            const SizedBox(height: 16),
            _buildPrimaryCta(),
            const SizedBox(height: 10),
            _buildBiometricButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildOAuthGrid() {
    return Row(
      children: [
        Expanded(
          child: _oauthButton(
            label: 'Apple',
            leading: const Icon(
              Icons.apple,
              size: 20,
              color: AppColors.textPrimaryLight,
            ),
            onTap: () => _showMessage(
              'Apple sign-in is coming soon. Use Google or phone/email for now.',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _oauthButton(
            label: 'Google',
            leading: _googleLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const GoogleLogo(size: 18),
            onTap: _googleLoading ? null : _googleSignIn,
          ),
        ),
      ],
    );
  }

  Widget _oauthButton({
    required String label,
    required Widget leading,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: _surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: _surfaceContainerHigh),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'or phone / email',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: AppColors.textHintLight.withValues(alpha: 0.95),
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: _surfaceContainerHigh),
        ),
      ],
    );
  }

  Widget _buildInputHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _isEmailMode ? 'Fleet / Driver Email' : 'Mobile Number',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryLight,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() {
            _isEmailMode = !_isEmailMode;
            _formKey.currentState?.reset();
          }),
          child: Text(
            _isEmailMode ? 'Use Phone Instead' : 'Use Email Instead',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentifierField() {
    if (_isEmailMode) {
      return TextFormField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        validator: Validators.email,
        decoration: _fieldDecoration(
          hint: 'driver@roadrescue.io',
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: AppColors.textHintLight,
            ),
          ),
        ),
      );
    }

    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: Validators.phone,
      onChanged: (_) => setState(() {}),
      decoration: _fieldDecoration(
        hint: '98765 43210',
        prefix: Padding(
          padding: const EdgeInsets.only(left: 12, right: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '+91',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 17, color: _outlineVariant),
            ],
          ),
        ),
        suffix: digits.length == 10
            ? const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppColors.primary,
              )
            : null,
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordCtrl,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.password],
      validator: Validators.password,
      onFieldSubmitted: (_) => _login(),
      decoration: _fieldDecoration(
        hint: 'Enter your password',
        prefix: const Padding(
          padding: EdgeInsets.only(left: 12, right: 8),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: AppColors.textHintLight,
          ),
        ),
        suffix: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          splashRadius: 18,
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: AppColors.textHintLight,
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 12.5,
        color: AppColors.textHintLight,
      ),
      prefixIcon: prefix,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      isDense: true,
      filled: true,
      fillColor: _surfaceContainerLow,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.white.withValues(alpha: 0.9)),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger, 1.5),
      errorStyle: const TextStyle(fontSize: 10.5, color: AppColors.danger),
    );
  }

  Widget _buildSecurityRow() {
    return Row(
      children: [
        Icon(
          _isEmailMode
              ? Icons.lock_outline_rounded
              : Icons.security_update_good_rounded,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _isEmailMode
                ? 'Encrypted Firebase password sign-in'
                : 'Passwordless 6-digit OTP verification',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: _onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isEmailMode
              ? () => Navigator.pushNamed(context, AppRoutes.forgotPassword)
              : () => setState(() {
                    _isEmailMode = true;
                    _formKey.currentState?.reset();
                  }),
          child: Text(
            _isEmailMode ? 'Forgot?' : 'Use PIN',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryCta() {
    final label = _isEmailMode
        ? 'Sign In Securely'
        : 'Get Instant Verification Code';
    final busy = _isLoading || _googleLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: busy ? null : _submit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.1,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton() {
    return Material(
      color: _surfaceContainerHigh.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMessage(
          'Biometric fast pass is not set up on this device yet. Use Google or OTP sign-in.',
        ),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fingerprint_rounded,
                  size: 20, color: AppColors.primary),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Face ID / Touch ID Fast Pass',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SOS callout ───────────────────────────────────────────────────────

  Widget _buildSosCallout() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _secondaryContainer.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _secondaryContainer.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: _secondaryContainer.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _secondaryContainer,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: _secondaryContainer.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.crisis_alert_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Stranded right now?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: _secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: _onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Immediate highway tow, tire blowout, or hazard dispatch without signing in.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.35,
                    color: _onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: _secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _showEmergencyDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Skip Login & Request Emergency Tow',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Trust + footer ────────────────────────────────────────────────────

  Widget _buildTrustFooter() {
    return Column(
      children: [
        const Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            _TrustBadge(
              icon: Icons.lock_outline_rounded,
              label: '256-Bit TLS Protected',
            ),
            _TrustBadge(
              icon: Icons.verified_user_outlined,
              label: 'Verified & Insured Partners',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'New to RoadRescue?',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondaryLight,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(
                context,
                AppRoutes.register,
                arguments: {'role': _roleQuery},
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Create an account',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            _footerLink(
              'Terms of Dispatch',
              () => _showInfo(
                'Terms of Dispatch',
                'RoadRescue dispatches independent, verified service partners. '
                    'Callout fees are shown before you confirm a request.',
              ),
            ),
            const Text('•',
                style: TextStyle(fontSize: 8, color: _outlineVariant)),
            _footerLink(
              'Privacy Policy',
              () => _showInfo(
                'Privacy Policy',
                'Your location and contact details are used only to route the '
                    'nearest provider and are protected with Firebase security rules.',
              ),
            ),
            const Text('•',
                style: TextStyle(fontSize: 8, color: _outlineVariant)),
            _footerLink(
              'Enterprise Fleet SSO',
              () => _showInfo(
                'Enterprise Fleet SSO',
                'Fleet SSO is available on the RoadRescue business plan. '
                    'Contact support to connect your identity provider.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w500,
          color: AppColors.textHintLight,
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 6.5,
            height: 6.5,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textHintLight,
          ),
        ),
      ],
    );
  }
}
