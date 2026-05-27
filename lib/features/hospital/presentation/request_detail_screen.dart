import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/blood_request.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/blood_group_badge.dart';
import '../../../shared/widgets/urgency_badge.dart';
import '../logic/hospital_provider.dart';

class RequestDetailScreen extends StatelessWidget {
  final BloodRequest request;

  const RequestDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();
    final isActive = request.status == RequestStatus.active;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          if (isActive)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cancel') {
                  _showCancelDialog(context, provider);
                } else if (value == 'fulfill') {
                  provider.fulfillRequest(request.id);
                  Navigator.pop(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'fulfill',
                  child: Text('Mark Fulfilled'),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel Request'),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: BloodGroupBadge(
                bloodGroup: request.bloodGroupLabel,
                size: 80,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '${request.bloodGroupLabel} — ${request.units} unit${request.units > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: UrgencyBadge(urgency: request.urgency)),
            const SizedBox(height: 24),

            // Info cards
            _InfoRow(
              icon: Icons.access_time,
              label: 'Posted',
              value: _formatDateTime(request.createdAt),
            ),
            _InfoRow(
              icon: Icons.people,
              label: 'Donors Notified',
              value: '${request.donorsNotified}',
            ),
            _InfoRow(
              icon: Icons.water_drop,
              label: 'Units Fulfilled',
              value: '${request.unitsFulfilled} / ${request.units}',
            ),
            _InfoRow(
              icon: Icons.signal_cellular_alt,
              label: 'Current Radius',
              value: '${request.currentRadiusKm} km',
            ),
            _InfoRow(
              icon: Icons.circle,
              label: 'Status',
              value: request.status.name.toUpperCase(),
            ),

            if (request.patientStory != null) ...[
              const SizedBox(height: 24),
              Text(
                "Patient's Story",
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  request.patientStory!,
                  style: const TextStyle(
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            if (request.cancelReason != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cooldown.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Cancel reason: ${request.cancelReason}',
                  style: TextStyle(color: AppColors.cooldown),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, HospitalProvider provider) {
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancel Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you cancelling this request?'),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: selectedReason,
                onChanged: (value) {
                  setDialogState(() => selectedReason = value);
                },
                child: Column(
                  children:
                      [
                            'Found blood elsewhere',
                            'Patient condition changed',
                            'Created by mistake',
                          ]
                          .map(
                            (reason) => RadioListTile<String>(
                              title: Text(reason),
                              value: reason,
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            ElevatedButton(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      provider.cancelRequest(request.id, selectedReason!);
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.critical,
              ),
              child: const Text('Cancel Request'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
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
