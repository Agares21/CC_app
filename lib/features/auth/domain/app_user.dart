class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.lastName,
    required this.email,
    required this.isAdmin,
  });
  final int id;
  final String name;
  final String lastName;
  final String email;
  final bool isAdmin;

  String get fullName => '$name $lastName'.trim();

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int,
    name: json['name'] as String,
    lastName: json['last_name'] as String,
    email: json['email'] as String,
    isAdmin: json['is_admin'] as bool? ?? false,
  );
}
