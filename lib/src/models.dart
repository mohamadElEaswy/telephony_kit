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
  /// `hidden_number`, `allowed` or `disabled`.
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
