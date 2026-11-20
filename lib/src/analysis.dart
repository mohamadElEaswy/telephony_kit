// Pure Dart helpers that turn raw rows into call log statistics, grouped
// lists, duplicate contacts, SMS threads and parsed device data. Kept apart
// from the Android calls so they can be unit tested.

import 'dart:convert';

import 'models.dart';
import 'search.dart' show phoneTypeLabel;

/// The number reduced to digits (and a leading plus) for comparing numbers.
String normalizedNumber(String number) =>
    number.replaceAll(RegExp(r'[^0-9]'), '');

/// Whether two numbers are the same, ignoring formatting and treating a
/// leading `0` and a country code as equal (compares the last 9 digits when
/// both are long enough).
bool sameNumberDigits(String a, String b) {
  final x = normalizedNumber(a), y = normalizedNumber(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  final xs = x.replaceFirst(RegExp('^0+'), '');
  final ys = y.replaceFirst(RegExp('^0+'), '');
  if (xs.length < 7 || ys.length < 7) return false;
  return xs.endsWith(ys) || ys.endsWith(xs);
}

/// Builds a [CallLogEntry] from a call log provider row (column name to
/// text). Missing detail columns keep their defaults.
CallLogEntry callLogEntryFromRow(Map<String, String?> row) {
  int? number(String column) => int.tryParse(row[column] ?? '');
  String text(String column) => row[column] ?? '';
  final labelType = number('numbertype');
  final modified = number('last_modified');
  return CallLogEntry(
    id: text('_id'),
    isNew: row['new'] == '1' && row['type'] == '3',
    number: text('number'),
    name: text('name'),
    type: CallLogType.fromValue(number('type') ?? -1),
    // Android stores UTC milliseconds; this is the same moment in the
    // device's local time zone.
    date: DateTime.fromMillisecondsSinceEpoch(number('date') ?? 0),
    duration: Duration(seconds: number('duration') ?? 0),
    geocodedLocation: text('geocoded_location'),
    subscriptionId: number('subscription_id'),
    features: number('features') ?? 0,
    isRead: row['is_read'] != '0',
    countryIso: text('countryiso'),
    formattedNumber: text('formatted_number'),
    numberLabel: labelType == null
        ? ''
        : phoneTypeLabel(labelType, row['numberlabel']),
    postDialDigits: text('post_dial_digits'),
    viaNumber: text('via_number'),
    presentation: NumberPresentation.fromValue(number('presentation') ?? 1),
    lookupUri: row['lookup_uri'],
    voicemailUri: row['voicemail_uri'],
    transcription: text('transcription'),
    blockReason: number('block_reason') ?? 0,
    screeningAppName: text('call_screening_app_name'),
    lastModified: modified == null || modified <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(modified),
  );
}

/// Counts calls per number. Returns the numbers with the most calls first.
List<CallLogNumberStats> callLogStats(Iterable<CallLogEntry> entries) {
  final byKey = <String, List<CallLogEntry>>{};
  for (final e in entries) {
    final digits = normalizedNumber(e.number);
    final key = digits.length >= 9
        ? digits.substring(digits.length - 9)
        : (digits.isEmpty ? e.number : digits);
    byKey.putIfAbsent(key, () => []).add(e);
  }
  final stats = <CallLogNumberStats>[];
  for (final list in byKey.values) {
    var incoming = 0, outgoing = 0, missed = 0, rejected = 0, blocked = 0;
    var talk = Duration.zero;
    var last = list.first.date;
    var name = '';
    for (final e in list) {
      switch (e.type) {
        case CallLogType.incoming:
          incoming++;
        case CallLogType.outgoing:
          outgoing++;
        case CallLogType.missed:
          missed++;
        case CallLogType.rejected:
          rejected++;
        case CallLogType.blocked:
          blocked++;
        default:
      }
      talk += e.duration;
      if (e.date.isAfter(last)) last = e.date;
      if (name.isEmpty) name = e.name;
    }
    stats.add(
      CallLogNumberStats(
        number: list.first.number,
        name: name,
        total: list.length,
        incoming: incoming,
        outgoing: outgoing,
        missed: missed,
        rejected: rejected,
        blocked: blocked,
        totalDuration: talk,
        lastCall: last,
      ),
    );
  }
  stats.sort((a, b) {
    final c = b.total.compareTo(a.total);
    return c != 0 ? c : b.lastCall.compareTo(a.lastCall);
  });
  return stats;
}

/// Joins consecutive entries (in the order given, normally newest first) for
/// the same number into groups, as phone apps show "Sara (3)".
List<CallLogGroup> groupCallLog(Iterable<CallLogEntry> entries) {
  final groups = <CallLogGroup>[];
  List<CallLogEntry>? current;
  for (final e in entries) {
    if (current != null && sameNumberDigits(current.first.number, e.number)) {
      current.add(e);
    } else {
      current = [e];
      groups.add(CallLogGroup(number: e.number, entries: current));
    }
  }
  return groups;
}

String _nameKey(ContactDetails c) {
  final name = c.displayName.isNotEmpty
      ? c.displayName
      : '${c.givenName} ${c.familyName}';
  return name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Groups contacts that look like the same person: the same name, a shared
/// phone number or a shared email. Only groups of two or more are returned,
/// each in the order the contacts were given.
List<List<ContactDetails>> findDuplicateGroups(
  Iterable<ContactDetails> contacts,
) {
  final list = contacts.toList();
  final parent = List<int>.generate(list.length, (i) => i);
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  void union(int a, int b) => parent[find(a)] = find(b);

  final byKey = <String, int>{};
  void link(String key, int index) {
    final seen = byKey[key];
    if (seen == null) {
      byKey[key] = index;
    } else {
      union(seen, index);
    }
  }

  for (var i = 0; i < list.length; i++) {
    final c = list[i];
    final name = _nameKey(c);
    if (name.isNotEmpty) link('n:$name', i);
    for (final p in c.phones) {
      final d = normalizedNumber(p.number);
      if (d.length >= 7) link('p:${d.substring(d.length - 7)}', i);
    }
    for (final e in c.emails) {
      final a = e.address.toLowerCase().trim();
      if (a.isNotEmpty) link('e:$a', i);
    }
  }
  final groups = <int, List<ContactDetails>>{};
  for (var i = 0; i < list.length; i++) {
    groups.putIfAbsent(find(i), () => []).add(list[i]);
  }
  return [
    for (final g in groups.values)
      if (g.length > 1) g,
  ];
}

/// Builds conversations from [messages] (any order). Threads are sorted
/// newest first.
List<SmsThread> groupSmsThreads(Iterable<SmsMessage> messages) {
  final byThread = <String, List<SmsMessage>>{};
  for (final m in messages) {
    byThread.putIfAbsent(m.threadId, () => []).add(m);
  }
  final threads = <SmsThread>[];
  byThread.forEach((id, list) {
    list.sort((a, b) => b.date.compareTo(a.date));
    final latest = list.first;
    threads.add(
      SmsThread(
        threadId: id,
        address: latest.address,
        snippet: latest.body,
        lastDate: latest.date,
        messageCount: list.length,
        unreadCount: list
            .where((m) => !m.isRead && m.type == SmsType.inbox)
            .length,
      ),
    );
  });
  threads.sort((a, b) => b.lastDate.compareTo(a.lastDate));
  return threads;
}

/// Parses the lines `subscriptionId<TAB>slot<TAB>number` from the Android side.
List<PhoneNumberInfo> parsePhoneNumberLines(Iterable<String> lines) => [
  for (final line in lines)
    if (line.split('\t') case [final id, final slot, ...final rest])
      PhoneNumberInfo(
        subscriptionId: int.tryParse(id) ?? -1,
        slotIndex: int.tryParse(slot) ?? -1,
        number: rest.isEmpty ? '' : rest.first,
      ),
];

/// Parses the JSON array from the Android side into [CellInfo]s.
List<CellInfo> parseCellInfoJson(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) return const [];
  return [
    for (final item in decoded)
      if (item is Map)
        CellInfo(
          type: '${item['type'] ?? 'unknown'}',
          isRegistered: item['registered'] == true,
          dbm: switch (item['dbm']) {
            final int v when v != -2147483648 && v != 2147483647 => v,
            _ => null,
          },
          level: (item['level'] as num?)?.toInt() ?? -1,
          cellId: (item['cellId'] as num?)?.toInt() ?? -1,
        ),
  ];
}

/// Splits a recipient list such as `+2010,+2011` for MMS addresses.
List<String> splitAddresses(String? value) => [
  for (final a in (value ?? '').split(RegExp(r'[,;]')))
    if (a.trim().isNotEmpty) a.trim(),
];

/// The USSD code that turns forwarding on, off, or asks for its state.
///
/// [number] is needed to turn it on. These are the standard GSM service
/// codes, so they work on most carriers.
String forwardingUssd(
  CallForwardingCondition condition, {
  String? number,
  bool query = false,
  bool enable = true,
}) {
  final code = condition.code;
  if (query) return '*#$code#';
  if (!enable) return '##$code#';
  final target = (number ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  if (target.isEmpty) {
    throw ArgumentError('A forwarding number is needed to turn it on.');
  }
  return '**$code*$target#';
}
