import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  group('PhoneAccount', () {
    test('displayName joins slot and label', () {
      expect(
        const PhoneAccount(id: 'a', label: 'Carrier', slotIndex: 1).displayName,
        'SIM 2 · Carrier',
      );
      expect(
        const PhoneAccount(id: 'a', label: 'Carrier').displayName,
        'Carrier',
      );
      expect(
        const PhoneAccount(id: 'a', label: '', slotIndex: 0).displayName,
        'SIM 1',
      );
    });
  });
}
