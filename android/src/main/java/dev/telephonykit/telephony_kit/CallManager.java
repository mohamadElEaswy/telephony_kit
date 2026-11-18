package dev.telephonykit.telephony_kit;

import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.telecom.Call;
import android.telecom.CallAudioState;
import android.telecom.DisconnectCause;
import android.telecom.InCallService;
import android.telecom.PhoneAccountHandle;
import android.telecom.VideoProfile;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Tracks calls reported by {@link TelephonyKitInCallService} and exposes
 * simple, id based controls that are easy to call from Dart through jnigen.
 */
public final class CallManager {
  private CallManager() {}

  private static final Object lock = new Object();
  private static final Map<String, Call> calls = new LinkedHashMap<>();
  private static final Map<String, Boolean> incoming = new LinkedHashMap<>();
  private static final Map<Call, Call.Callback> callbacks = new LinkedHashMap<>();
  private static final Handler mainHandler = new Handler(Looper.getMainLooper());

  private static InCallService service;
  private static CallEventListener listener;
  private static boolean launchAppOnIncomingCall = true;
  private static boolean showNotifications = true;
  private static Context appContext;
  private static CallAudioState lastAudioState;
  private static int nextId = 1;
  private static boolean lastMuted = false;
  private static int lastRoute = CallAudioState.ROUTE_EARPIECE;
  private static boolean proximityEnabled = true;
  /** Digits waiting for the user after a ';' in the dialed number. */
  private static final Map<String, String> postDialWaits = new LinkedHashMap<>();
  /** Why recent calls ended, kept after removal so Dart can still read it. */
  private static final Map<String, DisconnectCause> disconnectCauses =
      new LinkedHashMap<String, DisconnectCause>() {
        @Override
        protected boolean removeEldestEntry(Map.Entry<String, DisconnectCause> eldest) {
          return size() > 20;
        }
      };
  /** RTT requests from the other side that the user has not answered yet. */
  private static final Map<String, Integer> rttRequests = new LinkedHashMap<>();
  private static PowerManager.WakeLock proximityLock;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /** Sets (or clears, with {@code null}) the listener that receives call events. */
  public static void setListener(CallEventListener newListener) {
    synchronized (lock) {
      listener = newListener;
    }
  }

  /** Whether the app's launch activity is opened when a call starts ringing. */
  public static void setLaunchAppOnIncomingCall(boolean enabled) {
    launchAppOnIncomingCall = enabled;
  }

  /**
   * Whether incoming and ongoing call notifications are shown (default true).
   * The incoming notification has answer and decline buttons and opens the
   * app full screen on the lock screen.
   */
  public static void setShowCallNotifications(boolean enabled) {
    showNotifications = enabled;
    Context ctx = appContext;
    if (!enabled && ctx != null) CallNotifications.cancel(ctx);
  }

  /**
   * Whether the screen turns off when the phone is near the ear during a
   * call (default true). Only applies to calls that are active or dialing
   * with audio on the earpiece or a wired headset.
   */
  public static void setProximitySensorEnabled(boolean enabled) {
    proximityEnabled = enabled;
    mainHandler.post(CallManager::updateProximity);
  }

  public static boolean isProximitySensorEnabled() {
    return proximityEnabled;
  }

  /** True while the proximity wake lock is held (the screen may be off). */
  public static boolean isProximityLockHeld() {
    PowerManager.WakeLock lock = proximityLock;
    return lock != null && lock.isHeld();
  }

