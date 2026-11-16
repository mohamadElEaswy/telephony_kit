package dev.telephonykit.telephony_kit;

/** A one-shot result from an asynchronous Android request (USSD, SMS). */
public interface ResultListener {
  /** The request succeeded. {@code value} is the response text, if any. */
  void onSuccess(String value);

  /** The request failed with an Android error code. */
  void onFailure(int code, String message);
}
