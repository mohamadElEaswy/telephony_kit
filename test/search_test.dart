import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/src/search.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  group('numberSearchPatterns', () {
    test('drops formatting', () {
      expect(numberSearchPatterns('(010) 123-45'), contains('01012345'));
    });

    test('adds a pattern without the trunk 0', () {
      expect(numberSearchPatterns('0100123'), ['0100123', '100123']);
    });

    test('ignores text and single digits', () {
      expect(numberSearchPatterns('Ahmed'), isEmpty);
      expect(numberSearchPatterns('5'), isEmpty);
    });

    test('international numbers are kept as digits', () {
      expect(numberSearchPatterns('+20 100 123'), ['20100123']);
    });
  });

  test('phoneTypeLabel maps Android types and custom labels', () {
    expect(phoneTypeLabel(2, null), 'Mobile');
    expect(phoneTypeLabel(0, 'Office line'), 'Office line');
    expect(phoneTypeLabel(99, null), '');
  });

  test('groupContactRows merges numbers per contact and drops duplicates', () {
    final contacts = groupContactRows([
      {
        'contact_id': '1',
        'display_name': 'Ahmed',
        'data1': '+20 100 123 4567',
        'data2': '2',
        'starred': '1',
      },
      {
        'contact_id': '2',
        'display_name': 'Sara',
        'data1': '0222222222',
        'data2': '1',
      },
      {
        'contact_id': '1',
        'display_name': 'Ahmed',
        'data1': '+201001234567',
        'data2': '2',
      },
      {
        'contact_id': '1',
        'display_name': 'Ahmed',
        'data1': '0233333333',
        'data2': '3',
      },
    ]);
    expect(contacts.map((c) => c.displayName), ['Ahmed', 'Sara']);
    final ahmed = contacts.first;
    expect(ahmed.isStarred, isTrue);
    expect(ahmed.phones.map((p) => p.label), ['Mobile', 'Work']);
    expect(contacts.last.phones.single.label, 'Home');
  });

  test('Contact and ContactPhone print readably', () {
    const phone = ContactPhone(number: '123', label: 'Mobile');
    expect('$phone', '123 (Mobile)');
  });
}
