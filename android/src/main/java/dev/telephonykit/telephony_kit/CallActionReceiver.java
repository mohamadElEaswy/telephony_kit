package dev.telephonykit.telephony_kit;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.telecom.TelecomManager;

/** Handles the buttons on call and missed call notifications. */
public class CallActionReceiver extends BroadcastReceiver {
  static final String ACTION_ANSWER = "dev.telephonykit.telephony_kit.ANSWER";
  static final String ACTION_DECLINE = "dev.telephonykit.telephony_kit.DECLINE";
  static final String ACTION_HANG_UP = "dev.telephonykit.telephony_kit.HANG_UP";
  static final String ACTION_CALL_BACK = "dev.telephonykit.telephony_kit.CALL_BACK";
  static final String EXTRA_CALL_ID = "callId";
  static final String EXTRA_NUMBER = "number";

  @Override
  public void onReceive(Context context, Intent intent) {
    String action = intent.getAction();
    if (ACTION_CALL_BACK.equals(action)) {
      callBack(context, intent.getStringExtra(EXTRA_NUMBER));
      return;
    }
    String id = intent.getStringExtra(EXTRA_CALL_ID);
    if (id == null || action == null) return;
    switch (action) {
      case ACTION_ANSWER:
        CallManager.answer(id);
        CallManager.launchApp(context);
        break;
      case ACTION_DECLINE:
        CallManager.reject(id);
        break;
      case ACTION_HANG_UP:
        CallManager.disconnect(id);
        break;
      default:
        break;
    }
  }

  /** Calls the number back, or opens the dialer without CALL_PHONE. */
  private static void callBack(Context context, String number) {
    MissedCallNotifications.clear(context);
    if (number == null || number.isEmpty()) return;
    Uri uri = Uri.fromParts("tel", number, null);
    if (context.checkSelfPermission(android.Manifest.permission.CALL_PHONE)
        == PackageManager.PERMISSION_GRANTED) {
      TelecomManager telecom = context.getSystemService(TelecomManager.class);
      if (telecom != null) {
        try {
          telecom.placeCall(uri, null);
          return;
        } catch (RuntimeException ignored) {
          // Fall back to the dialer.
        }
      }
    }
    Intent dial = new Intent(Intent.ACTION_DIAL, uri);
    dial.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    try {
      context.startActivity(dial);
    } catch (RuntimeException ignored) {
      // Background activity start blocked.
    }
  }
}
