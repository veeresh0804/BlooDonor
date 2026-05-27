import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/enums.dart';
import '../../../config/theme/app_theme.dart';
import '../../../core/utils/seed_data.dart';
import '../logic/auth_provider.dart';
import '../logic/demo_provider.dart';
import 'login_screen.dart';
import '../../hospital/presentation/hospital_home.dart';
import '../../donor/presentation/donor_home.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if Supabase is initialized
    bool supabaseReady = false;
    try {
      Supabase.instance.client;
      supabaseReady = true;
    } catch (_) {
      supabaseReady = false;
    }

    if (!supabaseReady) {
      return const _DemoModeScreen();
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          return const LoginScreen();
        }

        // User is authenticated — check role for routing
        return FutureBuilder<UserRole?>(
          future: context.read<AuthProvider>().getUserRole(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnapshot.data;

            if (role == null) {
              return const LoginScreen();
            }

            return switch (role) {
              UserRole.hospital => const HospitalHome(),
              UserRole.donor => const DonorHome(),
              UserRole.ngo => const DonorHome(),
            };
          },
        );
      },
    );
  }
}

/// Demo mode screen — lets you explore the app without Supabase
class _DemoModeScreen extends StatelessWidget {
  const _DemoModeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bloodtype,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'BlooDonor',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Every drop counts. Every life matters.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 40),

                // Demo mode badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.urgent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.urgent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science, size: 16, color: AppColors.urgent),
                      SizedBox(width: 6),
                      Text(
                        'DEMO MODE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 12,
                          color: AppColors.urgent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Supabase not configured.\nExplore the full app UI below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                // Hospital demo button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Load demo data into providers
                      context.read<DemoProvider>().enterDemoMode(
                            role: UserRole.hospital,
                          );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const HospitalHome()),
                      );
                    },
                    icon: const Icon(Icons.local_hospital),
                    label: const Text('Enter as Hospital'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Donor demo button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.read<DemoProvider>().enterDemoMode(
                            role: UserRole.donor,
                          );
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DonorHome()),
                      );
                    },
                    icon: const Icon(Icons.volunteer_activism),
                    label: const Text('Enter as Donor'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.eligible,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Quick stats about demo data
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _DemoStat(
                        count: '${SeedData.hospitals.length}',
                        label: 'Hospitals',
                      ),
                      _DemoStat(
                        count: '${SeedData.donors.length}',
                        label: 'Donors',
                      ),
                      _DemoStat(
                        count: '${SeedData.activeRequests.length}',
                        label: 'Active',
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

class _DemoStat extends StatelessWidget {
  final String count;
  final String label;

  const _DemoStat({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
