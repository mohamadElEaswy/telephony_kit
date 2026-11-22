package dev.telephonykit.telephony_kit;

import android.app.role.RoleManager;
import android.content.ContentValues;
import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.provider.Telephony;

/**
 * Writes messages to Android's SMS provider. Only the default SMS app may do
 * this, and it must: Android stores neither the messages it delivers to that
 * app nor the ones that app sends.
 */
public final class SmsStore {
  private SmsStore() {}

  /** Whether this app is the default SMS app. */
  public static boolean isDefaultSmsApp(Context context) {
    if (Build.VERSION.SDK_INT >= 29) {
      // getDefaultSmsPackage can return null on some devices.
      RoleManager roles = context.getSystemService(RoleManager.class);
      if (roles != null && roles.isRoleAvailable(RoleManager.ROLE_SMS)) {
        return roles.isRoleHeld(RoleManager.ROLE_SMS);
      }
    }
    String pkg = Telephony.Sms.getDefaultSmsPackage(context);
    return context.getPackageName().equals(pkg);
  }

  /** Stores a received message in the inbox, unread. Returns its uri or null. */
  static Uri insertInbox(Context context, String address, String body, long sentAt, int subId) {
    ContentValues v = new ContentValues();
    v.put(Telephony.Sms.ADDRESS, address);
    v.put(Telephony.Sms.BODY, body);
    v.put(Telephony.Sms.DATE, System.currentTimeMillis());
    v.put(Telephony.Sms.DATE_SENT, sentAt);
    v.put(Telephony.Sms.READ, 0);
    v.put(Telephony.Sms.SEEN, 0);
    if (subId >= 0) v.put(Telephony.Sms.SUBSCRIPTION_ID, subId);
    try {
      return context.getContentResolver().insert(Telephony.Sms.Inbox.CONTENT_URI, v);
    } catch (RuntimeException e) {
      return null;
    }
  }

  /** Stores a message that is being sent in the outbox. Returns its uri or null. */
  static Uri insertOutbox(Context context, String address, String body, int subId) {
    ContentValues v = new ContentValues();
    v.put(Telephony.Sms.ADDRESS, address);
    v.put(Telephony.Sms.BODY, body);
    v.put(Telephony.Sms.DATE, System.currentTimeMillis());
    v.put(Telephony.Sms.READ, 1);
    v.put(Telephony.Sms.SEEN, 1);
    if (subId >= 0) v.put(Telephony.Sms.SUBSCRIPTION_ID, subId);
    try {
      return context.getContentResolver().insert(Telephony.Sms.Outbox.CONTENT_URI, v);
    } catch (RuntimeException e) {
      return null;
    }
  }

  /** Moves a message to the sent box, or to failed when {@code sent} is false. */
  static void markSent(Context context, Uri message, boolean sent) {
    if (message == null) return;
    ContentValues v = new ContentValues();
    v.put(
        Telephony.Sms.TYPE,
        sent ? Telephony.Sms.MESSAGE_TYPE_SENT : Telephony.Sms.MESSAGE_TYPE_FAILED);
    try {
      context.getContentResolver().update(message, v, null, null);
    } catch (RuntimeException ignored) {
      // The role was lost while sending.
    }
  }
}
