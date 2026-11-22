package dev.telephonykit.telephony_kit;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;

/**
 * Reads what an SMS intent that opened the activity asks for: a {@code
 * SENDTO}, {@code SEND} or {@code VIEW} intent with an {@code sms:}, {@code
 * smsto:}, {@code mms:} or {@code mmsto:} uri, or a tap on a message
 * notification.
 */
public final class SmsIntents {
  private SmsIntents() {}

  /** The action of the intent a message notification opens. */
  static final String ACTION_OPEN = "dev.telephonykit.telephony_kit.OPEN_SMS";

  static final String EXTRA_ADDRESS = "dev.telephonykit.telephony_kit.SMS_ADDRESS";

  /**
   * Returns {@code [recipients, body, fromNotification]} for an SMS intent
   * the activity was started with, or null, and marks it handled so it is
   * returned once. Recipients are separated by {@code ;}. {@code
   * fromNotification} is "1" when the user tapped a message notification.
   */
  public static String[] takeRequest(Activity activity) {
    if (activity == null) return null;
    Intent intent = activity.getIntent();
    if (intent == null) return null;
    String action = intent.getAction();
    String[] result = null;
    if (ACTION_OPEN.equals(action)) {
      String address = intent.getStringExtra(EXTRA_ADDRESS);
      result = new String[] {address == null ? "" : address, "", "1"};
    } else if (Intent.ACTION_SENDTO.equals(action)
        || Intent.ACTION_SEND.equals(action)
        || Intent.ACTION_VIEW.equals(action)) {
      Uri data = intent.getData();
      if (data == null || !isMessageScheme(data.getScheme())) return null;
      String body = intent.getStringExtra("sms_body");
      if (body == null) body = intent.getStringExtra(Intent.EXTRA_TEXT);
      if (body == null) body = queryBody(data);
      result = new String[] {recipients(data), body == null ? "" : body, "0"};
    }
    if (result != null) activity.setIntent(new Intent(Intent.ACTION_MAIN));
    return result;
  }

  static boolean isMessageScheme(String scheme) {
    return "sms".equals(scheme)
        || "smsto".equals(scheme)
        || "mms".equals(scheme)
        || "mmsto".equals(scheme);
  }

  /** The recipients of an {@code smsto:} style uri, separated by {@code ;}. */
  static String recipients(Uri data) {
    String part = data.getSchemeSpecificPart();
    if (part == null) return "";
    int query = part.indexOf('?');
    if (query >= 0) part = part.substring(0, query);
    return part.replace(',', ';');
  }

  private static String queryBody(Uri data) {
    String part = data.getSchemeSpecificPart();
    if (part == null) return null;
    int query = part.indexOf('?');
    if (query < 0) return null;
    for (String pair : part.substring(query + 1).split("&")) {
      if (pair.startsWith("body=")) return Uri.decode(pair.substring(5));
    }
    return null;
  }
}
