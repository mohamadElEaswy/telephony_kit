package dev.telephonykit.telephony_kit;

import android.app.Service;
import android.content.Intent;
import android.net.Uri;
import android.os.IBinder;
import android.telephony.TelephonyManager;

/**
 * Sends "respond via message" texts (a quick reply when rejecting a call
 * from the system or another dialer). Android requires a default SMS app to
 * have this service. Declared by the app, protected by {@code
 * SEND_RESPOND_VIA_MESSAGE}.
 */
public final class TelephonyKitRespondViaMessageService extends Service {
  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    if (intent != null
        && TelephonyManager.ACTION_RESPOND_VIA_MESSAGE.equals(intent.getAction())) {
      String text = intent.getStringExtra(Intent.EXTRA_TEXT);
      Uri data = intent.getData();
      if (text != null && !text.isEmpty() && data != null) {
        String recipients = SmsIntents.recipients(data);
        int subId = TelephonyKitSmsDeliverReceiver.subscriptionId(intent);
        for (String to : recipients.split(";")) {
          if (to.trim().isEmpty()) continue;
          SmsHelper.send(this, to.trim(), text, subId, SmsHelper.IGNORE);
        }
      }
    }
    stopSelf(startId);
    return START_NOT_STICKY;
  }

  @Override
  public IBinder onBind(Intent intent) {
    return null;
  }
}
