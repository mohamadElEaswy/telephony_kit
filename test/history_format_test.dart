import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  // Fixed offsets keep the tests independent of the machine's time zone.
  const cairo = CallTimeFormatter(utcOffset: Duration(hours: 2));
  const cairo12 = CallTimeFormatter(
    use24HourFormat: false,
    utcOffset: Duration(hours: 2),
  );
  // Wednesday 12 November 2025, 14:05:09 in Cairo (12:05:09 UTC).
  final call = DateTime.utc(2025, 11, 12, 12, 5, 9);
  final sameEvening = DateTime.utc(2025, 11, 12, 20, 0);

  group('CallTimeFormatter', () {
    test('time in 24 and 12 hour formats', () {
      expect(cairo.time(call), '14:05');
      expect(cairo.time(call, seconds: true), '14:05:09');
      expect(cairo12.time(call), '2:05 PM');
      expect(cairo12.time(DateTime.utc(2025, 11, 12, 22, 30)), '12:30 AM');
      expect(cairo12.time(DateTime.utc(2025, 11, 12, 10, 0)), '12:00 PM');
    });

    test('converts to the chosen offset, crossing midnight', () {
      // 23:30 UTC is already the next day at +02:00.
      final late = DateTime.utc(2025, 11, 12, 23, 30);
      expect(cairo.time(late), '01:30');
      expect(cairo.date(late, now: late), '13 Nov');
      const newYork = CallTimeFormatter(utcOffset: Duration(hours: -5));
      expect(newYork.time(late), '18:30');
      expect(newYork.date(late, now: late), '12 Nov');
    });

    test('date shows the year only when it differs', () {
      expect(cairo.date(call, now: sameEvening), '12 Nov');
      expect(cairo.date(call, now: DateTime.utc(2026, 1, 2)), '12 Nov 2025');
      expect(cairo.date(call, now: sameEvening, long: true), '12 November');
      expect(cairo.date(call, now: sameEvening, withYear: true), '12 Nov 2025');
    });

    test('day labels', () {
      expect(cairo.day(call, now: sameEvening), 'Today');
      expect(cairo.day(call, now: DateTime.utc(2025, 11, 13, 9)), 'Yesterday');
      expect(cairo.day(call, now: DateTime.utc(2025, 11, 17, 9)), 'Wednesday');
      expect(cairo.day(call, now: DateTime.utc(2025, 11, 20, 9)), '12 Nov');
    });

    test('relative row labels', () {
      expect(cairo.relative(call, now: sameEvening), '14:05');
      expect(
        cairo.relative(call, now: call.add(const Duration(seconds: 20))),
        '14:05',
      );
      expect(
        cairo.relative(
          call,
          now: call.add(const Duration(seconds: 20)),
          ago: true,
        ),
        'Just now',
      );
      expect(
        cairo.relative(
          call,
          now: call.add(const Duration(minutes: 7)),
          ago: true,
        ),
        '7 min ago',
      );
      expect(
        cairo.relative(call, now: DateTime.utc(2025, 11, 13, 9)),
        'Yesterday',
      );
    });

    test('dateTime and full', () {
      expect(cairo.dateTime(call, now: sameEvening), 'Today, 14:05');
      expect(
        cairo.full(call),
        'Wednesday, 12 November 2025, 14:05:09 GMT+02:00',
      );
      expect(cairo.full(call, timeZone: false), endsWith('14:05:09'));
    });

    test('offset labels', () {
      expect(cairo.offsetLabel(call), 'GMT+02:00');
      const india = CallTimeFormatter(
        utcOffset: Duration(hours: 5, minutes: 30),
      );
      expect(india.offsetLabel(call), 'GMT+05:30');
      const newfoundland = CallTimeFormatter(
        utcOffset: Duration(hours: -3, minutes: -30),
      );
      expect(newfoundland.offsetLabel(call), 'GMT-03:30');
      const utc = CallTimeFormatter(utcOffset: Duration.zero);
      expect(utc.offsetLabel(call), 'GMT');
    });

    test('local time zone by default', () {
      const local = CallTimeFormatter();
      final now = DateTime.now();
      expect(local.offsetAt(now), now.timeZoneOffset);
      expect(local.wallClock(now.toUtc()).hour, now.hour);
    });

    test('durations', () {
      const f = CallTimeFormatter();
      expect(f.duration(Duration.zero), '0:00');
      expect(f.duration(const Duration(seconds: 45)), '0:45');
      expect(f.duration(const Duration(minutes: 12, seconds: 3)), '12:03');
      expect(
        f.duration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
      expect(f.duration(const Duration(seconds: -4)), '0:00');
      expect(f.durationWords(Duration.zero), '0 s');
      expect(f.durationWords(const Duration(seconds: 45)), '45 s');
      expect(f.durationWords(const Duration(minutes: 2)), '2 min');
      expect(
        f.durationWords(const Duration(minutes: 2, seconds: 5)),
        '2 min 5 s',
      );
      expect(
        f.durationWords(const Duration(hours: 1, minutes: 2, seconds: 5)),
        '1 h 2 min',
      );
    });

    test('custom labels', () {
      const arabic = CallTimeFormatter(
        utcOffset: Duration(hours: 2),
        labels: CallTimeLabels(today: 'اليوم', minutes: 'د', seconds: 'ث'),
      );
      expect(arabic.day(call, now: sameEvening), 'اليوم');
      expect(arabic.durationWords(const Duration(seconds: 65)), '1 د 5 ث');
    });
  });

  test('groupByDay splits at local midnight', () {
    final times = [
      DateTime.utc(2025, 11, 12, 23, 30), // 13 Nov 01:30 in Cairo
      DateTime.utc(2025, 11, 12, 20, 0),
      DateTime.utc(2025, 11, 12, 8, 0),
      DateTime.utc(2025, 11, 10, 8, 0),
    ];
    final groups = groupByDay(times, (t) => t, formatter: cairo);
    expect(groups.map((g) => g.value.length), [1, 2, 1]);
    expect(groups.first.key, times.first);
  });

  group('callLogEntryFromRow', () {
    test('reads the base and detail columns', () {
      final e = callLogEntryFromRow({
        '_id': '42',
        'number': '01001234567',
        'name': 'Sara',
        'type': '3',
        'new': '1',
        'date': '${call.millisecondsSinceEpoch}',
        'duration': '0',
        'is_read': '0',
        'formatted_number': '010 01234567',
        'numbertype': '2',
        'numberlabel': null,
        'post_dial_digits': ',123',
        'presentation': '1',
        'block_reason': '0',
        'last_modified': '${call.millisecondsSinceEpoch + 1000}',
      });
      expect(e.id, '42');
      expect(e.type, CallLogType.missed);
      expect(e.isNew, isTrue);
      expect(e.isRead, isFalse);
      expect(e.date.isAtSameMomentAs(call), isTrue);
      expect(e.date.isUtc, isFalse); // shown in local time
      expect(e.numberLabel, 'Mobile');
      expect(e.displayNumber, '010 01234567');
      expect(e.displayName, 'Sara');
      expect(e.postDialDigits, ',123');
      expect(e.presentation, NumberPresentation.allowed);
      expect(e.wasConnected, isFalse);
      expect(e.lastModified, isNotNull);
    });

    test('defaults when detail columns are missing', () {
      final e = callLogEntryFromRow({
        'number': '',
        'type': '1',
        'date': '0',
        'duration': '65',
        'presentation': '2',
      });
      expect(e.formattedNumber, '');
      expect(e.numberLabel, '');
      expect(e.presentation, NumberPresentation.restricted);
      expect(e.endTime.difference(e.date), const Duration(seconds: 65));
      expect(e.wasConnected, isTrue);
      expect(e.lastModified, isNull);
      expect(e.displayName, '');
    });

    test('custom number label', () {
      final e = callLogEntryFromRow({
        'type': '2',
        'numbertype': '0',
        'numberlabel': 'Villa',
      });
      expect(e.numberLabel, 'Villa');
    });
  });

  group('CallHistory', () {
    CallLogEntry entry(
      String id,
      String number,
      CallLogType type,
      int day, {
      int seconds = 0,
      String name = '',
    }) => CallLogEntry(
      id: id,
      number: number,
      name: name,
      type: type,
      date: DateTime.utc(2025, 11, day, 10),
      duration: Duration(seconds: seconds),
    );

    final log = [
      entry('1', '+201001234567', CallLogType.outgoing, 10, seconds: 120),
      entry('2', '01001234567', CallLogType.missed, 12, name: 'Sara'),
      entry('3', '0100 123 4567', CallLogType.incoming, 11, seconds: 30),
      // Contains the digits but is a longer, different number.
      entry('4', '5501001234567999', CallLogType.incoming, 13),
      entry('5', '0222222222', CallLogType.incoming, 9, seconds: 10),
      entry('2', '01001234567', CallLogType.missed, 12), // duplicate row
    ];

    test('keeps the same number in any format, newest first', () {
      final h = CallHistory.from(log, ['010-0123-4567']);
      expect(h.entries.map((e) => e.id), ['2', '3', '1']);
      expect(h.name, 'Sara');
      expect(h.total, 3);
      expect(h.incoming, 1);
      expect(h.outgoing, 1);
      expect(h.missed, 1);
      expect(h.totalDuration, const Duration(seconds: 150));
      expect(h.longestCall?.id, '1');
      expect(h.lastCall?.id, '2');
      expect(h.firstCall?.id, '1');
    });

    test('joins all numbers of a contact', () {
      final h = CallHistory.from(
        log,
        ['01001234567', '02 2222 2222'],
        name: 'Sara Ali',
        contactId: '7',
      );
      expect(h.entries.map((e) => e.id), ['2', '3', '1', '5']);
      expect(h.name, 'Sara Ali');
      expect(h.contactId, '7');
      expect(h.entriesFor('0222222222').map((e) => e.id), ['5']);
    });

    test('hidden numbers match exactly', () {
      final hidden = [
        entry('8', '', CallLogType.incoming, 1),
        entry('9', 'Private', CallLogType.missed, 2),
      ];
      expect(CallHistory.from(hidden, ['Private']).entries.single.id, '9');
      expect(CallHistory.from(hidden, ['']).entries, isEmpty);
    });

    test('empty history', () {
      final h = CallHistory.from(const [], ['123456789']);
      expect(h.total, 0);
      expect(h.lastCall, isNull);
      expect(h.longestCall, isNull);
    });
  });

  test('DeviceTimeZone.inDaylightTime', () {
    const summer = DeviceTimeZone(
      id: 'Africa/Cairo',
      name: 'Eastern European Summer Time',
      shortName: 'EEST',
      offset: Duration(hours: 3),
      standardOffset: Duration(hours: 2),
      usesDaylightTime: true,
    );
    expect(summer.inDaylightTime, isTrue);
  });

  test('CallScreenRequested carries the call id', () {
    const CallEvent event = CallScreenRequested('call-3');
    expect(event, isA<CallScreenRequested>());
    expect((event as CallScreenRequested).callId, 'call-3');
  });
}
