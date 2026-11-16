// Pure Dart helpers for search, kept separate so they can be unit tested
// without a device.

import 'models.dart';

/// Digit patterns to match [query] against stored phone numbers with SQL
/// `LIKE`. Returns nothing when [query] has fewer than 2 digits.
///
/// Formatting characters are dropped. A leading `0` (local trunk prefix) also
/// yields the pattern without it, so a local number matches the same number
/// saved in international format.
List<String> numberSearchPatterns(String query) {
  final digits = query.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 2) return const [];
  final patterns = <String>{digits};
  final withoutTrunk = digits.replaceFirst(RegExp('^0+'), '');
  if (withoutTrunk.length >= 2) patterns.add(withoutTrunk);
  return patterns.toList();
}

/// The label Android shows for `ContactsContract.CommonDataKinds.Phone.TYPE`.
String phoneTypeLabel(int type, String? customLabel) => switch (type) {
  0 => customLabel ?? '',
  1 => 'Home',
  2 => 'Mobile',
  3 => 'Work',
  4 => 'Work fax',
  5 => 'Home fax',
  6 => 'Pager',
  7 => 'Other',
  12 => 'Main',
  _ => customLabel ?? '',
};

/// Groups phone rows (one per number) into contacts, keeping row order and
/// dropping duplicate numbers on the same contact.
List<Contact> groupContactRows(List<Map<String, String?>> rows) {
  final byId = <String, _ContactBuilder>{};
  for (final row in rows) {
    final id = row['contact_id'] ?? '';
    final builder = byId.putIfAbsent(
      id,
      () => _ContactBuilder(
        id: id,
        name: row['display_name'] ?? '',
        photoUri: row['photo_thumb_uri'],
        starred: row['starred'] == '1',
      ),
    );
    final number = row['data1'] ?? '';
    if (number.isEmpty) continue;
    final key = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (builder.seen.add(key)) {
      builder.phones.add(
        ContactPhone(
          number: number,
          label: phoneTypeLabel(
            int.tryParse(row['data2'] ?? '') ?? 0,
            row['data3'],
          ),
        ),
      );
    }
  }
  return [
    for (final b in byId.values)
      Contact(
        id: b.id,
        displayName: b.name,
        phones: List.unmodifiable(b.phones),
        photoUri: b.photoUri,
        isStarred: b.starred,
      ),
  ];
}

class _ContactBuilder {
  _ContactBuilder({
    required this.id,
    required this.name,
    required this.photoUri,
    required this.starred,
  });

  final String id;
  final String name;
  final String? photoUri;
  final bool starred;
  final phones = <ContactPhone>[];
  final seen = <String>{};
}
