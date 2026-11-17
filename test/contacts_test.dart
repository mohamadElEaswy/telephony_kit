import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/src/contacts.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  group('buildContactDetails', () {
    test('reads every data kind', () {
      final c = buildContactDetails(
        {
          '_id': '7',
          'lookup': 'abc',
          'display_name': 'Dr Sara Ali',
          'photo_uri': 'content://photo/7',
          'starred': '1',
        },
        [
          {
            'mimetype': ContactMime.name,
            'data2': 'Sara',
            'data3': 'Ali',
            'data4': 'Dr',
            'data5': 'M',
          },
          {'mimetype': ContactMime.phone, 'data1': '+20 100 123', 'data2': '2'},
          {'mimetype': ContactMime.phone, 'data1': '+20100123', 'data2': '3'},
          {
            'mimetype': ContactMime.phone,
            'data1': '0111',
            'data2': '0',
            'data3': 'Gym',
          },
          {'mimetype': ContactMime.email, 'data1': 's@x.com', 'data2': '2'},
          {'mimetype': ContactMime.address, 'data1': '1 Main St', 'data2': '1'},
          {
            'mimetype': ContactMime.organization,
            'data1': 'Acme',
            'data4': 'CTO',
            'data5': 'R&D',
          },
          {'mimetype': ContactMime.nickname, 'data1': 'Sar'},
          {'mimetype': ContactMime.note, 'data1': 'friend'},
          {'mimetype': ContactMime.website, 'data1': 'https://x.com'},
          {'mimetype': ContactMime.event, 'data1': '1990-05-04', 'data2': '3'},
          {'mimetype': ContactMime.event, 'data1': '2020-01-01', 'data2': '1'},
        ],
      );
      expect(c.id, '7');
      expect(c.givenName, 'Sara');
      expect(c.middleName, 'M');
      expect(c.namePrefix, 'Dr');
      expect(c.phones.map((p) => p.number), ['+20 100 123', '0111']);
      expect(c.phones.map((p) => p.label), ['Mobile', 'Gym']);
      expect(c.emails.single.label, 'Work');
      expect(c.addresses.single.label, 'Home');
      expect(c.company, 'Acme');
      expect(c.jobTitle, 'CTO');
      expect(c.department, 'R&D');
      expect(c.nickname, 'Sar');
      expect(c.note, 'friend');
      expect(c.websites, ['https://x.com']);
      expect(c.birthday, '1990-05-04');
      expect(c.photoUri, 'content://photo/7');
      expect(c.isStarred, isTrue);
    });

    test('handles a contact with no data', () {
      final c = buildContactDetails({'_id': '1', 'display_name': 'X'}, []);
      expect(c.phones, isEmpty);
      expect(c.birthday, isNull);
      expect(c.isStarred, isFalse);
    });
  });

  group('contactDataRows', () {
    test('uses the display name when there are no name parts', () {
      final rows = contactDataRows(const ContactDetails(displayName: ' Sara '));
      expect(rows, [
        {'mimetype': ContactMime.name, 'data1': 'Sara'},
      ]);
    });

    test('prefers name parts over the display name', () {
      final rows = contactDataRows(
        const ContactDetails(
          displayName: 'x',
          givenName: 'Sara',
          familyName: 'Ali',
        ),
      );
      expect(rows.single, {
        'mimetype': ContactMime.name,
        'data2': 'Sara',
        'data3': 'Ali',
      });
    });

    test('maps labels to types and keeps custom labels', () {
      final rows = contactDataRows(
        const ContactDetails(
          phones: [
            ContactPhone(number: '1', label: 'work'),
            ContactPhone(number: '2', label: 'Gym'),
            ContactPhone(number: '3', label: ''),
            ContactPhone(number: '  ', label: 'Home'),
          ],
          emails: [ContactEmail(address: 'a@b.c', label: 'Mobile')],
        ),
      );
      expect(rows[0]['data2'], 3);
      expect(rows[1]['data2'], 0);
      expect(rows[1]['data3'], 'Gym');
      expect(rows[2]['data2'], 7);
      expect(
        rows.where((r) => r['mimetype'] == ContactMime.phone),
        hasLength(3),
      );
      expect(rows.last['data2'], 4);
    });

    test('skips blank fields and writes the birthday', () {
      expect(contactDataRows(const ContactDetails()), isEmpty);
      final rows = contactDataRows(const ContactDetails(birthday: '--05-04'));
      expect(rows.single, {
        'mimetype': ContactMime.event,
        'data1': '--05-04',
        'data2': 3,
      });
    });

    test('round trips through buildContactDetails', () {
      const original = ContactDetails(
        givenName: 'Sara',
        phones: [ContactPhone(number: '+201001', label: 'Mobile')],
        emails: [ContactEmail(address: 'a@b.c', label: 'Home')],
        company: 'Acme',
        note: 'hi',
      );
      final data = [
        for (final r in contactDataRows(original))
          {for (final e in r.entries) e.key: e.value.toString()},
      ];
      final back = buildContactDetails({
        '_id': '1',
        'display_name': 'Sara',
      }, data);
      expect(back.phones.single.label, 'Mobile');
      expect(back.emails.single.address, 'a@b.c');
      expect(back.company, 'Acme');
      expect(back.note, 'hi');
    });
  });

  test('copyWith keeps id and photo', () {
    const c = ContactDetails(id: '9', photoUri: 'p', displayName: 'A');
    final d = c.copyWith(displayName: 'B');
    expect(d.id, '9');
    expect(d.photoUri, 'p');
    expect(d.displayName, 'B');
  });
}
