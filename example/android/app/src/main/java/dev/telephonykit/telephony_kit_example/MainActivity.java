package dev.telephonykit.telephony_kit_example;

import android.content.Intent;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
  @Override
  protected void onNewIntent(@NonNull Intent intent) {
    super.onNewIntent(intent);
    // Keep the latest dial intent for TelephonyKit.takeDialNumber().
    setIntent(intent);
  }
}
