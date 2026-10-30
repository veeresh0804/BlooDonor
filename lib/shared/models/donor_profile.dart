import 'enums.dart';
import 'parse_utils.dart';

class DonorProfile {
  final String id;
  final String userId;
  final BloodGroup bloodGroup;
  final RhFactor rhFactor;
  final String city;
  final double? lat;
  final double? lng;
  final int radiusKm;
  final bool availability;
  final bool dndMode;
  final DateTime? lastDonationDate;
  final DonationType? donationTypeLast;
  final DateTime? cooldownEndDate;
  final bool cooldownActive;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final int points;

  DonorProfile({
    required this.id,
    required this.userId,
    required this.bloodGroup,
    required this.rhFactor,
    this.city = 'Hyderabad',
    this.lat,
    this.lng,
    this.radiusKm = 10,
    this.availability = true,
    this.dndMode = false,
    this.lastDonationDate,
    this.donationTypeLast,
    this.cooldownEndDate,
    this.cooldownActive = false,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.points = 0,
  });

  String get bloodGroupLabel =>
      '${bloodGroup.name.toUpperCase()}${rhFactor == RhFactor.positive ? '+' : '-'}';

  int? get cooldownDaysRemaining {
    if (!cooldownActive || cooldownEndDate == null) return null;
    final remaining = cooldownEndDate!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  factory DonorProfile.fromJson(Map<String, dynamic> json) {
    return DonorProfile(
      id: json['id'],
      userId: json['user_id'],
      bloodGroup: BloodGroup.values.byName(json['blood_group']),
      rhFactor: RhFactor.values.byName(json['rh_factor']),
      city: json['city'] ?? 'Hyderabad',
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      radiusKm: json['radius_km'] ?? 10,
      availability: json['availability'] ?? true,
      dndMode: json['dnd_mode'] ?? false,
      lastDonationDate: json['last_donation_date'] != null
          ? DateTime.parse(json['last_donation_date'])
          : null,
      donationTypeLast: tryParseEnum(
        DonationType.values,
        json['donation_type_last'],
      ),
      cooldownEndDate: json['cooldown_end_date'] != null
          ? DateTime.parse(json['cooldown_end_date'])
          : null,
      cooldownActive: json['cooldown_active'] ?? false,
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      points: json['points'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'blood_group': bloodGroup.name,
      'rh_factor': rhFactor.name,
      'city': city,
      'lat': lat,
      'lng': lng,
      'radius_km': radiusKm,
      'availability': availability,
      'dnd_mode': dndMode,
      'last_donation_date': lastDonationDate?.toIso8601String(),
      'donation_type_last': donationTypeLast?.name,
      'cooldown_end_date': cooldownEndDate?.toIso8601String(),
      'cooldown_active': cooldownActive,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'points': points,
    };
  }
}
