package dev.telephonykit.telephony_kit;

import android.telecom.Call;
import android.telecom.CallAudioState;
import android.telecom.InCallService;

/**
 * The {@link InCallService} used by apps built with telephony_kit.
 *
 * <p>The system only binds to it while the app holds the default dialer role.
 * Apps must declare it in their own AndroidManifest.xml (see the package
 * README), because declaring it in a library would register every app that
 * depends on the package as an in-call UI.
 */
public class TelephonyKitInCallService extends InCallService {
  @Override
  public void onCreate() {
    super.onCreate();
    CallManager.attachService(this);
  }

  @Override
  public void onDestroy() {
    CallManager.detachService(this);
    super.onDestroy();
  }

  @Override
  public void onCallAdded(Call call) {
    CallManager.addCall(this, call);
  }

  @Override
  public void onCallRemoved(Call call) {
    CallManager.removeCall(call);
  }

  @Override
  @SuppressWarnings("deprecation")
  public void onCallAudioStateChanged(CallAudioState audioState) {
    CallManager.onAudioStateChanged(audioState);
  }
}
