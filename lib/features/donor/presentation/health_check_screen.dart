import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/blood_request.dart';
import '../logic/donor_provider.dart';
import '../../donor_journey/logic/donor_journey_provider.dart';
import 'journey_screen.dart';

class HealthCheckScreen extends StatefulWidget {
  final BloodRequest request;
  final String hospitalName;
  final int distanceKm;

  const HealthCheckScreen({
    super.key,
    required this.request,
    required this.hospitalName,
    required this.distanceKm,
  });

  @override
  State<HealthCheckScreen> createState() => _HealthCheckScreenState();
}

class _HealthCheckScreenState extends State<HealthCheckScreen> {
  bool? _feelingWell;
  bool? _onMedication;
  bool? _hasEaten;
  bool _showResult = false;
  bool _passed = false;

  bool get _allAnswered =>
      _feelingWell != null && _onMedication != null && _hasEaten != null;

  bool get _healthCheckPassed =>
      _feelingWell == true && _onMedication == false && _hasEaten == true;

  void _checkHealth() {
    setState(() {
      _showResult = true;
      _passed = _healthCheckPassed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Check')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.health_and_safety,
              size: 64,
              color: AppColors.eligible,
            ),
            const SizedBox(height: 16),
            Text(
              'Quick Health Check',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please answer honestly. Your health comes first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            if (!_showResult) ...[
              // Question 1
              _HealthQuestion(
                question: 'Are you feeling well today?',
                icon: Icons.favorite,
                value: _feelingWell,
                onChanged: (v) => setState(() => _feelingWell = v),
              ),
              const SizedBox(height: 16),

              // Question 2
              _HealthQuestion(
                question: 'Are you currently on any medication?',
                icon: Icons.medication,
                value: _onMedication,
                onChanged: (v) => setState(() => _onMedication = v),
                invertLogic: true,
              ),
              const SizedBox(height: 16),

              // Question 3
              _HealthQuestion(
                question: 'Have you eaten in the last 4 hours?',
                icon: Icons.restaurant,
                value: _hasEaten,
                onChanged: (v) => setState(() => _hasEaten = v),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _allAnswered ? _checkHealth : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Continue'),
              ),
            ] else if (_passed) ...[
              // Passed — show acceptance confirmation
              Container(
                padding: const EdgeInsets.all(24),
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
                    const SizedBox(height: 16),
                    const Text(
                      'Health Check Passed!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.eligible,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You are about to accept this emergency request.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.request.bloodGroupLabel} at ${widget.hospitalName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cancellation window info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.urgent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer, color: AppColors.urgent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will have 3 minutes to cancel after accepting if you change your mind.',
                        style: TextStyle(color: AppColors.urgent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: () => _confirmAcceptance(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.eligible,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'I Accept — I Will Donate',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () => setState(() => _showResult = false),
                child: const Text('Go back to questions'),
              ),
            ] else ...[
              // Failed health check
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.critical.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.critical),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.health_and_safety,
                      size: 64,
                      color: AppColors.critical,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We Recommend You Sit This One Out',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.critical,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your health comes first. There will be other opportunities to save a life.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _showResult = false;
                    _feelingWell = null;
                    _onMedication = null;
                    _hasEaten = null;
                  });
                },
                child: const Text('Retake Health Check'),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Return to request',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmAcceptance(BuildContext context) async {
    final donorId = context.read<DonorProvider>().profile?.id;
    if (donorId == null) return;

    final recorded = await context.read<DonorJourneyProvider>().acceptRequest(
      requestId: widget.request.id,
      donorId: donorId,
    );

    if (!recorded && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not record your acceptance. Please try again.'),
          backgroundColor: AppColors.critical,
        ),
      );
      return;
    }
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AcceptanceConfirmationDialog(
        request: widget.request,
        hospitalName: widget.hospitalName,
        distanceKm: widget.distanceKm,
        donorId: donorId,
      ),
    );
  }
}

class _HealthQuestion extends StatelessWidget {
  final String question;
  final IconData icon;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final bool invertLogic;

  const _HealthQuestion({
    required this.question,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.invertLogic = false,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AnswerButton(
                  label: 'Yes',
                  isSelected: value == true,
                  color: invertLogic ? AppColors.critical : AppColors.eligible,
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnswerButton(
                  label: 'No',
                  isSelected: value == false,
                  color: invertLogic ? AppColors.eligible : AppColors.critical,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptanceConfirmationDialog extends StatefulWidget {
  final BloodRequest request;
  final String hospitalName;
  final int distanceKm;
  final String donorId;

  const _AcceptanceConfirmationDialog({
    required this.request,
    required this.hospitalName,
    required this.distanceKm,
    required this.donorId,
  });

  @override
  State<_AcceptanceConfirmationDialog> createState() =>
      _AcceptanceConfirmationDialogState();
}

class _AcceptanceConfirmationDialogState
    extends State<_AcceptanceConfirmationDialog> {
  int _secondsRemaining = 180; // 3 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
        if (_secondsRemaining <= 0) {
          _timer?.cancel();
          // Auto-close and navigate to journey
          _navigateToJourney();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime() {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _navigateToJourney() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JourneyScreen(
          request: widget.request,
          hospitalName: widget.hospitalName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.eligible),
          const SizedBox(width: 8),
          const Text('Request Accepted!'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You have accepted to donate ${widget.request.bloodGroupLabel} at ${widget.hospitalName}.',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.urgent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer, color: AppColors.urgent),
                const SizedBox(width: 8),
                Text(
                  'Cancel window: ${_formatTime()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'After this, your commitment is locked in.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _timer?.cancel();
            context.read<DonorJourneyProvider>().cancelAcceptance(
              requestId: widget.request.id,
              donorId: widget.donorId,
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text(
            'I Accepted by Mistake',
            style: TextStyle(color: AppColors.critical),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            _timer?.cancel();
            _navigateToJourney();
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.eligible),
          child: const Text('Confirm — On My Way'),
        ),
      ],
    );
  }
}
