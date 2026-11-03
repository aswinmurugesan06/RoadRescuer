import 'package:url_launcher/url_launcher.dart';

/// Opens the device phone dialer for roadside calls.
class PhoneService {
  PhoneService._();

  /// Returns true when the dialer was opened.
  static Future<bool> call(String? number) async {
    final cleaned = (number ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return false;

    final uri = Uri.parse('tel:$cleaned');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        return await launchUrl(uri);
      } catch (_) {
        return false;
      }
    }
  }
}
