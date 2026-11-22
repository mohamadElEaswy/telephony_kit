package dev.telephonykit.telephony_kit;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * Receives MMS notifications while the app is the default SMS app ({@code
 * WAP_PUSH_DELIVER}). Android requires a default SMS app to have this
 * receiver. telephony_kit does not download MMS: it shows a notification
 * so the user knows a multimedia message arrived. Declared by the app,
 * protected by {@code BROADCAST_WAP_PUSH}.
 */
public final class TelephonyKitMmsReceiver extends BroadcastReceiver {
  @Override
  public void onReceive(Context context, Intent intent) {
    if (!"android.provider.Telephony.WAP_PUSH_DELIVER".equals(intent.getAction())) return;
    SmsNotifications.showMms(context);
  }
}
