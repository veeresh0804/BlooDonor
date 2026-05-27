import 'package:flutter/material.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/models/blood_request.dart';

class CommunitySosScreen extends StatelessWidget {
  final BloodRequest request;
  final String hospitalName;

  const CommunitySosScreen({
    super.key,
    required this.request,
    required this.hospitalName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community SOS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SOS header
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
                    Icons.campaign,
                    size: 64,
                    color: AppColors.critical,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'COMMUNITY SOS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.critical,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We urgently need ${request.bloodGroupLabel} blood',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'at $hospitalName',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No matching donor found nearby',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Even if your blood group does not match, you might know someone with ${request.bloodGroupLabel} blood who can help.',
                    style: const TextStyle(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lead submission form
            Text(
              'Know someone with ${request.bloodGroupLabel}?',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _LeadSubmissionForm(request: request),
          ],
        ),
      ),
    );
  }
}

class _LeadSubmissionForm extends StatefulWidget {
  final BloodRequest request;

  const _LeadSubmissionForm({required this.request});

  @override
  State<_LeadSubmissionForm> createState() => _LeadSubmissionFormState();
}

class _LeadSubmissionFormState extends State<_LeadSubmissionForm> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // TODO: Submit lead to Supabase leads table
    setState(() => _submitted = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! The hospital will contact them directly.'),
        backgroundColor: AppColors.eligible,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.eligible.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.eligible),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 48, color: AppColors.eligible),
            const SizedBox(height: 12),
            const Text(
              'Lead Submitted!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.eligible,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The hospital will contact ${_nameController.text} directly. If they donate, they will be invited to register.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
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
              labelText: 'Their Phone Number',
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.critical,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Submit Lead — Help Save a Life',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
