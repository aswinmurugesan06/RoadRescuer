import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase/firestore_helpers.dart';

/// Typed callback for provider GPS location updates.
typedef ProviderLocationCallback = void Function(
  String requestId,
  double latitude,
  double longitude,
);

/// Typed callback for status change events.
typedef StatusChangeCallback = void Function(String requestId, String status);

/// Typed callback for a new available request (received by providers).
typedef NewRequestCallback = void Function(Map<String, dynamic> requestData);

/// Typed callback for request cancellation.
typedef RequestCancelledCallback = void Function(
  String requestId,
  String? reason,
);

/// Typed callback for request accepted (received by customers).
typedef RequestAcceptedCallback = void Function(Map<String, dynamic> data);

/// Typed callback for bill and payment events.
typedef BillEventCallback = void Function(Map<String, dynamic> data);

/// Firestore-backed realtime service.
///
/// This keeps the same public API as the old Socket.IO client, but all events
/// now come from Firestore snapshot listeners. No backend server is required.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _requestSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _paymentSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pendingSub;

  bool _connected = false;
  bool _firstPendingSnapshot = true;
  String? _roomRequestId;

  String? _lastStatus;
  String? _lastProviderId;
  double? _lastProviderLat;
  double? _lastProviderLng;
  final Set<String> _seenPayments = <String>{};
  final Map<String, String> _lastBillStatus = <String, String>{};

  // ── Event Listeners ──────────────────────────────────────────────────
  ProviderLocationCallback? onProviderLocation;
  StatusChangeCallback? onStatusChange;
  NewRequestCallback? onNewRequest;
  RequestCancelledCallback? onRequestCancelled;
  RequestAcceptedCallback? onRequestAccepted;
  BillEventCallback? onBillCreated;
  BillEventCallback? onBillStatus;
  BillEventCallback? onPaymentSuccess;

  final StreamController<bool> _connectedController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectedController.stream;
  bool get isConnected => _connected;

  /// Starts Firestore listeners. Safe to call multiple times.
  Future<void> connect() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (_connected) {
      if (_pendingSub == null) _startPendingListener();
      return;
    }

    _connected = true;
    _connectedController.add(true);
    _startPendingListener();
  }

  void _startPendingListener() {
    _pendingSub?.cancel();
    _firstPendingSnapshot = true;
    _pendingSub = _db
        .collection('serviceRequests')
        .where('status', whereIn: const ['PENDING', 'SEARCHING'])
        .snapshots()
        .listen((snapshot) {
      if (_firstPendingSnapshot) {
        _firstPendingSnapshot = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        if (data['providerId'] != null) continue;
        onNewRequest?.call(firestoreQueryDocToJson(change.doc));
      }
    });
  }

  /// Joins the realtime stream for a service request.
  void joinRequestRoom(String requestId) {
    if (_roomRequestId == requestId) return;
    _cancelRequestListeners();
    _roomRequestId = requestId;
    _lastStatus = null;
    _lastProviderId = null;
    _lastProviderLat = null;
    _lastProviderLng = null;
    _seenPayments.clear();
    _lastBillStatus.clear();

    _requestSub = _db
        .collection('serviceRequests')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data() ?? <String, dynamic>{};

      final status = (data['status'] as String? ?? '').toUpperCase();
      if (status.isNotEmpty && status != _lastStatus) {
        _lastStatus = status;
        onStatusChange?.call(requestId, status);
        if (status == 'CANCELLED') {
          onRequestCancelled?.call(
            requestId,
            data['cancellationReason'] as String?,
          );
        }
      }

      final providerId = data['providerId'] as String?;
      if (providerId != null &&
          providerId.isNotEmpty &&
          providerId != _lastProviderId) {
        _lastProviderId = providerId;
        onRequestAccepted?.call({
          ...firestoreDocToJson(snapshot),
          'requestId': requestId,
        });
      }

      final lat = (data['providerLatitude'] as num?)?.toDouble();
      final lng = (data['providerLongitude'] as num?)?.toDouble();
      if (lat != null && lng != null && (lat != _lastProviderLat || lng != _lastProviderLng)) {
        _lastProviderLat = lat;
        _lastProviderLng = lng;
        onProviderLocation?.call(requestId, lat, lng);
      }
    });

    _billSub = _db
        .collection('bills')
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final bill = firestoreQueryDocToJson(doc);
        final status = (bill['status'] as String? ?? '').toUpperCase();
        if (!_lastBillStatus.containsKey(doc.id)) {
          _lastBillStatus[doc.id] = status;
          onBillCreated?.call({...bill, 'requestId': requestId});
        } else if (_lastBillStatus[doc.id] != status) {
          _lastBillStatus[doc.id] = status;
          onBillStatus?.call({...bill, 'requestId': requestId});
        }
      }
    });

    _paymentSub = _db
        .collection('payments')
        .where('requestId', isEqualTo: requestId)
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        if (_seenPayments.contains(doc.id)) continue;
        final payment = firestoreQueryDocToJson(doc);
        if ((payment['status'] as String? ?? '').toUpperCase() != 'COMPLETED') {
          continue;
        }
        _seenPayments.add(doc.id);
        onPaymentSuccess?.call({...payment, 'requestId': requestId});
      }
    });
  }

  /// Emits the provider's current GPS to the request document.
  void sendProviderLocation({
    required String requestId,
    required double latitude,
    required double longitude,
  }) {
    _db.collection('serviceRequests').doc(requestId).update({
      'providerLatitude': latitude,
      'providerLongitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stops listeners for one request room.
  void leaveRequestRoom(String requestId) {
    if (_roomRequestId == requestId) {
      _cancelRequestListeners();
    }
  }

  void _cancelRequestListeners() {
    _requestSub?.cancel();
    _billSub?.cancel();
    _paymentSub?.cancel();
    _requestSub = null;
    _billSub = null;
    _paymentSub = null;
    _roomRequestId = null;
  }

  /// Clears the provider-facing new-request feed.
  void clearProviderListeners() {
    _pendingSub?.cancel();
    _pendingSub = null;
    onNewRequest = null;
  }

  /// Removes all listeners.
  void disconnect() {
    _cancelRequestListeners();
    _pendingSub?.cancel();
    _pendingSub = null;
    _connected = false;
    _connectedController.add(false);
    _clearListeners();
  }

  void _clearListeners() {
    onProviderLocation = null;
    onStatusChange = null;
    onNewRequest = null;
    onRequestCancelled = null;
    onRequestAccepted = null;
    onBillCreated = null;
    onBillStatus = null;
    onPaymentSuccess = null;
  }
}
