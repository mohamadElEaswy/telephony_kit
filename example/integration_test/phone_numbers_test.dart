// Checks phone number formatting through Android's PhoneNumberUtils on a
// device or emulator:
//
//   flutter test integration_test/phone_numbers_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final t = TelephonyKit.instance;

  testWidgets('defaultCountryIso is a code or empty', (tester) async {
    final iso = t.defaultCountryIso;
    expect(iso.isEmpty || RegExp(r'^[A-Z]{2}$').hasMatch(iso), isTrue);
  });

  testWidgets('formats national and international numbers', (tester) async {
    expect(
      t.formatPhoneNumber('6502530000', countryIso: 'US'),
      '(650) 253-0000',
    );
    expect(
      t.formatPhoneNumber('+442079460000', countryIso: 'US'),
      '+44 20 7946 0000',
    );
    expect(t.formatPhoneNumber('*100#', countryIso: 'EG'), '*100#');
  });

  testWidgets('E.164', (tester) async {
    expect(
      t.phoneNumberToE164('01001234567', countryIso: 'EG'),
      '+201001234567',
    );
    expect(t.phoneNumberToE164('12', countryIso: 'EG'), isNull);
  });

  testWidgets('as you type', (tester) async {
    expect(t.formatPhoneNumberAsYouType('650', countryIso: 'US'), '650');
    expect(
      t.formatPhoneNumberAsYouType('6502530000', countryIso: 'US'),
      '(650) 253-0000',
    );
    expect(
      t.formatPhoneNumberAsYouType('+4420794', countryIso: 'US'),
      '+44 20 794',
    );
    // Repeated calls reuse the formatter without leaking state.
    expect(t.formatPhoneNumberAsYouType('650', countryIso: 'US'), '650');
    expect(t.formatPhoneNumberAsYouType('*#06#', countryIso: 'US'), '*#06#');
  });

  testWidgets('normalize, compare and country', (tester) async {
    expect(t.normalizePhoneNumber('+1 (800) FLOWERS'), '+18003569377');
    expect(
      t.isSamePhoneNumber('01001234567', '+20 100 123 4567', countryIso: 'EG'),
      isTrue,
    );
    expect(
      t.isSamePhoneNumber('01001234567', '01001234568', countryIso: 'EG'),
      isFalse,
    );
    expect(
      t.phoneNumberCountry('01001234567', countryIso: 'EG')?.isoCode,
      'EG',
    );
    expect(t.phoneNumberCountry('+447911123456')?.isoCode, 'GB');
    expect(t.isGlobalPhoneNumber('+20 100 123 4567'), isTrue);
    expect(t.isGlobalPhoneNumber('me@example.com'), isFalse);
  });

  testWidgets('silenceRinger is safe without a ringing call', (tester) async {
    expect(t.silenceRinger(), t.isDefaultDialer);
  });
}
