// Pure Dart phone number helpers: country calling codes, the country of an
// international number, and cursor handling for as-you-type formatting.
// Formatting itself is done by Android's PhoneNumberUtils (see TelephonyKit).

import 'package:flutter/services.dart';

import 'models.dart';
import 'telephony_kit_impl.dart';

/// Country calling codes (ITU-T E.164) and the regions that use them, main
/// region first. Shared codes such as +1 and +7 are refined by area code in
/// [countryOfNumber].
const Map<int, List<String>> _regionsByCode = {
  1: ['US', 'CA'],
  7: ['RU', 'KZ'],
  20: ['EG'],
  27: ['ZA'],
  30: ['GR'],
  31: ['NL'],
  32: ['BE'],
  33: ['FR'],
  34: ['ES'],
  36: ['HU'],
  39: ['IT', 'VA'],
  40: ['RO'],
  41: ['CH'],
  43: ['AT'],
  44: ['GB', 'GG', 'IM', 'JE'],
  45: ['DK'],
  46: ['SE'],
  47: ['NO', 'SJ'],
  48: ['PL'],
  49: ['DE'],
  51: ['PE'],
  52: ['MX'],
  53: ['CU'],
  54: ['AR'],
  55: ['BR'],
  56: ['CL'],
  57: ['CO'],
  58: ['VE'],
  60: ['MY'],
  61: ['AU', 'CC', 'CX'],
  62: ['ID'],
  63: ['PH'],
  64: ['NZ'],
  65: ['SG'],
  66: ['TH'],
  81: ['JP'],
  82: ['KR'],
  84: ['VN'],
  86: ['CN'],
  90: ['TR'],
  91: ['IN'],
  92: ['PK'],
  93: ['AF'],
  94: ['LK'],
  95: ['MM'],
  98: ['IR'],
  211: ['SS'],
  212: ['MA', 'EH'],
  213: ['DZ'],
  216: ['TN'],
  218: ['LY'],
  220: ['GM'],
  221: ['SN'],
  222: ['MR'],
  223: ['ML'],
  224: ['GN'],
  225: ['CI'],
  226: ['BF'],
  227: ['NE'],
  228: ['TG'],
  229: ['BJ'],
  230: ['MU'],
  231: ['LR'],
  232: ['SL'],
  233: ['GH'],
  234: ['NG'],
  235: ['TD'],
  236: ['CF'],
  237: ['CM'],
  238: ['CV'],
  239: ['ST'],
  240: ['GQ'],
  241: ['GA'],
  242: ['CG'],
  243: ['CD'],
  244: ['AO'],
  245: ['GW'],
  246: ['IO'],
  248: ['SC'],
  249: ['SD'],
  250: ['RW'],
  251: ['ET'],
  252: ['SO'],
  253: ['DJ'],
  254: ['KE'],
  255: ['TZ'],
  256: ['UG'],
  257: ['BI'],
  258: ['MZ'],
  260: ['ZM'],
  261: ['MG'],
  262: ['RE', 'YT'],
  263: ['ZW'],
  264: ['NA'],
  265: ['MW'],
  266: ['LS'],
  267: ['BW'],
  268: ['SZ'],
  269: ['KM'],
  290: ['SH'],
  291: ['ER'],
  297: ['AW'],
  298: ['FO'],
  299: ['GL'],
  350: ['GI'],
  351: ['PT'],
  352: ['LU'],
  353: ['IE'],
  354: ['IS'],
  355: ['AL'],
  356: ['MT'],
  357: ['CY'],
  358: ['FI', 'AX'],
  359: ['BG'],
  370: ['LT'],
  371: ['LV'],
  372: ['EE'],
  373: ['MD'],
  374: ['AM'],
  375: ['BY'],
  376: ['AD'],
  377: ['MC'],
  378: ['SM'],
  380: ['UA'],
  381: ['RS'],
  382: ['ME'],
  383: ['XK'],
  385: ['HR'],
  386: ['SI'],
  387: ['BA'],
  389: ['MK'],
  420: ['CZ'],
  421: ['SK'],
  423: ['LI'],
  500: ['FK'],
  501: ['BZ'],
  502: ['GT'],
  503: ['SV'],
  504: ['HN'],
  505: ['NI'],
  506: ['CR'],
  507: ['PA'],
  508: ['PM'],
  509: ['HT'],
  590: ['GP', 'BL', 'MF'],
  591: ['BO'],
  592: ['GY'],
  593: ['EC'],
  594: ['GF'],
  595: ['PY'],
  596: ['MQ'],
  597: ['SR'],
  598: ['UY'],
  599: ['CW', 'BQ'],
  670: ['TL'],
  672: ['NF'],
  673: ['BN'],
  674: ['NR'],
  675: ['PG'],
  676: ['TO'],
  677: ['SB'],
  678: ['VU'],
  679: ['FJ'],
  680: ['PW'],
  681: ['WF'],
  682: ['CK'],
  683: ['NU'],
  685: ['WS'],
  686: ['KI'],
  687: ['NC'],
  688: ['TV'],
  689: ['PF'],
  690: ['TK'],
  691: ['FM'],
  692: ['MH'],
  850: ['KP'],
  852: ['HK'],
  853: ['MO'],
  855: ['KH'],
  856: ['LA'],
  880: ['BD'],
  886: ['TW'],
  960: ['MV'],
  961: ['LB'],
  962: ['JO'],
  963: ['SY'],
  964: ['IQ'],
  965: ['KW'],
  966: ['SA'],
  967: ['YE'],
  968: ['OM'],
  970: ['PS'],
  971: ['AE'],
  972: ['IL'],
  973: ['BH'],
  974: ['QA'],
  975: ['BT'],
  976: ['MN'],
  977: ['NP'],
  992: ['TJ'],
  993: ['TM'],
  994: ['AZ'],
  995: ['GE'],
  996: ['KG'],
  998: ['UZ'],
};

