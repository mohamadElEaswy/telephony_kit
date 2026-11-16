import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  group('NetworkGeneration.from', () {
    test('maps radio types', () {
      expect(NetworkGeneration.from(2), NetworkGeneration.g2); // EDGE
      expect(NetworkGeneration.from(15), NetworkGeneration.g3); // HSPA+
      expect(NetworkGeneration.from(13), NetworkGeneration.g4); // LTE
      expect(NetworkGeneration.from(20), NetworkGeneration.g5); // NR
      expect(NetworkGeneration.from(0), NetworkGeneration.unknown);
    });

    test('5G shown over an LTE anchor counts as 5G', () {
      expect(NetworkGeneration.from(13, 3), NetworkGeneration.g5);
      expect(NetworkGeneration.from(13, 5), NetworkGeneration.g5);
      expect(NetworkGeneration.from(13, 1), NetworkGeneration.g4);
    });

    test('labels', () {
      expect(NetworkGeneration.g4.label, '4G');
      expect(NetworkGeneration.unknown.label, '');
    });
  });

  test('NetworkTypeChanged exposes the generation', () {
    const event = NetworkTypeChanged(networkType: 13, overrideType: 3);
    expect(event.generation, NetworkGeneration.g5);
  });

  test('ScreeningAction maps values and defaults to allow', () {
    expect(ScreeningAction.fromValue(2), ScreeningAction.reject);
    expect(ScreeningAction.fromValue(9), ScreeningAction.allow);
  });

  test('ServiceStatus, DeviceCallState and SmsType map values', () {
    expect(ServiceStatus.fromValue(1), ServiceStatus.outOfService);
    expect(DeviceCallState.fromValue(1), DeviceCallState.ringing);
    expect(SmsType.fromValue(2), SmsType.sent);
    expect(SmsType.fromValue(77), SmsType.unknown);
  });

  test('CallLogEntry defaults keep older constructors working', () {
    final entry = CallLogEntry(
      number: '1',
      name: '',
      type: CallLogType.missed,
      date: DateTime(2026),
      duration: Duration.zero,
    );
    expect(entry.id, '');
    expect(entry.isNew, isFalse);
  });
}
