/// Data types returned by `TelephonyKit`.
library;

import 'analysis.dart' show normalizedNumber, sameNumberDigits;

/// The state of a call, mirroring `android.telecom.Call.STATE_*`.
enum CallState {
  newCall(0),
  dialing(1),
  ringing(2),
  holding(3),
  active(4),
  disconnected(7),
  selectPhoneAccount(8),
  connecting(9),
  disconnecting(10),
  pulling(11),
  audioProcessing(12),
  simulatedRinging(13),

  /// The call is no longer tracked or the platform reported a value this
  /// version of the package does not know about.
  unknown(-1);

  const CallState(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw `android.telecom.Call.STATE_*` value.
  static CallState fromValue(int value) => CallState.values.firstWhere(
    (s) => s.value == value,
    orElse: () => CallState.unknown,
  );

  /// True for states where the call has not ended yet.
  bool get isLive =>
      this != CallState.disconnected &&
      this != CallState.disconnecting &&
      this != CallState.unknown;
}

/// Where call audio is played, mirroring `android.telecom.CallAudioState`.
enum AudioRoute {
  earpiece(1),
  bluetooth(2),
  wiredHeadset(4),
  speaker(8),
  streaming(16),
  unknown(-1);

  const AudioRoute(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw `CallAudioState.ROUTE_*` value.
  static AudioRoute fromValue(int value) => AudioRoute.values.firstWhere(
    (r) => r.value == value,
    orElse: () => AudioRoute.unknown,
  );
}

/// The kind of entry in the call log, mirroring `CallLog.Calls.*_TYPE`.
enum CallLogType {
  incoming(1),
  outgoing(2),
  missed(3),
  voicemail(4),
  rejected(5),
  blocked(6),
  answeredExternally(7),
  unknown(-1);

  const CallLogType(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw `CallLog.Calls.TYPE` value.
  static CallLogType fromValue(int value) => CallLogType.values.firstWhere(
    (t) => t.value == value,
    orElse: () => CallLogType.unknown,
  );
}

/// The SIM state, mirroring `TelephonyManager.SIM_STATE_*`.
enum SimState {
  unknown(0),
  absent(1),
  pinRequired(2),
  pukRequired(3),
  networkLocked(4),
  ready(5),
  notReady(6),
  permanentlyDisabled(7),
  cardIoError(8),
  cardRestricted(9);

  const SimState(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw `TelephonyManager.SIM_STATE_*` value.
  static SimState fromValue(int value) => SimState.values.firstWhere(
    (s) => s.value == value,
    orElse: () => SimState.unknown,
  );
}

/// The radio type of the device, mirroring `TelephonyManager.PHONE_TYPE_*`.
enum PhoneType {
  none(0),
  gsm(1),
  cdma(2),
  sip(3),
  unknown(-1);

  const PhoneType(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw `TelephonyManager.PHONE_TYPE_*` value.
  static PhoneType fromValue(int value) => PhoneType.values.firstWhere(
    (t) => t.value == value,
    orElse: () => PhoneType.unknown,
  );
}

/// An active SIM subscription.
class SimCard {
  const SimCard({
    required this.subscriptionId,
    required this.slotIndex,
    required this.displayName,
    required this.carrierName,
    required this.countryIso,
    required this.isEmbedded,
  });

  /// The Android subscription id.
  final int subscriptionId;

  /// The physical slot, starting at 0. -1 when unknown.
  final int slotIndex;

  /// The name the user or carrier gave this SIM.
  final String displayName;

  /// The carrier name.
  final String carrierName;

  /// ISO 3166-1 country code of the SIM's carrier, in lower case.
  final String countryIso;

  /// True for an eSIM.
  final bool isEmbedded;

  @override
  String toString() =>
      'SimCard(slot: $slotIndex, id: $subscriptionId, name: $displayName, '
      'carrier: $carrierName)';
}

/// A phone account that can place calls, usually one per SIM.
class PhoneAccount {
  const PhoneAccount({
    required this.id,
    required this.label,
    this.slotIndex = -1,
  });

  /// The id to pass to `PhoneCall.selectPhoneAccount` or
  /// `TelephonyKit.placeCall`.
  final String id;

  /// The name the system shows for it, usually the carrier. May be empty.
  final String label;

  /// The SIM slot, starting at 0, or -1 when unknown (Android 11+ and
  /// `TelephonyPermission.readPhoneState` needed).
  final int slotIndex;

  /// A short name for a picker, for example `SIM 1 · Vodafone`.
  String get displayName {
    final slot = slotIndex >= 0 ? 'SIM ${slotIndex + 1}' : '';
    return [slot, label].where((s) => s.isNotEmpty).join(' · ');
  }

  @override
  String toString() => 'PhoneAccount($id, $label, slot: $slotIndex)';
}

/// Information about the device and the network it is registered on.
class NetworkInfo {
  const NetworkInfo({
    required this.networkOperatorName,
    required this.networkOperator,
    required this.networkCountryIso,
    required this.simOperatorName,
    required this.simCountryIso,
    required this.simState,
    required this.phoneType,
    required this.isRoaming,
    required this.isVoiceCapable,
    required this.slotCount,
  });

  /// The name of the network the device is registered on.
  final String networkOperatorName;

  /// The MCC+MNC of the registered network.
  final String networkOperator;

  /// ISO country code of the registered network, in lower case.
  final String networkCountryIso;

