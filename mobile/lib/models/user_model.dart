enum UserRole { customer, provider }

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final bool isVerified;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.isVerified = false,
    this.createdAt,
  });

  static UserModel get mockCustomer => UserModel(
        id: 'u1',
        name: 'Murugan Kumar',
        phone: '+91 98765 43210',
        email: 'murugan@example.com',
        role: UserRole.customer,
        isVerified: true,
        createdAt: DateTime(2025, 1, 15),
      );

  static UserModel get mockProvider => UserModel(
        id: 'p1',
        name: 'Rajan',
        phone: '+91 87654 32109',
        email: 'rajan@example.com',
        role: UserRole.provider,
        isVerified: true,
        createdAt: DateTime(2024, 11, 5),
      );
}
