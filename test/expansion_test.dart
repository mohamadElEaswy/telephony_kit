import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/src/analysis.dart' as a;
import 'package:telephony_kit/src/contacts.dart';
import 'package:telephony_kit/telephony_kit.dart';

CallLogEntry _entry(
  String number,
  CallLogType type,
  DateTime date, {
  int seconds = 0,
  String name = '',
}) => CallLogEntry(
  number: number,
  name: name,
  type: type,
  date: date,
  duration: Duration(seconds: seconds),
);

SmsMessage _sms(
  String id,
  String thread,
  String body,
  DateTime date, {
  bool read = true,
  SmsType type = SmsType.inbox,
}) => SmsMessage(
  id: id,
  threadId: thread,
  address: '+20100',
  body: body,
  date: date,
  type: type,
  isRead: read,
);

void main() {
  group('contact IM, relation and SIP fields', () {
    test('are read from data rows', () {
      final c = buildContactDetails(
        {'_id': '1', 'display_name': 'A'},
        [
          {'mimetype': ContactMime.im, 'data1': 'sara.k', 'data5': '3'},
          {
            'mimetype': ContactMime.im,
            'data1': 'x',
            'data5': '-1',
            'data6': 'Signal',
          },
          {'mimetype': ContactMime.relation, 'data1': 'Omar', 'data2': '14'},
          {
            'mimetype': ContactMime.relation,
            'data1': 'Lee',
            'data2': '0',
            'data3': 'Mentor',
          },
          {'mimetype': ContactMime.sip, 'data1': 'sara@sip.example'},
        ],
      );
      expect(c.ims.map((i) => i.protocol), ['Skype', 'Signal']);
      expect(c.relations.map((r) => r.label), ['Spouse', 'Mentor']);
      expect(c.sipAddresses, ['sara@sip.example']);
    });

    test('are written with protocol and type codes', () {
      final rows = contactDataRows(
        const ContactDetails(
          ims: [
            ContactIm(address: 'a', protocol: 'skype'),
            ContactIm(address: 'b', protocol: 'Signal'),
          ],
          relations: [ContactRelation(name: 'Omar', label: 'Spouse')],
          sipAddresses: ['s@x'],
        ),
      );
      expect(rows[0]['data5'], 3);
      expect(rows[1]['data5'], -1);
      expect(rows[1]['data6'], 'Signal');
      expect(rows[2]['data2'], 14);
      expect(rows[3]['mimetype'], ContactMime.sip);
    });

    test('are replaced by updateContact', () {
      expect(
        ContactMime.managed,
        containsAll([ContactMime.im, ContactMime.relation, ContactMime.sip]),
      );
      expect(ContactMime.managed, isNot(contains(ContactMime.groupMembership)));
    });
  });

  group('vCard', () {
    const sara = ContactDetails(
      displayName: 'Sara Ali',
      givenName: 'Sara',
      familyName: 'Ali',
      company: 'Acme, Inc',
      jobTitle: 'CTO',
      phones: [
        ContactPhone(number: '+20 100 123', label: 'Mobile'),
        ContactPhone(number: '0222', label: 'Work fax'),
      ],
      emails: [ContactEmail(address: 's@x.com', label: 'Work')],
      addresses: [ContactAddress(address: '1 Main St\nCairo', label: 'Home')],
      websites: ['https://x.com'],
      sipAddresses: ['s@sip'],
      ims: [ContactIm(address: 'sara.k', protocol: 'Skype')],
      relations: [ContactRelation(name: 'Omar', label: 'Spouse')],
      note: 'line1\nline2; semi',
      birthday: '1990-05-04',
      isStarred: true,
    );

    test('export then import keeps the data', () {
      final text = exportVCard([sara]);
      expect(text, contains('BEGIN:VCARD'));
      expect(text, contains('\r\n'));
      final back = parseVCard(text).single;
      expect(back.displayName, 'Sara Ali');
      expect(back.givenName, 'Sara');
      expect(back.company, 'Acme, Inc');
      expect(back.jobTitle, 'CTO');
      expect(back.phones.map((p) => p.label), ['Mobile', 'Work fax']);
      expect(back.phones.first.number, '+20 100 123');
      expect(back.emails.single.label, 'Work');
      expect(back.addresses.single.address, '1 Main St\nCairo');
      expect(back.websites, ['https://x.com']);
      expect(back.sipAddresses, ['s@sip']);
      expect(back.ims.single.protocol, 'skype');
      expect(back.relations.single.name, 'Omar');
      expect(back.relations.single.label, 'Spouse');
      expect(back.note, 'line1\nline2; semi');
      expect(back.birthday, '1990-05-04');
      expect(back.isStarred, isTrue);
    });

    test('folds long lines and unfolds them again', () {
      final long = 'x' * 200;
      final text = exportVCard([ContactDetails(displayName: 'A', note: long)]);
      expect(text.split('\r\n').every((l) => l.length <= 75), isTrue);
      expect(parseVCard(text).single.note, long);
    });

    test(
      'reads vCard 2.1 with groups, compact birthday and quoted-printable',
      () {
        const vcf =
            'BEGIN:VCARD\nVERSION:2.1\nN:Ali;Sara;;;\nFN:Sara Ali\n'
            'item1.TEL;CELL:0100\nTEL;WORK;VOICE:0222\nBDAY:19900504\n'
            'NOTE;ENCODING=QUOTED-PRINTABLE;CHARSET=UTF-8:=D9=85=D8=B1\n'
            'END:VCARD\n'
            'BEGIN:VCARD\nVERSION:3.0\nEND:VCARD\n';
        final list = parseVCard(vcf);
        expect(list, hasLength(1)); // the empty card is skipped
        expect(list.single.phones.map((p) => p.label), ['Mobile', 'Work']);
        expect(list.single.birthday, '1990-05-04');
        expect(list.single.note, 'مر');
      },
    );

    test('uses the company as the name when nothing else is there', () {
      final c = parseVCard(
        'BEGIN:VCARD\nORG:Acme\nTEL:1234567\nEND:VCARD',
      ).single;
      expect(c.displayName, 'Acme');
    });
  });

  group('call log analysis', () {
    final t = DateTime(2026, 1, 10, 12);
    final entries = [
      _entry('+20 100 123 4567', CallLogType.missed, t, name: 'Sara'),
      _entry(
        '0100 123 4567',
        CallLogType.incoming,
        t.subtract(const Duration(hours: 1)),
        seconds: 60,
      ),
      _entry(
        '0100-123-4567',
        CallLogType.outgoing,
        t.subtract(const Duration(hours: 2)),
        seconds: 30,
      ),
      _entry('555', CallLogType.rejected, t.subtract(const Duration(hours: 3))),
      _entry(
        '0100 123 4567',
        CallLogType.blocked,
        t.subtract(const Duration(days: 1)),
      ),
    ];

    test('stats merge the same number in different formats', () {
      final stats = callLogStats(entries);
      expect(stats, hasLength(2));
      final first = stats.first;
      expect(first.total, 4);
      expect(first.missed, 1);
      expect(first.incoming, 1);
      expect(first.outgoing, 1);
      expect(first.blocked, 1);
      expect(first.name, 'Sara');
      expect(first.totalDuration, const Duration(seconds: 90));
      expect(first.lastCall, t);
      expect(stats.last.rejected, 1);
    });

    test('grouping joins only consecutive entries', () {
      final groups = groupCallLog(entries);
      expect(groups.map((g) => g.entries.length), [3, 1, 1]);
      expect(groups.first.name, 'Sara');
      expect(groups.first.latest.type, CallLogType.missed);
    });

    test('number comparison ignores formatting and country code', () {
      expect(a.sameNumberDigits('+20 100 123 4567', '01001234567'), isTrue);
      expect(a.sameNumberDigits('123', '1234'), isFalse);
      expect(a.sameNumberDigits('', ''), isFalse);
    });

    test('entry feature bits', () {
      final e = CallLogEntry(
        number: '1',
        name: '',
        type: CallLogType.incoming,
        date: t,
        duration: Duration.zero,
        features: 1 | 8 | 32,
      );
      expect(
        [e.hasVideo, e.isWifi, e.isHd, e.isRtt],
        [true, true, false, true],
      );
    });
  });

  group('duplicate contacts', () {
    test('finds same name, shared number and shared email', () {
      final groups = findDuplicateGroups(const [
        ContactDetails(id: '1', displayName: 'Sara Ali'),
        ContactDetails(id: '2', displayName: ' sara  ali '),
        ContactDetails(
          id: '3',
          displayName: 'S',
          phones: [ContactPhone(number: '+20 100 123 4567', label: '')],
        ),
        ContactDetails(
          id: '4',
          displayName: 'Other',
          phones: [ContactPhone(number: '01001234567', label: '')],
        ),
        ContactDetails(
          id: '5',
          displayName: 'Zed',
          emails: [ContactEmail(address: 'Z@X.com')],
        ),
        ContactDetails(
          id: '6',
          displayName: 'Zed Two',
          emails: [ContactEmail(address: 'z@x.com')],
        ),
        ContactDetails(id: '7', displayName: 'Alone'),
      ]);
      final ids = groups.map((g) => g.map((c) => c.id).toList()).toList();
      expect(ids, [
        ['1', '2'],
        ['3', '4'],
        ['5', '6'],
      ]);
    });
  });

  group('SMS threads', () {
    test('groups, counts unread and sorts newest first', () {
      final t = DateTime(2026, 1, 1);
      final threads = groupSmsThreads([
        _sms('1', 'a', 'old', t),
        _sms('2', 'a', 'new', t.add(const Duration(hours: 1)), read: false),
        _sms('3', 'b', 'other', t.add(const Duration(hours: 2))),
        _sms(
          '4',
          'a',
          'sent',
          t.add(const Duration(hours: 3)),
          read: false,
          type: SmsType.sent,
        ),
      ]);
      expect(threads.map((x) => x.threadId), ['a', 'b']);
      expect(threads.first.snippet, 'sent');
      expect(threads.first.messageCount, 3);
      expect(threads.first.unreadCount, 1); // sent messages never count
    });
  });

  group('device data parsing', () {
    test('phone number lines', () {
      final list = a.parsePhoneNumberLines(['3\t0\t+2010', '4\t1\t', 'bad']);
      expect(list, hasLength(2));
      expect(list.first.number, '+2010');
      expect(list.last.number, '');
      expect(list.last.slotIndex, 1);
    });

    test('cell info json treats unknown dBm as null', () {
      final cells = a.parseCellInfoJson(
        '[{"type":"lte","registered":true,"dbm":-95,"level":3,"cellId":42},'
        '{"type":"gsm","registered":false,"dbm":-2147483648,"level":-1,"cellId":-1}]',
      );
      expect(cells.first.dbm, -95);
      expect(cells.first.isRegistered, isTrue);
      expect(cells.last.dbm, isNull);
      expect(a.parseCellInfoJson('{}'), isEmpty);
    });

    test('forwarding USSD codes', () {
      expect(
        a.forwardingUssd(
          CallForwardingCondition.unconditional,
          number: '+20 100',
        ),
        '**21*+20100#',
      );
      expect(
        a.forwardingUssd(CallForwardingCondition.busy, enable: false),
        '##67#',
      );
      expect(
        a.forwardingUssd(CallForwardingCondition.noReply, query: true),
        '*#61#',
      );
      expect(
        () => a.forwardingUssd(CallForwardingCondition.busy),
        throwsArgumentError,
      );
    });

    test('enums map Android values', () {
      expect(NumberVerification.fromValue(1), NumberVerification.passed);
      expect(NumberVerification.fromValue(9), NumberVerification.unknown);
      expect(DataConnectionState.fromValue(2), DataConnectionState.connected);
      expect(DataConnectionState.fromValue(7), DataConnectionState.unknown);
    });

    test('MMS message joins text parts', () {
      final m = MmsMessage(
        id: '1',
        threadId: '1',
        date: DateTime(2026),
        subject: '',
        addresses: const ['+20'],
        isIncoming: true,
        isRead: true,
        parts: const [
          MmsPart(
            id: '1',
            contentType: 'text/plain',
            name: '',
            text: 'hi',
            uri: '',
          ),
          MmsPart(
            id: '2',
            contentType: 'image/jpeg',
            name: 'a.jpg',
            text: '',
            uri: 'u',
          ),
        ],
      );
      expect(m.text, 'hi');
      expect(m.parts.last.isImage, isTrue);
    });
  });
}
