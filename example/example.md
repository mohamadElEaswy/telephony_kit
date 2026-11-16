# telephony_kit examples

The full example in [`lib/main.dart`](lib/main.dart) is a working dialer with
a keypad, recent calls, contacts, device info, call blocking, messages and an
in-call screen. Run it with `flutter run` on an Android phone or emulator and
tap **Set default** to make it the phone app.

## Place a call and read the device

```dart
import 'package:telephony_kit/telephony_kit.dart';

final telephony = TelephonyKit.instance;

void callSupport() {
  if (telephony.hasPermission(TelephonyPermission.callPhone)) {
    telephony.placeCall('+201001234567');
  } else {
    telephony.openDialer('+201001234567'); // no permission needed
  }
  final info = telephony.getNetworkInfo();
  print('${info.networkOperatorName} ${telephony.networkGeneration.label}');
}
```

## Show your own in-call screen

```dart
// After requestDefaultDialer() and declaring TelephonyKitInCallService.
telephony.callEvents.listen((event) {
  final live = telephony.calls.where((c) => c.state.isLive).toList();
  if (live.isEmpty) return closeInCallScreen();
  final call = live.firstWhere(
    (c) => c.state == CallState.ringing,
    orElse: () => live.last,
  );
  showInCallScreen(call); // call.answer(), call.hangUp(), call.hold() ...
});
```

## Block calls, even when the app is closed

```dart
final rules = telephony.screening;
rules.blockNumber('+201001234567');
rules.blockPrefix('0900');
rules.unknownCallerAction = ScreeningAction.silence;
```

## Search

```dart
final missed = telephony.searchCallLog(types: {CallLogType.missed}, limit: 20);
final people = telephony.searchContacts('ahmed');
final balance = await telephony.sendUssd('*100#');
```
