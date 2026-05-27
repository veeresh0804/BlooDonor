import 'package:flutter/material.dart';
import '../../config/theme/app_theme.dart';
import '../models/enums.dart';

class UrgencyBadge extends StatelessWidget {
  final Urgency urgency;

  const UrgencyBadge({super.key, required this.urgency});

  @override
  Widget build(BuildContext context) {
    final color = switch (urgency) {
      Urgency.critical => AppColors.critical,
      Urgency.urgent => AppColors.urgent,
      Urgency.normal => AppColors.normal,
    };

    final label = switch (urgency) {
      Urgency.critical => 'CRITICAL',
      Urgency.urgent => 'URGENT',
      Urgency.normal => 'NORMAL',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