  /// The name of the default SIM's operator.
  final String simOperatorName;

  /// ISO country code of the default SIM's operator.
  final String simCountryIso;

  /// The state of the default SIM.
  final SimState simState;

  /// The radio type.
  final PhoneType phoneType;

  /// True when the device is roaming.
  final bool isRoaming;

  /// False for devices that cannot place voice calls, such as some tablets.
  final bool isVoiceCapable;

  /// The number of SIM slots the modem supports.
  final int slotCount;
}

/// One entry from the device call log.
class CallLogEntry {
  const CallLogEntry({
    this.id = '',
    this.isNew = false,
    required this.number,
    required this.name,
    required this.type,
    required this.date,
    required this.duration,
    this.geocodedLocation = '',
    this.subscriptionId,
    this.features = 0,
    this.isRead = true,
    this.countryIso = '',
    this.formattedNumber = '',
    this.numberLabel = '',
    this.postDialDigits = '',
    this.viaNumber = '',
    this.presentation = NumberPresentation.allowed,
    this.lookupUri,
    this.voicemailUri,
    this.transcription = '',
    this.blockReason = 0,
    this.screeningAppName = '',
    this.lastModified,
  });

  /// The row id, used by `TelephonyKit.deleteCallLogEntries`.
  final String id;

  /// True for a missed call the user has not seen yet.
  final bool isNew;

  /// The phone number.
  final String number;

  /// The cached contact name, or an empty string.
  final String name;

  /// Incoming, outgoing, missed and so on.
  final CallLogType type;

  /// When the call started.
  final DateTime date;

  /// How long the call lasted.
  final Duration duration;

  /// Where the number is from, such as "Cairo, Egypt", or an empty string.
  final String geocodedLocation;

  /// The id of the SIM subscription that handled the call (compare with
  /// `SimCard.subscriptionId`), or null when unknown.
  final int? subscriptionId;

  /// `CallLog.Calls.FEATURES_*` bits. Prefer [hasVideo], [isWifi], [isHd]
  /// and [isRtt].
  final int features;

  /// Whether the user has seen the entry.
  final bool isRead;

  /// The country the number was dialed or received in, such as `EG`, or an
  /// empty string.
  final String countryIso;

  /// The call was a video call.
  bool get hasVideo => features & 1 != 0;

  /// The call went over Wi-Fi.
  bool get isWifi => features & 8 != 0;

  /// The call used HD voice.
  bool get isHd => features & 4 != 0;

  /// The call used real-time text.
  bool get isRtt => features & 32 != 0;

  // The fields below are filled by `TelephonyKit.getCallLogEntry`,
  // `getCallHistory`, `getContactCallHistory`, and `searchCallLog` with
  // `details: true`. Elsewhere they keep their defaults.

  /// The number formatted for the user's country, such as
  /// `+20 100 123 4567`, or an empty string. Prefer it over [number] for
  /// display.
  final String formattedNumber;

  /// The contact's label for the number at the time of the call: Mobile,
  /// Home, Work or a custom label. Empty when unknown.
  final String numberLabel;

  /// Digits dialed after the number, such as an extension after a pause.
  final String postDialDigits;

  /// The number the call came through, for calls forwarded by another
  /// number. Empty when not known.
  final String viaNumber;

  /// Whether the caller's number was shown, hidden or unknown.
  final NumberPresentation presentation;

  /// The contact lookup URI cached with the call, or null.
  final String? lookupUri;

  /// For voicemail entries, the voicemail's content URI, or null.
  final String? voicemailUri;

  /// For voicemail entries, the text transcription, or an empty string.
  final String transcription;

  /// Why a blocked call was blocked (`CallLog.Calls.BLOCK_REASON_*`, Android
  /// 10+), or 0.
  final int blockReason;

  /// The app that screened the call (Android 10+), or an empty string.
  final String screeningAppName;

  /// When the row last changed, or null.
  final DateTime? lastModified;

  /// The number to show: [formattedNumber] when known, else [number].
  String get displayNumber =>
      formattedNumber.isNotEmpty ? formattedNumber : number;

  /// The name to show: the cached contact [name], else the [displayNumber],
  /// or an empty string for a hidden number.
  String get displayName => name.isNotEmpty ? name : displayNumber;

  /// When the call ended: [date] plus [duration]. Equal to [date] for calls
  /// that were never connected.
  DateTime get endTime => date.add(duration);

  /// Whether the call was connected (an incoming, outgoing or externally
  /// answered call with talk time).
  bool get wasConnected => duration > Duration.zero;

  @override
  String toString() => 'CallLogEntry($type, $number, $date, $duration)';
}

/// Whether a caller's number was shown, mirroring
/// `CallLog.Calls.PRESENTATION_*`.
enum NumberPresentation {
  /// The number is known and shown.
  allowed(1),

  /// The caller hid their number.
  restricted(2),

  /// The network did not provide the number.
  unknown(3),

  /// A payphone.
  payphone(4),

  /// The number is not verified (Android 13+).
  unavailable(5);

