import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../config/constants/app_constants.dart';
import '../../../shared/models/enums.dart';
import '../logic/hospital_provider.dart';

class ConfirmDonationScreen extends StatefulWidget {
  final String donorId;
  final String donorName;
  final String bloodGroup;
  final String requestId;

  const ConfirmDonationScreen({
    super.key,
    required this.donorId,
    required this.donorName,
    required this.bloodGroup,
    required this.requestId,
  });

  @override
  State<ConfirmDonationScreen> createState() => _ConfirmDonationScreenState();
}

class _ConfirmDonationScreenState extends State<ConfirmDonationScreen> {
  DonationType _donationType = DonationType.whole_blood;
  int _units = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Donation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Donor info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.eligible.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.eligible),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: AppColors.eligible,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.donorName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Blood Group: ${widget.bloodGroup}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Donation type
            Text(
              'Donation Type',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...DonationType.values.map((type) {
              final label = switch (type) {
                DonationType.whole_blood => 'Whole Blood',
                DonationType.platelets => 'Platelets',
                DonationType.plasma => 'Plasma',
                DonationType.double_red_cells => 'Double Red Cells',
              };
              final cooldown =
                  AppConstants.donationCooldownDays[type.name] ?? 90;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DonationTypeCard(
                  label: label,
                  cooldownDays: cooldown,
                  isSelected: _donationType == type,
                  onTap: () => setState(() => _donationType = type),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Units
            Text(
              'Units Donated',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: _units > 1 ? () => setState(() => _units--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_units',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _units < 5 ? () => setState(() => _units++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.eligible,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Confirm Donation Complete',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirm() async {
    final success = await context.read<HospitalProvider>().confirmDonation(
      requestId: widget.requestId,
      donorId: widget.donorId,
      donationType: _donationType,
      units: _units,
    );

    if (success && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Donation Confirmed!'),
          content: Text(
            '${widget.donorName}\'s donation has been recorded. '
            'A digital certificate will be generated and the donor will be notified.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }
}

class _DonationTypeCard extends StatelessWidget {
  final String label;
  final int cooldownDays;
  final bool isSelected;
  final VoidCallback onTap;

  const _DonationTypeCard({
    required this.label,
    required this.cooldownDays,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.eligible.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.eligible : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.eligible : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.eligible
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Cooldown: $cooldownDays days',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
