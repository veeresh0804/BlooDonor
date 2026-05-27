import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';
import '../../auth/logic/auth_provider.dart';
import '../logic/donor_provider.dart';
import '../data/donor_achievements_service.dart';
import 'donor_profile_setup.dart';

class DonorHome extends StatefulWidget {
  const DonorHome({super.key});

  @override
  State<DonorHome> createState() => _DonorHomeState();
}

class _DonorHomeState extends State<DonorHome> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        context.read<DonorProvider>().loadProfile(userId);
      }
    } catch (_) {
      // Supabase not initialized — demo mode
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DonorProvider>();

    if (!provider.hasProfile && !provider.isLoading) {
      return const DonorProfileSetup();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlooDonor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: [_HeroWallTab(provider: provider), _HistoryTab(donorId: provider.profile?.id), _ProfileTab(provider: provider)][_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Hero Wall',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HeroWallTab extends StatelessWidget {
  final DonorProvider provider;

  const _HeroWallTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final profile = provider.profile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Blood group badge
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Center(
                    child: Text(
                      profile.bloodGroupLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lives saved
                const Text(
                  'Lives Saved',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  '0',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have helped 0 people',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Eligibility status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: profile.cooldownActive
                  ? AppColors.cooldown.withValues(alpha: 0.1)
                  : AppColors.eligible.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: profile.cooldownActive
                    ? AppColors.cooldown
                    : AppColors.eligible,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  profile.cooldownActive
                      ? Icons.timer_outlined
                      : Icons.check_circle_outline,
                  color: profile.cooldownActive
                      ? AppColors.cooldown
                      : AppColors.eligible,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.cooldownActive
                            ? 'Cooling Down'
                            : 'Ready to Save a Life',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: profile.cooldownActive
                              ? AppColors.cooldown
                              : AppColors.eligible,
                        ),
                      ),
                      if (profile.cooldownActive &&
                          profile.cooldownDaysRemaining != null)
                        Text(
                          'Eligible again in ${profile.cooldownDaysRemaining} days',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick stats
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.bloodtype,
                  label: 'Blood Group',
                  value: profile.bloodGroupLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.star,
                  label: 'Points',
                  value: '${profile.points}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.location_on,
                  label: 'Radius',
                  value: '${profile.radiusKm} km',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: profile.availability
                      ? Icons.check_circle
                      : Icons.cancel,
                  label: 'Status',
                  value: profile.availability ? 'Available' : 'Unavailable',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Today's heroes placeholder
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events,
                  size: 48,
                  color: AppColors.urgent,
                ),
                const SizedBox(height: 12),
                const Text(
                  "Today's Heroes",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first hero today!',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  final String? donorId;

  const _HistoryTab({this.donorId});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  final _service = DonorAchievementsService();
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _todaysHeroes = [];
  Map<String, dynamic>? _achievements;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (widget.donorId != null) {
        final results = await Future.wait([
          _service.getDonationHistory(widget.donorId!),
          _service.getTodaysHeroes(),
          _service.getAchievements(widget.donorId!),
        ]);
        _history = results[0] as List<Map<String, dynamic>>;
        _todaysHeroes = results[1] as List<Map<String, dynamic>>;
        _achievements = results[2] as Map<String, dynamic>?;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges section
          Text(
            'Your Badges',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _BadgesGrid(achievements: _achievements),
          const SizedBox(height: 24),

          // Today's Heroes
          Text(
            "Today's Heroes",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_todaysHeroes.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, size: 40, color: AppColors.urgent),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first hero today!',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ...List.generate(
              _todaysHeroes.length > 5 ? 5 : _todaysHeroes.length,
              (i) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.urgent.withValues(alpha: 0.15),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.urgent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Anonymous Hero',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.volunteer_activism, color: AppColors.critical, size: 20),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),

          // Donation history
          Text(
            'Donation History',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (_history.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.history, size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    'Your donation history will appear here.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            ..._history.map((donation) {
              final request = donation['blood_requests'] as Map<String, dynamic>?;
              final bloodGroup = request?['blood_group'] ?? '';
              final rhFactor = request?['rh_factor'] ?? '';
              final label = '${bloodGroup.toString().toUpperCase()}${rhFactor == 'positive' ? '+' : '-'}';
              final date = donation['accepted_at'] != null
                  ? DateTime.tryParse(donation['accepted_at'])
                  : null;
              final dateStr = date != null
                  ? '${date.day}/${date.month}/${date.year}'
                  : 'Unknown';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.eligible.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.critical.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.bloodtype, color: AppColors.critical),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(dateStr, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle, color: AppColors.eligible),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _BadgesGrid extends StatelessWidget {
  final Map<String, dynamic>? achievements;

  const _BadgesGrid({this.achievements});

  @override
  Widget build(BuildContext context) {
    final livesSaved = achievements?['lives_saved'] ?? 0;

    final badges = [
      _Badge(
        icon: Icons.volunteer_activism,
        label: 'Life Saver',
        unlocked: livesSaved >= 1,
        requirement: '1 donation',
      ),
      _Badge(
        icon: Icons.repeat,
        label: '3x Donor',
        unlocked: livesSaved >= 3,
        requirement: '3 donations',
      ),
      _Badge(
        icon: Icons.flash_on,
        label: 'First Responder',
        unlocked: achievements?['first_responder'] == true,
        requirement: 'Respond first',
      ),
      _Badge(
        icon: Icons.star,
        label: 'Elite Donor',
        unlocked: livesSaved >= 10,
        requirement: '10 donations',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: badges.map((badge) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: badge.unlocked
                ? AppColors.urgent.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: badge.unlocked
                  ? AppColors.urgent.withValues(alpha: 0.3)
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                badge.icon,
                size: 32,
                color: badge.unlocked
                    ? AppColors.urgent
                    : AppColors.textSecondary.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              Text(
                badge.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: badge.unlocked
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              Text(
                badge.unlocked ? '✅ Unlocked' : badge.requirement,
                style: TextStyle(
                  fontSize: 11,
                  color: badge.unlocked
                      ? AppColors.eligible
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Badge {
  final IconData icon;
  final String label;
  final bool unlocked;
  final String requirement;

  const _Badge({
    required this.icon,
    required this.label,
    required this.unlocked,
    required this.requirement,
  });
}

class _ProfileTab extends StatelessWidget {
  final DonorProvider provider;

  const _ProfileTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final profile = provider.profile;
    if (profile == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Availability toggle
          _ToggleCard(
            title: 'Available for Donations',
            subtitle: 'You will receive emergency alerts',
            icon: Icons.notifications_active,
            value: profile.availability,
            onChanged: (_) => provider.toggleAvailability(),
          ),
          const SizedBox(height: 12),

          // DND toggle
          _ToggleCard(
            title: 'Do Not Disturb',
            subtitle: 'Temporarily pause all notifications',
            icon: Icons.do_not_disturb_on,
            value: profile.dndMode,
            onChanged: (_) => provider.toggleDndMode(),
          ),
          const SizedBox(height: 24),

          // Profile info
          Text(
            'Profile Details',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.bloodtype,
            label: 'Blood Group',
            value: profile.bloodGroupLabel,
          ),
          _InfoTile(
            icon: Icons.location_on,
            label: 'City',
            value: profile.city,
          ),
          _InfoTile(
            icon: Icons.radar,
            label: 'Alert Radius',
            value: '${profile.radiusKm} km',
          ),
          if (profile.emergencyContactName != null) ...[
            const SizedBox(height: 16),
            Text(
              'Emergency Contact',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _InfoTile(
              icon: Icons.person,
              label: 'Name',
              value: profile.emergencyContactName!,
            ),
            _InfoTile(
              icon: Icons.phone,
              label: 'Phone',
              value: profile.emergencyContactPhone ?? 'Not set',
            ),
          ],
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AppColors.eligible : AppColors.textSecondary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.eligible,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