  const NumberPresentation(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw `CallLog.Calls.NUMBER_PRESENTATION` value.
  static NumberPresentation fromValue(int value) =>
      NumberPresentation.values.firstWhere(
        (p) => p.value == value,
        orElse: () => NumberPresentation.allowed,
      );
}

/// All calls with one person: every number of a contact, or one number.
/// Returned by `TelephonyKit.getCallHistory` and
/// `TelephonyKit.getContactCallHistory`, or built with [CallHistory.from].
class CallHistory {
  const CallHistory({
    required this.numbers,
    required this.entries,
    this.name = '',
    this.contactId,
  });

  /// Keeps the [entries] that match any of [numbers] (ignoring formatting,
  /// and treating a leading 0 and a country code as the same number),
  /// newest first.
  factory CallHistory.from(
    Iterable<CallLogEntry> entries,
    List<String> numbers, {
    String name = '',
    String? contactId,
  }) {
    bool matches(String number) {
      for (final n in numbers) {
        if (_sameNumber(n, number)) return true;
      }
      return false;
    }

    final seen = <String>{};
    final kept = [
      for (final e in entries)
        if (matches(e.number) && (e.id.isEmpty || seen.add(e.id))) e,
    ]..sort((a, b) => b.date.compareTo(a.date));
    var resolved = name;
    if (resolved.isEmpty) {
      for (final e in kept) {
        if (e.name.isNotEmpty) {
          resolved = e.name;
          break;
        }
      }
    }
    return CallHistory(
      numbers: numbers,
      entries: kept,
      name: resolved,
      contactId: contactId,
    );
  }

  /// The numbers looked up.
  final List<String> numbers;

  /// The calls, newest first.
  final List<CallLogEntry> entries;

  /// The contact's name, or the cached name from the call log, or empty.
  final String name;

  /// The contact id, when the history is for a contact.
  final String? contactId;

  int _count(CallLogType type) => entries.where((e) => e.type == type).length;

  /// The number of calls.
  int get total => entries.length;
  int get incoming => _count(CallLogType.incoming);
  int get outgoing => _count(CallLogType.outgoing);
  int get missed => _count(CallLogType.missed);
  int get rejected => _count(CallLogType.rejected);
  int get blocked => _count(CallLogType.blocked);

  /// Time spent talking over all calls.
  Duration get totalDuration =>
      entries.fold(Duration.zero, (sum, e) => sum + e.duration);

  /// The longest call, or null when there are none with talk time.
  CallLogEntry? get longestCall {
    CallLogEntry? best;
    for (final e in entries) {
      if (e.duration > (best?.duration ?? Duration.zero)) best = e;
    }
    return best;
  }

  /// The newest call, or null when there are none.
  CallLogEntry? get lastCall => entries.isEmpty ? null : entries.first;

  /// The oldest call, or null when there are none.
  CallLogEntry? get firstCall => entries.isEmpty ? null : entries.last;

  /// The calls made with [number] only.
  List<CallLogEntry> entriesFor(String number) => [
    for (final e in entries)
      if (_sameNumber(number, e.number)) e,
  ];

  @override
  String toString() => 'CallHistory($numbers, $total calls)';
}

/// Same number ignoring formatting; numbers without digits (such as a
/// hidden caller) only match exactly.
bool _sameNumber(String a, String b) {
  if (sameNumberDigits(a, b)) return true;
  return normalizedNumber(a).isEmpty && a.isNotEmpty && a.trim() == b.trim();
}

/// The device's time zone, from `TelephonyKit.timeZone`.
class DeviceTimeZone {
  const DeviceTimeZone({
    required this.id,
    required this.name,
    required this.shortName,
    required this.offset,
    required this.standardOffset,
    required this.usesDaylightTime,
  });

  /// The IANA id, such as `Africa/Cairo`.
  final String id;

  /// The long name right now, such as `Eastern European Summer Time`.
  final String name;

  /// The short name right now, such as `EEST` or `GMT+03:00`.
  final String shortName;

  /// The offset from UTC right now, including daylight saving.
  final Duration offset;

  /// The offset from UTC without daylight saving.
  final Duration standardOffset;

  /// Whether the zone has daylight saving at some time of year.
  final bool usesDaylightTime;

  /// Whether daylight saving is in effect right now.
  bool get inDaylightTime => offset != standardOffset;

  @override
  String toString() => 'DeviceTimeZone($id, $offset)';
}

/// Something that happened to a call or to call audio.
sealed class CallEvent {
  const CallEvent();
}

/// A new call appeared, incoming or outgoing.
final class CallAdded extends CallEvent {
  const CallAdded(this.callId);

  /// The id to use with `TelephonyKit.call`.
  final String callId;
}

/// A call changed state.
final class CallStateChanged extends CallEvent {
  const CallStateChanged(this.callId, this.state);

  /// The call's id.
  final String callId;

  /// The new state.
  final CallState state;
}

/// A call ended and is no longer tracked.
final class CallRemoved extends CallEvent {
  const CallRemoved(this.callId);

  /// The call's id.
  final String callId;
}

/// A call ended, with the reason. Sent just before [CallRemoved].
final class CallDisconnected extends CallEvent {
  const CallDisconnected(this.callId, this.cause);

  /// The call's id.
  final String callId;

  /// Why the call ended.
  final DisconnectCause cause;
}

/// The dialed number had a wait character (`;`), for example
/// `0123456789;1234` for an extension. Ask the user whether to send
/// [remaining], then call `PhoneCall.continuePostDial`.
///
/// A pause (`,`) needs no answer: Android waits a moment and sends the
/// digits after it by itself.
final class PostDialWait extends CallEvent {
  const PostDialWait(this.callId, this.remaining);

