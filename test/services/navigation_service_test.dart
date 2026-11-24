import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/rider/services/navigation_service.dart';

void main() {
  group('NavigationService phone sanitization', () {
    test('normalizes 12-digit Indian number with country code', () {
      expect(NavigationService.sanitizePhone('+919825901508'), '9825901508');
      expect(NavigationService.sanitizePhone('919825901508'), '9825901508');
    });

    test('normalizes 11-digit number with leading zero', () {
      expect(NavigationService.sanitizePhone('09825901508'), '9825901508');
    });

    test('removes spaces, dashes and brackets', () {
      expect(NavigationService.sanitizePhone('(98259) 015-08'), '9825901508');
    });

    test('returns standard 10 digit number untouched', () {
      expect(NavigationService.sanitizePhone('9825901508'), '9825901508');
    });
  });
}

