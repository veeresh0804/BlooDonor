import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../config/theme/app_theme.dart';
import '../../../config/constants/app_constants.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../logic/hospital_provider.dart';

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  final _storyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitsController = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();

  BloodGroup _bloodGroup = BloodGroup.o;
  RhFactor _rhFactor = RhFactor.positive;
  Urgency _urgency = Urgency.urgent;

  @override
  void dispose() {
    _storyController.dispose();
    _descriptionController.dispose();
    _unitsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<HospitalProvider>();
    final success = await provider.createRequest(
      bloodGroup: _bloodGroup,
      rhFactor: _rhFactor,
      units: int.parse(_unitsController.text.trim()),
      urgency: _urgency,
      patientStory: _storyController.text.trim().isEmpty
          ? null
          : _storyController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood request created! Donors will be notified.'),
          backgroundColor: AppColors.eligible,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HospitalProvider>();

    return LoadingOverlay(
      isLoading: provider.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('New Blood Request')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Blood group selection
                Text(
                  'Blood Group Needed',
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
                    ButtonSegment(value: RhFactor.positive, label: Text('+')),
                    ButtonSegment(value: RhFactor.negative, label: Text('-')),
                  ],
                  selected: {_rhFactor},
                  onSelectionChanged: (selected) {
                    setState(() => _rhFactor = selected.first);
                  },
                ),
                const SizedBox(height: 16),

                // Units
                TextFormField(
                  controller: _unitsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Units Needed',
                    prefixIcon: const Icon(Icons.water_drop),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final n = int.tryParse(value);
                    if (n == null || n < 1) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Urgency
                Text(
                  'Urgency Level',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<Urgency>(
                  segments: const [
                    ButtonSegment(
                      value: Urgency.critical,
                      label: Text('Critical'),
                      icon: Icon(Icons.warning, size: 18),
                    ),
                    ButtonSegment(
                      value: Urgency.urgent,
                      label: Text('Urgent'),
                      icon: Icon(Icons.priority_high, size: 18),
                    ),
                    ButtonSegment(
                      value: Urgency.normal,
                      label: Text('Normal'),
                      icon: Icon(Icons.info_outline, size: 18),
                    ),
                  ],
                  selected: {_urgency},
                  onSelectionChanged: (selected) {
                    setState(() => _urgency = selected.first);
                  },
                ),
                const SizedBox(height: 24),

                // Patient story
                Text(
                  "Patient's Story (optional but powerful)",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This is what donors will read. A human story moves people to act.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _storyController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., "A 7-year-old boy needs O+ for emergency surgery tonight. Please help."',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Additional description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Additional Details (optional)',
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
                  onPressed: provider.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Send Emergency Alert',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
