import 'package:edutrack/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('abc'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('student@kingston.ac.uk'), isNull);
    });
    test('password rules', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('onlyletters'), isNotNull);
      expect(Validators.password('12345678'), isNotNull);
      expect(Validators.password('Passw0rdX'), isNull);
    });
    test('confirm password', () {
      expect(Validators.confirmPassword('x', 'y'), isNotNull);
      expect(Validators.confirmPassword('same', 'same'), isNull);
    });
    test('time and date order', () {
      expect(Validators.timeOrder('10:00', '09:00'), isNotNull);
      expect(Validators.timeOrder('10:00', '10:00'), isNotNull);
      expect(Validators.timeOrder('09:00', '10:30'), isNull);
      expect(Validators.dateOrder(DateTime(2026, 5, 1), DateTime(2026, 1, 1)), isNotNull);
      expect(Validators.dateOrder(DateTime(2026, 1, 1), DateTime(2026, 1, 1)), isNull);
    });
    test('required / maxLen', () {
      expect(Validators.required('  ', 'Title'), 'Title is required');
      expect(Validators.maxLen('abcdef', 3), isNotNull);
      expect(Validators.maxLen('abc', 3), isNull);
    });
  });
}