  /// The call's id.
  final String callId;

  /// The digits still to send, which may contain more `,` or `;`.
  final String remaining;
}

/// The user asked to see the call screen: they answered from the call
/// notification, tapped the notification, or tapped Open on the call bubble.
/// The app is being brought to the front; show the call with [callId] (or
/// the current call when it is empty).
///
/// Only sent while Flutter is running. When the tap starts the app, read
/// `TelephonyKit.takeCallScreenRequest()` at startup instead.
final class CallScreenRequested extends CallEvent {
  const CallScreenRequested(this.callId);

  /// The call to show, or an empty string for the current call.
  final String callId;
}

/// Mute or the audio route changed.
final class AudioStateChanged extends CallEvent {
  const AudioStateChanged({required this.muted, required this.route});

  /// Whether the microphone is muted.
  final bool muted;

  /// Where audio is played.
  final AudioRoute route;
}

/// Kinds of call endings, mirroring `android.telecom.DisconnectCause` codes.
enum DisconnectCode {
  unknown(0),

  /// The call failed, for example no network.
  error(1),

  /// The user hung up.
  local(2),

  /// The other side hung up.
  remote(3),

  /// The outgoing call was canceled before it connected.
  canceled(4),

  /// An incoming call was not answered.
  missed(5),

  /// An incoming call was rejected.
  rejected(6),

  /// The other side was busy.
  busy(7),

  /// The call is not allowed, for example by call barring.
  restricted(8),

  /// Another reason, see [DisconnectCause.reason].
  other(9),

  connectionManagerNotSupported(10),

  /// The call was answered on another device.
  answeredElsewhere(11),

  /// The call was moved to another device.
  callPulled(12);

  const DisconnectCode(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw `android.telecom.DisconnectCause` code.
  static DisconnectCode fromValue(int value) =>
      DisconnectCode.values.firstWhere(
        (c) => c.value == value,
        orElse: () => DisconnectCode.unknown,
      );
}

/// Why a call ended.
class DisconnectCause {
  const DisconnectCause({
    required this.code,
    this.label = '',
    this.description = '',
    this.reason = '',
  });

  /// The kind of ending.
  final DisconnectCode code;

  /// A short text from Android to show the user, such as "Busy". Often
  /// empty.
  final String label;

  /// A longer explanation from Android to show the user. Often empty.
  final String description;

  /// A technical reason for logs, not for the user.
  final String reason;

  /// True when the call ended because of a problem rather than someone
  /// hanging up: [DisconnectCode.error], [DisconnectCode.busy],
  /// [DisconnectCode.restricted] or [DisconnectCode.other].
  bool get isFailure => const {
    DisconnectCode.error,
    DisconnectCode.busy,
    DisconnectCode.restricted,
    DisconnectCode.other,
  }.contains(code);

  /// Text to show the user: [label] when Android gave one, else a default
  /// for [code] such as "Busy" or "Call failed".
  String get displayText {
    if (label.isNotEmpty) return label;
    return switch (code) {
      DisconnectCode.error => 'Call failed',
      DisconnectCode.local => 'Call ended',
      DisconnectCode.remote => 'Call ended',
      DisconnectCode.canceled => 'Call canceled',
      DisconnectCode.missed => 'Missed call',
      DisconnectCode.rejected => 'Call declined',
      DisconnectCode.busy => 'Busy',
      DisconnectCode.restricted => 'Call not allowed',
      DisconnectCode.answeredElsewhere => 'Answered on another device',
      DisconnectCode.callPulled => 'Moved to another device',
      _ => 'Call ended',
    };
  }

  @override
  String toString() => 'DisconnectCause(${code.name}, "$label", $reason)';
}

/// Thrown when an Android call fails, for example because a permission is
/// missing.
class TelephonyException implements Exception {
  const TelephonyException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => 'TelephonyException: $message';
}

/// A phone number saved on a contact.
class ContactPhone {
  const ContactPhone({required this.number, required this.label});

  /// The number as stored in the contact.
  final String number;

  /// Mobile, home, work and so on, or a custom label. Empty when unknown.
  final String label;

  @override
  String toString() => label.isEmpty ? number : '$number ($label)';
}

/// A contact from the device address book.
class Contact {
  const Contact({
    required this.id,
    required this.displayName,
    required this.phones,
    required this.photoUri,
    required this.isStarred,
  });

  /// The contact id from `ContactsContract`.
  final String id;

  /// The contact's name.
  final String displayName;

  /// The contact's phone numbers.
  final List<ContactPhone> phones;

  /// A `content://` URI of the contact's thumbnail photo, or null.
  final String? photoUri;

  /// Whether the contact is a favorite.
  final bool isStarred;

  @override
  String toString() => 'Contact($displayName, $phones)';
}

/// An email address saved on a contact.
class ContactEmail {
  const ContactEmail({required this.address, this.label = ''});

  /// The email address.
  final String address;

  /// Home, Work, Mobile, Other, or a custom label. Empty when unknown.
  final String label;

  @override
  String toString() => label.isEmpty ? address : '$address ($label)';
}

/// A postal address saved on a contact.
class ContactAddress {
  const ContactAddress({required this.address, this.label = ''});

  /// The whole address as one text, with line breaks.
  final String address;

  /// Home, Work, Other, or a custom label. Empty when unknown.
  final String label;

