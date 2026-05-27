import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/blood_request.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/blood_group_badge.dart';
import '../../../shared/widgets/urgency_badge.dart';
import '../logic/donor_provider.dart';
import '../../donor_journey/logic/donor_journey_provider.dart';
import 'health_check_screen.dart';

class EmergencyCardScreen extends StatefulWidget {
  final BloodRequest request;
  final String hospitalName;
  final int distanceKm;

  const EmergencyCardScreen({
    super.key,
    required this.request,
    required this.hospitalName,
    required this.distanceKm,
  });

  @override
  State<EmergencyCardScreen> createState() => _EmergencyCardScreenState();
}

class _EmergencyCardScreenState extends State<EmergencyCardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();

    // Pulse animation for urgency
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Elapsed time timer
    _elapsed = DateTime.now().difference(widget.request.createdAt);
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.request.createdAt);
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String _formatElapsed() {
    if (_elapsed.inMinutes < 1) return 'Just now';
    if (_elapsed.inMinutes < 60) return '${_elapsed.inMinutes}m ago';
    if (_elapsed.inHours < 24) {
      return '${_elapsed.inHours}h ${_elapsed.inMinutes % 60}m ago';
    }
    return '${_elapsed.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final urgencyColor = switch (request.urgency) {
      Urgency.critical => AppColors.critical,
      Urgency.urgent => AppColors.urgent,
      Urgency.normal => AppColors.normal,
    };

    return Scaffold(
      backgroundColor: urgencyColor.withValues(alpha: 0.05),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Emergency header with pulse
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bloodtype, size: 64, color: urgencyColor),
                ),
              ),
              const SizedBox(height: 16),

              // EMERGENCY label
              Text(
                'EMERGENCY REQUEST',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: urgencyColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),

              // Blood group + urgency
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BloodGroupBadge(
                    bloodGroup: request.bloodGroupLabel,
                    size: 72,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.units} unit${request.units > 1 ? 's' : ''} needed',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      UrgencyBadge(urgency: request.urgency),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Hospital + distance
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
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Text(
                          '${widget.distanceKm} km away',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Posted ${_formatElapsed()}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Patient story
              if (request.patientStory != null &&
                  request.patientStory!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: urgencyColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite, color: urgencyColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "Patient's Story",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: urgencyColor,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        request.patientStory!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Action buttons
              ElevatedButton(
                onPressed: () => _acceptRequest(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.eligible,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'I Can Donate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              OutlinedButton(
                onPressed: () => _showKnowSomeoneSheet(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.normal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'I Know Someone',
                  style: TextStyle(fontSize: 16, color: AppColors.normal),
                ),
              ),
              const SizedBox(height: 16),

              // Decline
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Not available right now',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _acceptRequest(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HealthCheckScreen(
          request: widget.request,
          hospitalName: widget.hospitalName,
          distanceKm: widget.distanceKm,
        ),
      ),
    );
  }

  void _showKnowSomeoneSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _KnowSomeoneSheet(request: widget.request),
    );
  }
}

class _KnowSomeoneSheet extends StatefulWidget {
  final BloodRequest request;

  const _KnowSomeoneSheet({required this.request});

  @override
  State<_KnowSomeoneSheet> createState() => _KnowSomeoneSheetState();
}

class _KnowSomeoneSheetState extends State<_KnowSomeoneSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Refer a Donor',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Know someone with ${widget.request.bloodGroupLabel}? Submit their details and the hospital will contact them directly.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Their Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Required';
                return null;
              },
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Their Phone',
                prefixText: '+91 ',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (value.length < 10) return 'Enter valid phone';
                return null;
              },
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.normal,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Submit Lead'),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final donorProvider = context.read<DonorProvider>();
    final journeyProvider = context.read<DonorJourneyProvider>();
    final donorId = donorProvider.profile?.id;

    if (donorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify current donor.')),
      );
      return;
    }

    final success = await journeyProvider.submitLead(
      requestId: widget.request.id,
      referredByDonorId: donorId,
      name: _nameController.text.trim(),
      phone: '+91${_phoneController.text.trim()}',
    );

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lead submitted! The hospital will contact them.'),
          backgroundColor: AppColors.eligible,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(journeyProvider.error ?? 'Failed to submit lead.'),
          backgroundColor: AppColors.critical,
        ),
      );
    }
  }
}
