import 'package:equatable/equatable.dart';

/// Modelo del usuario autenticado.
class UserModel extends Equatable {
  final int id;
  final String name;
  final String lastName;
  final String email;
  final String? emailVerifiedAt;
  final String createdAt;
  final RoleModel? role;

  const UserModel({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    this.emailVerifiedAt,
    required this.createdAt,
    this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String,
      emailVerifiedAt: json['email_verified_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      role: json['role'] != null
          ? RoleModel.fromJson(json['role'] as Map<String, dynamic>)
          : null,
    );
  }

  String get initials {
    final a = name.trim().isNotEmpty ? name.trim()[0] : '';
    final b = lastName.trim().isNotEmpty ? lastName.trim()[0] : '';
    final result = (a + b).toUpperCase();
    return result.isNotEmpty ? result : 'U';
  }

  String get fullName => '$name $lastName'.trim();
  bool get isAdmin => role?.name == 'administrador';

  @override
  List<Object?> get props => [id, name, lastName, email, role];
}

class RoleModel extends Equatable {
  final int id;
  final String name;

  const RoleModel({required this.id, required this.name});

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
        id: json['id'] as int,
        name: json['name'] as String,
      );

  @override
  List<Object?> get props => [id, name];
}
