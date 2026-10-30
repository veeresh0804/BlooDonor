import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../config/constants/app_constants.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../core/utils/phone_utils.dart';
import '../logic/auth_provider.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) => validateIndianPhone(value);

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final phone = normalizeIndianPhone(_phoneController.text);

    final success = await authProvider.sendOtp(phone);
    if (success && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: authProvider.isLoading,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 60),

                  // Hero section
                  Icon(Icons.bloodtype, size: 80, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Every drop counts. Every life matters.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Phone input
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixText: '+91 ',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _validatePhone,
                  ),
                  const SizedBox(height: 8),

                  if (authProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        authProvider.error!,
                        style: const TextStyle(color: AppColors.critical),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Send OTP button
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _sendOtp,
                    child: const Text('Send OTP'),
                  ),
                  const SizedBox(height: 16),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text('Register'),
                      ),
                    ],
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
