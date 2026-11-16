import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  group('CallState', () {
    test('maps Android values', () {
      expect(CallState.fromValue(1), CallState.dialing);
      expect(CallState.fromValue(2), CallState.ringing);
      expect(CallState.fromValue(4), CallState.active);
      expect(CallState.fromValue(7), CallState.disconnected);
    });

    test('unknown values map to unknown', () {
      expect(CallState.fromValue(999), CallState.unknown);
    });

    test('isLive is false once the call ends', () {
      expect(CallState.active.isLive, isTrue);
      expect(CallState.ringing.isLive, isTrue);
      expect(CallState.disconnected.isLive, isFalse);
      expect(CallState.unknown.isLive, isFalse);
    });
  });

  test('AudioRoute maps Android values', () {
    expect(AudioRoute.fromValue(8), AudioRoute.speaker);
    expect(AudioRoute.fromValue(3), AudioRoute.unknown);
  });

  test('CallLogType maps Android values', () {
    expect(CallLogType.fromValue(3), CallLogType.missed);
    expect(CallLogType.fromValue(42), CallLogType.unknown);
  });

  test('SimState and PhoneType map Android values', () {
    expect(SimState.fromValue(5), SimState.ready);
    expect(PhoneType.fromValue(1), PhoneType.gsm);
  });

  test('TelephonyException has a readable message', () {
    expect(
      const TelephonyException('boom').toString(),
      'TelephonyException: boom',
    );
  });
}
