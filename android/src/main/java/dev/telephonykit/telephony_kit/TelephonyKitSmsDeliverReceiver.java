package dev.telephonykit.telephony_kit;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.provider.Telephony;
import android.telephony.SmsMessage;

/**
 * Receives SMS while the app is the default SMS app ({@code SMS_DELIVER}),
 * stores them in the inbox and shows a notification. Android does neither
 * for the default SMS app. Declared by the app, protected by {@code
 * BROADCAST_SMS}.
 */
public final class TelephonyKitSmsDeliverReceiver extends BroadcastReceiver {
  @Override
  public void onReceive(Context context, Intent intent) {
    if (!Telephony.Sms.Intents.SMS_DELIVER_ACTION.equals(intent.getAction())) return;
    SmsMessage[] parts = Telephony.Sms.Intents.getMessagesFromIntent(intent);
    if (parts == null || parts.length == 0) return;
    StringBuilder body = new StringBuilder();
    String address = "";
    long sentAt = 0;
    for (SmsMessage part : parts) {
      if (part == null) continue;
      if (address.isEmpty() && part.getDisplayOriginatingAddress() != null) {
        address = part.getDisplayOriginatingAddress();
        sentAt = part.getTimestampMillis();
      }
      String text = part.getDisplayMessageBody();
      if (text != null) body.append(text);
    }
    int subId = subscriptionId(intent);
    SmsStore.insertInbox(context, address, body.toString(), sentAt, subId);
    SmsNotifications.show(context, address, body.toString());
  }

  static int subscriptionId(Intent intent) {
    if (Build.VERSION.SDK_INT >= 30) {
      int id = intent.getIntExtra(android.telephony.SubscriptionManager.EXTRA_SUBSCRIPTION_INDEX, -1);
      if (id >= 0) return id;
    }
    return intent.getIntExtra("subscription", -1);
  }
}
