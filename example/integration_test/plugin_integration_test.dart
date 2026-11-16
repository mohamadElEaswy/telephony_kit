// Runs on an Android device or emulator: flutter test integration_test
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final telephony = TelephonyKit.instance;

  testWidgets('reads network info through JNI', (tester) async {
    final info = telephony.getNetworkInfo();
    expect(info.slotCount, greaterThanOrEqualTo(0));
  });

  testWidgets('reports dialer role without throwing', (tester) async {
    expect(telephony.isDefaultDialer, isA<bool>());
  });

  testWidgets('no calls are tracked when not the default dialer', (
    tester,
  ) async {
    if (!telephony.isDefaultDialer) {
      expect(telephony.calls, isEmpty);
    }
  });
}
