// Pure Dart helpers for reading and writing full contacts, kept separate so
// they can be unit tested without a device.

import 'models.dart';
import 'search.dart';

/// `ContactsContract.CommonDataKinds` mime types the package reads and writes.
abstract final class ContactMime {
  static const name = 'vnd.android.cursor.item/name';
  static const phone = 'vnd.android.cursor.item/phone_v2';
  static const email = 'vnd.android.cursor.item/email_v2';
  static const address = 'vnd.android.cursor.item/postal-address_v2';
  static const organization = 'vnd.android.cursor.item/organization';
  static const nickname = 'vnd.android.cursor.item/nickname';
  static const note = 'vnd.android.cursor.item/note';
  static const website = 'vnd.android.cursor.item/website';
  static const event = 'vnd.android.cursor.item/contact_event';

  /// Every kind that `updateContact` replaces. Photos, groups, IM and other
  /// kinds are left alone.
  static const managed = [
    name,
    phone,
    email,
    address,
    organization,
    nickname,
    note,
    website,
    event,
  ];
}

const _emailTypes = {1: 'Home', 2: 'Work', 3: 'Other', 4: 'Mobile'};
const _addressTypes = {1: 'Home', 2: 'Work', 3: 'Other'};
const _phoneTypes = {
  1: 'Home',
  2: 'Mobile',
  3: 'Work',
  4: 'Work fax',
  5: 'Home fax',
  6: 'Pager',
  7: 'Other',
  12: 'Main',
};

/// The label Android shows for `CommonDataKinds.Email.TYPE`.
String emailTypeLabel(int type, String? customLabel) =>
    _emailTypes[type] ?? customLabel ?? '';

/// The label Android shows for `CommonDataKinds.StructuredPostal.TYPE`.
String addressTypeLabel(int type, String? customLabel) =>
    _addressTypes[type] ?? customLabel ?? '';

/// Turns a label into a data type and custom label for saving. A known label
/// such as `Work` (any case) becomes its type, other text becomes a custom
/// label (type 0), and empty text becomes [fallback].
({int type, String? label}) typeFromLabel(
  String label,
  Map<int, String> types,
  int fallback,
) {
  final text = label.trim();
  if (text.isEmpty) return (type: fallback, label: null);
  for (final entry in types.entries) {
    if (entry.value.toLowerCase() == text.toLowerCase()) {
      return (type: entry.key, label: null);
    }
  }
  return (type: 0, label: text);
}

String _s(Map<String, String?> row, String key) => row[key] ?? '';

/// Builds a [ContactDetails] from a `contacts` row and the `data` rows of the
/// same contact.
ContactDetails buildContactDetails(
  Map<String, String?> contact,
  List<Map<String, String?>> data,
) {
  var givenName = '', middleName = '', familyName = '';
  var namePrefix = '', nameSuffix = '', nickname = '';
  var company = '', department = '', jobTitle = '', note = '';
  String? birthday;
  final phones = <ContactPhone>[];
  final emails = <ContactEmail>[];
  final addresses = <ContactAddress>[];
  final websites = <String>[];
  final seenPhones = <String>{};

  for (final row in data) {
    final type = int.tryParse(_s(row, 'data2')) ?? 0;
    switch (row['mimetype']) {
      case ContactMime.name:
        givenName = _s(row, 'data2');
        familyName = _s(row, 'data3');
        namePrefix = _s(row, 'data4');
        middleName = _s(row, 'data5');
        nameSuffix = _s(row, 'data6');
      case ContactMime.phone:
        final number = _s(row, 'data1');
        final key = number.replaceAll(RegExp(r'[^0-9+]'), '');
        if (number.isNotEmpty && seenPhones.add(key)) {
          phones.add(
            ContactPhone(
              number: number,
              label: phoneTypeLabel(type, row['data3']),
            ),
          );
        }
      case ContactMime.email:
        if (_s(row, 'data1').isNotEmpty) {
          emails.add(
            ContactEmail(
              address: _s(row, 'data1'),
              label: emailTypeLabel(type, row['data3']),
            ),
          );
        }
      case ContactMime.address:
        if (_s(row, 'data1').isNotEmpty) {
          addresses.add(
            ContactAddress(
              address: _s(row, 'data1'),
              label: addressTypeLabel(type, row['data3']),
            ),
          );
        }
      case ContactMime.organization:
        company = _s(row, 'data1');
        jobTitle = _s(row, 'data4');
        department = _s(row, 'data5');
      case ContactMime.nickname:
        nickname = _s(row, 'data1');
      case ContactMime.note:
        note = _s(row, 'data1');
      case ContactMime.website:
        if (_s(row, 'data1').isNotEmpty) websites.add(_s(row, 'data1'));
      case ContactMime.event:
        // Event.TYPE_BIRTHDAY is 3.
        if (type == 3 && _s(row, 'data1').isNotEmpty) {
          birthday = _s(row, 'data1');
        }
    }
  }

  return ContactDetails(
    id: _s(contact, '_id'),
    lookupKey: _s(contact, 'lookup'),
    displayName: _s(contact, 'display_name'),
    givenName: givenName,
    middleName: middleName,
    familyName: familyName,
    namePrefix: namePrefix,
    nameSuffix: nameSuffix,
    nickname: nickname,
    company: company,
    department: department,
    jobTitle: jobTitle,
    phones: List.unmodifiable(phones),
    emails: List.unmodifiable(emails),
    addresses: List.unmodifiable(addresses),
    websites: List.unmodifiable(websites),
    note: note,
    birthday: birthday,
    photoUri: contact['photo_uri'] ?? contact['photo_thumb_uri'],
    isStarred: contact['starred'] == '1',
  );
}

