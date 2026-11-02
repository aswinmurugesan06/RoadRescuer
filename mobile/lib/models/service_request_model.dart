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
  });

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
    final vehicleData = json['vehicle'] as Map<String, dynamic>?;
    final billData = json['bill'] as Map<String, dynamic>?;
    final paymentsList = json['payments'] as List<dynamic>?;

    final vehicleModel = json['vehicleModel'] as String? ??
        vehicleData?['model'] as String? ??
        '';
    final vehiclePlate = json['vehiclePlate'] as String? ??
        vehicleData?['plateNumber'] as String? ??
        '';
    final vehicleType = json['vehicleType'] as String? ??
        vehicleData?['type'] as String?;

    final dateParsed = json['completedAt'] != null
        ? DateTime.tryParse(json['completedAt'] as String) ?? DateTime.now()
        : (json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : (json['date'] != null
                ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
                : DateTime.now()));

    final totalAmountParsed = (json['finalAmount'] as num?)?.toDouble() ??
        (json['totalAmount'] as num?)?.toDouble() ??
        (billData?['grandTotal'] as num?)?.toDouble() ??
        (paymentsList != null && paymentsList.isNotEmpty
            ? ((paymentsList[0] as Map<String, dynamic>?)?['amount'] as num?)?.toDouble()
            : null) ??
        (json['estimatedAmount'] as num?)?.toDouble() ??
        0.0;

    return ServiceRequestModel(
      id: json['id'] as String? ?? '',
      vehiclePlate: vehiclePlate,
      vehicleModel: vehicleModel,
      vehicleType: vehicleType,
      vehicleId: json['vehicleId'] as String?,
      serviceType: json['serviceType'] as String? ?? 'Mechanic',
      problem: json['problemDescription'] as String? ??
          json['problem'] as String? ??
          '',
      status: status,
      date: dateParsed,
      providerName: providerData?['name'] as String? ??
          json['providerName'] as String? ??
          'Assigning...',
      providerId: json['providerId'] as String? ?? providerData?['id'] as String?,
      providerMobile: providerData?['mobile'] as String? ?? json['providerMobile'] as String?,
      totalAmount: totalAmountParsed,
      location: loc,
      distanceFromProvider: (json['distanceFromProvider'] as num?)?.toDouble(),
      customerLatitude: lat,
      customerLongitude: lng,
      customerName: customerData?['name'] as String? ?? json['customerName'] as String?,
      customerMobile: customerData?['mobile'] as String? ?? json['customerMobile'] as String?,
      category: json['category'] as String?,
      customerAddress: addr,
      cancellationReason: json['cancellationReason'] as String?,
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
