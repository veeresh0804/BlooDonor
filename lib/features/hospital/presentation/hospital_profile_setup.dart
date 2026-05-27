import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../logic/hospital_provider.dart';

class HospitalProfileSetup extends StatefulWidget {
  const HospitalProfileSetup({super.key});

  @override
  State<HospitalProfileSetup> createState() => _HospitalProfileSetupState();
}

class _HospitalProfileSetupState extends State<HospitalProfileSetup> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Default Hyderabad coordinates (center of city)
  final double _lat = 17.3850;
  final double _lng = 78.4867;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final provider = context.read<HospitalProvider>();
    final success = await provider.saveProfile(
      userId: userId,
      hospitalName: _nameController.text.trim(),
      address: _addressController.text.trim(),
      lat: _lat,
      lng: _lng,
    );

    if (success && mounted) {
      // HospitalHome will detect profile exists and show dashboard
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();

    return LoadingOverlay(
      isLoading: provider.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Hospital Profile')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.local_hospital,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Set up your hospital profile',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This information will be shown to donors when they receive your blood requests.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Hospital Name',
                    prefixIcon: const Icon(Icons.local_hospital),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Hospital name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    prefixIcon: const Icon(Icons.location_on),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Location info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.normal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.normal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.normal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Location set to Hyderabad center. GPS-based location picker coming soon.',
                          style: TextStyle(color: AppColors.normal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: AppColors.critical),
                    ),
                  ),

                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: provider.isLoading ? null : _saveProfile,
                  child: const Text('Save Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