/// The `data` rows to insert for [contact], without `raw_contact_id`. Each
/// row has `mimetype` and `data1`..`data9` values that are [String] or [int].
/// Blank entries are skipped.
List<Map<String, Object>> contactDataRows(ContactDetails contact) {
  final rows = <Map<String, Object>>[];

  final hasStructuredName = [
    contact.givenName,
    contact.middleName,
    contact.familyName,
    contact.namePrefix,
    contact.nameSuffix,
  ].any((v) => v.trim().isNotEmpty);
  if (hasStructuredName) {
    rows.add({
      'mimetype': ContactMime.name,
      if (contact.givenName.trim().isNotEmpty)
        'data2': contact.givenName.trim(),
      if (contact.familyName.trim().isNotEmpty)
        'data3': contact.familyName.trim(),
      if (contact.namePrefix.trim().isNotEmpty)
        'data4': contact.namePrefix.trim(),
      if (contact.middleName.trim().isNotEmpty)
        'data5': contact.middleName.trim(),
      if (contact.nameSuffix.trim().isNotEmpty)
        'data6': contact.nameSuffix.trim(),
    });
  } else if (contact.displayName.trim().isNotEmpty) {
    // Android splits an unstructured display name by itself.
    rows.add({
      'mimetype': ContactMime.name,
      'data1': contact.displayName.trim(),
    });
  }

  for (final phone in contact.phones) {
    final number = phone.number.trim();
    if (number.isEmpty) continue;
    final t = typeFromLabel(phone.label, _phoneTypes, 7);
    rows.add({
      'mimetype': ContactMime.phone,
      'data1': number,
      'data2': t.type,
      if (t.label != null) 'data3': t.label!,
    });
  }
  for (final email in contact.emails) {
    final address = email.address.trim();
    if (address.isEmpty) continue;
    final t = typeFromLabel(email.label, _emailTypes, 3);
    rows.add({
      'mimetype': ContactMime.email,
      'data1': address,
      'data2': t.type,
      if (t.label != null) 'data3': t.label!,
    });
  }
  for (final address in contact.addresses) {
    final text = address.address.trim();
    if (text.isEmpty) continue;
    final t = typeFromLabel(address.label, _addressTypes, 3);
    rows.add({
      'mimetype': ContactMime.address,
      'data1': text,
      'data2': t.type,
      if (t.label != null) 'data3': t.label!,
    });
  }

  if ([
    contact.company,
    contact.department,
    contact.jobTitle,
  ].any((v) => v.trim().isNotEmpty)) {
    rows.add({
      'mimetype': ContactMime.organization,
      'data1': contact.company.trim(),
      'data4': contact.jobTitle.trim(),
      'data5': contact.department.trim(),
    });
  }
  if (contact.nickname.trim().isNotEmpty) {
    rows.add({
      'mimetype': ContactMime.nickname,
      'data1': contact.nickname.trim(),
    });
  }
  if (contact.note.trim().isNotEmpty) {
    rows.add({'mimetype': ContactMime.note, 'data1': contact.note.trim()});
  }
  for (final site in contact.websites) {
    if (site.trim().isEmpty) continue;
    rows.add({'mimetype': ContactMime.website, 'data1': site.trim()});
  }
  final birthday = contact.birthday?.trim() ?? '';
  if (birthday.isNotEmpty) {
    rows.add({
      'mimetype': ContactMime.event,
      'data1': birthday,
      'data2': 3, // Event.TYPE_BIRTHDAY
    });
  }
  return rows;
}