  @override
  String toString() => label.isEmpty ? address : '$address ($label)';
}

/// An instant messaging handle saved on a contact.
class ContactIm {
  const ContactIm({required this.address, this.protocol = ''});

  /// The handle or user name.
  final String address;

  /// The service, such as Skype, Google Talk or Jabber, or a custom name.
  /// Empty when unknown.
  final String protocol;

  @override
  String toString() => protocol.isEmpty ? address : '$address ($protocol)';
}

/// A related person saved on a contact, such as a spouse or manager.
class ContactRelation {
  const ContactRelation({required this.name, this.label = ''});

  /// The related person's name.
  final String name;

  /// Spouse, Mother, Manager, Friend and so on, or a custom label.
  final String label;

  @override
  String toString() => label.isEmpty ? name : '$name ($label)';
}

/// One page of contacts from `TelephonyKit.getContactsPage`.
///
/// Load the next page by passing [nextOffset] as the offset, while [hasMore]
/// is true.
class ContactPage {
  const ContactPage({
    required this.contacts,
    required this.offset,
    required this.nextOffset,
    required this.totalCount,
  });

  /// An empty page, before anything is loaded.
  static const empty = ContactPage(
    contacts: [],
    offset: 0,
    nextOffset: 0,
    totalCount: 0,
  );

  /// The contacts on this page, in list order (favorites first, then by
  /// name).
  final List<ContactDetails> contacts;

  /// Where this page starts in the full list.
  final int offset;

  /// The offset of the next page. Usually `offset + contacts.length`, but
  /// larger when a contact was deleted after the list was counted.
  final int nextOffset;

  /// How many contacts match the query in total.
  final int totalCount;

  /// Whether there are contacts after this page.
  bool get hasMore => nextOffset < totalCount;

  @override
  String toString() =>
      'ContactPage(offset: $offset, count: ${contacts.length}, '
      'total: $totalCount)';
}

/// Everything saved on a contact, and also what you pass to
/// `TelephonyKit.addContact` and `TelephonyKit.updateContact`.
///
/// Every field except [id] is optional, so a new contact can be as small as
/// `ContactDetails(displayName: 'Sara', phones: [ContactPhone(...)])`. Use
/// [copyWith] to change a contact you read and save it again.
class ContactDetails {
  const ContactDetails({
    this.id = '',
    this.lookupKey = '',
    this.displayName = '',
    this.givenName = '',
    this.middleName = '',
    this.familyName = '',
    this.namePrefix = '',
    this.nameSuffix = '',
    this.nickname = '',
    this.company = '',
    this.department = '',
    this.jobTitle = '',
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.websites = const [],
    this.ims = const [],
    this.relations = const [],
    this.sipAddresses = const [],
    this.note = '',
    this.birthday,
    this.photoUri,
    this.isStarred = false,
  });

  /// The contact id from `ContactsContract`. Empty for a contact that has not
  /// been added yet.
  final String id;

  /// A key that stays valid when the contact is merged or synced. Read only.
  final String lookupKey;

  /// The name shown in lists. When you save a contact and give no
  /// [givenName] or [familyName], Android splits this text into them.
  final String displayName;

  /// First name.
  final String givenName;

  /// Middle name.
  final String middleName;

  /// Last name.
  final String familyName;

  /// Dr, Mrs and so on.
  final String namePrefix;

  /// Jr, III and so on.
  final String nameSuffix;

  /// Nickname.
  final String nickname;

  /// Company or organization.
  final String company;

  /// Department in the [company].
  final String department;

  /// Job title in the [company].
  final String jobTitle;

  /// Phone numbers.
  final List<ContactPhone> phones;

  /// Email addresses.
  final List<ContactEmail> emails;

  /// Postal addresses.
  final List<ContactAddress> addresses;

  /// Website URLs.
  final List<String> websites;

  /// Instant messaging handles.
  final List<ContactIm> ims;

  /// Related people (spouse, manager and so on).
  final List<ContactRelation> relations;

  /// Internet call (SIP) addresses.
  final List<String> sipAddresses;

  /// Free text notes.
  final String note;

  /// The birthday as `yyyy-MM-dd`, or `--MM-dd` when the year is unknown.
  final String? birthday;

  /// A `content://` URI of the contact's photo, or null. Read only: photos
  /// are not changed by `TelephonyKit.updateContact`.
  final String? photoUri;

  /// Whether the contact is a favorite.
  final bool isStarred;

  /// A copy with the given fields changed.
  ContactDetails copyWith({
    String? displayName,
    String? givenName,
    String? middleName,
    String? familyName,
    String? namePrefix,
    String? nameSuffix,
    String? nickname,
    String? company,
    String? department,
    String? jobTitle,
    List<ContactPhone>? phones,
    List<ContactEmail>? emails,
    List<ContactAddress>? addresses,
    List<String>? websites,
    List<ContactIm>? ims,
    List<ContactRelation>? relations,
    List<String>? sipAddresses,
    String? note,
    String? birthday,
    bool? isStarred,
  }) => ContactDetails(
    id: id,
    lookupKey: lookupKey,
    displayName: displayName ?? this.displayName,
    givenName: givenName ?? this.givenName,
    middleName: middleName ?? this.middleName,
    familyName: familyName ?? this.familyName,
    namePrefix: namePrefix ?? this.namePrefix,
    nameSuffix: nameSuffix ?? this.nameSuffix,
    nickname: nickname ?? this.nickname,
    company: company ?? this.company,
    department: department ?? this.department,
    jobTitle: jobTitle ?? this.jobTitle,
    phones: phones ?? this.phones,
    emails: emails ?? this.emails,
    addresses: addresses ?? this.addresses,
    websites: websites ?? this.websites,
    ims: ims ?? this.ims,
    relations: relations ?? this.relations,
    sipAddresses: sipAddresses ?? this.sipAddresses,
    note: note ?? this.note,
    birthday: birthday ?? this.birthday,
    photoUri: photoUri,
    isStarred: isStarred ?? this.isStarred,
  );

