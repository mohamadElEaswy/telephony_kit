package dev.telephonykit.telephony_kit;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.telephony.PhoneStateListener;
import android.telephony.ServiceState;
import android.telephony.SignalStrength;
import android.telephony.TelephonyCallback;
import android.telephony.TelephonyDisplayInfo;
import android.telephony.TelephonyManager;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executor;

/** Streams signal, service, network type and call state changes. */
public final class NetworkMonitor {
  private NetworkMonitor() {}

  private static final Handler main = new Handler(Looper.getMainLooper());
  private static final List<Object> registered = new ArrayList<>();
  private static TelephonyManager manager;

  /** Starts sending events to {@code listener}. Replaces any earlier listener. */
  public static void start(Context context, NetworkEventListener listener) {
    final Context app = context.getApplicationContext();
    main.post(
        () -> {
          stopNow();
          manager = app.getSystemService(TelephonyManager.class);
          if (manager == null) return;
          boolean canReadPhone =
              app.checkSelfPermission(Manifest.permission.READ_PHONE_STATE)
                  == PackageManager.PERMISSION_GRANTED;
          if (Build.VERSION.SDK_INT >= 31) {
            registerCallbacks(app, listener, canReadPhone);
          } else {
            registerLegacy(listener, canReadPhone);
          }
        });
  }

  /** Stops sending events. */
  public static void stop() {
    main.post(NetworkMonitor::stopNow);
  }

  /** The current signal level from 0 to 4, or -1 if unknown. */
  public static int getSignalLevel(Context context) {
    if (Build.VERSION.SDK_INT < 28) return -1;
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    if (tm == null) return -1;
    SignalStrength s = tm.getSignalStrength();
    return s == null ? -1 : s.getLevel();
  }

  /**
   * The current data network type ({@code TelephonyManager.NETWORK_TYPE_*}),
   * or 0 if unknown. Needs READ_PHONE_STATE.
   */
  public static int getDataNetworkType(Context context) {
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    if (tm == null) return 0;
    try {
      return tm.getDataNetworkType();
    } catch (SecurityException e) {
      return 0;
    }
  }

  private static void stopNow() {
    TelephonyManager tm = manager;
    if (tm != null) {
      for (Object o : registered) {
        if (Build.VERSION.SDK_INT >= 31 && o instanceof TelephonyCallback) {
          tm.unregisterTelephonyCallback((TelephonyCallback) o);
        } else if (o instanceof PhoneStateListener) {
          tm.listen((PhoneStateListener) o, PhoneStateListener.LISTEN_NONE);
        }
      }
    }
    registered.clear();
  }

  // Android 12+ --------------------------------------------------------------

  private static void registerCallbacks(
      Context context, NetworkEventListener listener, boolean canReadPhone) {
    Executor executor = context.getMainExecutor();
    register(executor, new SignalCallback(listener));
    register(executor, new ServiceCallback(listener));
    register(executor, new DisplayCallback(listener));
    if (canReadPhone) register(executor, new CallStateCallback(listener));
  }

  private static void register(Executor executor, TelephonyCallback callback) {
    try {
      manager.registerTelephonyCallback(executor, callback);
      registered.add(callback);
    } catch (RuntimeException ignored) {
      // Missing permission for this callback; skip it.
    }
  }

  private static final class SignalCallback extends TelephonyCallback
      implements TelephonyCallback.SignalStrengthsListener {
    private final NetworkEventListener l;

    SignalCallback(NetworkEventListener l) {
      this.l = l;
    }

    @Override
    public void onSignalStrengthsChanged(SignalStrength signalStrength) {
      l.onSignalStrengthChanged(signalStrength.getLevel());
    }
  }

  private static final class ServiceCallback extends TelephonyCallback
      implements TelephonyCallback.ServiceStateListener {
    private final NetworkEventListener l;

    ServiceCallback(NetworkEventListener l) {
      this.l = l;
    }

    @Override
    public void onServiceStateChanged(ServiceState serviceState) {
      l.onServiceStateChanged(serviceState.getState());
    }
  }

  private static final class DisplayCallback extends TelephonyCallback
      implements TelephonyCallback.DisplayInfoListener {
    private final NetworkEventListener l;

    DisplayCallback(NetworkEventListener l) {
      this.l = l;
    }

    @Override
    public void onDisplayInfoChanged(TelephonyDisplayInfo info) {
      l.onNetworkTypeChanged(info.getNetworkType(), info.getOverrideNetworkType());
    }
  }

  private static final class CallStateCallback extends TelephonyCallback
      implements TelephonyCallback.CallStateListener {
    private final NetworkEventListener l;

    CallStateCallback(NetworkEventListener l) {
      this.l = l;
    }

    @Override
    public void onCallStateChanged(int state) {
      l.onCallStateChanged(state, "");
    }
  }

  // Android 11 and older -----------------------------------------------------

  @SuppressWarnings("deprecation")
  private static void registerLegacy(final NetworkEventListener listener, boolean canReadPhone) {
    PhoneStateListener psl =
        new PhoneStateListener() {
          @Override
          public void onSignalStrengthsChanged(SignalStrength signalStrength) {
            if (Build.VERSION.SDK_INT >= 23) {
              listener.onSignalStrengthChanged(signalStrength.getLevel());
            }
          }

          @Override
          public void onServiceStateChanged(ServiceState serviceState) {
            listener.onServiceStateChanged(serviceState.getState());
          }

          @Override
          public void onDataConnectionStateChanged(int state, int networkType) {
            listener.onNetworkTypeChanged(networkType, 0);
          }

          @Override
          public void onCallStateChanged(int state, String phoneNumber) {
            listener.onCallStateChanged(state, phoneNumber == null ? "" : phoneNumber);
          }
        };
    int events =
        PhoneStateListener.LISTEN_SIGNAL_STRENGTHS
            | PhoneStateListener.LISTEN_SERVICE_STATE
            | PhoneStateListener.LISTEN_DATA_CONNECTION_STATE;
    if (canReadPhone) events |= PhoneStateListener.LISTEN_CALL_STATE;
    try {
      manager.listen(psl, events);
      registered.add(psl);
    } catch (RuntimeException ignored) {
      // Missing permission.
    }
  }
}
