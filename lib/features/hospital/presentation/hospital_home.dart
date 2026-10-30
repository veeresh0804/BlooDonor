import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/blood_request.dart';
import '../../auth/logic/auth_provider.dart';
import '../logic/hospital_provider.dart';
import 'hospital_profile_setup.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';
import 'request_live_tracker.dart';
import 'hospital_analytics.dart';

class HospitalHome extends StatefulWidget {
  const HospitalHome({super.key});

  @override
  State<HospitalHome> createState() => _HospitalHomeState();
}

class _HospitalHomeState extends State<HospitalHome> {
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
        context.read<HospitalProvider>().loadProfile(userId);
      }
    } catch (_) {
      // Supabase not initialized — demo mode
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();

    if (!provider.hasProfile && !provider.isLoading) {
      return const HospitalProfileSetup();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.profile?.hospitalName ?? 'Hospital Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().signOut(),
          ),
        ],
      ),
      body: [_DashboardTab(provider: provider), _RequestsTab(provider: provider), const HospitalAnalytics()][_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'My Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final HospitalProvider provider;

  const _DashboardTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final active = provider.activeRequests;

    if (active.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bloodtype, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No active requests',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create a blood request',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadRequests(provider.profile!.id),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: active.length,
        itemBuilder: (context, index) {
          final request = active[index];
          return _ActiveRequestCard(
            request: request,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestLiveTracker(request: request),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ActiveRequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback? onTap;

  const _ActiveRequestCard({required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    final urgencyColor = switch (request.urgency) {
      Urgency.critical => AppColors.critical,
      Urgency.urgent => AppColors.urgent,
      Urgency.normal => AppColors.normal,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: urgencyColor, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        request.bloodGroupLabel,
                        style: TextStyle(
                          color: urgencyColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        request.urgency.name.toUpperCase(),
                        style: TextStyle(
                          color: urgencyColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _timeAgo(request.createdAt),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (request.patientStory != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    request.patientStory!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${request.donorsNotified} notified',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.water_drop, size: 16, color: AppColors.critical),
                    const SizedBox(width: 4),
                    Text(
                      '${request.unitsFulfilled}/${request.units} units',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _RequestsTab extends StatelessWidget {
  final HospitalProvider provider;

  const _RequestsTab({required this.provider});

  @override
  Widget build(BuildContext context) {
    final all = provider.requests;

    if (all.isEmpty) {
      return const Center(child: Text('No requests yet'));
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadRequests(provider.profile!.id),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: all.length,
        itemBuilder: (context, index) {
          final request = all[index];
          return _RequestListTile(request: request);
        },
      ),
    );
  }
}

class _RequestListTile extends StatelessWidget {
  final BloodRequest request;

  const _RequestListTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (request.status) {
      RequestStatus.active => AppColors.eligible,
      RequestStatus.fulfilled => AppColors.normal,
      RequestStatus.cancelled => AppColors.cooldown,
      RequestStatus.escalating => AppColors.urgent,
    };

    return ListTile(
      onTap: () {
        final isOpen = request.status == RequestStatus.active ||
            request.status == RequestStatus.escalating;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isOpen
                ? RequestLiveTracker(request: request)
                : RequestDetailScreen(request: request),
          ),
        );
      },
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            request.bloodGroupLabel,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
      title: Text(
        '${request.bloodGroupLabel} — ${request.units} unit${request.units > 1 ? 's' : ''}',
      ),
      subtitle: Text(
        request.patientStory ?? 'No story provided',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          request.status.name,
          style: TextStyle(
            color: statusColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