  /** True while the system is bound to {@link TelephonyKitInCallService}. */
  public static boolean isServiceBound() {
    synchronized (lock) {
      return service != null;
    }
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /** Ids of all tracked calls, oldest first. */
  public static String[] getCallIds() {
    synchronized (lock) {
      return calls.keySet().toArray(new String[0]);
    }
  }

  /** One of {@code android.telecom.Call.STATE_*}, or -1 if the call is unknown. */
  @SuppressWarnings("deprecation")
  public static int getState(String callId) {
    Call call = find(callId);
    if (call == null) return -1;
    if (Build.VERSION.SDK_INT >= 31) {
      return call.getDetails().getState();
    }
    return call.getState();
  }

  /** The remote phone number, or an empty string if it is hidden or unknown. */
  public static String getNumber(String callId) {
    Call call = find(callId);
    if (call == null || call.getDetails() == null) return "";
    Uri handle = call.getDetails().getHandle();
    if (handle == null) return "";
    String number = handle.getSchemeSpecificPart();
    return number == null ? "" : number;
  }

  /** The caller name provided by the network or contacts, or an empty string. */
  public static String getDisplayName(String callId) {
    Call call = find(callId);
    if (call == null || call.getDetails() == null) return "";
    Call.Details details = call.getDetails();
    String name = null;
    if (Build.VERSION.SDK_INT >= 29) {
      name = details.getContactDisplayName();
    }
    if (name == null || name.isEmpty()) {
      name = details.getCallerDisplayName();
    }
    return name == null ? "" : name;
  }

  /** True if the call was incoming. */
  public static boolean isIncoming(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    if (Build.VERSION.SDK_INT >= 29) {
      return call.getDetails().getCallDirection() == Call.Details.DIRECTION_INCOMING;
    }
    synchronized (lock) {
      Boolean value = incoming.get(callId);
      return value != null && value;
    }
  }

  /** Wall clock time in milliseconds when the call connected, or 0. */
  public static long getConnectTimeMillis(String callId) {
    Call call = find(callId);
    if (call == null || call.getDetails() == null) return 0;
    return call.getDetails().getConnectTimeMillis();
  }

  /** Whether the microphone is muted for the current call. */
  public static boolean isMuted() {
    return lastMuted;
  }

  /** The current audio route, one of {@code android.telecom.CallAudioState.ROUTE_*}. */
  public static int getAudioRoute() {
    return lastRoute;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /** Answers a ringing call as an audio call. Returns false if the call is unknown. */
  public static boolean answer(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    call.answer(VideoProfile.STATE_AUDIO_ONLY);
    return true;
  }

  /** Rejects a ringing call. */
  public static boolean reject(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    call.reject(false, null);
    return true;
  }

  /**
   * Rejects a ringing call and sends {@code message} to the caller as a text
   * message. Telecom sends it; the app needs no SMS permission.
   */
  public static boolean rejectWithMessage(String callId, String message) {
    Call call = find(callId);
    if (call == null) return false;
    call.reject(message != null && !message.isEmpty(), message);
    return true;
  }

  /**
   * The quick reply texts Telecom offers for a ringing call (the user's
   * "respond via message" settings), or an empty array if not loaded yet.
   */
  public static String[] getCannedTextResponses(String callId) {
    Call call = find(callId);
    if (call == null) return new String[0];
    List<String> responses = call.getCannedTextResponses();
    return responses == null ? new String[0] : responses.toArray(new String[0]);
  }

  /** Hangs up an active, dialing or held call. */
  public static boolean disconnect(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    call.disconnect();
    return true;
  }

  /** Puts a call on hold. */
  public static boolean hold(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    call.hold();
    return true;
  }

  /** Resumes a held call. */
  public static boolean unhold(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    call.unhold();
    return true;
  }

  /** Starts playing a DTMF tone. {@code digit} is one of 0-9, *, #. */
  public static boolean playDtmfTone(String callId, String digit) {
    Call call = find(callId);
    if (call == null || digit == null || digit.isEmpty()) return false;
    call.playDtmfTone(digit.charAt(0));
    return true;
  }

  /** Stops the DTMF tone started with {@link #playDtmfTone}. */
  public static boolean stopDtmfTone(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    call.stopDtmfTone();
    return true;
  }

  /** Mutes or unmutes the microphone. Returns false when no call is in progress. */
  public static boolean setMuted(boolean muted) {
    InCallService current;
    synchronized (lock) {
      current = service;
    }
    if (current == null) return false;
    current.setMuted(muted);
    return true;
  }

  /** Routes audio to the speaker, or back to the earpiece or wired headset. */
  @SuppressWarnings("deprecation")
  public static boolean setSpeakerOn(boolean on) {
    InCallService current;
    synchronized (lock) {
      current = service;
    }
    if (current == null) return false;
    current.setAudioRoute(on ? CallAudioState.ROUTE_SPEAKER : CallAudioState.ROUTE_WIRED_OR_EARPIECE);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Post-dial digits
  // ---------------------------------------------------------------------------

  /**
   * Digits waiting to be sent after a wait character (';') in the dialed
   * number, or "" when the call is not waiting.
   */
  public static String getPostDialRemaining(String callId) {
    synchronized (lock) {
      String remaining = postDialWaits.get(callId);
      return remaining == null ? "" : remaining;
    }
  }

  /**
   * Answers a post-dial wait: {@code proceed} true sends the remaining
   * digits, false drops them. Returns false if the call is unknown.
   */
  public static boolean continuePostDial(String callId, boolean proceed) {
    Call call = find(callId);
    if (call == null) return false;
    synchronized (lock) {
      postDialWaits.remove(callId);
    }
    call.postDialContinue(proceed);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Disconnect cause
  // ---------------------------------------------------------------------------

  private static DisconnectCause causeOf(String callId) {
    Call call = find(callId);
    if (call != null && call.getDetails() != null) {
      DisconnectCause cause = call.getDetails().getDisconnectCause();
      if (cause != null && cause.getCode() != DisconnectCause.UNKNOWN) return cause;
    }
    synchronized (lock) {
      return disconnectCauses.get(callId);
    }
  }

  /**
   * Why the call ended, one of {@code android.telecom.DisconnectCause} codes
   * (for example BUSY is 7), or -1 if it has not ended. Still available for a
   * while after the call was removed.
   */
  public static int getDisconnectCode(String callId) {
    DisconnectCause cause = causeOf(callId);
    return cause == null ? -1 : cause.getCode();
  }

  /** A short text to show the user, such as "Busy", or "". */
  public static String getDisconnectLabel(String callId) {
    DisconnectCause cause = causeOf(callId);
    return cause == null || cause.getLabel() == null ? "" : cause.getLabel().toString();
  }

  /** A longer explanation to show the user, or "". */
  public static String getDisconnectDescription(String callId) {
    DisconnectCause cause = causeOf(callId);
    return cause == null || cause.getDescription() == null
        ? ""
        : cause.getDescription().toString();
  }

  /** The technical reason for logs, or "". */
  public static String getDisconnectReason(String callId) {
    DisconnectCause cause = causeOf(callId);
    return cause == null || cause.getReason() == null ? "" : cause.getReason();
  }

  // ---------------------------------------------------------------------------
  // Phone accounts (SIMs)
  // ---------------------------------------------------------------------------

  /**
   * Ids of the phone accounts the user can pick for a call in {@code
   * STATE_SELECT_PHONE_ACCOUNT} (an outgoing call on a multi SIM device with
   * no default SIM). Empty if the call is unknown.
   */
  public static String[] getSelectablePhoneAccountIds(String callId) {
    Call call = find(callId);
    if (call == null) return new String[0];
    List<String> ids = new ArrayList<>();
    for (PhoneAccountHandle h : PhoneAccounts.selectable(appContext, call)) ids.add(h.getId());
    return ids.toArray(new String[0]);
  }

  /** The label of a call capable phone account (usually the carrier), or "". */
  public static String getPhoneAccountLabel(Context context, String accountId) {
    Context ctx = context != null ? context.getApplicationContext() : appContext;
    if (ctx == null) return "";
    return PhoneAccounts.label(ctx, PhoneAccounts.find(PhoneAccounts.callCapable(ctx), accountId));
  }

  /**
   * The SIM slot (0 based) of a call capable phone account, or -1 when
   * unknown or before Android 11.
   */
  public static int getPhoneAccountSlot(Context context, String accountId) {
    Context ctx = context != null ? context.getApplicationContext() : appContext;
    if (ctx == null) return -1;
    return PhoneAccounts.slot(ctx, PhoneAccounts.find(PhoneAccounts.callCapable(ctx), accountId));
  }

  /** The id of the phone account (SIM) the call uses, or "" if not chosen yet. */
  public static String getPhoneAccountId(String callId) {
    Call call = find(callId);
    if (call == null || call.getDetails() == null) return "";
    PhoneAccountHandle handle = call.getDetails().getAccountHandle();
    return handle == null || handle.getId() == null ? "" : handle.getId();
  }

  /** The label of the phone account the call uses (usually the carrier), or "". */
  public static String getCallPhoneAccountLabel(String callId) {
    Call call = find(callId);
    if (call == null || call.getDetails() == null) return "";
    return PhoneAccounts.label(appContext, call.getDetails().getAccountHandle());
  }

  /** The SIM slot of the phone account the call uses, or -1. */
  public static int getCallPhoneAccountSlot(String callId) {
    Call call = find(callId);
    if (call == null || call.getDetails() == null) return -1;
    return PhoneAccounts.slot(appContext, call.getDetails().getAccountHandle());
  }

  /**
   * Places a call that waits in {@code STATE_SELECT_PHONE_ACCOUNT} on the
   * account with this id. {@code setDefault} also makes it the default for
   * calls. Returns false if the call or account is unknown.
   */
  public static boolean selectPhoneAccount(String callId, String accountId, boolean setDefault) {
    Call call = find(callId);
    if (call == null) return false;
    PhoneAccountHandle handle = PhoneAccounts.find(PhoneAccounts.selectable(appContext, call), accountId);
    if (handle == null) return false;
    call.phoneAccountSelected(handle, setDefault);
    return true;
  }

  // ---------------------------------------------------------------------------
  // Video, verification, Wi-Fi and RTT
  // ---------------------------------------------------------------------------

  /** {@code VideoProfile.STATE_*} bits of the call (0 audio only, 1 TX, 2 RX, 3 both), or -1. */
  public static int getVideoState(String callId) {
    Call call = find(callId);
    return call == null || call.getDetails() == null ? -1 : call.getDetails().getVideoState();
  }

  /** Answers a ringing call with the given {@code VideoProfile.STATE_*} bits. */
  public static boolean answerWithVideoState(String callId, int videoState) {
    Call call = find(callId);
    if (call == null) return false;
    call.answer(videoState);
    return true;
  }

  /**
   * STIR/SHAKEN result for the caller's number: 0 not verified, 1 passed, 2
   * failed, or -1 when unknown or before Android 11.
   */
  public static int getNumberVerification(String callId) {
    if (Build.VERSION.SDK_INT < 30) return -1;
    Call call = find(callId);
    if (call == null || call.getDetails() == null) return -1;
    return call.getDetails().getCallerNumberVerificationStatus();
  }

  /** True if the call is carried over Wi-Fi (Wi-Fi calling). */
  public static boolean isWifiCall(String callId) {
    Call call = find(callId);
    return call != null
        && call.getDetails() != null
        && call.getDetails().hasProperty(Call.Details.PROPERTY_WIFI);
  }

  /** True if the call uses high definition audio (HD voice). */
  public static boolean isHighDefinitionAudio(String callId) {
    Call call = find(callId);
    return call != null
        && call.getDetails() != null
        && call.getDetails().hasProperty(Call.Details.PROPERTY_HIGH_DEF_AUDIO);
  }

  /** True while real-time text (RTT) is active on the call. Android 9+. */
  public static boolean isRttActive(String callId) {
    if (Build.VERSION.SDK_INT < 28) return false;
    Call call = find(callId);
    return call != null && call.isRttActive();
  }

  /** Asks the other side to start real-time text. Android 9+. */
  public static boolean requestRtt(String callId) {
    if (Build.VERSION.SDK_INT < 28) return false;
    Call call = find(callId);
    if (call == null) return false;
    call.sendRttRequest();
    return true;
  }

  /** Stops real-time text on the call. Android 9+. */
  public static boolean stopRtt(String callId) {
    if (Build.VERSION.SDK_INT < 28) return false;
    Call call = find(callId);
    if (call == null) return false;
    call.stopRtt();
    return true;
  }

  /** The id of an RTT request from the other side waiting for an answer, or -1. */
  public static int getPendingRttRequest(String callId) {
    synchronized (lock) {
      Integer id = rttRequests.get(callId);
      return id == null ? -1 : id;
    }
  }

  /** Accepts or declines an RTT request that arrived on the call. Android 9+. */
  public static boolean respondToRttRequest(String callId, int requestId, boolean accept) {
    if (Build.VERSION.SDK_INT < 28) return false;
    Call call = find(callId);
    if (call == null) return false;
    call.respondToRttRequest(requestId, accept);
    synchronized (lock) {
      rttRequests.remove(callId);
    }
    return true;
  }

  /** Sends typed text over RTT. Returns false if RTT is not active. */
  public static boolean writeRtt(String callId, String text) {
    if (Build.VERSION.SDK_INT < 28) return false;
    Call call = find(callId);
    Call.RttCall rtt = call == null ? null : call.getRttCall();
    if (rtt == null) return false;
    try {
      rtt.write(text);
      return true;
    } catch (java.io.IOException e) {
      return false;
    }
  }

  /** Text received over RTT since the last read, or an empty string. Never blocks. */
  public static String readRtt(String callId) {
    if (Build.VERSION.SDK_INT < 28) return "";
    Call call = find(callId);
    Call.RttCall rtt = call == null ? null : call.getRttCall();
    if (rtt == null) return "";
    try {
      String text = rtt.readImmediately();
      return text == null ? "" : text;
    } catch (java.io.IOException e) {
      return "";
    }
  }

  // ---------------------------------------------------------------------------
  // Conference and multi-call
  // ---------------------------------------------------------------------------

  /** True if the call is a conference (it has child calls). */
  public static boolean isConference(String callId) {
    Call call = find(callId);
    return call != null
        && call.getDetails() != null
        && call.getDetails().hasProperty(Call.Details.PROPERTY_CONFERENCE);
  }

  /** True if the call can be merged with another call into a conference. */
  public static boolean canMerge(String callId) {
    Call call = find(callId);
    if (call == null || call.getDetails() == null) return false;
    return call.getDetails().can(Call.Details.CAPABILITY_MERGE_CONFERENCE)
        || !call.getConferenceableCalls().isEmpty();
  }

  /** True if the call (a conference) can swap between its two parties. */
  public static boolean canSwap(String callId) {
    Call call = find(callId);
    return call != null
        && call.getDetails() != null
        && call.getDetails().can(Call.Details.CAPABILITY_SWAP_CONFERENCE);
  }

  /** Joins two calls into a conference. */
  public static boolean conference(String callId, String otherCallId) {
    Call call = find(callId);
    Call other = find(otherCallId);
    if (call == null || other == null) return false;
    call.conference(other);
    return true;
  }

  /** Merges the calls that this call can be merged with into a conference. */
  public static boolean mergeConference(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    if (call.getDetails().can(Call.Details.CAPABILITY_MERGE_CONFERENCE)) {
      call.mergeConference();
      return true;
    }
    List<Call> conferenceable = call.getConferenceableCalls();
    if (conferenceable.isEmpty()) return false;
    call.conference(conferenceable.get(0));
    return true;
  }

  /** Swaps the active party of a two-party conference. */
  public static boolean swapConference(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    call.swapConference();
    return true;
  }

  /** Splits a call out of its conference so it can be talked to privately. */
  public static boolean splitFromConference(String callId) {
    Call call = find(callId);
    if (call == null) return false;
    call.splitFromConference();
    return true;
  }

  /** Ids of the calls that make up a conference. */
  public static String[] getChildIds(String callId) {
    Call call = find(callId);
    if (call == null) return new String[0];
    List<String> ids = new ArrayList<>();
    for (Call child : call.getChildren()) {
      String id = idOf(child);
      if (id != null) ids.add(id);
    }
    return ids.toArray(new String[0]);
  }

  /** The id of the conference this call belongs to, or an empty string. */
  public static String getParentId(String callId) {
    Call call = find(callId);
    if (call == null || call.getParent() == null) return "";
    String id = idOf(call.getParent());
    return id == null ? "" : id;
  }

  /**
   * Swaps between an active and a held call: holds the active one and
   * resumes the other. Use for call waiting.
   */
  @SuppressWarnings("deprecation")
  public static boolean swapCalls() {
    Call held = null;
    synchronized (lock) {
      for (Call c : calls.values()) {
        if (c.getParent() != null) continue;
        if (c.getState() == Call.STATE_HOLDING && held == null) held = c;
      }
    }
    if (held == null) return false;
    // Telecom holds the active call itself when another call is resumed.
    // Holding it here too starts a second hold that can fail.
    held.unhold();
    return true;
  }

  // ---------------------------------------------------------------------------
  // Audio routes
  // ---------------------------------------------------------------------------

  /** Bit mask of supported routes ({@code CallAudioState.ROUTE_*}), or 0. */
  public static int getSupportedAudioRouteMask() {
    CallAudioState state = lastAudioState;
    return state == null ? 0 : state.getSupportedRouteMask();
  }

  /** Routes call audio. {@code route} is one of {@code CallAudioState.ROUTE_*}. */
  @SuppressWarnings("deprecation")
  public static boolean setAudioRoute(int route) {
    InCallService current;
    synchronized (lock) {
      current = service;
    }
    if (current == null) return false;
    current.setAudioRoute(route);
    return true;
  }

  /** Addresses of Bluetooth devices that can carry call audio. */
  public static String[] getBluetoothDeviceAddresses() {
    CallAudioState state = lastAudioState;
    if (state == null || Build.VERSION.SDK_INT < 28) return new String[0];
    Collection<BluetoothDevice> devices = state.getSupportedBluetoothDevices();
    List<String> out = new ArrayList<>();
    for (BluetoothDevice d : devices) out.add(d.getAddress());
    return out.toArray(new String[0]);
  }

  /**
   * The name of a Bluetooth device, or an empty string. Needs
   * BLUETOOTH_CONNECT on Android 12+.
   */
  public static String getBluetoothDeviceName(String address) {
    BluetoothDevice device = findBluetooth(address);
    if (device == null) return "";
    try {
      String name = device.getName();
      return name == null ? "" : name;
    } catch (SecurityException e) {
      return "";
    }
  }

  /** Address of the Bluetooth device in use, or an empty string. */
  public static String getActiveBluetoothDeviceAddress() {
    CallAudioState state = lastAudioState;
    if (state == null || Build.VERSION.SDK_INT < 28) return "";
    BluetoothDevice device = state.getActiveBluetoothDevice();
    return device == null ? "" : device.getAddress();
  }

  /** Sends call audio to the Bluetooth device with this address. */
  public static boolean selectBluetoothDevice(String address) {
    InCallService current;
    synchronized (lock) {
      current = service;
    }
    BluetoothDevice device = findBluetooth(address);
    if (current == null || device == null || Build.VERSION.SDK_INT < 28) return false;
    current.requestBluetoothAudio(device);
    return true;
  }

  private static BluetoothDevice findBluetooth(String address) {
    CallAudioState state = lastAudioState;
    if (state == null || address == null || Build.VERSION.SDK_INT < 28) return null;
    for (BluetoothDevice d : state.getSupportedBluetoothDevices()) {
      if (address.equals(d.getAddress())) return d;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Called by TelephonyKitInCallService
  // ---------------------------------------------------------------------------

  static void attachService(InCallService inCallService) {
    synchronized (lock) {
      service = inCallService;
      appContext = inCallService.getApplicationContext();
    }
  }

  static void detachService(InCallService inCallService) {
    synchronized (lock) {
      if (service == inCallService) {
        service = null;
      }
    }
    PowerManager.WakeLock proximity = proximityLock;
    if (proximity != null && proximity.isHeld()) proximity.release();
  }

  @SuppressWarnings("deprecation")
  static void addCall(Context context, Call call) {
    final String id;
    synchronized (lock) {
      id = "call-" + (nextId++);
      calls.put(id, call);
      incoming.put(id, call.getState() == Call.STATE_RINGING);
    }
    Call.Callback callback =
        new Call.Callback() {
          @Override
          public void onStateChanged(Call c, int state) {
            updateNotification();
            CallEventListener l = currentListener();
            if (l != null) l.onCallStateChanged(id, state);
          }

          @Override
          public void onPostDialWait(Call c, String remainingPostDialSequence) {
            String remaining = remainingPostDialSequence == null ? "" : remainingPostDialSequence;
            synchronized (lock) {
              postDialWaits.put(id, remaining);
            }
            CallEventListener l = currentListener();
            if (l != null) l.onPostDialWait(id, remaining);
          }

          // Conference changes do not change the state, but the UI must
          // update (merge and swap buttons, which call to show), so report
          // them as a state event with the current state.
          @Override
          public void onParentChanged(Call c, Call parent) {
            conferenceChanged(id);
          }

          @Override
          public void onChildrenChanged(Call c, List<Call> children) {
            conferenceChanged(id);
          }

          @Override
          public void onConferenceableCallsChanged(Call c, List<Call> conferenceable) {
            conferenceChanged(id);
          }

          // RTT, video and details changes also do not change the state, so
          // they are reported as a state event for the UI to re-read.
          @Override
          public void onRttRequest(Call c, int requestId) {
            synchronized (lock) {
              rttRequests.put(id, requestId);
            }
            conferenceChanged(id);
          }

          @Override
          public void onRttStatusChanged(Call c, boolean enabled, Call.RttCall rttCall) {
            synchronized (lock) {
              rttRequests.remove(id);
            }
            conferenceChanged(id);
          }

          @Override
          public void onDetailsChanged(Call c, Call.Details details) {
            conferenceChanged(id);
          }
        };
    synchronized (lock) {
      callbacks.put(call, callback);
    }
    call.registerCallback(callback, mainHandler);

    CallEventListener l = currentListener();
    if (l != null) l.onCallAdded(id);

    updateNotification();
    if (launchAppOnIncomingCall && call.getState() == Call.STATE_RINGING) {
      launchApp(context);
    }
  }

  private static void conferenceChanged(String id) {
    updateNotification();
    CallEventListener l = currentListener();
    if (l != null) l.onCallStateChanged(id, getState(id));
  }

  static void removeCall(Call call) {
    String removedId = null;
    Call.Callback callback;
    synchronized (lock) {
      Iterator<Map.Entry<String, Call>> it = calls.entrySet().iterator();
      while (it.hasNext()) {
        Map.Entry<String, Call> entry = it.next();
        if (entry.getValue() == call) {
          removedId = entry.getKey();
          it.remove();
          incoming.remove(removedId);
          postDialWaits.remove(removedId);
          break;
        }
      }
      callback = callbacks.remove(call);
    }
    if (callback != null) call.unregisterCallback(callback);
    updateNotification();
    if (removedId != null) {
      DisconnectCause cause = call.getDetails() == null ? null : call.getDetails().getDisconnectCause();
      if (cause != null) {
        synchronized (lock) {
          disconnectCauses.put(removedId, cause);
        }
      }
      CallEventListener l = currentListener();
      if (l != null) {
        if (cause != null) {
          l.onCallDisconnected(
              removedId,
              cause.getCode(),
              cause.getLabel() == null ? "" : cause.getLabel().toString(),
              cause.getReason() == null ? "" : cause.getReason());
        }
        l.onCallRemoved(removedId);
      }
    }
  }

  static void onAudioStateChanged(CallAudioState state) {
    if (state == null) return;
    lastAudioState = state;
    lastMuted = state.isMuted();
    lastRoute = state.getRoute();
    updateProximity();
    CallEventListener l = currentListener();
    if (l != null) l.onAudioStateChanged(lastMuted, lastRoute);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  private static Call find(String callId) {
    synchronized (lock) {
      return calls.get(callId);
    }
  }

  private static CallEventListener currentListener() {
    synchronized (lock) {
      return listener;
    }
  }

  private static String idOf(Call call) {
    synchronized (lock) {
      for (Map.Entry<String, Call> e : calls.entrySet()) {
        if (e.getValue() == call) return e.getKey();
      }
    }
    return null;
  }

  /** Shows the notification for the most relevant call, or clears it. */
  @SuppressWarnings("deprecation")
  private static void updateNotification() {
    updateProximity();
    Context ctx = appContext;
    if (ctx == null) return;
    if (!showNotifications) {
      CallNotifications.cancel(ctx);
      return;
    }
    String ringingId = null;
    String liveId = null;
    synchronized (lock) {
      for (Map.Entry<String, Call> e : calls.entrySet()) {
        Call c = e.getValue();
        if (c.getParent() != null) continue;
        int state = c.getState();
        if (state == Call.STATE_RINGING) ringingId = e.getKey();
        else if (state != Call.STATE_DISCONNECTED && state != Call.STATE_DISCONNECTING) {
          liveId = e.getKey();
        }
      }
    }
    if (ringingId != null) {
      CallNotifications.showIncoming(ctx, ringingId, callerLabel(ringingId));
    } else if (liveId != null) {
      int state = getState(liveId);
      String status =
          state == Call.STATE_HOLDING
              ? "On hold"
              : state == Call.STATE_ACTIVE ? "Ongoing call" : "Calling…";
      CallNotifications.showOngoing(
          ctx, liveId, callerLabel(liveId), status, getConnectTimeMillis(liveId));
    } else {
      CallNotifications.cancel(ctx);
    }
  }

  /**
   * Holds the proximity wake lock while a call is active or dialing on the
   * earpiece or a wired headset, and releases it otherwise. Must run on the
   * main thread.
   */
  @SuppressWarnings("deprecation")
  private static void updateProximity() {
    boolean want = false;
    if (proximityEnabled
        && lastRoute != CallAudioState.ROUTE_SPEAKER
        && lastRoute != CallAudioState.ROUTE_BLUETOOTH) {
      synchronized (lock) {
        for (Call c : calls.values()) {
          int state = c.getState();
          if (state == Call.STATE_ACTIVE
              || state == Call.STATE_DIALING
              || state == Call.STATE_CONNECTING) {
            want = true;
            break;
          }
        }
      }
    }
    if (want) {
      if (proximityLock == null) {
        Context ctx = appContext;
        if (ctx == null) return;
        PowerManager pm = ctx.getSystemService(PowerManager.class);
        if (pm == null
            || !pm.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) {
          return;
        }
        proximityLock =
            pm.newWakeLock(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK, "telephony_kit:proximity");
        proximityLock.setReferenceCounted(false);
      }
      if (!proximityLock.isHeld()) {
        try {
          proximityLock.acquire();
        } catch (SecurityException ignored) {
          // WAKE_LOCK permission missing.
        }
      }
    } else if (proximityLock != null && proximityLock.isHeld()) {
      // Keep the screen off until the phone leaves the ear.
      proximityLock.release(PowerManager.RELEASE_FLAG_WAIT_FOR_NO_PROXIMITY);
    }
  }

  private static String callerLabel(String callId) {
    String name = getDisplayName(callId);
    if (!name.isEmpty()) return name;
    String number = getNumber(callId);
    return number.isEmpty() ? "Unknown caller" : number;
  }

  static void launchApp(Context context) {
    Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
    if (intent == null) return;
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    try {
      context.startActivity(intent);
    } catch (RuntimeException ignored) {
      // Background activity starts can be blocked; the call still rings.
    }
  }

  /** Visible for testing: the number of tracked calls. */
  static List<String> debugIds() {
    synchronized (lock) {
      return new ArrayList<>(calls.keySet());
    }
  }
}
