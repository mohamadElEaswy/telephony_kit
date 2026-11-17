package dev.telephonykit.telephony_kit;

import android.content.Context;
import android.os.Build;
import android.provider.Settings;
import android.telephony.CellInfo;
import android.telephony.CellInfoCdma;
import android.telephony.CellInfoGsm;
import android.telephony.CellInfoLte;
import android.telephony.CellInfoNr;
import android.telephony.CellInfoWcdma;
import android.telephony.CellSignalStrength;
import android.telephony.SignalStrength;
import android.telephony.SubscriptionInfo;
import android.telephony.SubscriptionManager;
import android.telephony.TelephonyManager;
import android.telephony.euicc.EuiccManager;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executor;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** Phone numbers, cell info, data and eSIM state, and the call waiting query. */
public final class DeviceTools {
  private DeviceTools() {}

  /**
   * The device's own phone numbers, one {@code subscriptionId<TAB>slot<TAB>number}
   * line per active SIM. Numbers are often empty because the carrier did not
   * store them. Needs READ_PHONE_NUMBERS (or READ_PHONE_STATE before Android 13).
   */
  public static String[] getPhoneNumbers(Context context) {
    SubscriptionManager sm = context.getSystemService(SubscriptionManager.class);
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    if (sm == null || tm == null) return new String[0];
    List<SubscriptionInfo> subs = sm.getActiveSubscriptionInfoList();
    List<String> lines = new ArrayList<>();
    if (subs == null) return new String[0];
    for (SubscriptionInfo info : subs) {
      String number = "";
      try {
        if (Build.VERSION.SDK_INT >= 33) {
          number = sm.getPhoneNumber(info.getSubscriptionId());
        } else {
          number = tm.createForSubscriptionId(info.getSubscriptionId()).getLine1Number();
        }
      } catch (RuntimeException ignored) {
        // Permission or carrier restriction: leave empty.
      }
      lines.add(info.getSubscriptionId() + "\t" + info.getSimSlotIndex() + "\t" + (number == null ? "" : number));
    }
    return lines.toArray(new String[0]);
  }

  /**
   * Nearby cells as a JSON array. Each item has {@code type} (lte, nr, gsm,
   * wcdma, cdma), {@code registered}, {@code dbm}, {@code level} and {@code
   * cellId} (-1 if unknown). Needs ACCESS_FINE_LOCATION.
   */
  public static String getCellInfoJson(Context context) throws JSONException {
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    JSONArray array = new JSONArray();
    if (tm == null) return array.toString();
    List<CellInfo> cells = tm.getAllCellInfo();
    if (cells == null) return array.toString();
    for (CellInfo cell : cells) {
      JSONObject o = new JSONObject();
      CellSignalStrength strength = null;
      String type = "unknown";
      long cellId = -1;
      if (cell instanceof CellInfoLte) {
        type = "lte";
        strength = ((CellInfoLte) cell).getCellSignalStrength();
        cellId = ((CellInfoLte) cell).getCellIdentity().getCi();
      } else if (Build.VERSION.SDK_INT >= 29 && cell instanceof CellInfoNr) {
        type = "nr";
        strength = ((CellInfoNr) cell).getCellSignalStrength();
      } else if (cell instanceof CellInfoGsm) {
        type = "gsm";
        strength = ((CellInfoGsm) cell).getCellSignalStrength();
        cellId = ((CellInfoGsm) cell).getCellIdentity().getCid();
      } else if (cell instanceof CellInfoWcdma) {
        type = "wcdma";
        strength = ((CellInfoWcdma) cell).getCellSignalStrength();
        cellId = ((CellInfoWcdma) cell).getCellIdentity().getCid();
      } else if (cell instanceof CellInfoCdma) {
        type = "cdma";
        strength = ((CellInfoCdma) cell).getCellSignalStrength();
        cellId = ((CellInfoCdma) cell).getCellIdentity().getBasestationId();
      }
      o.put("type", type);
      o.put("registered", cell.isRegistered());
      o.put("dbm", strength == null ? Integer.MIN_VALUE : strength.getDbm());
      o.put("level", strength == null ? -1 : strength.getLevel());
      o.put("cellId", cellId);
      array.put(o);
    }
    return array.toString();
  }

