/// Data types returned by `TelephonyKit`.
library;

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
    required this.number,
    required this.name,
    required this.type,
    required this.date,
    required this.duration,
  });

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

  @override
  String toString() => 'CallLogEntry($type, $number, $date, $duration)';
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

/// Mute or the audio route changed.
final class AudioStateChanged extends CallEvent {
  const AudioStateChanged({required this.muted, required this.route});

  /// Whether the microphone is muted.
  final bool muted;

  /// Where audio is played.
  final AudioRoute route;
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
