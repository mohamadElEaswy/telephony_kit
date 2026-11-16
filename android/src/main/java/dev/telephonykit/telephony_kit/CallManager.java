package dev.telephonykit.telephony_kit;

import android.bluetooth.BluetoothDevice;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.telecom.Call;
import android.telecom.CallAudioState;
import android.telecom.InCallService;
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
          break;
        }
      }
      callback = callbacks.remove(call);
    }
    if (callback != null) call.unregisterCallback(callback);
    updateNotification();
    if (removedId != null) {
      CallEventListener l = currentListener();
      if (l != null) l.onCallRemoved(removedId);
    }
  }

  static void onAudioStateChanged(CallAudioState state) {
    if (state == null) return;
    lastAudioState = state;
    lastMuted = state.isMuted();
    lastRoute = state.getRoute();
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
