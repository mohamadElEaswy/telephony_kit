package dev.telephonykit.telephony_kit;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;
import android.os.Build;
import android.telephony.PhoneNumberUtils;
import android.telephony.TelephonyManager;
import java.util.HashSet;
import java.util.Set;

/**
 * Block rules applied by {@link TelephonyKitCallScreeningService}.
 *
 * <p>Rules are saved in SharedPreferences so they work even when the Flutter
 * app is not running.
 */
public final class CallScreening {
  private CallScreening() {}

  public static final int ACTION_ALLOW = 0;
  public static final int ACTION_SILENCE = 1;
  public static final int ACTION_REJECT = 2;

  private static final String PREFS = "telephony_kit_screening";
  private static final String KEY_ENABLED = "enabled";
  private static final String KEY_NUMBERS = "numbers";
  private static final String KEY_PREFIXES = "prefixes";
  private static final String KEY_UNKNOWN = "unknown_action";
  private static final String KEY_HIDDEN = "hidden_action";
  private static final String KEY_BLOCKED = "blocked_action";

  /** Digits needed for two numbers to match by suffix (handles +20 vs 0). */
  private static final int MIN_SUFFIX = 7;

  private static ScreeningListener listener;

  private static SharedPreferences prefs(Context context) {
    return context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
  }

  /** Receives a callback for each screened call while the app is running. */
  public static synchronized void setListener(ScreeningListener newListener) {
    listener = newListener;
  }

  static synchronized ScreeningListener currentListener() {
    return listener;
  }

  /** Turns screening on or off. Off lets every call through. */
  public static void setEnabled(Context context, boolean enabled) {
    prefs(context).edit().putBoolean(KEY_ENABLED, enabled).apply();
  }

  public static boolean isEnabled(Context context) {
    return prefs(context).getBoolean(KEY_ENABLED, true);
  }

  /** What to do with numbers on the block list. Defaults to reject. */
  public static void setBlockedNumberAction(Context context, int action) {
    prefs(context).edit().putInt(KEY_BLOCKED, action).apply();
  }

  public static int getBlockedNumberAction(Context context) {
    return prefs(context).getInt(KEY_BLOCKED, ACTION_REJECT);
  }

  /** What to do with callers not in contacts. Defaults to allow. */
  public static void setUnknownCallerAction(Context context, int action) {
    prefs(context).edit().putInt(KEY_UNKNOWN, action).apply();
  }

  public static int getUnknownCallerAction(Context context) {
    return prefs(context).getInt(KEY_UNKNOWN, ACTION_ALLOW);
  }

  /** What to do with private or hidden numbers. Defaults to allow. */
  public static void setHiddenNumberAction(Context context, int action) {
    prefs(context).edit().putInt(KEY_HIDDEN, action).apply();
  }

  public static int getHiddenNumberAction(Context context) {
    return prefs(context).getInt(KEY_HIDDEN, ACTION_ALLOW);
  }

  public static void addBlockedNumber(Context context, String number) {
    edit(context, KEY_NUMBERS, digits(number), true);
  }

  public static void removeBlockedNumber(Context context, String number) {
    edit(context, KEY_NUMBERS, digits(number), false);
  }

  public static String[] getBlockedNumbers(Context context) {
    return prefs(context).getStringSet(KEY_NUMBERS, new HashSet<>()).toArray(new String[0]);
  }

  /** Blocks every number that starts with {@code prefix}, such as "+20900". */
  public static void addBlockedPrefix(Context context, String prefix) {
    edit(context, KEY_PREFIXES, digits(prefix), true);
  }

  public static void removeBlockedPrefix(Context context, String prefix) {
    edit(context, KEY_PREFIXES, digits(prefix), false);
  }

  public static String[] getBlockedPrefixes(Context context) {
    return prefs(context).getStringSet(KEY_PREFIXES, new HashSet<>()).toArray(new String[0]);
  }

  private static void edit(Context context, String key, String value, boolean add) {
    if (value.isEmpty()) return;
    SharedPreferences p = prefs(context);
    Set<String> set = new HashSet<>(p.getStringSet(key, new HashSet<>()));
    if (add) set.add(value);
    else set.remove(value);
    p.edit().putStringSet(key, set).apply();
  }

  /**
   * True if {@code number} is an emergency number in the current country,
   * such as 112 or 911. Uses {@code TelephonyManager.isEmergencyNumber} on
   * Android 10+ and {@code PhoneNumberUtils} before.
   */
  @SuppressWarnings("deprecation")
  public static boolean isEmergencyNumber(Context context, String number) {
    if (number == null || number.trim().isEmpty()) return false;
    if (Build.VERSION.SDK_INT >= 29) {
      TelephonyManager tm = context.getSystemService(TelephonyManager.class);
      if (tm != null) {
        try {
          return tm.isEmergencyNumber(number);
        } catch (RuntimeException ignored) {
          // No telephony; fall back below.
        }
      }
    }
    try {
      return PhoneNumberUtils.isEmergencyNumber(number);
    } catch (RuntimeException e) {
      return false;
    }
  }

  /** Decides what to do with an incoming call. Returns {action, reason}. */
  static Object[] evaluate(Context context, String number) {
    if (!isEnabled(context)) return new Object[] {ACTION_ALLOW, "disabled"};
    // Never block or silence emergency services calling back.
    if (isEmergencyNumber(context, number)) return new Object[] {ACTION_ALLOW, "emergency"};
    String d = digits(number);
    if (d.isEmpty()) {
      int action = getHiddenNumberAction(context);
      return new Object[] {action, action == ACTION_ALLOW ? "allowed" : "hidden_number"};
    }
    for (String blocked : prefs(context).getStringSet(KEY_NUMBERS, new HashSet<>())) {
      if (sameNumber(d, blocked)) {
        return new Object[] {getBlockedNumberAction(context), "blocked_number"};
      }
    }
    for (String prefix : prefs(context).getStringSet(KEY_PREFIXES, new HashSet<>())) {
      if (d.startsWith(prefix) || ("0" + d).startsWith(prefix)) {
        return new Object[] {getBlockedNumberAction(context), "blocked_prefix"};
      }
    }
    int unknown = getUnknownCallerAction(context);
    if (unknown != ACTION_ALLOW && !isContact(context, number)) {
      return new Object[] {unknown, "unknown_caller"};
    }
    return new Object[] {ACTION_ALLOW, "allowed"};
  }

  static String digits(String number) {
    if (number == null) return "";
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < number.length(); i++) {
      char c = number.charAt(i);
      if (c >= '0' && c <= '9') sb.append(c);
    }
    return sb.toString();
  }

  static boolean sameNumber(String a, String b) {
    if (a.equals(b)) return true;
    int n = Math.min(a.length(), b.length());
    if (n < MIN_SUFFIX) return false;
    String sa = a.replaceFirst("^0+", "");
    String sb = b.replaceFirst("^0+", "");
    return sa.endsWith(sb) || sb.endsWith(sa);
  }

  /** True if the number is saved in contacts. True when contacts can't be read. */
  private static boolean isContact(Context context, String number) {
    if (context.checkSelfPermission(android.Manifest.permission.READ_CONTACTS)
        != PackageManager.PERMISSION_GRANTED) {
      return true;
    }
    Uri uri =
        Uri.withAppendedPath(
            Uri.parse("content://com.android.contacts/phone_lookup"), Uri.encode(number));
    try (Cursor c =
        context.getContentResolver().query(uri, new String[] {"_id"}, null, null, null)) {
      return c != null && c.moveToFirst();
    } catch (RuntimeException e) {
      return true;
    }
  }
}
