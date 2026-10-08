class Validators {
  Validators._();

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone number is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter a valid 10-digit phone number';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length < 2) return 'Name is too short';
    return null;
  }

  static String? plateNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vehicle number is required';
    final regex = RegExp(r'^[A-Z]{2}\s?\d{2}\s?[A-Z]{1,2}\s?\d{4}$');
    if (!regex.hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid vehicle number (e.g. TN 38 AB 1234)';
    }
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'OTP is required';
    if (value.trim().length != 6) return 'Enter the 6-digit OTP';
    return null;
  }

  static String? year(String? value) {
    if (value == null || value.trim().isEmpty) return 'Year is required';
    final y = int.tryParse(value.trim());
    if (y == null) return 'Enter a valid year';
    if (y < 1990 || y > DateTime.now().year) return 'Enter a valid year';
    return null;
  }
}
