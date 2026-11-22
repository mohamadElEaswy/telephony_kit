package dev.telephonykit.telephony_kit;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.telephony.SubscriptionManager;

/**
 * Reports when the active SIMs change (a SIM inserted, removed or swapped, an
 * eSIM profile turned on or off). {@link
 * SubscriptionManager.OnSubscriptionsChangedListener} is a class, so it cannot
 * be implemented from Dart. Dart reads the SIM list again on each change and
 * works out what changed.
 */
public final class SimMonitor {
  private SimMonitor() {}

  private static final Handler main = new Handler(Looper.getMainLooper());
  private static SubscriptionManager.OnSubscriptionsChangedListener registered;
  private static SubscriptionManager manager;

  /**
   * Starts sending changes to {@code listener} as {@code onChange("sim")}.
   * Android also calls it once right after registering. Replaces any earlier
   * listener.
   */
  public static void start(Context context, ChangeListener listener) {
    final Context app = context.getApplicationContext();
    main.post(
        () -> {
          stopNow();
          SubscriptionManager sm = app.getSystemService(SubscriptionManager.class);
          if (sm == null) return;
          // Created on the main thread: before Android 11 the listener needs a
          // Looper on the thread that creates it.
          SubscriptionManager.OnSubscriptionsChangedListener l =
              new SubscriptionManager.OnSubscriptionsChangedListener() {
                @Override
                public void onSubscriptionsChanged() {
                  listener.onChange("sim");
                }
              };
          try {
            sm.addOnSubscriptionsChangedListener(l);
            manager = sm;
            registered = l;
          } catch (RuntimeException ignored) {
            // Missing READ_PHONE_STATE on some devices.
          }
        });
  }

  /** Stops sending changes. */
  public static void stop() {
    main.post(SimMonitor::stopNow);
  }

  private static void stopNow() {
    if (manager != null && registered != null) {
      manager.removeOnSubscriptionsChangedListener(registered);
    }
    manager = null;
    registered = null;
  }
}
