import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/rr_button.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrlList = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusList = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendSeconds = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void _resend() {
    setState(() => _resendSeconds = 30);
    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP sent!')),
    );
  }

  String get _otp => _ctrlList.map((c) => c.text).join();

  void _verify() async {
    if (_otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit OTP')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.roleSelect, (r) => false);
  }

  @override
  void dispose() {
    for (final c in _ctrlList) {
      c.dispose();
    }
    for (final f in _focusList) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone = widget.phone.length >= 7
        ? '${widget.phone.substring(0, 3)}XXXX${widget.phone.substring(widget.phone.length - 3)}'
        : widget.phone;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_android_rounded, size: 36, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Verify Phone',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Enter the 6-digit OTP sent to\n+91 $maskedPhone',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondaryLight, height: 1.5),
                ),
              ),
              const SizedBox(height: 40),
              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    height: 56,
                    child: TextFormField(
                      controller: _ctrlList[i],
                      focusNode: _focusList[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.dividerLight),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) {
                          _focusList[i + 1].requestFocus();
                        } else if (v.isEmpty && i > 0) {
                          _focusList[i - 1].requestFocus();
                        }
                        setState(() {});
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              RRButton(label: 'Verify OTP', onPressed: _verify, isLoading: _isLoading),
              const SizedBox(height: 20),
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend OTP in ${_resendSeconds}s',
                        style: const TextStyle(color: AppColors.textSecondaryLight),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('Resend OTP', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
