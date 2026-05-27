class HospitalProfile {
  final String id;
  final String userId;
  final String hospitalName;
  final String address;
  final String city;
  final double? lat;
  final double? lng;
  final bool verified;
  final DateTime? verifiedAt;

  HospitalProfile({
    required this.id,
    required this.userId,
    required this.hospitalName,
    required this.address,
    this.city = 'Hyderabad',
    this.lat,
    this.lng,
    this.verified = false,
    this.verifiedAt,
  });

  factory HospitalProfile.fromJson(Map<String, dynamic> json) {
    return HospitalProfile(
      id: json['id'],
      userId: json['user_id'],
      hospitalName: json['hospital_name'],
      address: json['address'],
      city: json['city'] ?? 'Hyderabad',
      lat: json['lat']?.toDouble(),
      lng: json['lng']?.toDouble(),
      verified: json['verified'] ?? false,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'hospital_name': hospitalName,
      'address': address,
      'city': city,
      'lat': lat,
      'lng': lng,
      'verified': verified,
      'verified_at': verifiedAt?.toIso8601String(),
    };
  }
}
