// Pure Dart vCard (.vcf) reading and writing, so contacts can be exported,
// shared and imported without a device. Writes vCard 3.0 and reads 2.1, 3.0
// and 4.0 (quoted-printable text is decoded as UTF-8).

import 'dart:convert';

import 'models.dart';

String _escape(String v) => v
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll('\r\n', r'\n')
    .replaceAll('\n', r'\n');

String _unescape(String v) {
  final b = StringBuffer();
  for (var i = 0; i < v.length; i++) {
    final c = v[i];
    if (c == r'\' && i + 1 < v.length) {
      final n = v[++i];
      b.write(n == 'n' || n == 'N' ? '\n' : n);
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

/// Splits [v] at unescaped [sep].
List<String> _split(String v, String sep) {
  final parts = <String>[];
  final b = StringBuffer();
  for (var i = 0; i < v.length; i++) {
    final c = v[i];
    if (c == r'\' && i + 1 < v.length) {
      b
        ..write(c)
        ..write(v[++i]);
    } else if (c == sep) {
      parts.add(b.toString());
      b.clear();
    } else {
      b.write(c);
    }
  }
  parts.add(b.toString());
  return parts;
}

String _fold(String line) {
  if (line.length <= 75) return line;
  final b = StringBuffer(line.substring(0, 75));
  for (var i = 75; i < line.length; i += 74) {
    b
      ..write('\r\n ')
      ..write(line.substring(i, i + 74 > line.length ? line.length : i + 74));
  }
  return b.toString();
}

String _phoneType(String label) => switch (label.toLowerCase()) {
  'mobile' => 'CELL',
  'home' => 'HOME',
  'work' => 'WORK',
  'work fax' => 'WORK,FAX',
  'home fax' => 'HOME,FAX',
  'pager' => 'PAGER',
  'main' => 'PREF',
  _ => 'VOICE',
};

String _simpleType(String label) => switch (label.toLowerCase()) {
  'home' => 'HOME',
  'work' => 'WORK',
  'mobile' => 'CELL',
  _ => 'OTHER',
};

/// Writes [contacts] as one vCard 3.0 text, with CRLF line ends. Pass the
/// result to `Share` or save it as `contacts.vcf`.
String exportVCard(Iterable<ContactDetails> contacts) {
  final out = StringBuffer();
  void line(String text) => out.write('${_fold(text)}\r\n');

  for (final c in contacts) {
    final name = c.displayName.isNotEmpty
        ? c.displayName
        : [c.givenName, c.familyName].where((p) => p.isNotEmpty).join(' ');
    line('BEGIN:VCARD');
    line('VERSION:3.0');
    line(
      'N:${_escape(c.familyName)};${_escape(c.givenName)};'
      '${_escape(c.middleName)};${_escape(c.namePrefix)};'
      '${_escape(c.nameSuffix)}',
    );
    line('FN:${_escape(name)}');
    if (c.nickname.isNotEmpty) line('NICKNAME:${_escape(c.nickname)}');
    if (c.company.isNotEmpty || c.department.isNotEmpty) {
      line('ORG:${_escape(c.company)};${_escape(c.department)}');
    }
    if (c.jobTitle.isNotEmpty) line('TITLE:${_escape(c.jobTitle)}');
    for (final p in c.phones) {
      line('TEL;TYPE=${_phoneType(p.label)}:${_escape(p.number)}');
    }
    for (final e in c.emails) {
      line('EMAIL;TYPE=${_simpleType(e.label)}:${_escape(e.address)}');
    }
    for (final a in c.addresses) {
      line('ADR;TYPE=${_simpleType(a.label)}:;;${_escape(a.address)};;;;');
    }
    for (final w in c.websites) {
      line('URL:${_escape(w)}');
    }
    for (final s in c.sipAddresses) {
      line('IMPP:sip:${_escape(s)}');
    }
    for (final im in c.ims) {
      final scheme = im.protocol.isEmpty
          ? 'im'
          : im.protocol.toLowerCase().replaceAll(' ', '');
      line('IMPP:$scheme:${_escape(im.address)}');
    }
    for (final r in c.relations) {
      line(
        'X-ABRELATEDNAMES;TYPE=${_escape(r.label.isEmpty ? 'Relative' : r.label)}'
        ':${_escape(r.name)}',
      );
    }
    if (c.note.isNotEmpty) line('NOTE:${_escape(c.note)}');
    if (c.birthday != null && c.birthday!.isNotEmpty) {
      line('BDAY:${c.birthday}');
    }
    if (c.isStarred) line('X-FAVORITE:1');
    line('END:VCARD');
  }
  return out.toString();
}

class _Prop {
  _Prop(this.name, this.params, this.value);
  final String name;
  final List<String> params;
  final String value;

  bool hasType(String type) => params.any((p) => p.toUpperCase() == type);
}

_Prop? _parseLine(String line) {
  final colon = line.indexOf(':');
  if (colon <= 0) return null;
  final head = line.substring(0, colon).split(';');
  var name = head.first.toUpperCase();
  final dot = name.indexOf('.');
  if (dot >= 0) name = name.substring(dot + 1); // item1.TEL
  final params = <String>[];
  var quotedPrintable = false;
  for (final p in head.skip(1)) {
    final eq = p.indexOf('=');
    final value = eq < 0 ? p : p.substring(eq + 1);
    if (eq >= 0 && p.substring(0, eq).toUpperCase() == 'ENCODING') {
      if (value.toUpperCase() == 'QUOTED-PRINTABLE') quotedPrintable = true;
      continue;
    }
    if (eq >= 0 && p.substring(0, eq).toUpperCase() == 'CHARSET') continue;
    params.addAll(value.replaceAll('"', '').split(','));
  }
  var value = line.substring(colon + 1);
  if (quotedPrintable) value = _decodeQuotedPrintable(value);
  return _Prop(name, params, value);
}

String _decodeQuotedPrintable(String v) {
  final bytes = <int>[];
  for (var i = 0; i < v.length; i++) {
    if (v[i] == '=' && i + 2 < v.length) {
      final hex = v.substring(i + 1, i + 3);
      final n = int.tryParse(hex, radix: 16);
      if (n != null) {
        bytes.add(n);
        i += 2;
        continue;
      }
    }
    bytes.addAll(utf8.encode(v[i]));
  }
  return utf8.decode(bytes, allowMalformed: true);
}

String _phoneLabel(_Prop p) {
  if (p.hasType('FAX')) return p.hasType('HOME') ? 'Home fax' : 'Work fax';
  if (p.hasType('CELL')) return 'Mobile';
  if (p.hasType('HOME')) return 'Home';
  if (p.hasType('WORK')) return 'Work';
  if (p.hasType('PAGER')) return 'Pager';
  if (p.hasType('PREF') || p.hasType('MAIN')) return 'Main';
  return 'Other';
}

String _simpleLabel(_Prop p) {
  if (p.hasType('HOME')) return 'Home';
  if (p.hasType('WORK')) return 'Work';
  if (p.hasType('CELL') || p.hasType('MOBILE')) return 'Mobile';
  return 'Other';
}

/// Reads every contact from vCard [text]. Unknown properties are ignored and
/// cards without any name, number or email are skipped. Contacts come back
/// with an empty [ContactDetails.id]; pass them to `TelephonyKit.addContact`
/// or use `TelephonyKit.importVCard`.
List<ContactDetails> parseVCard(String text) {
  // Unfold: a line that starts with a space or tab continues the previous one.
  final raw = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final lines = <String>[];
  for (final l in raw) {
    if ((l.startsWith(' ') || l.startsWith('\t')) && lines.isNotEmpty) {
      lines[lines.length - 1] += l.substring(1);
    } else if (lines.isNotEmpty &&
        lines.last.toUpperCase().contains('QUOTED-PRINTABLE') &&
        lines.last.endsWith('=')) {
      lines[lines.length - 1] =
          lines.last.substring(0, lines.last.length - 1) + l;
    } else {
      lines.add(l);
    }
  }

  final result = <ContactDetails>[];
  List<_Prop>? card;
  for (final l in lines) {
    final upper = l.trim().toUpperCase();
    if (upper == 'BEGIN:VCARD') {
      card = [];
    } else if (upper == 'END:VCARD') {
      if (card != null) {
        final c = _buildCard(card);
        if (c != null) result.add(c);
      }
      card = null;
    } else if (card != null) {
      final p = _parseLine(l);
      if (p != null) card.add(p);
    }
  }
  return result;
}

ContactDetails? _buildCard(List<_Prop> props) {
  var display = '', given = '', middle = '', family = '';
  var prefix = '', suffix = '', nickname = '', company = '';
  var department = '', title = '', note = '';
  String? birthday;
  var starred = false;
  final phones = <ContactPhone>[];
  final emails = <ContactEmail>[];
  final addresses = <ContactAddress>[];
  final websites = <String>[];
  final sips = <String>[];
  final ims = <ContactIm>[];
  final relations = <ContactRelation>[];

  for (final p in props) {
    switch (p.name) {
      case 'FN':
        display = _unescape(p.value);
      case 'N':
        final f = _split(p.value, ';').map(_unescape).toList();
        String at(int i) => i < f.length ? f[i] : '';
        family = at(0);
        given = at(1);
        middle = at(2);
        prefix = at(3);
        suffix = at(4);
      case 'NICKNAME':
        nickname = _unescape(p.value);
      case 'ORG':
        final f = _split(p.value, ';').map(_unescape).toList();
        company = f.isNotEmpty ? f[0] : '';
        department = f.length > 1 ? f[1] : '';
      case 'TITLE':
        title = _unescape(p.value);
      case 'TEL':
        final number = _unescape(p.value).replaceFirst('tel:', '');
        if (number.trim().isNotEmpty) {
          phones.add(
            ContactPhone(number: number.trim(), label: _phoneLabel(p)),
          );
        }
      case 'EMAIL':
        if (p.value.trim().isNotEmpty) {
          emails.add(
            ContactEmail(
              address: _unescape(p.value).trim(),
              label: _simpleLabel(p),
            ),
          );
        }
      case 'ADR':
        final f = _split(p.value, ';').map(_unescape).toList();
        final text = f.where((v) => v.trim().isNotEmpty).join('\n');
        if (text.isNotEmpty) {
          addresses.add(ContactAddress(address: text, label: _simpleLabel(p)));
        }
      case 'URL':
        if (p.value.trim().isNotEmpty) websites.add(_unescape(p.value).trim());
      case 'IMPP':
        final value = _unescape(p.value);
        final colon = value.indexOf(':');
        final scheme = colon < 0 ? '' : value.substring(0, colon).toLowerCase();
        final handle = colon < 0 ? value : value.substring(colon + 1);
        if (handle.isEmpty) break;
        if (scheme == 'sip') {
          sips.add(handle);
        } else {
          ims.add(
            ContactIm(address: handle, protocol: scheme == 'im' ? '' : scheme),
          );
        }
      case 'X-ABRELATEDNAMES' || 'RELATED':
        if (p.value.trim().isNotEmpty) {
          relations.add(
            ContactRelation(
              name: _unescape(p.value),
              label: p.params.isEmpty ? '' : p.params.first,
            ),
          );
        }
      case 'NOTE':
        note = _unescape(p.value);
      case 'BDAY':
        final v = p.value.trim();
        if (RegExp(r'^\d{8}$').hasMatch(v)) {
          birthday =
              '${v.substring(0, 4)}-${v.substring(4, 6)}-${v.substring(6)}';
        } else if (v.isNotEmpty) {
          birthday = v.split('T').first;
        }
      case 'X-FAVORITE':
        starred = p.value.trim() == '1';
    }
  }

  if (display.isEmpty && given.isEmpty && family.isEmpty) {
    display = company;
  }
  if (display.isEmpty &&
      given.isEmpty &&
      family.isEmpty &&
      phones.isEmpty &&
      emails.isEmpty) {
    return null;
  }
  return ContactDetails(
    displayName: display,
    givenName: given,
    middleName: middle,
    familyName: family,
    namePrefix: prefix,
    nameSuffix: suffix,
    nickname: nickname,
    company: company,
    department: department,
    jobTitle: title,
    phones: phones,
    emails: emails,
    addresses: addresses,
    websites: websites,
    ims: ims,
    relations: relations,
    sipAddresses: sips,
    note: note,
    birthday: birthday,
    isStarred: starred,
  );
}
