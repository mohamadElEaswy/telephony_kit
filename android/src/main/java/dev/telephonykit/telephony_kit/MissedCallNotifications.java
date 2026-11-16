package dev.telephonykit.telephony_kit;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.telecom.TelecomManager;

/**
 * The missed call notification. As the default dialer the app is asked to
 * show it through {@link TelephonyKitMissedCallReceiver}; Telecom then does not
 * show its own.
 */
public final class MissedCallNotifications {
  private MissedCallNotifications() {}

  static final String CHANNEL = "telephony_kit_missed_calls";
  static final int NOTIFICATION_ID = 0x7e1f;
  private static final String PREFS = "telephony_kit_missed_calls";
  private static final String KEY_ENABLED = "enabled";

  private static SharedPreferences prefs(Context context) {
    return context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
  }

  /** Whether the package shows missed call notifications (default true). */
  public static boolean isEnabled(Context context) {
    return prefs(context).getBoolean(KEY_ENABLED, true);
  }

  /** Turns missed call notifications on or off. Off also clears the current one. */
  public static void setEnabled(Context context, boolean enabled) {
    prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply();
    if (!enabled) cancel(context);
  }

  /** Removes the notification and tells Telecom the missed calls were seen. */
  public static void clear(Context context) {
    cancel(context);
    TelecomManager telecom = context.getSystemService(TelecomManager.class);
    if (telecom == null) return;
    try {
      // Allowed for the default dialer; resets Telecom's missed call count.
      telecom.cancelMissedCallsNotification();
    } catch (RuntimeException ignored) {
      // Not the default dialer.
    }
  }

  static void cancel(Context context) {
    NotificationManager nm = context.getSystemService(NotificationManager.class);
    if (nm != null) nm.cancel(NOTIFICATION_ID);
  }

  /** Shows "{count} missed calls" with the last caller, or clears it for 0. */
  @SuppressWarnings("deprecation")
  static void show(Context context, int count, String number) {
    if (count <= 0) {
      cancel(context);
      return;
    }
    if (!isEnabled(context)) return;
    NotificationManager nm = context.getSystemService(NotificationManager.class);
    if (nm == null) return;
    if (Build.VERSION.SDK_INT >= 26) {
      nm.createNotificationChannel(
          new NotificationChannel(CHANNEL, "Missed calls", NotificationManager.IMPORTANCE_DEFAULT));
    }
    String caller = callerName(context, number);
    String title = count == 1 ? "Missed call" : count + " missed calls";
    String text = caller.isEmpty() ? "" : (count == 1 ? caller : "Last from " + caller);

    Notification.Builder b =
        Build.VERSION.SDK_INT >= 26
            ? new Notification.Builder(context, CHANNEL)
            : new Notification.Builder(context);
    b.setSmallIcon(android.R.drawable.stat_notify_missed_call)
        .setContentTitle(title)
        .setContentText(text)
        .setCategory(Notification.CATEGORY_MISSED_CALL)
        .setAutoCancel(true)
        .setNumber(count)
        .setContentIntent(launchIntent(context));
    if (number != null && !number.isEmpty()) {
      Intent callBack = new Intent(context, CallActionReceiver.class);
      callBack.setAction(CallActionReceiver.ACTION_CALL_BACK);
      callBack.putExtra(CallActionReceiver.EXTRA_NUMBER, number);
      PendingIntent pi =
          PendingIntent.getBroadcast(
              context, 10, callBack, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
      b.addAction(
          new Notification.Action.Builder(android.R.drawable.sym_action_call, "Call back", pi)
              .build());
    }
    try {
      nm.notify(NOTIFICATION_ID, b.build());
    } catch (RuntimeException ignored) {
      // POST_NOTIFICATIONS not granted.
    }
  }

  private static PendingIntent launchIntent(Context context) {
    Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
    if (intent == null) intent = new Intent();
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    return PendingIntent.getActivity(
        context, 11, intent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
  }

  /** The contact name for the number, else the number, else "". */
  private static String callerName(Context context, String number) {
    if (number == null || number.isEmpty()) return "";
    if (context.checkSelfPermission(android.Manifest.permission.READ_CONTACTS)
        != PackageManager.PERMISSION_GRANTED) {
      return number;
    }
    Uri uri =
        Uri.withAppendedPath(
            Uri.parse("content://com.android.contacts/phone_lookup"), Uri.encode(number));
    try (Cursor c =
        context.getContentResolver().query(uri, new String[] {"display_name"}, null, null, null)) {
      if (c != null && c.moveToFirst()) {
        String name = c.getString(0);
        if (name != null && !name.isEmpty()) return name;
      }
    } catch (RuntimeException ignored) {
      // Fall back to the number.
    }
    return number;
  }
}
