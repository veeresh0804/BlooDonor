import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/enums.dart';
import '../logic/hospital_provider.dart';

class HospitalAnalytics extends StatelessWidget {
  const HospitalAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();
    final requests = provider.requests;

    final totalRequests = requests.length;
    final fulfilled =
        requests.where((r) => r.status == RequestStatus.fulfilled).length;
    final cancelled =
        requests.where((r) => r.status == RequestStatus.cancelled).length;
    final active =
        requests.where((r) => r.status == RequestStatus.active).length;
    final fulfillmentRate =
        totalRequests > 0 ? ((fulfilled / totalRequests) * 100).round() : 0;

    // Blood group breakdown
    final bloodGroupCounts = <String, int>{};
    for (final r in requests) {
      final label = r.bloodGroupLabel;
      bloodGroupCounts[label] = (bloodGroupCounts[label] ?? 0) + 1;
    }
    final sortedBloodGroups = bloodGroupCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Overview',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _AnalyticCard(
                    label: 'Total Requests',
                    value: '$totalRequests',
                    icon: Icons.list_alt,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AnalyticCard(
                    label: 'Fulfilled',
                    value: '$fulfilled',
                    icon: Icons.check_circle,
                    color: AppColors.eligible,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AnalyticCard(
                    label: 'Active Now',
                    value: '$active',
                    icon: Icons.radar,
                    color: AppColors.critical,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AnalyticCard(
                    label: 'Fulfillment Rate',
                    value: '$fulfillmentRate%',
                    icon: Icons.trending_up,
                    color: AppColors.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AnalyticCard(
                    label: 'Cancelled',
                    value: '$cancelled',
                    icon: Icons.cancel,
                    color: AppColors.cooldown,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ),
            const SizedBox(height: 24),

            // Blood group breakdown
            Text(
              'Blood Group Breakdown',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (sortedBloodGroups.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.bar_chart,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Blood group data will appear after your first requests.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...sortedBloodGroups.map((entry) {
                final percent = totalRequests > 0
                    ? (entry.value / totalRequests * 100).round()
                    : 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _BloodGroupBar(
                    label: entry.key,
                    count: entry.value,
                    percent: percent,
                    maxCount: sortedBloodGroups.first.value,
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Urgency breakdown
            Text(
              'Urgency Distribution',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _UrgencyRow(
              label: 'Critical',
              count: requests
                  .where((r) => r.urgency == Urgency.critical)
                  .length,
              color: AppColors.critical,
            ),
            _UrgencyRow(
              label: 'Urgent',
              count:
                  requests.where((r) => r.urgency == Urgency.urgent).length,
              color: AppColors.urgent,
            ),
            _UrgencyRow(
              label: 'Normal',
              count:
                  requests.where((r) => r.urgency == Urgency.normal).length,
              color: AppColors.normal,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
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
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BloodGroupBar extends StatelessWidget {
  final String label;
  final int count;
  final int percent;
  final int maxCount;

  const _BloodGroupBar({
    required this.label,
    required this.count,
    required this.percent,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: maxCount > 0 ? count / maxCount : 0,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                color: AppColors.primary,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count ($percent%)',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgencyRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _UrgencyRow({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
