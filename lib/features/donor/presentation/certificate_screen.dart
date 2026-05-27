import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/enums.dart';

class CertificateScreen extends StatelessWidget {
  final String donorName;
  final String bloodGroup;
  final String hospitalName;
  final String city;
  final DateTime donatedAt;
  final DonationType donationType;

  const CertificateScreen({
    super.key,
    required this.donorName,
    required this.bloodGroup,
    required this.hospitalName,
    required this.city,
    required this.donatedAt,
    required this.donationType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Share certificate
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // TODO: Download as PDF
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Certificate card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  const Icon(Icons.bloodtype, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  const Text(
                    'BLOOD DONATION CERTIFICATE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Donor name
                  Text(
                    donorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Blood group badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white),
                    ),
                    child: Text(
                      bloodGroup,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Certificate body
                  Text(
                    'has successfully donated blood and saved a life.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _CertificateRow(label: 'Hospital', value: hospitalName),
                        const Divider(color: Colors.white24),
                        _CertificateRow(label: 'City', value: city),
                        const Divider(color: Colors.white24),
                        _CertificateRow(
                          label: 'Date',
                          value: DateFormat('MMMM d, yyyy').format(donatedAt),
                        ),
                        const Divider(color: Colors.white24),
                        _CertificateRow(
                          label: 'Donation Type',
                          value: _donationTypeLabel(donationType),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Footer
                  Text(
                    'Thank you for being a hero.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    icon: Icons.favorite,
                    label: 'Lives Saved',
                    value: '1',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _StatBox(
                    icon: Icons.bloodtype,
                    label: 'Blood Group',
                    value: bloodGroup,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _donationTypeLabel(DonationType type) {
    return switch (type) {
      DonationType.whole_blood => 'Whole Blood',
      DonationType.platelets => 'Platelets',
      DonationType.plasma => 'Plasma',
      DonationType.double_red_cells => 'Double Red Cells',
    };
  }
}

class _CertificateRow extends StatelessWidget {
  final String label;
  final String value;

  const _CertificateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
