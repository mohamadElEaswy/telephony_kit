import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  group('SmsRequest.fromParts', () {
    test('one recipient with a body', () {
      final r = SmsRequest.fromParts(['+201001234567', 'Hi', '0']);
      expect(r.recipients, ['+201001234567']);
      expect(r.body, 'Hi');
      expect(r.fromNotification, isFalse);
    });

    test('several recipients, encoded and with spaces', () {
      final r = SmsRequest.fromParts(['%2B20100; 0100 123 ;', '', '0']);
      expect(r.recipients, ['+20100', '0100 123']);
    });

    test('from a notification', () {
      final r = SmsRequest.fromParts(['5551234', '', '1']);
      expect(r.fromNotification, isTrue);
      expect('$r', contains('notification: true'));
    });

    test('a stray percent sign is kept', () {
      expect(SmsRequest.fromParts(['100%', '', '0']).recipients, ['100%']);
    });

    test('empty and short input', () {
      expect(SmsRequest.fromParts(const []).recipients, isEmpty);
      expect(SmsRequest.fromParts(const ['']).body, '');
    });
  });
}
