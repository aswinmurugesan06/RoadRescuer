import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/core/constants/mock_data.dart';
import 'package:road_rescue/core/theme/app_theme.dart';
import 'package:road_rescue/features/assistance/screens/nearby_providers_screen.dart';
import 'package:road_rescue/features/assistance/screens/select_problem_screen.dart';
import 'package:road_rescue/features/assistance/screens/cost_estimation_screen.dart';
import 'package:road_rescue/features/assistance/screens/request_assistance_screen.dart';
import 'package:road_rescue/features/assistance/screens/active_assistance_screen.dart';
import 'package:road_rescue/features/auth/screens/register_screen.dart';
import 'package:road_rescue/features/auth/screens/forgot_password_screen.dart';
import 'package:road_rescue/features/auth/screens/role_selector_screen.dart';
import 'package:road_rescue/features/customer/screens/customer_home_screen.dart';
import 'package:road_rescue/features/provider/screens/provider_home_screen.dart';
import 'package:road_rescue/features/assistance/screens/service_verification_pin_screen.dart';
import 'package:road_rescue/features/auth/screens/login_screen.dart';
import 'package:road_rescue/features/provider/screens/active_job_screen.dart';
import 'package:road_rescue/features/provider/screens/create_bill_screen.dart';
import 'package:road_rescue/features/provider/screens/provider_service_pin_screen.dart';
import 'package:road_rescue/models/service_request_model.dart';

ServiceRequestModel _request() => ServiceRequestModel(
      id: 'req-demo-12345678',
      vehiclePlate: 'TN 38 AB 1234',
      vehicleModel: 'Ashok Leyland 2820',
      vehicleType: 'Heavy Vehicle',
      serviceType: 'Mechanic',
      problem:
          'Engine overheating on the highway shoulder with smoke from the radiator',
      status: RequestStatus.inService,
      date: DateTime.now(),
      providerName: 'Rajan Auto Works',
      providerMobile: '+91 98765 43210',
      totalAmount: 1450,
      location: 'NH 44 Service Road, Krishnagiri, Tamil Nadu',
      customerName: 'Arun Kumar',
      customerMobile: '+91 98765 43210',
      customerLatitude: 12.5186,
      customerLongitude: 78.2137,
      estimatedDistanceKm: 10,
      estimatedDistanceCharge: 75,
      estimatedLaborCharge: 250,
      estimatedLaborHours: 1,
    );

ServiceRequestModel _aiRequest() => _request().copyWith(
      damageImageUrl: 'https://res.cloudinary.com/demo/image/upload/damage.jpg',
      aiDetectedIssue: 'Front left tyre is flat',
      aiSeverity: 'Severe',
      visibleIndicators: const [
        'Tyre is visibly deflated',
        'Nail embedded in the tread',
      ],
      requiredTools: const [
        'Hydraulic jack',
        'Wheel spanner',
        'Tyre levers',
        'Portable inflator',
      ],
      recommendedParts: const [
        'Replacement tyre',
        'Valve stem',
      ],
      estimatedLaborHours: 1.5,
      estimatedPartsCost: 1800,
      mechanicPrepNote:
          'Bring a matching 17-inch tyre and a portable inflator before departing.',
    );

ServiceRequestModel _searchingRequest() => _request().copyWith(
      status: RequestStatus.searching,
      providerName: 'Assigning...',
    );

void main() {
  final realFontAvailable = File(r'C:\Windows\Fonts\segoeui.ttf').existsSync() &&
      File(r'C:\Windows\Fonts\segoeuib.ttf').existsSync();

  if (!realFontAvailable) {
    test(
      'overflow audit needs a real system font',
      () {},
      skip: 'System font not available; widget tests would use Ahem widths.',
    );
    return;
  }

  setUpAll(() async {
    // Widget tests default to the Ahem font, which makes every glyph a square
    // and produces false overflow reports. Use a real system font when present
    // so this audit reflects what users actually see.
    await _loadSystemFont('Plus Jakarta Sans', r'C:\Windows\Fonts\segoeuib.ttf');
    await _loadSystemFont('Plus Jakarta Sans', r'C:\Windows\Fonts\segoeui.ttf');
    await _loadSystemFont('Inter', r'C:\Windows\Fonts\segoeui.ttf');
    await _loadSystemFont('Roboto', r'C:\Windows\Fonts\segoeui.ttf');
  });

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: screen,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final size in const [Size(360, 800), Size(390, 844)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('login has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, const LoginScreen(initialRole: 'CUSTOMER'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('select problem has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        SelectProblemScreen(
          serviceType: 'Mechanic',
          vehicle: MockData.userVehicles.first,
          estimatedAmount: 1149.32,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('provider confirm sheet has no overflow at $label',
        (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        const NearbyProvidersScreen(
          serviceType: 'Mechanic',
          problem: 'Engine overheating on the highway shoulder',
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Rajan Auto Works'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('service PIN screen has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        ProviderServicePinScreen(request: _request()),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('active job has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, ActiveJobScreen(request: _request()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('create bill has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, CreateBillScreen(request: _request()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cost estimator + AI card has no overflow at $label',
        (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        CostEstimationScreen(vehicle: MockData.userVehicles.first),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('provider estimator has no overflow at $label',
        (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        CostEstimationScreen(
          vehicle: MockData.userVehicles.first,
          isProvider: true,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('request assistance + AI card has no overflow at $label',
        (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, const RequestAssistanceScreen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('active assistance + AI report has no overflow at $label',
        (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        ActiveAssistanceScreen(request: _aiRequest()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('register screen has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        const RegisterScreen(initialRole: 'customer'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('role selector has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, const RoleSelectorScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('customer broadcasting banner has no overflow at $label',
        (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        ActiveAssistanceScreen(request: _searchingRequest()),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('forgot password has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, const ForgotPasswordScreen());
      expect(tester.takeException(), isNull);
    });

    testWidgets('customer home has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, const CustomerHomeScreen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('provider home has no overflow at $label', (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, const ProviderHomeScreen());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('customer service PIN has no overflow at $label',
        (tester) async {
      await setSize(tester, size);
      await pumpScreen(
        tester,
        const ServiceVerificationPinScreen(pin: '4829'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('active job AI prep card has no overflow at $label',
        (tester) async {
      await setSize(tester, size);
      await pumpScreen(tester, ActiveJobScreen(request: _aiRequest()));
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _loadSystemFont(String family, String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
