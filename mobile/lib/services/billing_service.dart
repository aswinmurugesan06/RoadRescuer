import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/bill_model.dart';
import 'api_client.dart';
import 'firebase/firestore_helpers.dart';

/// Firestore-backed billing and payment service.
///
/// Bills live in `bills`, payments in `payments`. Financial totals are
/// calculated here from the bill items (there is no separate backend).
class BillingService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const double _taxRate = 0.18;

  // ── Bill Retrieval ────────────────────────────────────────────────────

  static Future<BillModel?> getBillByRequestId(String requestId) async {
    final snapshot = await _db
        .collection('bills')
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return BillModel.fromJson(firestoreQueryDocToJson(snapshot.docs.first));
  }

  static Future<BillModel> getBillById(String billId) async {
    final doc = await _db.collection('bills').doc(billId).get();
    if (!doc.exists) throw notFound('Bill');
    return BillModel.fromJson(firestoreDocToJson(doc));
  }

  // ── Bill Status Updates ───────────────────────────────────────────────

  static Future<BillModel> approveBill(String billId) async {
    await _db.collection('bills').doc(billId).update({
      'status': 'APPROVED',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return getBillById(billId);
  }

  static Future<BillModel> rejectBill(String billId, String reason) async {
    await _db.collection('bills').doc(billId).update({
      'status': 'REJECTED',
      'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return getBillById(billId);
  }

  // ── Provider — Create/Update Bill ─────────────────────────────────────

  /// Provider creates the invoice for a service request.
  static Future<BillModel> createBill({
    required String requestId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final uid = currentUid;
    final provider = await currentProfileJson();
    if (provider == null) throw notFound('Provider profile');

    final requestDoc =
        await _db.collection('serviceRequests').doc(requestId).get();
    if (!requestDoc.exists) throw notFound('Service request');
    final request = requestDoc.data() ?? <String, dynamic>{};

    final customerId = request['customerId'] as String? ?? '';
    final customer = customerId.isEmpty ? null : await userJson(customerId);

    final normalizedItems = <Map<String, dynamic>>[];
    var subtotal = 0.0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
      final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
      final total = quantity * unitPrice;
      subtotal += total;
      normalizedItems.add({
        'id': 'item_$i',
        'description': item['description'] ?? '',
        'quantity': quantity,
        'unitPrice': unitPrice,
        'total': total,
      });
    }

    final taxAmount = subtotal * _taxRate;
    final grandTotal = subtotal + taxAmount;
    final doc = _db.collection('bills').doc();
    final now = FieldValue.serverTimestamp();

    await doc.set({
      'requestId': requestId,
      'providerId': uid,
      'customerId': customerId,
      'status': 'PENDING',
      'items': normalizedItems,
      'subtotal': subtotal,
      'taxRate': _taxRate,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'provider': {
        'id': uid,
        'name': provider['name'] ?? 'Service Provider',
        'mobile': provider['mobile'] ?? '',
      },
      'customer': {
        'id': customerId,
        'name': customer?['name'] ?? request['customerName'] ?? 'Customer',
        'mobile': customer?['mobile'] ?? request['customerMobile'] ?? '',
      },
      'createdAt': now,
      'updatedAt': now,
    });

    await requestDoc.reference.update({
      'finalAmount': grandTotal,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return getBillById(doc.id);
  }

  // ── Payment gateway (client-side simulation) ──────────────────────────

  /// Returns a local order id. Firestore records the actual payment.
  static Future<Map<String, dynamic>> createOrder(String billId) async {
    final bill = await getBillById(billId);
    return {
      'orderId': 'firestore_${billId}_${DateTime.now().millisecondsSinceEpoch}',
      'amount': bill.grandTotal,
      'currency': 'INR',
    };
  }

  /// Record a completed payment and mark the bill paid.
  static Future<Map<String, dynamic>> verifyPayment({
    required String billId,
    required String orderId,
    required String paymentId,
    required String signature,
    String method = 'UPI',
  }) async {
    return processPayment(billId: billId, method: method);
  }

  /// Customer pays the bill.
  static Future<Map<String, dynamic>> processPayment({
    required String billId,
    required String method,
  }) async {
    final bill = await getBillById(billId);
    if (bill.status == 'PAID') {
      throw const ApiException(
        statusCode: 409,
        message: 'This bill has already been paid.',
      );
    }

    final uid = currentUid;
    final customer = await currentProfileJson();
    final requestDoc =
        await _db.collection('serviceRequests').doc(bill.requestId).get();
    final request = requestDoc.data() ?? <String, dynamic>{};
    final providerId = request['providerId'] as String? ?? '';
    final provider = providerId.isEmpty ? null : await userJson(providerId);

    final paymentDoc = _db.collection('payments').doc();
    final now = FieldValue.serverTimestamp();
    final transactionId =
        'TXN${DateTime.now().millisecondsSinceEpoch}${paymentDoc.id.substring(0, 4)}';
    final receiptNumber =
        'RR-${DateTime.now().year}-${paymentDoc.id.substring(0, 6).toUpperCase()}';

    await _db.runTransaction((transaction) async {
      transaction.set(paymentDoc, {
        'billId': billId,
        'requestId': bill.requestId,
        'customerId': uid,
        'providerId': providerId,
        'amount': bill.grandTotal,
        'method': method.toUpperCase(),
        'status': 'COMPLETED',
        'transactionId': transactionId,
        'receiptNumber': receiptNumber,
        'paidAt': now,
        'customerName': customer?['name'] ?? bill.customer?.name ?? 'Customer',
        'providerName':
            provider?['name'] ?? bill.provider?.name ?? 'Service Provider',
        'vehicleModel': request['vehicleModel'] ?? '',
        'vehiclePlate': request['vehiclePlate'] ?? '',
        'location': request['customerAddress'] ??
            'GPS: ${(request['customerLatitude'] as num?)?.toStringAsFixed(4) ?? ''}, '
                '${(request['customerLongitude'] as num?)?.toStringAsFixed(4) ?? ''}',
        'serviceType': request['serviceType'] ?? 'Roadside Assistance',
        'category': request['category'] ?? 'MECHANIC',
        'createdAt': now,
        'updatedAt': now,
      });
      transaction.update(_db.collection('bills').doc(billId), {
        'status': 'PAID',
        'updatedAt': now,
      });
    });

    final payment = await paymentDoc.get();
    return {
      'payment': firestoreDocToJson(payment),
      'bill': bill.toJson(),
    };
  }

  // ── Receipts ──────────────────────────────────────────────────────────

  static Future<ReceiptModel> getReceiptByPaymentId(String paymentId) async {
    final paymentDoc = await _db.collection('payments').doc(paymentId).get();
    if (!paymentDoc.exists) throw notFound('Payment');
    return _receiptFromPayment(firestoreDocToJson(paymentDoc));
  }

  static Future<ReceiptModel> getReceiptByRequestId(String requestId) async {
    final snapshot = await _db
        .collection('payments')
        .where('requestId', isEqualTo: requestId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) throw notFound('Receipt');
    return _receiptFromPayment(firestoreQueryDocToJson(snapshot.docs.first));
  }

  static Future<ReceiptModel> _receiptFromPayment(
    Map<String, dynamic> payment,
  ) async {
    final billId = payment['billId'] as String? ?? '';
    if (billId.isEmpty) throw notFound('Bill');

    final billDoc = await _db.collection('bills').doc(billId).get();
    if (!billDoc.exists) throw notFound('Bill');
    final bill = firestoreDocToJson(billDoc);

    final requestId = payment['requestId'] as String? ?? '';
    Map<String, dynamic> request = <String, dynamic>{};
    if (requestId.isNotEmpty) {
      final requestDoc =
          await _db.collection('serviceRequests').doc(requestId).get();
      if (requestDoc.exists) request = firestoreDocToJson(requestDoc);
    }

    return ReceiptModel.fromJson({
      'receiptNumber': payment['receiptNumber'] ?? '',
      'transactionId': payment['transactionId'] ?? '',
      'paidAt': payment['paidAt'] ?? payment['createdAt'],
      'amount': payment['amount'] ?? bill['grandTotal'] ?? 0,
      'method': payment['method'] ?? 'UPI',
      'requestId': requestId,
      'serviceType': payment['serviceType'] ?? request['serviceType'],
      'location': payment['location'] ?? request['customerAddress'],
      'subtotal': bill['subtotal'] ?? 0,
      'taxRate': bill['taxRate'] ?? _taxRate,
      'taxAmount': bill['taxAmount'] ?? 0,
      'grandTotal': bill['grandTotal'] ?? 0,
      'items': bill['items'] ?? [],
      'notes': bill['notes'],
      'customer': bill['customer'],
      'provider': bill['provider'],
      'vehicle': {
        'model': request['vehicleModel'] ?? payment['vehicleModel'] ?? '',
        'plate': request['vehiclePlate'] ?? payment['vehiclePlate'] ?? '',
      },
    });
  }

  // ── Payment History ───────────────────────────────────────────────────

  static Future<List<PaymentHistoryItem>> getMyPayments() async {
    final uid = currentUid;
    final snapshot = await _db
        .collection('payments')
        .where('customerId', isEqualTo: uid)
        .limit(100)
        .get();

    final payments = snapshot.docs.map(firestoreQueryDocToJson).toList();
    payments.sort((a, b) {
      final aDate = DateTime.tryParse(
              (a['paidAt'] ?? a['createdAt'])?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = DateTime.tryParse(
              (b['paidAt'] ?? b['createdAt'])?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });

    return payments.map((payment) {
      return PaymentHistoryItem.fromJson({
        ...payment,
        'paymentId': payment['id'],
        'service': payment['serviceType'],
      });
    }).toList();
  }
}

extension on BillModel {
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestId': requestId,
      'status': status,
      'items': items
          .map((item) => {
                'id': item.id,
                'description': item.description,
                'quantity': item.quantity,
                'unitPrice': item.unitPrice,
                'total': item.total,
              })
          .toList(),
      'subtotal': subtotal,
      'taxRate': taxRate,
      'taxAmount': taxAmount,
      'grandTotal': grandTotal,
      'notes': notes,
      'rejectionReason': rejectionReason,
    };
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
