import 'package:flutter/material.dart';
import '../../config/theme/app_theme.dart';

class BloodGroupBadge extends StatelessWidget {
  final String bloodGroup;
  final double size;

  const BloodGroupBadge({super.key, required this.bloodGroup, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Center(
        child: Text(
          bloodGroup,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.35,
          ),
        ),
      ),
    );
  }
}
