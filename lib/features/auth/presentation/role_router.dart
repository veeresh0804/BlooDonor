import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../donor/presentation/donor_home.dart';
import '../../hospital/presentation/hospital_home.dart';
import '../../notifications/logic/notification_provider.dart';
import '../logic/auth_provider.dart';
import 'complete_profile_screen.dart';

/// Shown once a session exists. Resolves the user's role and routes:
///   role found       -> that role's home (and arms push notifications)
///   no profile row   -> CompleteProfileScreen (instead of bouncing to Login)
///   lookup failed    -> retry screen (instead of pretending there's no profile)
class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  late Future<UserRole?> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = context.read<AuthProvider>().getUserRole();
  }

  void _reload() {
    setState(() {
      _roleFuture = context.read<AuthProvider>().getUserRole();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserRole?>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    const Text(
                      "We couldn't load your account.",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check your connection and try again.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(onPressed: _reload, child: const Text('Retry')),
                    TextButton(
                      onPressed: () => context.read<AuthProvider>().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final role = snapshot.data;
        if (role == null) {
          return CompleteProfileScreen(onCompleted: _reload);
        }

        // Arm FCM now that we know who is signed in. initialize() is
        // idempotent and attempts at most once per app session.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.read<NotificationProvider>().initialize();
        });

        return switch (role) {
          UserRole.hospital => const HospitalHome(),
          UserRole.donor => const DonorHome(),
          // No UI exists for ngo yet; it has always routed to the donor home.
          UserRole.ngo => const DonorHome(),
        };
      },
    );
  }
}
