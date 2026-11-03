import 'package:flutter/material.dart';

// Auth
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/auth/screens/role_selector_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';

// Customer
import '../features/customer/screens/customer_shell.dart';

// Vehicle
import '../features/vehicle/screens/add_vehicle_screen.dart';
import '../features/vehicle/screens/vehicle_details_screen.dart';
import '../models/vehicle_model.dart';
import '../models/service_request_model.dart';
import '../models/bill_model.dart';

// Assistance
import '../features/assistance/screens/request_assistance_screen.dart';
import '../features/assistance/screens/select_problem_screen.dart';
import '../features/assistance/screens/location_confirmation_screen.dart';
import '../features/assistance/screens/cost_estimation_screen.dart';
import '../features/assistance/screens/nearby_providers_screen.dart';
import '../features/assistance/screens/active_assistance_screen.dart';
import '../features/assistance/screens/service_verification_pin_screen.dart';
import '../features/assistance/screens/rating_screen.dart';

// Payment
import '../features/payment/screens/bill_screen.dart';
import '../features/payment/screens/payment_screen.dart';
import '../features/payment/screens/payment_result_screen.dart';
import '../features/payment/screens/receipt_screen.dart';

// Profile
import '../features/profile/screens/complaint_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/customer/screens/notifications_screen.dart';

// Provider
import '../features/provider/screens/provider_shell.dart';
import '../features/provider/screens/provider_availability_screen.dart';
import '../features/provider/screens/request_details_screen.dart';
import '../features/provider/screens/active_job_screen.dart';
import '../features/provider/screens/provider_navigation_screen.dart';
import '../features/provider/screens/provider_service_pin_screen.dart';
import '../features/provider/screens/create_bill_screen.dart';

class AppRoutes {
  AppRoutes._();

  // ── Route Names ──────────────────────────────────────────────────
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String roleSelect = '/role-select';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  static const String customer = '/customer';
  static const String addVehicle = '/add-vehicle';
  static const String vehicleDetails = '/vehicle-details';

  static const String requestAssistance = '/request-assistance';
  static const String costEstimator = '/cost-estimator';
  static const String selectProblem = '/select-problem';
  static const String locationConfirm = '/location-confirm';
  static const String nearbyProviders = '/nearby-providers';
  static const String activeAssistance = '/active-assistance';
  static const String servicePin = '/service-pin';

  static const String bill = '/bill';
  static const String payment = '/payment';
  static const String paymentResult = '/payment-result';
  static const String receipt = '/receipt';
  static const String rating = '/rating';

  static const String complaint = '/complaint';
  static const String profile = '/profile';
  static const String notifications = '/notifications';

  static const String provider = '/provider';
  static const String providerAvailability = '/provider/availability';
  static const String requestDetails = '/request-details';
  static const String activeJob = '/active-job';
  static const String providerNavigation = '/provider/navigation';
  static const String providerServicePin = '/provider/service-pin';
  static const String createBill = '/create-bill';

  // ── Route Generator ──────────────────────────────────────────────
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final name = settings.name;

    if (name == splash) return _slide(const SplashScreen());
    if (name == welcome) return _slide(const WelcomeScreen());
    if (name == roleSelect) return _slide(const RoleSelectorScreen());
    if (name == login) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(LoginScreen(initialRole: args?['role'] as String?));
    }
    if (name == register) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(RegisterScreen(initialRole: args?['role'] as String?));
    }
    if (name == forgotPassword) return _slide(const ForgotPasswordScreen());
    if (name == resetPassword) return _slide(const ResetPasswordScreen());

    if (name == otp) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(OtpScreen(phone: args?['phone'] ?? ''));
    }

    if (name == customer) return _fade(const CustomerShell());
    if (name == addVehicle) return _slide(const AddVehicleScreen());
    if (name == vehicleDetails) {
      final vehicle = settings.arguments as VehicleModel?;
      return _slide(VehicleDetailsScreen(vehicle: vehicle));
    }

    if (name == requestAssistance) return _slide(const RequestAssistanceScreen());
    if (name == costEstimator) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(CostEstimationScreen(
        vehicle: args?['vehicle'] as VehicleModel?,
        initialServiceType: args?['serviceType'] as String?,
      ));
    }
    if (name == selectProblem) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(SelectProblemScreen(
        serviceType: args?['serviceType'] ?? 'Mechanic',
        vehicle: args?['vehicle'] as VehicleModel?,
        estimatedAmount: (args?['estimatedAmount'] as num?)?.toDouble(),
      ));
    }
    if (name == locationConfirm) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(LocationConfirmationScreen(
        serviceType: args?['serviceType'] ?? '',
        problem: args?['problem'] ?? '',
        vehicle: args?['vehicle'] as VehicleModel?,
        estimatedAmount: (args?['estimatedAmount'] as num?)?.toDouble(),
      ));
    }
    if (name == nearbyProviders) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(NearbyProvidersScreen(
        serviceType: args?['serviceType'] ?? '',
        problem: args?['problem'] ?? '',
      ));
    }
    if (name == activeAssistance) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(ActiveAssistanceScreen(
        request: args?['request'] as ServiceRequestModel?,
      ));
    }
    if (name == servicePin) return _slide(const ServiceVerificationPinScreen());

    if (name == bill) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(BillScreen(requestId: args?['requestId'] as String?));
    }
    if (name == payment) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(PaymentScreen(bill: args?['bill'] as BillModel?));
    }
    if (name == paymentResult) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(PaymentResultScreen(
        success: args?['success'] as bool? ?? true,
        amount: (args?['amount'] as num?)?.toDouble(),
        method: args?['method'] as String?,
        transactionId: args?['transactionId'] as String?,
        receiptNumber: args?['receiptNumber'] as String?,
        paymentId: args?['paymentId'] as String?,
        requestId: args?['requestId'] as String?,
      ));
    }
    if (name == receipt) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(ReceiptScreen(
        paymentId: args?['paymentId'] as String?,
        requestId: args?['requestId'] as String?,
      ));
    }
    if (name == rating) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(RatingScreen(
        request: args?['request'] as ServiceRequestModel?,
        requestId: args?['requestId'] as String?,
      ));
    }

    if (name == complaint) return _slide(const ComplaintScreen());
    if (name == profile) return _slide(const ProfileScreen());
    if (name == notifications) return _slide(const NotificationsScreen());

    if (name == provider) return _fade(const ProviderShell());
    if (name == providerAvailability) return _slide(const ProviderAvailabilityScreen());
    if (name == requestDetails) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(RequestDetailsScreen(
        request: args?['request'] as ServiceRequestModel?,
      ));
    }
    if (name == activeJob) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(ActiveJobScreen(
        request: args?['request'] as ServiceRequestModel?,
      ));
    }
    if (name == providerNavigation) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(ProviderNavigationScreen(
        request: args?['request'] as ServiceRequestModel?,
      ));
    }
    if (name == providerServicePin) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(ProviderServicePinScreen(
        request: args?['request'] as ServiceRequestModel?,
      ));
    }
    if (name == createBill) {
      final args = settings.arguments as Map<String, dynamic>?;
      return _slide(CreateBillScreen(
        request: args?['request'] as ServiceRequestModel?,
      ));
    }
    return _slide(_NotFoundScreen(routeName: name ?? ''));
  }

  static PageRouteBuilder _slide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }

  static PageRouteBuilder _fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(opacity: anim, child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  final String routeName;
  const _NotFoundScreen({required this.routeName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Screen not found:\n$routeName', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
