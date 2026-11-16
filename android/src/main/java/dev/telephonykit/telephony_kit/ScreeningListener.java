package dev.telephonykit.telephony_kit;

/** Told about each incoming call that {@link TelephonyKitCallScreeningService} screened. */
public interface ScreeningListener {
  /**
   * {@code action} is {@link CallScreening#ACTION_ALLOW},
   * {@link CallScreening#ACTION_SILENCE} or {@link CallScreening#ACTION_REJECT}.
   * {@code reason} is a short machine readable reason such as "blocked_number".
   */
  void onCallScreened(String number, int action, String reason);
}
