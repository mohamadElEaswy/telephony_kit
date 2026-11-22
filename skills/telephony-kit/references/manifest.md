# AndroidManifest.xml entries for telephony_kit

All entries go in `android/app/src/main/AndroidManifest.xml`. Add only the ones
for features the app uses.

## Permissions

```xml
<!-- Place calls, voicemail, USSD -->
<uses-permission android:name="android.permission.CALL_PHONE" />
<!-- SIM list, phone accounts, voicemail number, call state events -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<!-- Answer / end calls without being the default dialer -->
<uses-permission android:name="android.permission.ANSWER_PHONE_CALLS" />
<!-- Read / change the call log -->
<uses-permission android:name="android.permission.READ_CALL_LOG" />
<uses-permission android:name="android.permission.WRITE_CALL_LOG" />
<!-- Contact search, caller names, "callers not in contacts" screening -->
<uses-permission android:name="android.permission.READ_CONTACTS" />
<!-- Add, edit, delete contacts -->
<uses-permission android:name="android.permission.WRITE_CONTACTS" />
<!-- SIM phone numbers (getPhoneNumbers) and nearby cells (getCellInfo) -->
<uses-permission android:name="android.permission.READ_PHONE_NUMBERS" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<!-- Call notifications (dialer) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<!-- Floating call bubble (callBubble); the user allows it in Settings -->
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<!-- Bluetooth device names during calls (Android 12+) -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<!-- SMS (restricted on Google Play) -->
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />

<!-- Lets the app install on tablets without telephony -->
<uses-feature android:name="android.hardware.telephony" android:required="false" />
```

Runtime requests with `permission_handler`: `Permission.phone` covers
CALL_PHONE, READ_PHONE_STATE, ANSWER_PHONE_CALLS and the call log; also request
`Permission.contacts` (covers READ and WRITE_CONTACTS), `Permission.notification`, `Permission.sms` and
`Permission.bluetoothConnect` as needed.

## Default dialer (in-call UI)

On the main activity:

```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTop"
    android:showWhenLocked="true"
    android:turnScreenOn="true"
    ...>
    <!-- Stop Flutter from treating tel: links as routes -->
    <meta-data
        android:name="flutter_deeplinking_enabled"
        android:value="false" />

    <intent-filter>
        <action android:name="android.intent.action.DIAL" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
    <intent-filter>
        <action android:name="android.intent.action.DIAL" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:scheme="tel" />
    </intent-filter>
</activity>
```

Inside `<application>`:

```xml
<service
    android:name="dev.telephonykit.telephony_kit.TelephonyKitInCallService"
    android:permission="android.permission.BIND_INCALL_SERVICE"
    android:exported="true">
    <meta-data
        android:name="android.telecom.IN_CALL_SERVICE_UI"
        android:value="true" />
    <!-- false: the system plays the ringtone -->
    <meta-data
        android:name="android.telecom.IN_CALL_SERVICE_RINGING"
        android:value="false" />
    <intent-filter>
        <action android:name="android.telecom.InCallService" />
    </intent-filter>
</service>
```

For missed call notifications, also inside `<application>`:

```xml
<receiver
    android:name="dev.telephonykit.telephony_kit.TelephonyKitMissedCallReceiver"
    android:permission="android.permission.MODIFY_PHONE_STATE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.telecom.action.SHOW_MISSED_CALLS_NOTIFICATION" />
    </intent-filter>
</receiver>
```

In `MainActivity`, keep the newest dial intent so `takeDialNumber()` sees it:

```kotlin
class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
```

## Call screening (blocking)

Inside `<application>`:

```xml
<service
    android:name="dev.telephonykit.telephony_kit.TelephonyKitCallScreeningService"
    android:permission="android.permission.BIND_SCREENING_SERVICE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.telecom.CallScreeningService" />
    </intent-filter>
</service>
```

Android binds it when the app is the default dialer, or after
`requestCallScreeningRole()` (Android 10+).

The package's own manifest already declares `WAKE_LOCK` (proximity screen
off) and the notification button receiver.

## Default SMS app

Needed to be offered the SMS role (`requestDefaultSmsApp`) and to delete or
mark messages. The package provides every component; declare all of them or
Android will not offer the role. Do not write your own SMS receivers in
Kotlin/Java.

```xml
<!-- Next to SEND_SMS and READ_SMS. Android grants these with the SMS role. -->
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.RECEIVE_MMS" />
<uses-permission android:name="android.permission.RECEIVE_WAP_PUSH" />

<!-- On the main activity, next to the DIAL filters. -->
<intent-filter>
    <action android:name="android.intent.action.SENDTO" />
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="sms" />
    <data android:scheme="smsto" />
    <data android:scheme="mms" />
    <data android:scheme="mmsto" />
</intent-filter>

<!-- Inside <application>. -->
<receiver
    android:name="dev.telephonykit.telephony_kit.TelephonyKitSmsDeliverReceiver"
    android:permission="android.permission.BROADCAST_SMS"
    android:exported="true">
    <intent-filter>
        <action android:name="android.provider.Telephony.SMS_DELIVER" />
    </intent-filter>
</receiver>
<receiver
    android:name="dev.telephonykit.telephony_kit.TelephonyKitMmsReceiver"
    android:permission="android.permission.BROADCAST_WAP_PUSH"
    android:exported="true">
    <intent-filter>
        <action android:name="android.provider.Telephony.WAP_PUSH_DELIVER" />
        <data android:mimeType="application/vnd.wap.mms-message" />
    </intent-filter>
</receiver>
<service
    android:name="dev.telephonykit.telephony_kit.TelephonyKitRespondViaMessageService"
    android:permission="android.permission.SEND_RESPOND_VIA_MESSAGE"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.RESPOND_VIA_MESSAGE" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:scheme="sms" />
        <data android:scheme="smsto" />
        <data android:scheme="mms" />
        <data android:scheme="mmsto" />
    </intent-filter>
</service>
```

While the app holds the role, the package stores incoming SMS in the inbox,
stores sent SMS (outbox, then sent or failed), and shows a notification per
sender (`smsNotificationsEnabled`). MMS are not downloaded: the MMS receiver
only shows a "Multimedia message" notification.

Reading, sending and the `incomingSms` stream do not need the SMS role.
