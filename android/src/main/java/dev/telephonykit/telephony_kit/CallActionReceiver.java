package dev.telephonykit.telephony_kit;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** Handles the answer, decline and hang up buttons on call notifications. */
public class CallActionReceiver extends BroadcastReceiver {
  static final String ACTION_ANSWER = "dev.telephonykit.telephony_kit.ANSWER";
  static final String ACTION_DECLINE = "dev.telephonykit.telephony_kit.DECLINE";
  static final String ACTION_HANG_UP = "dev.telephonykit.telephony_kit.HANG_UP";
  static final String EXTRA_CALL_ID = "callId";

  @Override
  public void onReceive(Context context, Intent intent) {
    String id = intent.getStringExtra(EXTRA_CALL_ID);
    String action = intent.getAction();
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
}