  @override
  String toString() => 'ContactDetails($id, $displayName)';
}

/// What call screening does with a matching call.
enum ScreeningAction {
  /// Let the call ring normally.
  allow(0),

  /// Let the call through without ringing. Needs Android 10+.
  silence(1),

  /// Reject the call and leave no notification.
  reject(2);

  const ScreeningAction(this.value);

  /// The raw value used by the Java layer.
  final int value;

  /// Converts a raw value.
  static ScreeningAction fromValue(int value) => ScreeningAction.values
      .firstWhere((a) => a.value == value, orElse: () => ScreeningAction.allow);
}

/// An incoming call that the screening service checked.
class ScreenedCall {
  const ScreenedCall({
    required this.number,
    required this.action,
    required this.reason,
  });

  /// The caller's number, or an empty string if hidden.
  final String number;

  /// What was done with the call.
  final ScreeningAction action;

  /// Why: `blocked_number`, `blocked_prefix`, `unknown_caller`,
  /// `hidden_number`, `emergency` (never blocked), `allowed` or `disabled`.
  final String reason;

  @override
  String toString() => 'ScreenedCall($number, $action, $reason)';
}

/// A number on the system block list (`BlockedNumberContract`).
class BlockedNumber {
  const BlockedNumber({
    required this.id,
    required this.number,
    required this.e164Number,
  });

  /// The row id.
  final String id;

  /// The number as it was blocked.
  final String number;

  /// The number in E.164 format, or an empty string.
  final String e164Number;

  @override
  String toString() => 'BlockedNumber($number)';
}

/// A Bluetooth device that can carry call audio.
class BluetoothAudioDevice {
  const BluetoothAudioDevice({
    required this.address,
    required this.name,
    required this.isActive,
  });

  /// The device's hardware address.
  final String address;

  /// The device's name. Empty without BLUETOOTH_CONNECT on Android 12+.
  final String name;

  /// Whether call audio is going to this device now.
  final bool isActive;

  @override
  String toString() => 'BluetoothAudioDevice(${name.isEmpty ? address : name})';
}

/// Whether the device is registered on a network,
/// mirroring `ServiceState.STATE_*`.
enum ServiceStatus {
  inService(0),
  outOfService(1),
  emergencyOnly(2),
  radioOff(3),
  unknown(-1);

  const ServiceStatus(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw value.
  static ServiceStatus fromValue(int value) => ServiceStatus.values.firstWhere(
    (s) => s.value == value,
    orElse: () => ServiceStatus.unknown,
  );
}

/// The device's call state, mirroring `TelephonyManager.CALL_STATE_*`.
enum DeviceCallState {
  idle(0),
  ringing(1),
  offHook(2),
  unknown(-1);

  const DeviceCallState(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw value.
  static DeviceCallState fromValue(int value) =>
      DeviceCallState.values.firstWhere(
        (s) => s.value == value,
        orElse: () => DeviceCallState.unknown,
      );
}

/// A simplified mobile network generation.
enum NetworkGeneration {
  unknown,
  g2,
  g3,
  g4,

  /// 5G standalone, or 5G shown over an LTE anchor (NSA).
  g5;

  /// The label phones usually show.
  String get label => switch (this) {
    NetworkGeneration.g2 => '2G',
    NetworkGeneration.g3 => '3G',
    NetworkGeneration.g4 => '4G',
    NetworkGeneration.g5 => '5G',
    NetworkGeneration.unknown => '',
  };

  /// Maps `TelephonyManager.NETWORK_TYPE_*` and
  /// `TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_*` to a generation.
  static NetworkGeneration from(int networkType, [int overrideType = 0]) {
    // OVERRIDE_NETWORK_TYPE_NR_NSA = 3, NR_ADVANCED = 5 (NR_NSA_MMWAVE = 4).
    if (overrideType == 3 || overrideType == 4 || overrideType == 5) {
      return NetworkGeneration.g5;
    }
    return switch (networkType) {
      1 || 2 || 4 || 7 || 11 || 16 => NetworkGeneration.g2,
      3 ||
      5 ||
      6 ||
      8 ||
      9 ||
      10 ||
      12 ||
      14 ||
      15 ||
      17 => NetworkGeneration.g3,
      13 || 18 || 19 => NetworkGeneration.g4,
      20 => NetworkGeneration.g5,
      _ => NetworkGeneration.unknown,
    };
  }
}

/// A change in signal, service or network reported by
/// `TelephonyKit.networkEvents`.
sealed class NetworkEvent {
  const NetworkEvent();
}

/// The signal level changed.
final class SignalStrengthChanged extends NetworkEvent {
  const SignalStrengthChanged(this.level);

