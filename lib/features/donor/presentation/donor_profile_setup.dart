import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/theme/app_theme.dart';
import '../../../config/constants/app_constants.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../logic/donor_provider.dart';

class DonorProfileSetup extends StatefulWidget {
  const DonorProfileSetup({super.key});

  @override
  State<DonorProfileSetup> createState() => _DonorProfileSetupState();
}

class _DonorProfileSetupState extends State<DonorProfileSetup> {
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  BloodGroup _bloodGroup = BloodGroup.o;
  RhFactor _rhFactor = RhFactor.positive;
  int _radiusKm = 10;

  // Default Hyderabad coordinates
  final double _lat = 17.3850;
  final double _lng = 78.4867;

  @override
  void dispose() {
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final provider = context.read<DonorProvider>();
    final success = await provider.saveProfile(
      userId: userId,
      bloodGroup: _bloodGroup,
      rhFactor: _rhFactor,
      lat: _lat,
      lng: _lng,
      radiusKm: _radiusKm,
      emergencyContactName: _emergencyNameController.text.trim().isEmpty
          ? null
          : _emergencyNameController.text.trim(),
      emergencyContactPhone: _emergencyPhoneController.text.trim().isEmpty
          ? null
          : _emergencyPhoneController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DonorProvider>();

    return LoadingOverlay(
      isLoading: provider.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Donor Profile')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.bloodtype, size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Set up your donor profile',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This helps us match you with nearby hospitals when someone needs blood.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Blood group
                Text(
                  'Blood Group',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConstants.bloodGroups.map((group) {
                    final isSelected = _bloodGroup.name == group.toLowerCase();
                    return ChoiceChip(
                      label: Text(group),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _bloodGroup = BloodGroup.values.byName(
                              group.toLowerCase(),
                            );
                          });
                        }
                      },
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Rh factor
                Text(
                  'Rh Factor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<RhFactor>(
                  segments: const [
                    ButtonSegment(
                      value: RhFactor.positive,
                      label: Text('Positive (+)'),
                    ),
                    ButtonSegment(
                      value: RhFactor.negative,
                      label: Text('Negative (-)'),
                    ),
                  ],
                  selected: {_rhFactor},
                  onSelectionChanged: (selected) {
                    setState(() => _rhFactor = selected.first);
                  },
                ),
                const SizedBox(height: 24),

                // Radius preference
                Text(
                  'Alert Radius: $_radiusKm km',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How far you are willing to travel to donate',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Slider(
                  value: _radiusKm.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 5,
                  label: '$_radiusKm km',
                  onChanged: (value) {
                    setState(() => _radiusKm = value.round());
                  },
                ),
                const SizedBox(height: 8),

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
                          'Location set to Hyderabad center. GPS-based location coming soon.',
                          style: TextStyle(color: AppColors.normal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Emergency contact
                Text(
                  'Emergency Contact (optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "We'll notify them when you go to donate",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emergencyNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Contact Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Contact Phone',
                    prefixText: '+91 ',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
