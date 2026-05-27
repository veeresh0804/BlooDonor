class AppConstants {
  // App
  static const String appName = 'BlooDonor';
  static const String defaultCity = 'Hyderabad';

  // Radar
  static const int defaultRadiusKm = 10;
  static const int maxRadiusKm = 30;
  static const List<int> radiusEscalationSteps = [10, 20, 30];

  // Cooldown (days)
  static const int cooldownWholeBlood = 90;
  static const int cooldownPlatelets = 14;
  static const int cooldownPlasma = 28;
  static const int cooldownDoubleRedCells = 180;

  // Timing
  static const int cancellationWindowMinutes = 3;
  static const int radarEscalationMinutes = 5;

  // Blood groups
  static const List<String> bloodGroups = ['A', 'B', 'AB', 'O'];
  static const List<String> rhFactors = ['+', '-'];

  // Donation types
  static const Map<String, int> donationCooldownDays = {
    'whole_blood': cooldownWholeBlood,
    'platelets': cooldownPlatelets,
    'plasma': cooldownPlasma,
    'double_red_cells': cooldownDoubleRedCells,
  };
}

/// Blood compatibility: donor blood group → list of compatible recipient groups
const Map<String, List<String>> bloodCompatibility = {
  'O-': ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'],
  'O+': ['O+', 'A+', 'B+', 'AB+'],
  'A-': ['A-', 'A+', 'AB-', 'AB+'],
  'A+': ['A+', 'AB+'],
  'B-': ['B-', 'B+', 'AB-', 'AB+'],
  'B+': ['B+', 'AB+'],
  'AB-': ['AB-', 'AB+'],
  'AB+': ['AB+'],
};
