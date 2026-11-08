/// Pure functions used by form fields - easy to unit test.
class Validators {
  Validators._();

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? maxLen(String? v, int max, [String field = 'This field']) =>
      (v != null && v.trim().length > max) ? '$field must be at most $max characters' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) return 'Include at least one letter';
    if (!RegExp(r'\d').hasMatch(v)) return 'Include at least one number';
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    return v == original ? null : 'Passwords do not match';
  }

  static String? name(String? v) {
    final r = required(v, 'Name');
    if (r != null) return r;
    return v!.trim().length < 2 ? 'Name must be at least 2 characters' : null;
  }

  /// Returns an error if end is not after start ("HH:mm" strings compare lexicographically).
  static String? timeOrder(String start, String end) => end.compareTo(start) > 0 ? null : 'End time must be after start time';

  static String? dateOrder(DateTime start, DateTime end) => end.isBefore(start) ? 'End date must not be before start date' : null;
}
