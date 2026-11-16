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

  group('DisconnectCause', () {
    test('maps Android codes', () {
      expect(DisconnectCode.fromValue(7), DisconnectCode.busy);
      expect(DisconnectCode.fromValue(3), DisconnectCode.remote);
      expect(DisconnectCode.fromValue(99), DisconnectCode.unknown);
    });

    test('displayText prefers the label, else a default', () {
      expect(
        const DisconnectCause(code: DisconnectCode.busy).displayText,
        'Busy',
      );
      expect(
        const DisconnectCause(code: DisconnectCode.error).displayText,
        'Call failed',
      );
      expect(
        const DisconnectCause(
          code: DisconnectCode.other,
          label: 'No service',
        ).displayText,
        'No service',
      );
    });

    test('isFailure is true only for problems', () {
      expect(
        const DisconnectCause(code: DisconnectCode.busy).isFailure,
        isTrue,
      );
      expect(
        const DisconnectCause(code: DisconnectCode.error).isFailure,
        isTrue,
      );
      expect(
        const DisconnectCause(code: DisconnectCode.local).isFailure,
        isFalse,
      );
      expect(
        const DisconnectCause(code: DisconnectCode.remote).isFailure,
        isFalse,
      );
    });
  });
}
