package dev.telephonykit.telephony_kit;

import android.content.Context;
import android.os.Bundle;
import android.os.Parcelable;
import android.telecom.Call;
import android.telecom.PhoneAccount;
import android.telecom.PhoneAccountHandle;
import android.telecom.TelecomManager;
import java.util.ArrayList;
import java.util.List;

/** Phone account (SIM) helpers used by {@link CallManager}. */
final class PhoneAccounts {
  private PhoneAccounts() {}

  /** Call capable accounts, or an empty list without READ_PHONE_STATE. */
  static List<PhoneAccountHandle> callCapable(Context context) {
    TelecomManager telecom = context.getSystemService(TelecomManager.class);
    if (telecom == null) return new ArrayList<>();
    try {
      return new ArrayList<>(telecom.getCallCapablePhoneAccounts());
    } catch (SecurityException e) {
      return new ArrayList<>();
    }
  }

  /**
   * Accounts the user can choose from for a call waiting in
   * {@code STATE_SELECT_PHONE_ACCOUNT}: the ones Telecom offers in the call
   * extras, or else every call capable account.
   */
  @SuppressWarnings("deprecation")
  static List<PhoneAccountHandle> selectable(Context context, Call call) {
    List<PhoneAccountHandle> out = new ArrayList<>();
    Call.Details details = call.getDetails();
    Bundle extras = details == null ? null : details.getExtras();
    if (extras != null) {
      try {
        ArrayList<Parcelable> offered = extras.getParcelableArrayList(Call.AVAILABLE_PHONE_ACCOUNTS);
        if (offered != null) {
          for (Parcelable p : offered) {
            if (p instanceof PhoneAccountHandle) out.add((PhoneAccountHandle) p);
          }
        }
      } catch (RuntimeException ignored) {
        // Bad parcel; fall back to the call capable accounts.
      }
    }
    if (out.isEmpty() && context != null) out.addAll(callCapable(context));
    return out;
  }

  static PhoneAccountHandle find(List<PhoneAccountHandle> handles, String id) {
    if (id == null) return null;
    for (PhoneAccountHandle h : handles) {
      if (id.equals(h.getId())) return h;
    }
    return null;
  }

  /** The label the system shows for the account (usually the carrier), or "". */
  static String label(Context context, PhoneAccountHandle handle) {
    if (context == null || handle == null) return "";
    TelecomManager telecom = context.getSystemService(TelecomManager.class);
    if (telecom == null) return "";
    try {
      PhoneAccount account = telecom.getPhoneAccount(handle);
      if (account == null || account.getLabel() == null) return "";
      return account.getLabel().toString();
    } catch (RuntimeException e) {
      return "";
    }
  }
}
