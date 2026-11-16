package dev.telephonykit.telephony_kit;

import android.net.Uri;
import android.os.Build;
import android.telecom.Call;
import android.telecom.CallScreeningService;

/**
 * Applies the {@link CallScreening} rules to incoming calls.
 *
 * <p>The system binds to it when the app is the default dialer or holds the
 * call screening role. Apps declare it in their own manifest (see README).
 */
public class TelephonyKitCallScreeningService extends CallScreeningService {
  @Override
  public void onScreenCall(Call.Details details) {
    if (Build.VERSION.SDK_INT >= 29
        && details.getCallDirection() != Call.Details.DIRECTION_INCOMING) {
      respondToCall(details, new CallResponse.Builder().build());
      return;
    }
    Uri handle = details.getHandle();
    String number = handle == null ? "" : handle.getSchemeSpecificPart();
    if (number == null) number = "";

    Object[] decision = CallScreening.evaluate(this, number);
    int action = (Integer) decision[0];
    String reason = (String) decision[1];

    CallResponse.Builder response = new CallResponse.Builder();
    if (action == CallScreening.ACTION_REJECT) {
      response.setDisallowCall(true).setRejectCall(true).setSkipNotification(true);
    } else if (action == CallScreening.ACTION_SILENCE && Build.VERSION.SDK_INT >= 29) {
      response.setSilenceCall(true);
    }
    respondToCall(details, response.build());

    ScreeningListener l = CallScreening.currentListener();
    if (l != null) {
      try {
        l.onCallScreened(number, action, reason);
      } catch (RuntimeException ignored) {
        // Never let a listener failure affect screening.
      }
    }
  }
}
