package dev.telephonykit.telephony_kit;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Person;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Incoming and ongoing call notifications shown by {@link CallManager}. */
final class CallNotifications {
  private CallNotifications() {}

  static final String CHANNEL_INCOMING = "telephony_kit_incoming_calls";
  static final String CHANNEL_ONGOING = "telephony_kit_ongoing_calls";
  static final int NOTIFICATION_ID = 0x7e1e;

  private static void ensureChannels(Context context, NotificationManager nm) {
    if (Build.VERSION.SDK_INT < 26) return;
    NotificationChannel incoming =
        new NotificationChannel(
            CHANNEL_INCOMING, "Incoming calls", NotificationManager.IMPORTANCE_HIGH);
    // Telecom plays the ringtone, so the notification itself stays silent.
    incoming.setSound(null, null);
    incoming.enableVibration(false);
    nm.createNotificationChannel(incoming);
    NotificationChannel ongoing =
        new NotificationChannel(
            CHANNEL_ONGOING, "Ongoing calls", NotificationManager.IMPORTANCE_LOW);
    nm.createNotificationChannel(ongoing);
  }

  private static PendingIntent launchIntent(Context context) {
    Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
    if (intent == null) intent = new Intent();
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    return PendingIntent.getActivity(
        context, 0, intent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
  }

  private static PendingIntent actionIntent(Context context, String action, String callId, int code) {
    Intent intent = new Intent(context, CallActionReceiver.class);
    intent.setAction(action);
    intent.putExtra(CallActionReceiver.EXTRA_CALL_ID, callId);
    return PendingIntent.getBroadcast(
        context, code, intent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
  }

  @SuppressWarnings("deprecation")
  private static Notification.Builder builder(Context context, String channel) {
    if (Build.VERSION.SDK_INT >= 26) return new Notification.Builder(context, channel);
    return new Notification.Builder(context);
  }

  @SuppressWarnings("deprecation")
  static void showIncoming(Context context, String callId, String caller) {
    NotificationManager nm = context.getSystemService(NotificationManager.class);
    if (nm == null) return;
    ensureChannels(context, nm);
    PendingIntent content = launchIntent(context);
    PendingIntent answer = actionIntent(context, CallActionReceiver.ACTION_ANSWER, callId, 1);
    PendingIntent decline = actionIntent(context, CallActionReceiver.ACTION_DECLINE, callId, 2);

    Notification.Builder b =
        builder(context, CHANNEL_INCOMING)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setContentTitle(caller)
            .setContentText("Incoming call")
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setContentIntent(content)
            .setFullScreenIntent(content, true);
    if (Build.VERSION.SDK_INT >= 31) {
      Person person = new Person.Builder().setName(caller).setImportant(true).build();
      b.setStyle(Notification.CallStyle.forIncomingCall(person, decline, answer));
    } else {
      b.setPriority(Notification.PRIORITY_MAX);
      b.addAction(new Notification.Action.Builder(android.R.drawable.sym_call_missed, "Decline", decline).build());
      b.addAction(new Notification.Action.Builder(android.R.drawable.sym_action_call, "Answer", answer).build());
    }
    notify(nm, b.build());
  }

  @SuppressWarnings("deprecation")
  static void showOngoing(Context context, String callId, String caller, String status, long connectedAt) {
    NotificationManager nm = context.getSystemService(NotificationManager.class);
    if (nm == null) return;
    ensureChannels(context, nm);
    PendingIntent hangUp = actionIntent(context, CallActionReceiver.ACTION_HANG_UP, callId, 3);
    Notification.Builder b =
        builder(context, CHANNEL_ONGOING)
            .setSmallIcon(android.R.drawable.sym_action_call)
            .setContentTitle(caller)
            .setContentText(status)
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(launchIntent(context))
            .addAction(
                new Notification.Action.Builder(android.R.drawable.sym_call_missed, "Hang up", hangUp)
                    .build());
    if (connectedAt > 0) {
      b.setWhen(connectedAt).setShowWhen(true).setUsesChronometer(true);
    }
    notify(nm, b.build());
  }

  static void cancel(Context context) {
    NotificationManager nm = context.getSystemService(NotificationManager.class);
    if (nm != null) nm.cancel(NOTIFICATION_ID);
  }

  private static void notify(NotificationManager nm, Notification notification) {
    try {
      nm.notify(NOTIFICATION_ID, notification);
    } catch (RuntimeException ignored) {
      // POST_NOTIFICATIONS not granted on Android 13+, or the style was refused.
    }
  }
}