  /**
   * The signal strength of the serving cell in dBm, or {@link Integer#MIN_VALUE}
   * if unknown. Needs Android 10+ and READ_PHONE_STATE.
   */
  public static int getSignalDbm(Context context) {
    if (Build.VERSION.SDK_INT < 29) return Integer.MIN_VALUE;
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    if (tm == null) return Integer.MIN_VALUE;
    SignalStrength s = tm.getSignalStrength();
    if (s == null) return Integer.MIN_VALUE;
    List<CellSignalStrength> list = s.getCellSignalStrengths();
    for (CellSignalStrength c : list) {
      if (c.getDbm() != Integer.MAX_VALUE) return c.getDbm();
    }
    return Integer.MIN_VALUE;
  }

  /** Whether mobile data is switched on. Needs Android 8+ and READ_PHONE_STATE. */
  public static boolean isDataEnabled(Context context) {
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    return tm != null && Build.VERSION.SDK_INT >= 26 && tm.isDataEnabled();
  }

  /** Whether the user allows mobile data while roaming. */
  public static boolean isDataRoamingEnabled(Context context) {
    if (Build.VERSION.SDK_INT >= 33) {
      TelephonyManager tm = context.getSystemService(TelephonyManager.class);
      return tm != null && tm.isDataRoamingEnabled();
    }
    try {
      return Settings.Global.getInt(context.getContentResolver(), Settings.Global.DATA_ROAMING) == 1;
    } catch (Settings.SettingNotFoundException e) {
      return false;
    }
  }

  /** {@code TelephonyManager.DATA_*}: disconnected 0, connecting 1, connected 2, suspended 3. */
  public static int getDataState(Context context) {
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    return tm == null ? -1 : tm.getDataState();
  }

  /** Whether the device supports eSIM (Android 9+). */
  public static boolean isEsimSupported(Context context) {
    if (Build.VERSION.SDK_INT < 28) return false;
    EuiccManager em = context.getSystemService(EuiccManager.class);
    return em != null && em.isEnabled();
  }

  /** The eSIM chip id, or an empty string (needs carrier privileges, so usually empty). */
  public static String getEid(Context context) {
    if (Build.VERSION.SDK_INT < 28) return "";
    try {
      EuiccManager em = context.getSystemService(EuiccManager.class);
      String eid = em == null ? null : em.getEid();
      return eid == null ? "" : eid;
    } catch (RuntimeException e) {
      return "";
    }
  }

  /**
   * Asks the network if call waiting is on. The listener gets {@code
   * enabled}, {@code disabled} or {@code unsupported}. Needs Android 13+ and
   * READ_PHONE_STATE; fails on older versions.
   */
  public static void getCallWaiting(Context context, int subscriptionId, ResultListener listener) {
    if (Build.VERSION.SDK_INT < 33) {
      listener.onFailure(-1, "Reading call waiting needs Android 13 or newer");
      return;
    }
    TelephonyManager tm = context.getSystemService(TelephonyManager.class);
    if (tm == null) {
      listener.onFailure(-1, "Telephony is not available");
      return;
    }
    if (subscriptionId >= 0) tm = tm.createForSubscriptionId(subscriptionId);
    Executor executor = context.getMainExecutor();
    try {
      tm.getCallWaitingStatus(
          executor,
          status -> {
            switch (status) {
              case TelephonyManager.CALL_WAITING_STATUS_ENABLED:
                listener.onSuccess("enabled");
                break;
              case TelephonyManager.CALL_WAITING_STATUS_DISABLED:
                listener.onSuccess("disabled");
                break;
              case TelephonyManager.CALL_WAITING_STATUS_NOT_SUPPORTED:
                listener.onSuccess("unsupported");
                break;
              default:
                listener.onFailure(status, "The network did not answer");
            }
          });
    } catch (SecurityException e) {
      listener.onFailure(-2, "READ_PHONE_STATE permission is missing");
    }
  }
}
