import 'enums.dart';

class BloodRequest {
  final String id;
  final String hospitalId;
  final BloodGroup bloodGroup;
  final RhFactor rhFactor;
  final int units;
  final int unitsFulfilled;
  final Urgency urgency;
  final RequestStatus status;
  final String city;
  final double? lat;
  final double? lng;
  final String? patientStory;
  final String? description;
  final String? cancelReason;
  final int currentRadiusKm;
  final int donorsNotified;
  final DateTime createdAt;
  final DateTime? fulfilledAt;
  final DateTime? cancelledAt;

  BloodRequest({
    required this.id,
    required this.hospitalId,
    required this.bloodGroup,
    required this.rhFactor,
    required this.units,
    this.unitsFulfilled = 0,
    required this.urgency,
    this.status = RequestStatus.active,
    this.city = 'Hyderabad',
    this.lat,
    this.lng,
    this.patientStory,
    this.description,
    this.cancelReason,
    this.currentRadiusKm = 10,
    this.donorsNotified = 0,
    required this.createdAt,
    this.fulfilledAt,
    this.cancelledAt,
  });

  String get bloodGroupLabel =>
      '${bloodGroup.name.toUpperCase()}${rhFactor == RhFactor.positive ? '+' : '-'}';

  factory BloodRequest.fromJson(Map<String, dynamic> json) {
    return BloodRequest(
      id: json['id'],
      hospitalId: json['hospital_id'],
      bloodGroup: BloodGroup.values.byName(json['blood_group']),
      rhFactor: RhFactor.values.byName(json['rh_factor']),
      units: json['units'],
      unitsFulfilled: json['units_fulfilled'] ?? 0,
      urgency: Urgency.values.byName(json['urgency']),
      status: RequestStatus.values.byName(json['status']),
      city: json['city'] ?? 'Hyderabad',
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      patientStory: json['patient_story'],
      description: json['description'],
      cancelReason: json['cancel_reason'],
      currentRadiusKm: json['current_radius_km'] ?? 10,
      donorsNotified: json['donors_notified'] ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      fulfilledAt: json['fulfilled_at'] != null
          ? DateTime.parse(json['fulfilled_at'])
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hospital_id': hospitalId,
      'blood_group': bloodGroup.name,
      'rh_factor': rhFactor.name,
      'units': units,
      'units_fulfilled': unitsFulfilled,
      'urgency': urgency.name,
      'status': status.name,
      'city': city,
      'lat': lat,
      'lng': lng,
      'patient_story': patientStory,
      'description': description,
      'cancel_reason': cancelReason,
      'current_radius_km': currentRadiusKm,
      'donors_notified': donorsNotified,
      'created_at': createdAt.toIso8601String(),
      'fulfilled_at': fulfilledAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
    };
  }
}
