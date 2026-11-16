package dev.telephonykit.telephony_kit;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.telecom.TelecomManager;

/**
 * Receives {@link TelecomManager#ACTION_SHOW_MISSED_CALLS_NOTIFICATION}, which
 * Telecom sends to the default dialer instead of showing its own missed call
 * notification. Apps declare it in their manifest (see the README).
 */
public class TelephonyKitMissedCallReceiver extends BroadcastReceiver {
  @Override
  public void onReceive(Context context, Intent intent) {
    if (!TelecomManager.ACTION_SHOW_MISSED_CALLS_NOTIFICATION.equals(intent.getAction())) return;
    int count = intent.getIntExtra(TelecomManager.EXTRA_NOTIFICATION_COUNT, 0);
    String number = intent.getStringExtra(TelecomManager.EXTRA_NOTIFICATION_PHONE_NUMBER);
    MissedCallNotifications.show(context, count, number);
  }
}
