/// Android permission names used by telephony_kit.
///
/// The package does not request permissions itself, because requesting them
/// needs an activity result callback. Use a package such as
/// `permission_handler` to request them, and [TelephonyPermission] names to
/// check them with `TelephonyKit.hasPermission`.
abstract final class TelephonyPermission {
  /// Needed by `TelephonyKit.placeCall`.
  static const callPhone = 'android.permission.CALL_PHONE';

  /// Needed for SIM and network details.
  static const readPhoneState = 'android.permission.READ_PHONE_STATE';

  /// Needed by `TelephonyKit.getCallLog`.
  static const readCallLog = 'android.permission.READ_CALL_LOG';

  /// Needed by `TelephonyKit.deleteCallLogEntries` and
  /// `TelephonyKit.markMissedCallsRead`.
  static const writeCallLog = 'android.permission.WRITE_CALL_LOG';

  /// Needed by `TelephonyKit.endCall` on Android 9 and newer.
  static const answerPhoneCalls = 'android.permission.ANSWER_PHONE_CALLS';

  /// Needed by `TelephonyKit.searchContacts`, `TelephonyKit.lookupNumber`,
  /// `TelephonyKit.getContact` and `TelephonyKit.getContacts`.
  static const readContacts = 'android.permission.READ_CONTACTS';

  /// Needed by `TelephonyKit.addContact`, `TelephonyKit.updateContact`,
  /// `TelephonyKit.deleteContacts` and `TelephonyKit.setContactStarred`.
  static const writeContacts = 'android.permission.WRITE_CONTACTS';

  /// Needed by `TelephonyKit.sendSms`.
  static const sendSms = 'android.permission.SEND_SMS';

  /// Needed by `TelephonyKit.searchSms`.
  static const readSms = 'android.permission.READ_SMS';

  /// Needed for call notifications on Android 13+.
  static const postNotifications = 'android.permission.POST_NOTIFICATIONS';

  /// Needed for Bluetooth device names on Android 12+.
  static const bluetoothConnect = 'android.permission.BLUETOOTH_CONNECT';

  /// Needed by `TelephonyKit.getCellInfo`.
  static const accessFineLocation = 'android.permission.ACCESS_FINE_LOCATION';

  /// Needed to read the device's own phone numbers.
  static const readPhoneNumbers = 'android.permission.READ_PHONE_NUMBERS';
}