  /// From 0 (none) to 4 (great).
  final int level;
}

/// The device registered on or lost the network.
final class ServiceStatusChanged extends NetworkEvent {
  const ServiceStatusChanged(this.status);

  /// The new status.
  final ServiceStatus status;
}

/// The network type changed, for example from LTE to 5G.
final class NetworkTypeChanged extends NetworkEvent {
  const NetworkTypeChanged({
    required this.networkType,
    required this.overrideType,
  });

  /// `TelephonyManager.NETWORK_TYPE_*`.
  final int networkType;

  /// `TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_*`, or 0.
  final int overrideType;

  /// The generation to show, such as 4G or 5G.
  NetworkGeneration get generation =>
      NetworkGeneration.from(networkType, overrideType);
}

/// The device call state changed (any app). Needs READ_PHONE_STATE.
final class DeviceCallStateChanged extends NetworkEvent {
  const DeviceCallStateChanged(this.state, this.number);

  /// The new state.
  final DeviceCallState state;

  /// The number, usually empty on modern Android.
  final String number;
}

/// Whether an SMS was received or sent, mirroring `Telephony.Sms.TYPE`.
enum SmsType {
  inbox(1),
  sent(2),
  draft(3),
  outbox(4),
  failed(5),
  queued(6),
  unknown(-1);

  const SmsType(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw value.
  static SmsType fromValue(int value) => SmsType.values.firstWhere(
    (t) => t.value == value,
    orElse: () => SmsType.unknown,
  );
}

/// One SMS from the device's message store.
class SmsMessage {
  const SmsMessage({
    required this.id,
    required this.threadId,
    required this.address,
    required this.body,
    required this.date,
    required this.type,
    required this.isRead,
  });

  /// The row id.
  final String id;

  /// The conversation id.
  final String threadId;

  /// The other party's number or sender name.
  final String address;

  /// The message text.
  final String body;

  /// When it was received or sent.
  final DateTime date;

  /// Inbox, sent and so on.
  final SmsType type;

  /// Whether the user has read it.
  final bool isRead;

  @override
  String toString() => 'SmsMessage($type, $address, $date)';
}

/// A contact group (a label such as Family or Work).
class ContactGroup {
  const ContactGroup({
    required this.id,
    required this.title,
    this.accountName = '',
    this.accountType = '',
    this.isReadOnly = false,
    this.memberCount = 0,
  });

  /// The group id.
  final String id;

  /// The group name.
  final String title;

  /// The account the group belongs to, or an empty string for the device.
  final String accountName;

  /// The account type, such as `com.google`, or an empty string.
  final String accountType;

  /// System groups cannot be renamed or deleted.
  final bool isReadOnly;

  /// How many contacts are in the group.
  final int memberCount;

  @override
  String toString() => 'ContactGroup($title, $memberCount)';
}

/// An account that holds contacts (Google, SIM, device and so on).
class ContactAccount {
  const ContactAccount({required this.name, required this.type});

  /// The account name, such as an email address.
  final String name;

  /// The account type, such as `com.google`.
  final String type;

  @override
  String toString() => 'ContactAccount($name, $type)';
}

/// Call counts for one phone number, from `TelephonyKit.getCallLogStats`.
class CallLogNumberStats {
  const CallLogNumberStats({
    required this.number,
    required this.name,
    required this.total,
    required this.incoming,
    required this.outgoing,
    required this.missed,
    required this.rejected,
    required this.blocked,
    required this.totalDuration,
    required this.lastCall,
  });

  /// The number as stored in the first entry seen.
  final String number;

  /// The cached contact name, or an empty string.
  final String name;

  /// All entries for the number.
  final int total;
  final int incoming;
  final int outgoing;
  final int missed;
  final int rejected;
  final int blocked;

  /// Time spent talking, over all entries.
  final Duration totalDuration;

  /// When the most recent call happened.
  final DateTime lastCall;

  @override
  String toString() => 'CallLogNumberStats($number, $total calls)';
}

/// Consecutive call log entries for the same number, shown as one row such
/// as "Sara (3)".
class CallLogGroup {
  const CallLogGroup({required this.number, required this.entries});

  /// The shared number.
  final String number;

  /// The entries, newest first.
  final List<CallLogEntry> entries;

  /// The newest entry.
  CallLogEntry get latest => entries.first;

  /// The contact name of the newest entry that has one, or an empty string.
  String get name {
    for (final e in entries) {
      if (e.name.isNotEmpty) return e.name;
    }
    return '';
  }

  @override
  String toString() => 'CallLogGroup($number, ${entries.length})';
}

/// One SMS conversation.
class SmsThread {
  const SmsThread({
    required this.threadId,
    required this.address,
    required this.snippet,
    required this.lastDate,
    required this.messageCount,
    required this.unreadCount,
  });

  /// The conversation id, for `TelephonyKit.searchSms(threadId: ...)`.
  final String threadId;

  /// The other party's number or sender name.
  final String address;

  /// The text of the newest message.
  final String snippet;

  /// When the newest message was received or sent.
  final DateTime lastDate;

  /// How many messages were read from the provider for this thread.
  final int messageCount;

  /// How many of them are unread.
  final int unreadCount;

  @override
  String toString() => 'SmsThread($address, $messageCount)';
}

/// One attachment or text part of an MMS.
class MmsPart {
  const MmsPart({
    required this.id,
    required this.contentType,
    required this.name,
    required this.text,
    required this.uri,
  });

