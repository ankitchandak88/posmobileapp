/// Authenticated user returned by POST /v1/auth/login and GET /v1/me.
class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.branchId,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? branchId;

  bool get isManagerOrOwner => role == 'Manager' || role == 'Owner';
  bool get isStaff => role == 'Staff';
  bool get isRider => role.toLowerCase() == 'rider';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'Staff',
      branchId: json['branch_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    'branch_id': branchId,
  };
}
