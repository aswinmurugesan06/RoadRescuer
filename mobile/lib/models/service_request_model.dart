enum RequestStatus { pending, searching, accepted, arriving, inService, active, completed, cancelled }

extension RequestStatusX on RequestStatus {
  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.searching:
        return 'Searching';
      case RequestStatus.accepted:
        return 'Accepted';
      case RequestStatus.arriving:
        return 'En Route';
      case RequestStatus.inService:
        return 'In Service';
      case RequestStatus.active:
        return 'Active';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  int get colorValue {
    switch (this) {
      case RequestStatus.pending:
      case RequestStatus.searching:
        return 0xFFF9A825;
      case RequestStatus.accepted:
      case RequestStatus.arriving:
      case RequestStatus.inService:
      case RequestStatus.active:
        return 0xFF1565C0;
      case RequestStatus.completed:
        return 0xFF2E7D32;
      case RequestStatus.cancelled:
        return 0xFFC62828;
    }
  }
}

class ServiceRequestModel {
  final String id;
  final String vehiclePlate;
  final String vehicleModel;
  final String? vehicleType;
  final String? vehicleId;
  final String serviceType;
  final String problem;
  final RequestStatus status;
  final DateTime date;
  final String providerName;
  final String? providerId;
  final String? providerMobile;
  final double totalAmount;
  final String location;
  final double? distanceFromProvider;
  final double? customerLatitude;
  final double? customerLongitude;
  final String? customerName;
  final String? customerMobile;
  final String? category;
  final String? customerAddress;
  final String? cancellationReason;
  final String? servicePin;
  final String? damageImageUrl;
  final String? aiDetectedIssue;
  final String? aiSeverity;
  final List<String> visibleIndicators;
  final List<String> requiredTools;
  final List<String> recommendedParts;
  final double? estimatedLaborHours;
  final double? estimatedPartsCost;
  final String? mechanicPrepNote;

  const ServiceRequestModel({
    required this.id,
    required this.vehiclePlate,
    required this.vehicleModel,
    this.vehicleType,
    this.vehicleId,
    required this.serviceType,
    required this.problem,
    required this.status,
    required this.date,
    required this.providerName,
    this.providerId,
    this.providerMobile,
    required this.totalAmount,
    required this.location,
    this.distanceFromProvider,
    this.customerLatitude,
    this.customerLongitude,
    this.customerName,
    this.customerMobile,
    this.category,
    this.customerAddress,
    this.cancellationReason,
    this.servicePin,
    this.damageImageUrl,
    this.aiDetectedIssue,
    this.aiSeverity,
    this.visibleIndicators = const [],
    this.requiredTools = const [],
    this.recommendedParts = const [],
    this.estimatedLaborHours,
    this.estimatedPartsCost,
    this.mechanicPrepNote,
  });

