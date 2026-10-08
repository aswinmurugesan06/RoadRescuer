import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'auth_service.dart';

/// Base URL of the RoadRescue backend WebSocket endpoint.
/// Same host as ApiClient — on Android emulator use 10.0.2.2.
const String _kSocketUrl = 'http://10.89.213.64:3000';

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

/// Singleton Socket.IO service for the RoadRescue app.
///
/// Usage:
///   await SocketService.instance.connect();
///   SocketService.instance.joinRequestRoom(requestId);
///   SocketService.instance.onProviderLocation = (id, lat, lng) { ... };
///   ...
///   SocketService.instance.disconnect();
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  sio.Socket? _socket;
  bool _connecting = false;

  // ── Event Listeners ──────────────────────────────────────────────────
  ProviderLocationCallback? onProviderLocation;
  StatusChangeCallback? onStatusChange;
  NewRequestCallback? onNewRequest;
  RequestCancelledCallback? onRequestCancelled;
  RequestAcceptedCallback? onRequestAccepted;
  BillEventCallback? onBillCreated;
  BillEventCallback? onBillStatus;
  BillEventCallback? onPaymentSuccess;

  // Connection state stream for reactive UI
  final StreamController<bool> _connectedController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectedController.stream;
  bool get isConnected => _socket?.connected ?? false;

  // ── Connect ───────────────────────────────────────────────────────────
  /// Connects the socket using the stored JWT token.
  /// Safe to call multiple times — won't reconnect if already connected.
  Future<void> connect() async {
    if (_socket != null && (_socket!.connected || _connecting)) return;

    final token = await AuthService.getToken();
    if (token == null) return; // Not logged in

    _connecting = true;

    _socket = sio.io(
      _kSocketUrl,
      sio.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      _connecting = false;
      _connectedController.add(true);
    });

    _socket!.onDisconnect((_) {
      _connectedController.add(false);
    });

    _socket!.onConnectError((err) {
      _connecting = false;
      _connectedController.add(false);
    });

    _socket!.onError((err) {
      // Connection errors handled silently; UI reacts to connectionStream
    });

    // ── Inbound events ──────────────────────────────────────────────────

    /// Provider GPS location (customer side)
    _socket!.on('provider:location', (data) {
      if (data is Map && onProviderLocation != null) {
        final requestId = data['requestId'] as String? ?? '';
        final lat = (data['latitude'] as num?)?.toDouble();
        final lng = (data['longitude'] as num?)?.toDouble();
        if (requestId.isNotEmpty && lat != null && lng != null) {
          onProviderLocation!(requestId, lat, lng);
        }
      }
    });

    /// Status change (both sides)
    _socket!.on('request:status', (data) {
      if (data is Map && onStatusChange != null) {
        final requestId = data['requestId'] as String? ?? '';
        final status = data['status'] as String? ?? '';
        if (requestId.isNotEmpty && status.isNotEmpty) {
          onStatusChange!(requestId, status);
        }
      }
    });

    /// New service request available (provider side)
    _socket!.on('request:new', (data) {
      if (data is Map && onNewRequest != null) {
        onNewRequest!(Map<String, dynamic>.from(data));
      }
    });

    /// Request cancelled (both sides)
    _socket!.on('request:cancelled', (data) {
      if (data is Map && onRequestCancelled != null) {
        final requestId = data['requestId'] as String? ?? '';
        final reason = data['cancellationReason'] as String?;
        if (requestId.isNotEmpty) {
          onRequestCancelled!(requestId, reason);
        }
      }
    });

    /// Provider accepted request (customer side)
    _socket!.on('request:accepted', (data) {
      if (data is Map && onRequestAccepted != null) {
        onRequestAccepted!(Map<String, dynamic>.from(data));
      }
    });

    /// Bill created or updated by provider
    _socket!.on('bill:created', (data) {
      if (data is Map && onBillCreated != null) {
        onBillCreated!(Map<String, dynamic>.from(data));
      }
    });

    /// Bill status update (e.g. approved, rejected)
    _socket!.on('bill:status', (data) {
      if (data is Map && onBillStatus != null) {
        onBillStatus!(Map<String, dynamic>.from(data));
      }
    });

    /// Payment completed successfully
    _socket!.on('payment:success', (data) {
      if (data is Map && onPaymentSuccess != null) {
        onPaymentSuccess!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  // ── Disconnect ────────────────────────────────────────────────────────
  /// Gracefully disconnects and removes all listeners.
  void disconnect() {
    _clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connecting = false;
  }

  // ── Room Management ───────────────────────────────────────────────────
  /// Ask the server to join the room for a specific request.
  /// Only authorized participants (customer / assigned provider) will be admitted.
  void joinRequestRoom(String requestId) {
    _socket?.emit('join:request', requestId);
  }

  // ── Provider → Send GPS update ─────────────────────────────────────────
  /// Emits the provider's current GPS to the backend for relay to the customer.
  /// The backend verifies the provider is authorized before relaying.
  void sendProviderLocation({
    required String requestId,
    required double latitude,
    required double longitude,
  }) {
    _socket?.emit('provider:location', {
      'requestId': requestId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // ── Listener Management ───────────────────────────────────────────────
  /// Clears all registered event callbacks (call from screen dispose).
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

  /// Removes event callbacks and unregisters from a specific request room.
  /// Call this from screen dispose to avoid stale callbacks.
  void leaveRequestRoom(String requestId) {
    // Socket.IO rooms are server-side; client simply stops listening.
    // Reassigning to null here ensures stale callbacks aren't invoked.
    onProviderLocation = null;
    onStatusChange = null;
    onRequestCancelled = null;
    onRequestAccepted = null;
    onBillCreated = null;
    onBillStatus = null;
    onPaymentSuccess = null;
  }

  /// Clear only the provider-facing listener (new request feed).
  void clearProviderListeners() {
    onNewRequest = null;
  }
}
