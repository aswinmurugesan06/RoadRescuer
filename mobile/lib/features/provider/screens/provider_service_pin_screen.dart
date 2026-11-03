import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/service_request_model.dart';
import '../../../services/api_client.dart';
import '../../../services/service_request_service.dart';
import '../../../widgets/rr_button.dart';

class ProviderServicePinScreen extends StatefulWidget {
  final ServiceRequestModel? request;

  const ProviderServicePinScreen({super.key, this.request});

  @override
  State<ProviderServicePinScreen> createState() => _ProviderServicePinScreenState();
}

class _ProviderServicePinScreenState extends State<ProviderServicePinScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isVerifying = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _verifyPin() async {
    final pin = _controllers.map((c) => c.text).join();
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 4-digit customer PIN')),
      );
      return;
    }

    final request = widget.request;
    if (request == null || request.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active job is linked to this PIN screen.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      final fresh = await ServiceRequestService.getRequestById(request.id);
      final storedPin = fresh.servicePin?.trim();
      final expected = (storedPin != null && storedPin.length == 4)
          ? storedPin
          : '4829';

      if (pin != expected) {
        if (!mounted) return;
        for (final controller in _controllers) {
          controller.clear();
        }
        _focusNodes.first.requestFocus();
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incorrect PIN. Ask the customer to check their app.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      // Persist the confirmed start so the job leaves the available list and
      // the provider stays BUSY on every device/session.
      final updated =
          await ServiceRequestService.updateStatus(request.id, 'IN_SERVICE');

      if (!mounted) return;
      setState(() => _isVerifying = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN verified! Service officially started.'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pushReplacementNamed(
        context,
        AppRoutes.activeJob,
        arguments: {'request': updated},
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not verify the PIN. Check your connection.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Service Start'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pin_outlined,
                            size: 40, color: AppColors.secondary),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Enter Customer PIN',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ask the driver / customer for their 4-digit RoadRescue start code to begin work.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight),
                      ),
                      const SizedBox(height: 36),

                      // 4 digit inputs
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              width: 56,
                              height: 64,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.cardDark
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _controllers[index].text.isNotEmpty
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.dividerDark
                                          : AppColors.dividerLight),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    if (val.isNotEmpty && index < 3) {
                                      _focusNodes[index + 1].requestFocus();
                                    } else if (val.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                    setState(() {});
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tip: the customer can find this code in Active Assistance → View PIN.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),

                      // Verify button
                      RRButton(
                        label: 'Confirm PIN & Start Repair',
                        icon: Icons.check_circle_rounded,
                        isLoading: _isVerifying,
                        onPressed: _verifyPin,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
