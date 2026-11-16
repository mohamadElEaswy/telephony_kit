package dev.telephonykit.telephony_kit;

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
  // Called by TelephonyKitInCallService
  // ---------------------------------------------------------------------------

  static void attachService(InCallService inCallService) {
    synchronized (lock) {
      service = inCallService;
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
            CallEventListener l = currentListener();
            if (l != null) l.onCallStateChanged(id, state);
          }
        };
    synchronized (lock) {
      callbacks.put(call, callback);
    }
    call.registerCallback(callback, mainHandler);

    CallEventListener l = currentListener();
    if (l != null) l.onCallAdded(id);

    if (launchAppOnIncomingCall && call.getState() == Call.STATE_RINGING) {
      launchApp(context);
    }
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
    if (removedId != null) {
      CallEventListener l = currentListener();
      if (l != null) l.onCallRemoved(removedId);
    }
  }

  static void onAudioStateChanged(CallAudioState state) {
    if (state == null) return;
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

  private static void launchApp(Context context) {
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
