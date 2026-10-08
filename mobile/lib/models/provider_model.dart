/// Represents the backend ProviderProfile model returned by /api/providers/profile.
class ProviderProfileData {
  final String id;
  final String userId;
  final String category; // MECHANIC | PUNCTURE | TOW_TRUCK
  final String verificationStatus; // PENDING | APPROVED | REJECTED | SUSPENDED
  final String availability; // OFFLINE | AVAILABLE | BUSY
  final String? garageName;
  final String? businessAddress;
  final double serviceRadiusKm;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int totalJobs;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProviderProfileData({
    required this.id,
    required this.userId,
    required this.category,
    required this.verificationStatus,
    required this.availability,
    this.garageName,
    this.businessAddress,
    required this.serviceRadiusKm,
    this.latitude,
    this.longitude,
    required this.rating,
    required this.totalJobs,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProviderProfileData.fromJson(Map<String, dynamic> json) {
    return ProviderProfileData(
      id: json['id'] as String,
      userId: json['userId'] as String,
      category: json['category'] as String? ?? 'MECHANIC',
      verificationStatus: json['verificationStatus'] as String? ?? 'PENDING',
      availability: json['availability'] as String? ?? 'OFFLINE',
      garageName: json['garageName'] as String?,
      businessAddress: json['businessAddress'] as String?,
      serviceRadiusKm: (json['serviceRadiusKm'] as num?)?.toDouble() ?? 25.0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      totalJobs: json['totalJobs'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  bool get isApproved => verificationStatus == 'APPROVED';
  bool get isAvailable => availability == 'AVAILABLE';
  bool get isBusy => availability == 'BUSY';

  String get categoryLabel {
    switch (category) {
      case 'MECHANIC':
        return 'Mechanic';
      case 'PUNCTURE':
        return 'Puncture & Tyre';
      case 'TOW_TRUCK':
        return 'Tow Truck';
      default:
        return category;
    }
  }

  String get availabilityLabel {
    switch (availability) {
      case 'AVAILABLE':
        return 'Online';
      case 'OFFLINE':
        return 'Offline';
      case 'BUSY':
        return 'On a Job';
      default:
        return availability;
    }
  }
}

/// Full provider account data returned by GET /api/providers/profile.
class ProviderAccountModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String role;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final ProviderProfileData providerProfile;

  const ProviderAccountModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.role,
    required this.isVerified,
    required this.isActive,
    required this.createdAt,
    required this.providerProfile,
  });

  factory ProviderAccountModel.fromJson(Map<String, dynamic> json) {
    return ProviderAccountModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      mobile: json['mobile'] as String,
      role: json['role'] as String,
      isVerified: json['isVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      providerProfile: ProviderProfileData.fromJson(
        json['providerProfile'] as Map<String, dynamic>,
      ),
    );
  }
}

// ── Legacy model kept for existing Phase 2 widgets ─────────────────────
class ProviderModel {
  final String id;
  final String name;
  final String type;
  final double rating;
  final int totalJobs;
  final double distanceKm;
  final String eta;
  final bool isAvailable;
  final String phone;
  final String location;

  const ProviderModel({
    required this.id,
    required this.name,
    required this.type,
    required this.rating,
    required this.totalJobs,
    required this.distanceKm,
    required this.eta,
    required this.isAvailable,
    required this.phone,
    required this.location,
  });

  String get typeIcon {
    switch (type) {
      case 'Mechanic':
        return '🔧';
      case 'Puncture':
        return '🛞';
      case 'Tow':
        return '🚚';
      default:
        return '🔧';
    }
  }

  int get typeColor {
    switch (type) {
      case 'Mechanic':
        return 0xFF1565C0;
      case 'Puncture':
        return 0xFF6A1B9A;
      case 'Tow':
        return 0xFFE65100;
      default:
        return 0xFF1565C0;
    }
  }
}
