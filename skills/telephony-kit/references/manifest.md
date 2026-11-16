# AndroidManifest.xml entries for telephony_kit

All entries go in `android/app/src/main/AndroidManifest.xml`. Add only the ones
for features the app uses.

## Permissions

```xml
<!-- Place calls, voicemail, USSD -->
<uses-permission android:name="android.permission.CALL_PHONE" />
<!-- SIM list, phone accounts, voicemail number, call state events -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<!-- Read / change the call log -->
<uses-permission android:name="android.permission.READ_CALL_LOG" />
<uses-permission android:name="android.permission.WRITE_CALL_LOG" />
<!-- Contact search, caller names, "callers not in contacts" screening -->
<uses-permission android:name="android.permission.READ_CONTACTS" />
<!-- Call notifications (dialer) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<!-- Bluetooth device names during calls (Android 12+) -->
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<!-- SMS (restricted on Google Play) -->
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />

<!-- Lets the app install on tablets without telephony -->
<uses-feature android:name="android.hardware.telephony" android:required="false" />
```

Runtime requests with `permission_handler`: `Permission.phone` covers
CALL_PHONE, READ_PHONE_STATE and the call log; also request
`Permission.contacts`, `Permission.notification`, `Permission.sms` and
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

The package's own manifest already declares the notification button receiver;
nothing else is needed for notifications.
