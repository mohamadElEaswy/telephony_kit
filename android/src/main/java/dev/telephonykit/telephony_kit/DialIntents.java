package dev.telephonykit.telephony_kit;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.telecom.PhoneAccountHandle;
import android.telecom.TelecomManager;

/**
 * Reads the number from a dial intent ({@code ACTION_DIAL} or {@code
 * ACTION_VIEW} with a {@code tel:} uri) that opened the activity.
 *
 * <p>The default dialer must handle these intents. Other apps send them
 * when the user taps a phone number.
 */
public final class DialIntents {
  private DialIntents() {}

  /**
   * Returns the number of the dial intent the activity was started with, or
   * an empty string, and marks the intent as handled so the number is only
   * returned once. Returns "" for a dial intent without a number.
   */
  public static String takeNumber(Activity activity) {
    if (activity == null) return "";
    Intent intent = activity.getIntent();
    if (intent == null) return "";
    String action = intent.getAction();
    if (!Intent.ACTION_DIAL.equals(action) && !Intent.ACTION_VIEW.equals(action)) {
      return "";
    }
    Uri data = intent.getData();
    if (data == null || !"tel".equals(data.getScheme())) return "";
    String number = data.getSchemeSpecificPart();
    // Handled: replace the intent so the number is not returned again.
    activity.setIntent(new Intent(Intent.ACTION_MAIN));
    return number == null ? "" : number;
  }

  /**
   * Extras for {@code TelecomManager.placeCall}: the SIM to use (or null) and
   * the starting video state ({@code VideoProfile.STATE_*}; 0 for audio).
   */
  public static Bundle callExtras(PhoneAccountHandle handle, int videoState) {
    Bundle extras = new Bundle();
    if (handle != null) extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle);
    if (videoState != 0) extras.putInt(TelecomManager.EXTRA_START_CALL_WITH_VIDEO_STATE, videoState);
    return extras;
  }
}
