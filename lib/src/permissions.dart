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

  /// Needed to change the call log.
  static const writeCallLog = 'android.permission.WRITE_CALL_LOG';

  /// Needed by `TelephonyKit.endCall` on Android 9 and newer.
  static const answerPhoneCalls = 'android.permission.ANSWER_PHONE_CALLS';

  /// Needed to read the device's own phone numbers.
  static const readPhoneNumbers = 'android.permission.READ_PHONE_NUMBERS';
}
