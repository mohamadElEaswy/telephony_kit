package dev.telephonykit.telephony_kit;

/**
 * Receives "something changed" notifications from {@link ChangeMonitor}.
 *
 * <p>Implemented from Dart through jnigen. Callbacks arrive on the Android
 * main thread and must return quickly.
 */
public interface ChangeListener {
  /** The content at {@code uri} changed. */
  void onChange(String uri);
}
