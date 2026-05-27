import 'enums.dart';

class User {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final UserRole role;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      role: UserRole.values.byName(json['role']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role.name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
