class AppConstants {
  AppConstants._();

  // ── App Info ─────────────────────────────────────────────
  static const String appName = 'RoadRescue';
  static const String appTagline = 'Roadside Assistance Platform';
  static const String appVersion = '1.0.0';

  // ── Spacing ──────────────────────────────────────────────
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ── Border Radius ─────────────────────────────────────────
  static const double radiusXS = 4.0;
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;

  // ── Padding ──────────────────────────────────────────────
  static const double pagePadding = 20.0;
  static const double cardPadding = 16.0;

  // ── Icon Sizes ────────────────────────────────────────────
  static const double iconSM = 18.0;
  static const double iconMD = 24.0;
  static const double iconLG = 32.0;
  static const double iconXL = 48.0;

  // ── Button Heights ────────────────────────────────────────
  static const double buttonHeightSM = 40.0;
  static const double buttonHeightMD = 52.0;
  static const double buttonHeightLG = 60.0;

  // ── Animation Durations ───────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMed = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 600);
  static const Duration splashDuration = Duration(seconds: 2);

  // ── Vehicle & Service Types ──────────────────────────────
  static const List<String> vehicleTypes = [
    'Heavy Vehicle',
    'Light Commercial Vehicle',
    'Bus',
    'Car',
    'Van',
    'Auto',
    'Bike',
  ];

  static const List<String> serviceTypes = [
    'Mechanic',
    'Puncture',
    'Tow',
    'Battery',
    'Fuel',
  ];
}
