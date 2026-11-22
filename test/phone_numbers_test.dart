import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  group('callingCodeOf', () {
    test('reads 1, 2 and 3 digit codes', () {
      expect(callingCodeOf('+1 650 253 0000'), 1);
      expect(callingCodeOf('+20 100 123 4567'), 20);
      expect(callingCodeOf('+44 20 7946 0000'), 44);
      expect(callingCodeOf('+971 50 123 4567'), 971);
      expect(callingCodeOf('+353 1 234 5678'), 353);
    });

    test('accepts the 00 prefix and formatting', () {
      expect(callingCodeOf('0044 (20) 7946-0000'), 44);
    });

    test('national and invalid numbers have no code', () {
      expect(callingCodeOf('0100 123 4567'), isNull);
      expect(callingCodeOf('+'), isNull);
      expect(callingCodeOf('+abc'), isNull);
      expect(callingCodeOf(''), isNull);
    });
  });

  group('countryOfNumber', () {
    test('finds the country', () {
      final eg = countryOfNumber('+201001234567')!;
      expect(eg.isoCode, 'EG');
      expect(eg.callingCode, 20);
      expect(eg.nationalNumber, '1001234567');
      expect(eg.flag, '🇪🇬');
    });

    test('tells North American countries apart by area code', () {
      expect(countryOfNumber('+1 650 253 0000')!.isoCode, 'US');
      expect(countryOfNumber('+1 416 555 0100')!.isoCode, 'CA');
      expect(countryOfNumber('+1 876 555 0100')!.isoCode, 'JM');
    });

    test('tells Russia and Kazakhstan apart', () {
      expect(countryOfNumber('+7 495 123 4567')!.isoCode, 'RU');
      expect(countryOfNumber('+7 701 123 4567')!.isoCode, 'KZ');
    });

    test('null for national numbers', () {
      expect(countryOfNumber('01001234567'), isNull);
    });
  });

  test('regions and codes', () {
    expect(regionsForCallingCode(44).first, 'GB');
    expect(regionsForCallingCode(9999), isEmpty);
    expect(callingCodeForRegion('eg'), 20);
    expect(callingCodeForRegion('JM'), 1);
    expect(callingCodeForRegion('ZZ'), isNull);
  });

  test('isDialableChar', () {
    for (final c in ['0', '9', '*', '#', '+', ',', ';']) {
      expect(isDialableChar(c), isTrue, reason: c);
    }
    for (final c in [' ', '-', '(', 'a']) {
      expect(isDialableChar(c), isFalse, reason: c);
    }
  });

  group('formattedCursorOffset', () {
    test('keeps the cursor after the same digit', () {
      expect(formattedCursorOffset('0100123', 7, '0100 123'), 8);
      expect(formattedCursorOffset('0100123', 4, '0100 123'), 4);
      expect(formattedCursorOffset('0100123', 5, '0100 123'), 6);
      expect(formattedCursorOffset('0100123', 0, '0100 123'), 0);
    });

    test('ends at the end when digits were dropped', () {
      expect(formattedCursorOffset('12345', 5, '123'), 3);
    });
  });

  group('PhoneNumberInputFormatter', () {
    // Groups digits in fours, like a simple as-you-type formatter.
    String fours(String text) {
      final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
      final parts = <String>[];
      for (var i = 0; i < digits.length; i += 4) {
        parts.add(digits.substring(i, (i + 4).clamp(0, digits.length)));
      }
      return parts.join(' ');
    }

    final formatter = PhoneNumberInputFormatter(format: fours);

    TextEditingValue type(String old, int oldCursor, String text, int cursor) =>
        formatter.formatEditUpdate(
          TextEditingValue(
            text: old,
            selection: TextSelection.collapsed(offset: oldCursor),
          ),
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: cursor),
          ),
        );

    test('formats while typing at the end', () {
      final value = type('1234', 4, '12345', 5);
      expect(value.text, '1234 5');
      expect(value.selection.extentOffset, 6);
    });

    test('keeps the cursor when typing in the middle', () {
      final value = type('1234 5', 2, '12934 5', 3);
      expect(value.text, '1293 45');
      expect(value.selection.extentOffset, 3);
    });

    test('deleting a separator deletes the digit before it', () {
      final value = type('1234 5', 5, '12345', 4);
      expect(value.text, '1235');
      expect(value.selection.extentOffset, 3);
    });

    test('clearing gives an empty value', () {
      expect(type('1', 1, '', 0).text, '');
    });

    test('returns the input when formatting fails', () {
      final failing = PhoneNumberInputFormatter(
        format: (_) => throw StateError('no'),
      );
      final value = failing.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '12'),
      );
      expect(value.text, '12');
    });
  });

  test('PhoneNumberCountry equality', () {
    const a = PhoneNumberCountry(
      isoCode: 'EG',
      callingCode: 20,
      nationalNumber: '1',
    );
    const b = PhoneNumberCountry(
      isoCode: 'EG',
      callingCode: 20,
      nationalNumber: '1',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
