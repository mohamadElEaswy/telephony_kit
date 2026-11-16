package dev.telephonykit.telephony_kit;

/** Receives radio and network changes from {@link NetworkMonitor}. */
public interface NetworkEventListener {
  /** Signal level from 0 (none) to 4 (great). */
  void onSignalStrengthChanged(int level);

  /** {@code android.telephony.ServiceState.STATE_*}: 0 in service, 1 out of service, 2 emergency only, 3 radio off. */
  void onServiceStateChanged(int state);

  /**
   * {@code networkType} is a {@code TelephonyManager.NETWORK_TYPE_*} value.
   * {@code overrideType} is a {@code TelephonyDisplayInfo.OVERRIDE_NETWORK_TYPE_*}
   * value (for example 5G NSA shown on LTE), or 0.
   */
  void onNetworkTypeChanged(int networkType, int overrideType);

  /**
   * Device call state: 0 idle, 1 ringing, 2 off hook. Only delivered when
   * READ_PHONE_STATE is granted. {@code number} is usually empty on modern
   * Android.
   */
  void onCallStateChanged(int state, String number);
}
