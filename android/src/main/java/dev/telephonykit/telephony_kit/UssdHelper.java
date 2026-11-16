package dev.telephonykit.telephony_kit;

import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.telephony.TelephonyManager;

/** Sends USSD codes such as {@code *100#} and returns the network's reply. */
public final class UssdHelper {
  private UssdHelper() {}

  /**
   * Sends {@code code}. Pass a subscription id to use a specific SIM, or -1
   * for the default. Needs CALL_PHONE and Android 8.0+.
   */
  public static void send(Context context, String code, int subscriptionId, ResultListener listener) {
    if (Build.VERSION.SDK_INT < 26) {
      listener.onFailure(-1, "USSD needs Android 8.0 or newer");
      return;
    }
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    if (tm == null) {
      listener.onFailure(-1, "Telephony is not available");
      return;
    }
    if (subscriptionId >= 0) tm = tm.createForSubscriptionId(subscriptionId);
    try {
      tm.sendUssdRequest(
          code,
          new TelephonyManager.UssdResponseCallback() {
            @Override
            public void onReceiveUssdResponse(
                TelephonyManager telephonyManager, String request, CharSequence response) {
              listener.onSuccess(response == null ? "" : response.toString());
            }

            @Override
            public void onReceiveUssdResponseFailed(
                TelephonyManager telephonyManager, String request, int failureCode) {
              listener.onFailure(failureCode, "USSD request failed");
            }
          },
          new Handler(Looper.getMainLooper()));
    } catch (SecurityException e) {
      listener.onFailure(-2, "CALL_PHONE permission is missing");
    } catch (RuntimeException e) {
      listener.onFailure(-1, String.valueOf(e.getMessage()));
    }
  }
}
