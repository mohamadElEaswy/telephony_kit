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

  /** A call was removed and is no longer tracked. */
  void onCallRemoved(String callId);

  /**
   * The audio state changed. {@code route} is one of
   * {@code android.telecom.CallAudioState.ROUTE_*}.
   */
  void onAudioStateChanged(boolean muted, int route);
}
