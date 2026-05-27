import 'package:flutter/material.dart';
import '../../config/theme/app_theme.dart';
import '../models/blood_request.dart';
import '../models/enums.dart';
import 'blood_group_badge.dart';
import 'urgency_badge.dart';

class RequestCard extends StatelessWidget {
  final BloodRequest request;
  final VoidCallback? onTap;

  const RequestCard({super.key, required this.request, this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _timeAgo(request.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BloodGroupBadge(
                    bloodGroup: request.bloodGroupLabel,
                    size: 48,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request.bloodGroupLabel} — ${request.units} unit${request.units > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UrgencyBadge(urgency: request.urgency),
                ],
              ),

              if (request.patientStory != null &&
                  request.patientStory!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.patientStory!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              Row(
                children: [
                  _StatusChip(status: request.status),
                  const Spacer(),
                  Icon(
                    Icons.people_outline,
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
                  const SizedBox(width: 12),
                  // Blood drop fill indicator
                  _BloodDropFill(
                    fulfilled: request.unitsFulfilled,
                    total: request.units,
                  ),
                ],
              ),
            ],
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

class _StatusChip extends StatelessWidget {
  final RequestStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      RequestStatus.active => (AppColors.eligible, 'Active'),
      RequestStatus.fulfilled => (AppColors.normal, 'Fulfilled'),
      RequestStatus.cancelled => (AppColors.cooldown, 'Cancelled'),
      RequestStatus.escalating => (AppColors.urgent, 'Escalating'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BloodDropFill extends StatelessWidget {
  final int fulfilled;
  final int total;

  const _BloodDropFill({required this.fulfilled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.water_drop, size: 16, color: AppColors.critical),
        const SizedBox(width: 4),
        Text(
          '$fulfilled/$total',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
