// Enum names are serialized with .name and must match the database contract.
// ignore_for_file: constant_identifier_names

enum UserRole { hospital, donor, ngo }

enum BloodGroup { a, b, ab, o }

enum RhFactor { positive, negative }

enum Urgency { critical, urgent, normal }

enum RequestStatus { active, fulfilled, cancelled, escalating }

enum DonorResponseStatus {
  notified,
  accepted,
  on_the_way,
  delayed,
  arrived,
  confirmed,
  donated,
  stepped_back,
  accident,
  missed,
  cooldown_override,
}

enum DonationType { whole_blood, platelets, plasma, double_red_cells }