/// North American area codes outside the United States.
const Map<String, String> _nanpAreas = {
  // Canada.
  '204': 'CA', '226': 'CA', '236': 'CA', '249': 'CA', '250': 'CA',
  '263': 'CA', '289': 'CA', '306': 'CA', '343': 'CA', '354': 'CA',
  '365': 'CA', '367': 'CA', '368': 'CA', '382': 'CA', '403': 'CA',
  '416': 'CA', '418': 'CA', '428': 'CA', '431': 'CA', '437': 'CA',
  '438': 'CA', '450': 'CA', '468': 'CA', '474': 'CA', '506': 'CA',
  '514': 'CA', '519': 'CA', '548': 'CA', '579': 'CA', '581': 'CA',
  '584': 'CA', '587': 'CA', '604': 'CA', '613': 'CA', '639': 'CA',
  '647': 'CA', '672': 'CA', '683': 'CA', '705': 'CA', '709': 'CA',
  '742': 'CA', '753': 'CA', '778': 'CA', '780': 'CA', '782': 'CA',
  '807': 'CA', '819': 'CA', '825': 'CA', '867': 'CA', '873': 'CA',
  '879': 'CA', '902': 'CA', '905': 'CA',
  // Caribbean and Pacific.
  '242': 'BS', '246': 'BB', '264': 'AI', '268': 'AG', '284': 'VG',
  '340': 'VI', '345': 'KY', '441': 'BM', '473': 'GD', '649': 'TC',
  '658': 'JM', '664': 'MS', '670': 'MP', '671': 'GU', '684': 'AS',
  '721': 'SX', '758': 'LC', '767': 'DM', '784': 'VC', '787': 'PR',
  '809': 'DO', '829': 'DO', '849': 'DO', '868': 'TT', '869': 'KN',
  '876': 'JM', '939': 'PR',
};

/// The digits of an international number: [number] must start with `+` or
/// `00`. Formatting characters are ignored. Returns null otherwise.
String? _internationalDigits(String number) {
  final trimmed = number.trim();
  final String rest;
  if (trimmed.startsWith('+')) {
    rest = trimmed.substring(1);
  } else if (trimmed.startsWith('00')) {
    rest = trimmed.substring(2);
  } else {
    return null;
  }
  final digits = rest.replaceAll(RegExp(r'[\s().\-/]'), '');
  if (digits.isEmpty || !RegExp(r'^[0-9]+$').hasMatch(digits)) return null;
  return digits;
}

/// The country calling code of an international number such as
/// `+20 100 123 4567` or `0044 20 7946 0000`, or null if [number] does not
/// start with `+` or `00` or the code is unknown.
int? callingCodeOf(String number) {
  final digits = _internationalDigits(number);
  if (digits == null) return null;
  for (var length = 1; length <= 3 && length <= digits.length; length++) {
    final code = int.parse(digits.substring(0, length));
    if (_regionsByCode.containsKey(code)) return code;
  }
  return null;
}

