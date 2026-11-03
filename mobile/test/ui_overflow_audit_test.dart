import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:road_rescue/core/constants/mock_data.dart';
import 'package:road_rescue/core/theme/app_theme.dart';
import 'package:road_rescue/features/assistance/screens/nearby_providers_screen.dart';
import 'package:road_rescue/features/assistance/screens/select_problem_screen.dart';
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
    );

void main() {
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
  }
}
