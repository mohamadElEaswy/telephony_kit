import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  test('call states map from Android values', () {
    expect(CallState.fromValue(2), CallState.ringing);
  });
}
