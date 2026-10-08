// ignore_for_file: avoid_positional_boolean_parameters

class BillItemModel {
  final String id;
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  const BillItemModel({
    this.id = '',
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory BillItemModel.fromJson(Map<String, dynamic> json) {
    return BillItemModel(
      id: json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BillParticipant {
  final String id;
  final String name;
  final String mobile;

  const BillParticipant({
    required this.id,
    required this.name,
    required this.mobile,
  });

  factory BillParticipant.fromJson(Map<String, dynamic> json) {
    return BillParticipant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      mobile: json['mobile'] as String? ?? '',
    );
  }
}

class BillModel {
  final String id;
  final String requestId;
  final String status; // DRAFT, PENDING, APPROVED, REJECTED, PAID
  final List<BillItemModel> items;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double grandTotal;
  final String? notes;
  final String? rejectionReason;
  final BillParticipant? provider;
  final BillParticipant? customer;

  const BillModel({
    required this.id,
    required this.requestId,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.grandTotal,
    this.notes,
    this.rejectionReason,
    this.provider,
    this.customer,
  });

  /// Display name for the provider in the UI.
  String get providerName => provider?.name ?? 'Service Provider';

  factory BillModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return BillModel(
      id: json['id'] as String? ?? '',
      requestId: json['requestId'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      items: rawItems
          .map((e) => BillItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.18,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      provider: json['provider'] != null
          ? BillParticipant.fromJson(json['provider'] as Map<String, dynamic>)
          : null,
      customer: json['customer'] != null
          ? BillParticipant.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
    );
  }

  static BillModel get mock => const BillModel(
        id: 'mock-bill-001',
        requestId: 'req001',
        status: 'PENDING',
        subtotal: 1980.0,
        taxRate: 0.18,
        taxAmount: 356.4,
        grandTotal: 2336.4,
        notes: 'Vehicle should be serviced again after 5000 km.',
        items: [
          BillItemModel(
            description: 'Engine inspection & diagnosis',
            quantity: 1,
            unitPrice: 350,
            total: 350,
          ),
          BillItemModel(
            description: 'Coolant replacement',
            quantity: 1,
            unitPrice: 480,
            total: 480,
          ),
          BillItemModel(
            description: 'Thermostat replacement',
            quantity: 1,
            unitPrice: 650,
            total: 650,
          ),
          BillItemModel(
            description: 'Labor charges',
            quantity: 1,
            unitPrice: 500,
            total: 500,
          ),
        ],
        provider: BillParticipant(
          id: 'prov-mock',
          name: 'Rajan Auto Works',
          mobile: '+91 99887 76655',
        ),
        customer: BillParticipant(
          id: 'cust-mock',
          name: 'Test Customer',
          mobile: '+91 98765 43210',
        ),
      );
}

// ── Receipt Model ─────────────────────────────────────────────────────────────

class ReceiptModel {
  final String receiptNumber;
  final String transactionId;
  final DateTime? paidAt;
  final double amount;
  final String method;
  final String requestId;
  final String? serviceType;
  final String? location;
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double grandTotal;
  final List<BillItemModel> items;
  final String? notes;
  final BillParticipant? customer;
  final BillParticipant? provider;
  final Map<String, String>? vehicle;

  const ReceiptModel({
    required this.receiptNumber,
    required this.transactionId,
    this.paidAt,
    required this.amount,
    required this.method,
    required this.requestId,
    this.serviceType,
    this.location,
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.grandTotal,
    required this.items,
    this.notes,
    this.customer,
    this.provider,
    this.vehicle,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final rawVehicle = json['vehicle'] as Map<String, dynamic>?;
    return ReceiptModel(
      receiptNumber: json['receiptNumber'] as String? ?? '',
      transactionId: json['transactionId'] as String? ?? '',
      paidAt: json['paidAt'] != null
          ? DateTime.tryParse(json['paidAt'] as String)
          : null,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      method: json['method'] as String? ?? 'UPI',
      requestId: json['requestId'] as String? ?? '',
      serviceType: json['serviceType'] as String?,
      location: json['location'] as String?,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0.18,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0.0,
      items: rawItems
          .map((e) => BillItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      customer: json['customer'] != null
          ? BillParticipant.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      provider: json['provider'] != null
          ? BillParticipant.fromJson(json['provider'] as Map<String, dynamic>)
          : null,
      vehicle: rawVehicle?.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}
