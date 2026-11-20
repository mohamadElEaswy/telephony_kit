package dev.telephonykit.telephony_kit;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

/**
 * An invisible activity behind the Answer button and the body of the call
 * notifications, and behind the Open button of the call bubble.
 *
 * <p>Since Android 12 a notification button that runs a broadcast receiver
 * may not open an activity (the "notification trampoline" rule), so the app
 * would stay closed after answering. An activity started from a
 * notification may, so this one answers the call, opens the app's launch
 * activity on the call screen and closes itself straight away.
 *
 * <p>Declared, not exported, in the library manifest.
 */
public class CallActionActivity extends Activity {
  static final String ACTION_ANSWER = "dev.telephonykit.telephony_kit.OPEN_AND_ANSWER";
  static final String ACTION_SHOW_CALL = "dev.telephonykit.telephony_kit.OPEN_CALL";

  @Override
  @SuppressWarnings("deprecation")
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    Intent intent = getIntent();
    String action = intent == null ? null : intent.getAction();
    String callId = intent == null ? null : intent.getStringExtra(CallActionReceiver.EXTRA_CALL_ID);
    if (ACTION_ANSWER.equals(action) && callId != null) {
      CallManager.answer(callId);
    }
    CallManager.requestCallScreen(this, callId);
    finish();
    overridePendingTransition(0, 0);
  }
}