  bool get hasAiDamageReport =>
      (damageImageUrl?.isNotEmpty ?? false) ||
      (aiDetectedIssue?.isNotEmpty ?? false) ||
      visibleIndicators.isNotEmpty ||
      requiredTools.isNotEmpty ||
      recommendedParts.isNotEmpty;

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] as String? ?? 'PENDING').toUpperCase();
    RequestStatus status;
    switch (statusStr) {
      case 'SEARCHING':
        status = RequestStatus.searching;
        break;
      case 'ACCEPTED':
        status = RequestStatus.accepted;
        break;
      case 'ARRIVING':
        status = RequestStatus.arriving;
        break;
      case 'IN_SERVICE':
        status = RequestStatus.inService;
        break;
      case 'ACTIVE':
        status = RequestStatus.active;
        break;
      case 'COMPLETED':
        status = RequestStatus.completed;
        break;
      case 'CANCELLED':
        status = RequestStatus.cancelled;
        break;
      case 'PENDING':
      default:
        status = RequestStatus.pending;
        break;
    }

    final lat = (json['customerLatitude'] as num?)?.toDouble();
    final lng = (json['customerLongitude'] as num?)?.toDouble();
    final addr = json['customerAddress'] as String?;

    String loc = addr ?? '';
    if (loc.isEmpty && lat != null && lng != null) {
      loc = 'GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
    if (loc.isEmpty) {
      loc = json['location'] as String? ?? 'Highway Location';
    }

    final providerData = json['provider'] as Map<String, dynamic>?;
    final customerData = json['customer'] as Map<String, dynamic>?;

    return ServiceRequestModel(
      id: json['id'] as String? ?? '',
      vehiclePlate: json['vehiclePlate'] as String? ?? '',
      vehicleModel: json['vehicleModel'] as String? ?? '',
      vehicleType: json['vehicleType'] as String?,
      vehicleId: json['vehicleId'] as String?,
      serviceType: json['serviceType'] as String? ?? 'Mechanic',
      problem: json['problemDescription'] as String? ??
          json['problem'] as String? ??
          '',
      status: status,
      date: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : (json['date'] != null
              ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
              : DateTime.now()),
      providerName: providerData?['name'] as String? ??
          json['providerName'] as String? ??
          'Assigning...',
      providerId: json['providerId'] as String? ?? providerData?['id'] as String?,
      providerMobile: providerData?['mobile'] as String? ?? json['providerMobile'] as String?,
      totalAmount: (json['estimatedAmount'] as num?)?.toDouble() ??
          (json['totalAmount'] as num?)?.toDouble() ??
          0.0,
      location: loc,
      distanceFromProvider: (json['distanceFromProvider'] as num?)?.toDouble(),
      customerLatitude: lat,
      customerLongitude: lng,
      customerName: customerData?['name'] as String? ?? json['customerName'] as String?,
      customerMobile: customerData?['mobile'] as String? ?? json['customerMobile'] as String?,
      category: json['category'] as String?,
      customerAddress: addr,
      cancellationReason: json['cancellationReason'] as String?,
      servicePin: json['servicePin'] as String?,
      damageImageUrl: json['damageImageUrl'] as String?,
      aiDetectedIssue: json['aiDetectedIssue'] as String?,
      aiSeverity: json['aiSeverity'] as String?,
      visibleIndicators: _stringList(json['visibleIndicators']),
      requiredTools: _stringList(json['requiredTools']),
      recommendedParts: _stringList(json['recommendedParts']),
      estimatedLaborHours:
          (json['estimatedLaborHours'] as num?)?.toDouble(),
      estimatedPartsCost: (json['estimatedPartsCost'] as num?)?.toDouble(),
      mechanicPrepNote: json['mechanicPrepNote'] as String?,
    );
  }

  ServiceRequestModel copyWith({
    String? id,
    String? vehiclePlate,
    String? vehicleModel,
    String? vehicleType,
    String? vehicleId,
    String? serviceType,
    String? problem,
    RequestStatus? status,
    DateTime? date,
    String? providerName,
    String? providerId,
    String? providerMobile,
    double? totalAmount,
    String? location,
    double? distanceFromProvider,
    double? customerLatitude,
    double? customerLongitude,
    String? customerName,
    String? customerMobile,
    String? category,
    String? customerAddress,
    String? cancellationReason,
    String? servicePin,
    String? damageImageUrl,
    String? aiDetectedIssue,
    String? aiSeverity,
    List<String>? visibleIndicators,
    List<String>? requiredTools,
    List<String>? recommendedParts,
    double? estimatedLaborHours,
    double? estimatedPartsCost,
    String? mechanicPrepNote,
  }) {
    return ServiceRequestModel(
      id: id ?? this.id,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceType: serviceType ?? this.serviceType,
      problem: problem ?? this.problem,
      status: status ?? this.status,
      date: date ?? this.date,
      providerName: providerName ?? this.providerName,
      providerId: providerId ?? this.providerId,
      providerMobile: providerMobile ?? this.providerMobile,
      totalAmount: totalAmount ?? this.totalAmount,
      location: location ?? this.location,
      distanceFromProvider: distanceFromProvider ?? this.distanceFromProvider,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      customerName: customerName ?? this.customerName,
      customerMobile: customerMobile ?? this.customerMobile,
      category: category ?? this.category,
      customerAddress: customerAddress ?? this.customerAddress,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      servicePin: servicePin ?? this.servicePin,
      damageImageUrl: damageImageUrl ?? this.damageImageUrl,
      aiDetectedIssue: aiDetectedIssue ?? this.aiDetectedIssue,
      aiSeverity: aiSeverity ?? this.aiSeverity,
      visibleIndicators: visibleIndicators ?? this.visibleIndicators,
      requiredTools: requiredTools ?? this.requiredTools,
      recommendedParts: recommendedParts ?? this.recommendedParts,
      estimatedLaborHours:
          estimatedLaborHours ?? this.estimatedLaborHours,
      estimatedPartsCost: estimatedPartsCost ?? this.estimatedPartsCost,
      mechanicPrepNote: mechanicPrepNote ?? this.mechanicPrepNote,
    );
  }

  String get serviceTypeIcon {
    switch (serviceType) {
      case 'Mechanic':
      case 'Mechanical Repair':
        return '🔧';
      case 'Puncture':
      case 'Tyre & Puncture Service':
        return '🛞';
      case 'Tow':
      case 'Tow Truck / Recovery':
        return '🚚';
      case 'Battery':
      case 'Battery Jump-Start':
        return '🔋';
      case 'Fuel':
      case 'Emergency Fuel Delivery':
        return '⛽';
      default:
        return '🔧';
    }
  }
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
