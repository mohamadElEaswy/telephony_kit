package dev.telephonykit.telephony_kit;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

/**
 * New message notifications. Android shows none while the app is the default
 * SMS app, so {@link TelephonyKitSmsDeliverReceiver} shows them here, one per
 * sender. Tapping one opens the app; {@link SmsIntents#takeRequest} then
 * returns the sender.
 */
public final class SmsNotifications {
  private SmsNotifications() {}

  static final String CHANNEL = "telephony_kit_messages";
  private static final String PREFS = "telephony_kit_sms";
  private static final String KEY_ENABLED = "notifications";
  private static final int MMS_ID = 0x7e20;

  private static SharedPreferences prefs(Context context) {
    return context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
  }

  /** Whether the package shows new message notifications (default true). */
  public static boolean isEnabled(Context context) {
    return prefs(context).getBoolean(KEY_ENABLED, true);
  }

  /** Turns new message notifications on or off. */
  public static void setEnabled(Context context, boolean enabled) {
    prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply();
  }

  /** Removes the notification for messages from {@code address}. */
  public static void cancel(Context context, String address) {
    NotificationManager nm = context.getSystemService(NotificationManager.class);
    if (nm != null) nm.cancel(idFor(address));
  }

  /** Removes every message notification. */
  public static void cancelAll(Context context) {
    NotificationManager nm = context.getSystemService(NotificationManager.class);
    if (nm == null) return;
    if (Build.VERSION.SDK_INT >= 23) {
      for (android.service.notification.StatusBarNotification n : nm.getActiveNotifications()) {
        if (n.getNotification() != null
            && CHANNEL.equals(channelOf(n.getNotification()))) {
          nm.cancel(n.getId());
        }
      }
    }
    nm.cancel(MMS_ID);
  }

  private static String channelOf(Notification n) {
    return Build.VERSION.SDK_INT >= 26 ? n.getChannelId() : CHANNEL;
  }

  static int idFor(String address) {
    return 0x7e300000 | ((address == null ? 0 : address.hashCode()) & 0xfffff);
  }

  static void show(Context context, String address, String body) {
    String name = MissedCallNotifications.callerName(context, address);
    post(context, idFor(address), name.isEmpty() ? address : name, body, address);
  }

  static void showMms(Context context) {
    post(context, MMS_ID, "Multimedia message", "Open your messages app to view it.", "");
  }

  @SuppressWarnings("deprecation")
  private static void post(Context context, int id, String title, String text, String address) {
    if (!isEnabled(context)) return;
    NotificationManager nm = context.getSystemService(NotificationManager.class);
    if (nm == null) return;
    if (Build.VERSION.SDK_INT >= 26) {
      nm.createNotificationChannel(
          new NotificationChannel(CHANNEL, "Messages", NotificationManager.IMPORTANCE_HIGH));
    }
    Notification.Builder b =
        Build.VERSION.SDK_INT >= 26
            ? new Notification.Builder(context, CHANNEL)
            : new Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH);
    b.setSmallIcon(android.R.drawable.stat_notify_chat)
        .setContentTitle(title)
        .setContentText(text)
        .setStyle(new Notification.BigTextStyle().bigText(text))
        .setCategory(Notification.CATEGORY_MESSAGE)
        .setAutoCancel(true)
        .setContentIntent(openIntent(context, id, address));
    if (Build.VERSION.SDK_INT < 26) b.setDefaults(Notification.DEFAULT_ALL);
    try {
      nm.notify(id, b.build());
    } catch (RuntimeException ignored) {
      // POST_NOTIFICATIONS not granted.
    }
  }

  private static PendingIntent openIntent(Context context, int id, String address) {
    Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
    if (intent == null) intent = new Intent();
    intent.setAction(SmsIntents.ACTION_OPEN);
    intent.putExtra(SmsIntents.EXTRA_ADDRESS, address);
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    return PendingIntent.getActivity(
        context, id, intent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
  }
}
