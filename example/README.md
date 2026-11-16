# telephony_kit example

A small dialer built with telephony_kit: keypad with SIM choice, recent calls,
device and network details, and an in-call screen.

Run it on an Android phone with a SIM:

```sh
flutter run
```

Grant the phone permissions, then tap **Set default** to make it the default
phone app. Incoming and outgoing calls then show in the app's in-call screen.
See `android/app/src/main/AndroidManifest.xml` for the manifest entries a
dialer app needs.
