package dev.telephonykit.telephony_kit;

/**
 * Receives call events from {@link CallManager}.
 *
 * <p>Implemented from Dart through jnigen. All callbacks are delivered on the
 * Android main thread and must return quickly.
 */
public interface CallEventListener {
  /** A new call was added (incoming or outgoing). */
  void onCallAdded(String callId);

  /** The state of a call changed. {@code state} is one of {@code android.telecom.Call.STATE_*}. */
  void onCallStateChanged(String callId, int state);

  /**
   * A call ended. {@code code} is one of {@code android.telecom.DisconnectCause}
   * codes, {@code label} a short text for the user (may be empty) and {@code
   * reason} a technical reason for logs. Sent just before {@link
   * #onCallRemoved}.
   */
  void onCallDisconnected(String callId, int code, String label, String reason);

  /**
   * The dialed number had a wait character (';'). Ask the user, then call
   * {@link CallManager#continuePostDial}. {@code remaining} is the digits
   * still to send.
   */
  void onPostDialWait(String callId, String remaining);

  /** A call was removed and is no longer tracked. */
  void onCallRemoved(String callId);

  /**
   * The audio state changed. {@code route} is one of
   * {@code android.telecom.CallAudioState.ROUTE_*}.
   */
  void onAudioStateChanged(boolean muted, int route);

  /**
   * The user asked to see the call screen: they answered from the
   * notification, tapped the call notification, or tapped Open on the call
   * bubble. {@code callId} is the call to show, or empty for the current
   * call. The app is being brought to the front.
   */
  void onShowCallScreen(String callId);
}
