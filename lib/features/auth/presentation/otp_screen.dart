import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../logic/auth_provider.dart';

class OtpScreen extends StatefulWidget {
  final String phone;

  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyOtp(_otpController.text.trim());

    if (success && mounted) {
      // AuthGate decides what to show next: the role's home, or the
      // "finish setting up" screen if this account has no profile yet.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: authProvider.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Verify OTP')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                Text(
                  'Enter the 6-digit code sent to',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.phone,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '------',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter OTP';
                    if (value.length != 6) return 'OTP must be 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                if (authProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      authProvider.error!,
                      style: const TextStyle(color: AppColors.critical),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: authProvider.isLoading ? null : _verifyOtp,
                  child: const Text('Verify'),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () => authProvider.sendOtp(widget.phone),
                  child: const Text('Resend OTP'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
