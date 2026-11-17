package dev.telephonykit.telephony_kit;

import android.content.ContentResolver;
import android.content.Context;
import android.database.ContentObserver;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import java.util.HashMap;
import java.util.Map;

/**
 * Watches a content provider URI (contacts, call log, SMS) and reports
 * changes. {@link ContentObserver} is an abstract class, so it cannot be
 * implemented from Dart.
 */
public final class ChangeMonitor {
  private ChangeMonitor() {}

  private static final Handler main = new Handler(Looper.getMainLooper());
  private static final Map<Integer, ContentObserver> observers = new HashMap<>();
  private static int nextToken = 1;

  /**
   * Starts watching {@code uri} (including everything below it). Returns a
   * token for {@link #stop}. The caller needs read access to the provider.
   */
  public static synchronized int start(Context context, String uri, ChangeListener listener) {
    final ContentResolver resolver = context.getApplicationContext().getContentResolver();
    ContentObserver observer =
        new ContentObserver(main) {
          @Override
          public void onChange(boolean selfChange, Uri changed) {
            listener.onChange(changed == null ? uri : changed.toString());
          }
        };
    resolver.registerContentObserver(Uri.parse(uri), true, observer);
    int token = nextToken++;
    observers.put(token, observer);
    return token;
  }

  /** Stops the watch with this token. Unknown tokens are ignored. */
  public static synchronized void stop(Context context, int token) {
    ContentObserver observer = observers.remove(token);
    if (observer != null) {
      context.getApplicationContext().getContentResolver().unregisterContentObserver(observer);
    }
  }
}
