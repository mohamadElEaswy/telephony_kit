package dev.telephonykit.telephony_kit;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.telephony.SmsManager;
import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicInteger;

/** Sends SMS messages and reports whether every part was sent. */
public final class SmsHelper {
  private SmsHelper() {}

  private static final AtomicInteger counter = new AtomicInteger();

  /** A listener that ignores the result. */
  static final ResultListener IGNORE =
      new ResultListener() {
        @Override
        public void onSuccess(String value) {}

        @Override
        public void onFailure(int code, String message) {}
      };

  /**
   * Sends {@code text} to {@code destination}. Long messages are split into
   * parts. Pass a subscription id to pick the SIM, or -1 for the default.
   * Needs SEND_SMS. The listener gets the number of parts on success. As
   * the default SMS app, the message is also stored: in the outbox while
   * sending, then in the sent box (or as failed).
   */
  @SuppressWarnings("deprecation")
  public static void send(
      Context context, String destination, String text, int subscriptionId, ResultListener listener) {
    final Context app = context.getApplicationContext();
    SmsManager sms;
    if (Build.VERSION.SDK_INT >= 31) {
      sms = app.getSystemService(SmsManager.class);
      if (sms != null && subscriptionId >= 0) sms = sms.createForSubscriptionId(subscriptionId);
    } else {
      sms =
          subscriptionId >= 0
              ? SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
              : SmsManager.getDefault();
    }
    if (sms == null) {
      listener.onFailure(-1, "SMS is not available");
      return;
    }

    final android.net.Uri stored =
        SmsStore.isDefaultSmsApp(app)
            ? SmsStore.insertOutbox(app, destination, text, subscriptionId)
            : null;
    final ArrayList<String> parts = sms.divideMessage(text);
    final int total = parts.size();
    final String action = app.getPackageName() + ".TELEPHONY_KIT_SMS_SENT_" + counter.incrementAndGet();
    final int[] remaining = {total};
    final boolean[] done = {false};

    BroadcastReceiver receiver =
        new BroadcastReceiver() {
          @Override
          public void onReceive(Context c, Intent intent) {
            if (done[0]) return;
            int code = getResultCode();
            if (code != Activity.RESULT_OK) {
              done[0] = true;
              safeUnregister(app, this);
              SmsStore.markSent(app, stored, false);
              listener.onFailure(code, "SMS was not sent");
              return;
            }
            remaining[0]--;
            if (remaining[0] <= 0) {
              done[0] = true;
              safeUnregister(app, this);
              SmsStore.markSent(app, stored, true);
              listener.onSuccess(String.valueOf(total));
            }
          }
        };
    IntentFilter filter = new IntentFilter(action);
    if (Build.VERSION.SDK_INT >= 33) {
      app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
    } else {
      app.registerReceiver(receiver, filter);
    }

    ArrayList<PendingIntent> sentIntents = new ArrayList<>();
    for (int i = 0; i < total; i++) {
      Intent intent = new Intent(action).setPackage(app.getPackageName());
      sentIntents.add(
          PendingIntent.getBroadcast(
              app, i, intent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_ONE_SHOT));
    }
    try {
      if (total > 1) {
        sms.sendMultipartTextMessage(destination, null, parts, sentIntents, null);
      } else {
        sms.sendTextMessage(destination, null, text, sentIntents.get(0), null);
      }
    } catch (SecurityException e) {
      done[0] = true;
      safeUnregister(app, receiver);
      SmsStore.markSent(app, stored, false);
      listener.onFailure(-2, "SEND_SMS permission is missing");
    } catch (RuntimeException e) {
      done[0] = true;
      safeUnregister(app, receiver);
      SmsStore.markSent(app, stored, false);
      listener.onFailure(-1, String.valueOf(e.getMessage()));
    }
  }

  /** The package name of the default SMS app, or an empty string. */
  public static String getDefaultPackage(Context context) {
    String pkg = android.provider.Telephony.Sms.getDefaultSmsPackage(context);
    return pkg == null ? "" : pkg;
  }

  /**
   * Shows the system prompt that makes this app the default SMS app. Use it
   * before Android 10; from Android 10 the SMS role is requested instead.
   * Returns false if there is no activity.
   */
  public static boolean requestDefaultLegacy(Activity activity, int requestCode) {
    if (activity == null) return false;
    Intent intent = new Intent(android.provider.Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT);
    intent.putExtra(android.provider.Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, activity.getPackageName());
    activity.startActivityForResult(intent, requestCode);
    return true;
  }

  private static void safeUnregister(Context context, BroadcastReceiver receiver) {
    try {
      context.unregisterReceiver(receiver);
    } catch (RuntimeException ignored) {
      // Already unregistered.
    }
  }
}