  /// The part id.
  final String id;

  /// The MIME type, such as `image/jpeg` or `text/plain`.
  final String contentType;

  /// The file name, or an empty string.
  final String name;

  /// The text for a `text/plain` part, otherwise an empty string.
  final String text;

  /// A `content://` URI of the part's data, for example to show an image.
  final String uri;

  /// Whether this is a text part.
  bool get isText => contentType == 'text/plain';

  /// Whether this is an image.
  bool get isImage => contentType.startsWith('image/');

  @override
  String toString() => 'MmsPart($contentType)';
}

/// A multimedia message (MMS), read only.
class MmsMessage {
  const MmsMessage({
    required this.id,
    required this.threadId,
    required this.date,
    required this.subject,
    required this.addresses,
    required this.isIncoming,
    required this.isRead,
    required this.parts,
  });

  /// The row id.
  final String id;

  /// The conversation id.
  final String threadId;

  /// When it was received or sent.
  final DateTime date;

  /// The subject, or an empty string.
  final String subject;

  /// The other parties' numbers.
  final List<String> addresses;

  /// Whether it was received.
  final bool isIncoming;

  /// Whether the user has read it.
  final bool isRead;

  /// The text and attachments.
  final List<MmsPart> parts;

  /// All text parts joined.
  String get text => parts.where((p) => p.isText).map((p) => p.text).join('\n');

  @override
  String toString() => 'MmsMessage($id, $addresses, ${parts.length} parts)';
}

/// The result of the STIR/SHAKEN check on a caller's number (Android 11+).
enum NumberVerification {
  /// The network did not verify the number.
  notVerified,

  /// The network confirmed the caller owns the number.
  passed,

  /// The check failed, so the number may be spoofed.
  failed,

  /// Not available on this device, call or Android version.
  unknown;

  /// Converts `Call.Details.getCallerNumberVerificationStatus` (0, 1, 2).
  static NumberVerification fromValue(int value) => switch (value) {
    0 => notVerified,
    1 => passed,
    2 => failed,
    _ => unknown,
  };
}

/// When a call is forwarded to another number.
enum CallForwardingCondition {
  /// Always.
  unconditional('21'),

  /// When you are busy.
  busy('67'),

  /// When you do not answer.
  noReply('61'),

  /// When your phone is off or has no signal.
  notReachable('62');

  const CallForwardingCondition(this.code);

  /// The GSM service code (`*21*number#` and so on).
  final String code;
}

/// A phone number of one of the device's SIMs.
class PhoneNumberInfo {
  const PhoneNumberInfo({
    required this.subscriptionId,
    required this.slotIndex,
    required this.number,
  });

  /// Matches `SimCard.subscriptionId`.
  final int subscriptionId;

  /// The SIM slot, starting at 0.
  final int slotIndex;

  /// The number, or an empty string when the carrier did not store it.
  final String number;

  @override
  String toString() => 'PhoneNumberInfo(slot $slotIndex, $number)';
}

/// A nearby cell tower.
class CellInfo {
  const CellInfo({
    required this.type,
    required this.isRegistered,
    required this.dbm,
    required this.level,
    required this.cellId,
  });

  /// `lte`, `nr`, `gsm`, `wcdma`, `cdma` or `unknown`.
  final String type;

  /// Whether the device is connected to this cell.
  final bool isRegistered;

  /// Signal strength in dBm, or null when unknown.
  final int? dbm;

  /// Signal level from 0 to 4, or -1 when unknown.
  final int level;

  /// The cell id, or -1 when unknown.
  final int cellId;

  @override
  String toString() => 'CellInfo($type, $dbm dBm)';
}

/// Mobile data connection state, mirroring `TelephonyManager.DATA_*`.
enum DataConnectionState {
  disconnected(0),
  connecting(1),
  connected(2),
  suspended(3),
  unknown(-1);

  const DataConnectionState(this.value);

  /// The raw Android value.
  final int value;

  /// Converts a raw value.
  static DataConnectionState fromValue(int value) =>
      DataConnectionState.values.firstWhere(
        (s) => s.value == value,
        orElse: () => DataConnectionState.unknown,
      );
}

/// eSIM support and the eSIM profiles on the device.
class EsimInfo {
  const EsimInfo({
    required this.isSupported,
    required this.eid,
    required this.profiles,
  });

  /// Whether the device has an eSIM chip that is enabled.
  final bool isSupported;

  /// The chip's EID. Empty unless the app has carrier privileges.
  final String eid;

  /// Active SIMs that are eSIM profiles.
  final List<SimCard> profiles;

  @override
  String toString() => 'EsimInfo(supported: $isSupported, ${profiles.length})';
}

/// Button labels of the floating call bubble. Set them with
/// `TelephonyKit.callBubble.labels` to translate the bubble.
class CallBubbleLabels {
  const CallBubbleLabels({
    this.answer = 'Answer',
    this.decline = 'Decline',
    this.mute = 'Mute',
    this.unmute = 'Unmute',
    this.speaker = 'Speaker',
    this.end = 'End',
    this.open = 'Open',
  });

  final String answer;
  final String decline;
  final String mute;
  final String unmute;
  final String speaker;
  final String end;

  /// Back to the app's call screen.
  final String open;
}
