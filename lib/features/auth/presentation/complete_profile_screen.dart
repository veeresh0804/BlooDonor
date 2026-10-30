import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../logic/auth_provider.dart';

/// For users who are signed in (OTP verified) but have no `users` row, e.g.
/// they tapped Login instead of Register. Previously they were sent back to
/// the login screen in a loop.
class CompleteProfileScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const CompleteProfileScreen({super.key, required this.onCompleted});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  UserRole? _role;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your role')),
      );
      return;
    }

    final email = _emailController.text.trim();
    final ok = await context.read<AuthProvider>().completeProfileForCurrentUser(
      name: _nameController.text.trim(),
      role: _role!,
      email: email.isEmpty ? null : email,
    );
    if (ok && mounted) widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return LoadingOverlay(
      isLoading: auth.isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finish setting up'),
          actions: [
            TextButton(
              onPressed: () => context.read<AuthProvider>().signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your phone is verified, but we have no profile for you yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (optional)',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('I am a…', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                // Only the two roles that have a UI are offered (ngo has none).
                RadioGroup<UserRole>(
                  groupValue: _role,
                  onChanged: (v) => setState(() => _role = v),
                  child: const Column(
                    children: [
                      RadioListTile<UserRole>(
                        title: Text('Blood donor'),
                        value: UserRole.donor,
                      ),
                      RadioListTile<UserRole>(
                        title: Text('Hospital'),
                        value: UserRole.hospital,
                      ),
                    ],
                  ),
                ),
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      auth.error!,
                      style: const TextStyle(color: AppColors.critical),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
