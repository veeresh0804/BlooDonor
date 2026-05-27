import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/blood_request.dart';
import '../../../shared/models/enums.dart';
import '../../donor_journey/logic/donor_journey_provider.dart';
import '../logic/donor_provider.dart';

class JourneyScreen extends StatefulWidget {
  final BloodRequest request;
  final String hospitalName;

  const JourneyScreen({
    super.key,
    required this.request,
    required this.hospitalName,
  });

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  bool _familyNotified = false;

  @override
  Widget build(BuildContext context) {
    final journeyProvider = context.watch<DonorJourneyProvider>();
    final donorProvider = context.watch<DonorProvider>();
    // Hospital location comes from the blood request, not the donor
    final hospitalLat = widget.request.lat;
    final hospitalLng = widget.request.lng;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Journey'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status header
            _StatusHeader(status: journeyProvider.currentStatus),
            const SizedBox(height: 24),

            // Hospital info
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_hospital,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.hospitalName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.hospitalName,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openMaps(hospitalLat, hospitalLng),
                      icon: const Icon(Icons.directions),
                      label: const Text('Get Directions'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.normal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Status update buttons
            Text(
              'Update Your Status',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _StatusButton(
              icon: Icons.directions_car,
              label: 'On the Way',
              color: AppColors.normal,
              isSelected:
                  journeyProvider.currentStatus ==
                  DonorResponseStatus.on_the_way,
              onTap: () =>
                  _updateStatus(context, DonorResponseStatus.on_the_way),
            ),
            const SizedBox(height: 8),

            _StatusButton(
              icon: Icons.access_time,
              label: 'Delayed',
              color: AppColors.urgent,
              isSelected:
                  journeyProvider.currentStatus == DonorResponseStatus.delayed,
              onTap: () => _updateStatus(context, DonorResponseStatus.delayed),
            ),
            const SizedBox(height: 8),

            _StatusButton(
              icon: Icons.location_on,
              label: 'I Have Arrived',
              color: AppColors.eligible,
              isSelected:
                  journeyProvider.currentStatus == DonorResponseStatus.arrived,
              onTap: () => _updateStatus(context, DonorResponseStatus.arrived),
            ),
            const SizedBox(height: 16),

            // Problem buttons
            Text(
              'Having Problems?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),

            _StatusButton(
              icon: Icons.sick,
              label: 'Feeling Unwell',
              color: AppColors.urgent,
              isSelected:
                  journeyProvider.currentStatus ==
                  DonorResponseStatus.stepped_back,
              onTap: () => _showProblemDialog(context, 'unwell'),
            ),
            const SizedBox(height: 8),

            _StatusButton(
              icon: Icons.car_crash,
              label: 'Vehicle Breakdown',
              color: AppColors.urgent,
              isSelected: false, // This is a momentary state
              onTap: () => _showProblemDialog(context, 'breakdown'),
            ),
            const SizedBox(height: 8),

            _StatusButton(
              icon: Icons.warning,
              label: 'Accident',
              color: AppColors.critical,
              isSelected:
                  journeyProvider.currentStatus == DonorResponseStatus.accident,
              onTap: () => _showAccidentDialog(context),
            ),
            const SizedBox(height: 24),

            // Notify family
            if (!_familyNotified &&
                donorProvider.profile?.emergencyContactPhone != null)
              OutlinedButton.icon(
                onPressed: () => _notifyFamily(context),
                icon: const Icon(Icons.family_restroom),
                label: const Text('Notify My Family'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: AppColors.normal,
                ),
              )
            else if (_familyNotified)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.eligible.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check,
                      color: AppColors.eligible,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Family notified',
                      style: TextStyle(color: AppColors.eligible),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(BuildContext context, DonorResponseStatus status) {
    final donorId = context.read<DonorProvider>().profile?.id;
    if (donorId == null) return;

    context.read<DonorJourneyProvider>().updateStatus(
      requestId: widget.request.id,
      donorId: donorId,
      status: status,
    );

    if (status == DonorResponseStatus.arrived) {
      // TODO: Send "arrived" family SMS
    }
  }

  void _openMaps(double? lat, double? lng) async {
    final latPos = lat ?? 17.3850;
    final lngPos = lng ?? 78.4867;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latPos,$lngPos',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _notifyFamily(BuildContext context) {
    final donor = context.read<DonorProvider>().profile;
    if (donor == null) return;

    context.read<DonorJourneyProvider>().notifyFamily(
      donor: donor,
      hospitalName: widget.hospitalName,
    );

    setState(() => _familyNotified = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your family has been notified!'),
        backgroundColor: AppColors.eligible,
      ),
    );
  }

  void _showProblemDialog(BuildContext context, String type) {
    final label = type == 'unwell' ? 'Feeling Unwell' : 'Vehicle Breakdown';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: Text(
          type == 'unwell'
              ? 'Your health comes first. The request will be returned to the radar so another donor can help. There is no penalty.'
              : 'The hospital will be notified. The request will be returned to the radar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateStatus(context, DonorResponseStatus.stepped_back);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.urgent),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showAccidentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppColors.critical),
            SizedBox(width: 8),
            Text('Report Accident'),
          ],
        ),
        content: const Text(
          'This will alert the hospital and your emergency contact immediately. Are you safe?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateStatus(context, DonorResponseStatus.accident);
              // TODO: Alert hospital + emergency contact
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.critical,
            ),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final DonorResponseStatus status;

  const _StatusHeader({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, subtitle) = switch (status) {
      DonorResponseStatus.accepted => (
        AppColors.eligible,
        Icons.check_circle,
        'Request Accepted',
        'Head to the hospital when you are ready',
      ),
      DonorResponseStatus.on_the_way => (
        AppColors.normal,
        Icons.directions_car,
        'On the Way',
        'The hospital has been notified',
      ),
      DonorResponseStatus.delayed => (
        AppColors.urgent,
        Icons.access_time,
        'Delayed',
        'The hospital knows you are running late',
      ),
      DonorResponseStatus.arrived => (
        AppColors.eligible,
        Icons.location_on,
        'Arrived',
        'Please wait for hospital confirmation',
      ),
      DonorResponseStatus.stepped_back => (
        AppColors.cooldown,
        Icons.sick,
        'Stepped Back',
        'The request has been returned to the radar',
      ),
      DonorResponseStatus.accident => (
        AppColors.critical,
        Icons.warning,
        'Accident Reported',
        'Hospital and emergency contact have been notified',
      ),
      _ => (AppColors.textSecondary, Icons.info, 'Status', ''),
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.icon,
    required this.label,
    required this.color,
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
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : AppColors.textPrimary,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Icon(Icons.check_circle, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
