import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routes/app_routes.dart';

/// Notification Service for RoadRescue.
///
/// Handles FCM device token lifecycle, backend token synchronization,
/// and notification tap navigation for both Customer and Provider flows.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const String _fcmTokenKey = 'roadrescue_fcm_token';
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String? _currentToken;
  String? get currentToken => _currentToken;

  /// Initialize notification service and synchronize stored FCM token.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentToken = prefs.getString(_fcmTokenKey);

    if (_currentToken != null && _currentToken!.isNotEmpty) {
      // Re-register stored token on app launch if authenticated
      try {
        await registerTokenWithBackend(_currentToken!);
      } catch (_) {
        // Silently ignore if not logged in yet
      }
    }
  }

  /// Register an FCM device token in Firestore.
  ///
  /// Kept under the original name so existing callers continue to work.
  Future<bool> registerTokenWithBackend(
    String token, {
    String deviceType = 'ANDROID',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      _currentToken = token;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);

      await FirebaseFirestore.instance
          .collection('deviceTokens')
          .doc(token)
          .set({
        'userId': user.uid,
        'token': token,
        'deviceType': deviceType.toUpperCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Remove an FCM device token from Firestore on logout.
  Future<void> removeTokenFromBackend([String? token]) async {
    final tokenToRemove = token ?? _currentToken;
    if (tokenToRemove == null || tokenToRemove.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('deviceTokens')
          .doc(tokenToRemove)
          .delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      _currentToken = null;
    } catch (_) {
      // Ignore cleanup errors on logout.
    }
  }

  /// Handle notification click and navigate to the target screen.
  void handleNotificationTap(Map<String, dynamic> data) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final type = data['type'] as String? ?? data['notificationType'] as String?;
    final requestId = data['requestId'] as String?;
    final billId = data['billId'] as String?;
    final paymentId = data['paymentId'] as String?;

    switch (type) {
      case 'NEW_REQUEST_AVAILABLE':
      case 'NEW_REQUEST':
        nav.pushNamed(AppRoutes.requestDetails, arguments: {
          'requestId': requestId,
        });
        break;

      case 'REQUEST_ACCEPTED':
      case 'REQUEST_STATUS_CHANGED':
      case 'REQUEST_STATUS':
        nav.pushNamed(AppRoutes.activeAssistance, arguments: {
          'requestId': requestId,
        });
        break;

      case 'BILL_CREATED':
      case 'BILL_READY':
        nav.pushNamed(AppRoutes.bill, arguments: {
          'requestId': requestId,
          'billId': billId,
        });
        break;

      case 'BILL_APPROVED':
        nav.pushNamed(AppRoutes.requestDetails, arguments: {
          'requestId': requestId,
        });
        break;

      case 'PAYMENT_SUCCESS':
      case 'PAYMENT_RECEIVED':
        nav.pushNamed(AppRoutes.receipt, arguments: {
          'paymentId': paymentId,
          'requestId': requestId,
        });
        break;

      case 'SERVICE_COMPLETED':
        nav.pushNamed(AppRoutes.rating, arguments: {
          'requestId': requestId,
        });
        break;

      case 'RATING_RECEIVED':
        nav.pushNamed(AppRoutes.provider);
        break;

      case 'REQUEST_CANCELLED':
        nav.pushNamed(AppRoutes.customer);
        break;

      default:
        // Default navigation fallback
        break;
    }
  }

  /// Show in-app foreground banner for received push notifications.
  void showInAppNotification(
    BuildContext context, {
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: data != null && data.isNotEmpty
            ? SnackBarAction(
                label: 'VIEW',
                onPressed: () => handleNotificationTap(data),
              )
            : null,
      ),
    );
  }
}
