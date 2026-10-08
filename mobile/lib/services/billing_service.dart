import '../models/bill_model.dart';
import 'api_client.dart';

/// Flutter service for billing and payment API interactions.
///
/// All financial amounts come from the backend — the app never
/// passes or trusts a client-calculated amount to the payment API.
class BillingService {
  // ── Bill Retrieval ──────────────────────────────────────────────────────────

  /// Fetch the bill associated with a service request.
  /// Returns null if no bill has been created yet.
  static Future<BillModel?> getBillByRequestId(String requestId) async {
    try {
      final res = await ApiClient.get('/bills/request/$requestId');
      final data = res['data'] as Map<String, dynamic>?;
      return data != null ? BillModel.fromJson(data) : null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Fetch a bill by its own ID.
  static Future<BillModel> getBillById(String billId) async {
    final res = await ApiClient.get('/bills/$billId');
    return BillModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── Bill Status Updates ─────────────────────────────────────────────────────

  /// Customer approves the bill.
  static Future<BillModel> approveBill(String billId) async {
    final res = await ApiClient.patch(
      '/bills/$billId/status',
      body: {'status': 'APPROVED'},
    );
    return BillModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Customer rejects the bill with a required [reason].
  static Future<BillModel> rejectBill(String billId, String reason) async {
    final res = await ApiClient.patch(
      '/bills/$billId/status',
      body: {'status': 'REJECTED', 'rejectionReason': reason},
    );
    return BillModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── Provider — Create/Update Bill ───────────────────────────────────────────

  /// Provider creates or updates the invoice for a service request.
  ///
  /// [items] each must have 'description', 'quantity', and 'unitPrice'.
  static Future<BillModel> createBill({
    required String requestId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'requestId': requestId,
      'items': items,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final res = await ApiClient.post('/bills', body);
    return BillModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── Razorpay Gateway Integration ────────────────────────────────────────────

  /// Create Razorpay payment order on the server.
  /// Amount is strictly calculated on the server from DB.
  static Future<Map<String, dynamic>> createOrder(String billId) async {
    final res = await ApiClient.post('/payments/order', {
      'billId': billId,
    });
    return res['data'] as Map<String, dynamic>;
  }

  /// Verify Razorpay payment signature on the server.
  static Future<Map<String, dynamic>> verifyPayment({
    required String billId,
    required String orderId,
    required String paymentId,
    required String signature,
    String method = 'UPI',
  }) async {
    final res = await ApiClient.post('/payments/verify', {
      'billId': billId,
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
      'method': method,
    });
    return res['data'] as Map<String, dynamic>;
  }

  // ── Payment ─────────────────────────────────────────────────────────────────

  /// Customer pays the bill directly (e.g. Cash on service).
  /// [method] must be one of: UPI, CARD, CASH, NET_BANKING.
  /// Amount is taken from the server — never pass it from the client.
  static Future<Map<String, dynamic>> processPayment({
    required String billId,
    required String method,
  }) async {
    final res = await ApiClient.post('/payments', {
      'billId': billId,
      'method': method,
    });
    return res['data'] as Map<String, dynamic>;
  }

  // ── Receipts ────────────────────────────────────────────────────────────────

  /// Get the digital receipt for a completed payment.
  static Future<ReceiptModel> getReceiptByPaymentId(String paymentId) async {
    final res = await ApiClient.get('/payments/$paymentId/receipt');
    return ReceiptModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  /// Get the digital receipt for a completed payment via request ID.
  static Future<ReceiptModel> getReceiptByRequestId(String requestId) async {
    final res = await ApiClient.get('/payments/request/$requestId/receipt');
    return ReceiptModel.fromJson(res['data'] as Map<String, dynamic>);
  }

  // ── Payment History ─────────────────────────────────────────────────────────

  /// Fetch payment history for the authenticated user from the database.
  static Future<List<PaymentHistoryItem>> getMyPayments() async {
    final res = await ApiClient.get('/payments/my-payments');
    final rawList = res['data'] as List<dynamic>? ?? [];
    return rawList
        .map((e) => PaymentHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Model representing a completed payment history entry.
class PaymentHistoryItem {
  final String id;
  final String paymentId;
  final String transactionId;
  final String receiptNumber;
  final double amount;
  final String method;
  final String status;
  final DateTime paidAt;
  final String requestId;
  final String service;
  final String serviceType;
  final String category;
  final String provider;
  final String providerName;
  final String customerName;
  final String vehicleModel;
  final String vehiclePlate;
  final String location;
  final String? billId;

  const PaymentHistoryItem({
    required this.id,
    required this.paymentId,
    required this.transactionId,
    required this.receiptNumber,
    required this.amount,
    required this.method,
    required this.status,
    required this.paidAt,
    required this.requestId,
    required this.service,
    required this.serviceType,
    required this.category,
    required this.provider,
    required this.providerName,
    required this.customerName,
    required this.vehicleModel,
    required this.vehiclePlate,
    required this.location,
    this.billId,
  });

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is String) return DateTime.tryParse(d) ?? DateTime.now();
      return DateTime.now();
    }

    return PaymentHistoryItem(
      id: json['id'] as String? ?? '',
      paymentId: json['paymentId'] as String? ?? json['id'] as String? ?? '',
      transactionId: json['transactionId'] as String? ?? '',
      receiptNumber: json['receiptNumber'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      method: json['method'] as String? ?? 'UPI',
      status: json['status'] as String? ?? 'Paid',
      paidAt: parseDate(json['paidAt'] ?? json['createdAt']),
      requestId: json['requestId'] as String? ?? '',
      service: json['service'] as String? ?? 'Roadside Assistance',
      serviceType: json['serviceType'] as String? ?? 'Roadside Assistance',
      category: json['category'] as String? ?? 'MECHANIC',
      provider: json['provider'] as String? ?? 'RoadRescue Partner',
      providerName: json['providerName'] as String? ?? 'RoadRescue Partner',
      customerName: json['customerName'] as String? ?? 'Customer',
      vehicleModel: json['vehicleModel'] as String? ?? '',
      vehiclePlate: json['vehiclePlate'] as String? ?? '',
      location: json['location'] as String? ?? '',
      billId: json['billId'] as String?,
    );
  }
}