/// The regions (ISO 3166-1 alpha-2, upper case) that use calling [code],
/// main region first. Empty if the code is unknown.
List<String> regionsForCallingCode(int code) =>
    _regionsByCode[code] ?? const [];

/// The calling code of region [isoCode] (for example 20 for `EG`), or null.
int? callingCodeForRegion(String isoCode) {
  final iso = isoCode.toUpperCase();
  for (final entry in _regionsByCode.entries) {
    if (entry.value.contains(iso)) return entry.key;
  }
  // NANP regions are only listed by area code.
  if (_nanpAreas.containsValue(iso)) return 1;
  return null;
}

/// The country of an international number (starting with `+` or `00`), or
/// null. North American numbers are told apart by area code, and +7 numbers
/// starting with 6 or 7 are Kazakh.
PhoneNumberCountry? countryOfNumber(String number) {
  final code = callingCodeOf(number);
  if (code == null) return null;
  final digits = _internationalDigits(number)!;
  final national = digits.substring('$code'.length);
  var iso = regionsForCallingCode(code).first;
  if (code == 1 && national.length >= 3) {
    iso = _nanpAreas[national.substring(0, 3)] ?? 'US';
  } else if (code == 7 && national.isNotEmpty) {
    iso = national.startsWith('6') || national.startsWith('7') ? 'KZ' : 'RU';
  }
  return PhoneNumberCountry(
    isoCode: iso,
    callingCode: code,
    nationalNumber: national,
  );
}

/// Characters that are part of a dialable number rather than formatting.
bool isDialableChar(String char) => RegExp(r'^[0-9*#+,;]$').hasMatch(char);

/// How many dialable characters of [text] come before [offset].
int _dialableBefore(String text, int offset) {
  var count = 0;
  final end = offset.clamp(0, text.length);
  for (var i = 0; i < end; i++) {
    if (isDialableChar(text[i])) count++;
  }
  return count;
}

/// The cursor position in [formatted] that keeps the cursor after the same
/// number of dialable characters it was after at [offset] in [raw].
int formattedCursorOffset(String raw, int offset, String formatted) {
  final wanted = _dialableBefore(raw, offset);
  if (wanted == 0) return 0;
  var seen = 0;
  for (var i = 0; i < formatted.length; i++) {
    if (isDialableChar(formatted[i])) {
      seen++;
      if (seen == wanted) return i + 1;
    }
  }
  return formatted.length;
}

/// A [TextInputFormatter] that formats a phone number as it is typed, the
/// way the system dialer does (for example `010 0123 4567` or
/// `+44 20 7946 0000`), and keeps the cursor in place.
///
/// Formatting uses Android's own as-you-type formatter through
/// `TelephonyKit.formatPhoneNumberAsYouType`. [countryIso] defaults to
/// `TelephonyKit.defaultCountryIso`. Pass [format] to use another formatter,
/// for example in tests.
///
/// ```dart
/// TextField(
///   keyboardType: TextInputType.phone,
///   inputFormatters: [PhoneNumberInputFormatter()],
/// )
/// ```
class PhoneNumberInputFormatter extends TextInputFormatter {
  /// Creates a formatter for numbers of [countryIso].
  PhoneNumberInputFormatter({this.countryIso, String Function(String)? format})
    : _format = format;

  /// The country used for numbers without a `+` country code, or null for
  /// the device's country.
  final String? countryIso;

  final String Function(String)? _format;

  String _apply(String text) =>
      _format?.call(text) ??
      TelephonyKit.instance.formatPhoneNumberAsYouType(
        text,
        countryIso: countryIso,
      );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset
        : text.length;
    // Deleting only a separator (a space or dash) would be undone by the
    // formatter, so delete the digit before it instead.
    final deletedOne = oldValue.text.length == text.length + 1;
    if (deletedOne &&
        _dialableBefore(oldValue.text, oldValue.text.length) ==
            _dialableBefore(text, text.length)) {
      var i = cursor - 1;
      while (i >= 0 && !isDialableChar(text[i])) {
        i--;
      }
      if (i >= 0) {
        text = text.substring(0, i) + text.substring(i + 1);
        cursor = i;
      }
    }
    if (text.isEmpty) return const TextEditingValue();
    final String formatted;
    try {
      formatted = _apply(text);
    } on Object {
      return newValue;
    }
    final offset = formattedCursorOffset(text, cursor, formatted);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
