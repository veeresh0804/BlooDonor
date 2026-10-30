import 'enums.dart';
import 'parse_utils.dart';

class DonorResponse {
  final String id;
  final String requestId;
  final String donorId;
  final DonorResponseStatus status;
  final bool isCooldownOverride;
  final int? cooldownDaysRemaining;
  final bool? healthCheckPassed;
  final bool familyNotified;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? donatedAt;
  final DateTime createdAt;

  DonorResponse({
    required this.id,
    required this.requestId,
    required this.donorId,
    required this.status,
    this.isCooldownOverride = false,
    this.cooldownDaysRemaining,
    this.healthCheckPassed,
    this.familyNotified = false,
    this.acceptedAt,
    this.arrivedAt,
    this.donatedAt,
    required this.createdAt,
  });

  factory DonorResponse.fromJson(Map<String, dynamic> json) {
    return DonorResponse(
      id: json['id'],
      requestId: json['request_id'],
      donorId: json['donor_id'],
      status: parseEnumOr(
        DonorResponseStatus.values,
        json['status'],
        DonorResponseStatus.notified,
        field: 'donor_responses.status',
      ),
      isCooldownOverride: json['is_cooldown_override'] ?? false,
      cooldownDaysRemaining: json['cooldown_days_remaining'],
      healthCheckPassed: json['health_check_passed'],
      familyNotified: json['family_notified'] ?? false,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'])
          : null,
      donatedAt: json['donated_at'] != null
          ? DateTime.parse(json['donated_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'donor_id': donorId,
      'status': status.name,
      'is_cooldown_override': isCooldownOverride,
      'cooldown_days_remaining': cooldownDaysRemaining,
      'health_check_passed': healthCheckPassed,
      'family_notified': familyNotified,
      'accepted_at': acceptedAt?.toIso8601String(),
      'arrived_at': arrivedAt?.toIso8601String(),
      'donated_at': donatedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
