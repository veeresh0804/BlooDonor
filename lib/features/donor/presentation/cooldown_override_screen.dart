import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/blood_request.dart';
import '../logic/donor_provider.dart';
import '../../donor_journey/logic/donor_journey_provider.dart';
import 'journey_screen.dart';

class CooldownOverrideScreen extends StatefulWidget {
  final BloodRequest request;
  final String hospitalName;
  final int distanceKm;
  final int cooldownDaysRemaining;

  const CooldownOverrideScreen({
    super.key,
    required this.request,
    required this.hospitalName,
    required this.distanceKm,
    required this.cooldownDaysRemaining,
  });

  @override
  State<CooldownOverrideScreen> createState() => _CooldownOverrideScreenState();
}

class _CooldownOverrideScreenState extends State<CooldownOverrideScreen> {
  bool? _medicallyFit;
  bool _understandCooldown = false;

  bool get _canProceed => _medicallyFit == true && _understandCooldown;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Override')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Warning header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.urgent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.urgent),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 64,
                    color: AppColors.urgent,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'EMERGENCY OVERRIDE',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.urgent,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'There are no available donors for ${widget.request.bloodGroupLabel} right now. '
                    'You are currently in your cooldown period (${widget.cooldownDaysRemaining} days remaining).',
                    textAlign: TextAlign.center,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Patient story
            if (widget.request.patientStory != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.critical.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: AppColors.critical,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Why we need you',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.critical,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.request.patientStory!,
                      style: const TextStyle(
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Medical fitness check
            Text(
              'Medical Fitness Confirmation',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Donating during your cooldown period carries additional health risks. '
                    'Please confirm that you are medically fit to donate.',
                    style: TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _FitnessButton(
                          label: 'I Am Fit',
                          icon: Icons.check_circle,
                          color: AppColors.eligible,
                          isSelected: _medicallyFit == true,
                          onTap: () => setState(() => _medicallyFit = true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FitnessButton(
                          label: 'Not Sure',
                          icon: Icons.cancel,
                          color: AppColors.critical,
                          isSelected: _medicallyFit == false,
                          onTap: () => setState(() => _medicallyFit = false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Understanding checkbox
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _understandCooldown,
                    onChanged: (v) =>
                        setState(() => _understandCooldown = v ?? false),
                    activeColor: AppColors.urgent,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(
                        () => _understandCooldown = !_understandCooldown,
                      ),
                      child: const Text(
                        'I understand that I am donating during my cooldown period '
                        'and I accept full responsibility for my health decision.',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Accept button
            ElevatedButton(
              onPressed: _canProceed ? _acceptOverride : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canProceed
                    ? AppColors.urgent
                    : AppColors.cooldown,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'I Will Donate Despite Cooldown',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _canProceed ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Not this time',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _acceptOverride() async {
    final donorId = context.read<DonorProvider>().profile?.id;
    if (donorId == null) return;

    final success = await context.read<DonorJourneyProvider>().acceptRequest(
      requestId: widget.request.id,
      donorId: donorId,
      isCooldownOverride: true,
    );

    if (success && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Override Accepted'),
          content: Text(
            'Thank you for stepping up during your cooldown. '
            'The hospital has been notified. Please take care of your health.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.of(context).popUntil((route) => route.isFirst);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JourneyScreen(
                      request: widget.request,
                      hospitalName: widget.hospitalName,
                    ),
                  ),
                );
              },
              child: const Text('Continue to Journey'),
            ),
          ],
        ),
      );
    }
  }
}

class _FitnessButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FitnessButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppColors.textSecondary,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
