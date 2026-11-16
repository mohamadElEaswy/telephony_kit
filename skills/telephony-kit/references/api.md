# telephony_kit API reference

`final telephony = TelephonyKit.instance;` All members are synchronous unless
they return a `Future` or `Stream`. Failures throw `TelephonyException`.

## Roles and permissions

| Member | Notes |
| --- | --- |
| `bool hasPermission(String permission)` | Use `TelephonyPermission.*` constants |
| `bool get isDefaultDialer` | |
| `bool requestDefaultDialer()` | Shows the system prompt; re-check on resume |
| `String? get defaultDialerPackage` | |
| `bool get isCallScreeningRoleHeld` / `bool requestCallScreeningRole()` | Android 10+ |
| `String? takeDialNumber()` | Number from a `tel:` intent that opened the app, once |

`TelephonyPermission`: `callPhone`, `readPhoneState`, `readCallLog`,
`writeCallLog`, `answerPhoneCalls`, `readContacts`, `sendSms`, `readSms`,
`postNotifications`, `bluetoothConnect`, `readPhoneNumbers`.

## Placing calls

| Member | Notes |
| --- | --- |
| `void openDialer(String number)` | No permission |
| `void placeCall(String number, {String? phoneAccountId})` | CALL_PHONE |
| `List<String> getPhoneAccounts()` | Account ids, usually one per SIM |
| `bool get isInCall` | Any app; READ_PHONE_STATE |

## Calls (default dialer only)

| Member | Notes |
| --- | --- |
| `Stream<CallEvent> get callEvents` | `CallAdded`, `CallStateChanged`, `CallRemoved`, `AudioStateChanged` (sealed) |
| `List<PhoneCall> get calls` / `PhoneCall call(String id)` | |
| `set showCallNotifications(bool)` / `set launchAppOnIncomingCall(bool)` | Both default true |
| `bool get isMuted`, `bool setMuted(bool)`, `bool setSpeakerOn(bool)` | |
| `AudioRoute get audioRoute`, `Set<AudioRoute> get supportedAudioRoutes`, `bool setAudioRoute(AudioRoute)` | |
| `List<BluetoothAudioDevice> get bluetoothDevices`, `bool selectBluetoothDevice(String address)` | Android 9+ |
| `bool swapCalls()` | Call waiting |
| `bool get isInCallServiceBound` | |

`PhoneCall`: `id`, `state` (`CallState`), `number`, `displayName`,
`isIncoming`, `connectedAt`, `answer()`, `reject()`, `hangUp()`, `hold()`,
`unhold()`, `playDtmf(digit)`, `stopDtmf()`, `isConference`, `canMerge`,
`canSwap`, `children`, `parent`, `merge()`, `conferenceWith(other)`, `swap()`,
`splitFromConference()`. Actions return `false` if the call is gone.

`CallState`: `newCall, dialing, ringing, holding, active, disconnected,
selectPhoneAccount, connecting, disconnecting, pulling, audioProcessing,
simulatedRinging, unknown`; `isLive`.

## Call log and contacts

| Member | Notes |
| --- | --- |
| `List<CallLogEntry> searchCallLog({String? query, Set<CallLogType>? types, DateTime? from, DateTime? to, int limit = 100})` | READ_CALL_LOG |
| `List<CallLogEntry> getCallLog({int limit = 100})` | |
| `int deleteCallLogEntries(Iterable<String> ids)`, `int deleteCallLogForNumber(String)`, `int markMissedCallsRead()` | WRITE_CALL_LOG |
| `List<Contact> searchContacts(String query, {int limit = 100})` | READ_CONTACTS; empty query lists all |
| `Contact? lookupNumber(String number)` | READ_CONTACTS |

`CallLogEntry`: `id`, `number`, `name`, `type` (`CallLogType`), `date`,
`duration`, `isNew`. `Contact`: `id`, `displayName`, `phones`
(`ContactPhone(number, label)`), `photoUri`, `isStarred`.

## Blocking

`telephony.screening` (`CallScreeningSettings`, saved on device): `enabled`,
`blockedAction`, `unknownCallerAction`, `hiddenNumberAction`
(`ScreeningAction.allow/silence/reject`), `blockedNumbers`, `blockNumber`,
`unblockNumber`, `blockedPrefixes`, `blockPrefix`, `unblockPrefix`.
`Stream<ScreenedCall> get screenedCalls` (`number`, `action`, `reason`).

System list (default dialer or SMS app): `bool get canBlockNumbers`,
`List<BlockedNumber> getBlockedNumbers()`, `bool blockNumber(String)`,
`int unblockNumber(String)`, `bool isNumberBlocked(String)`.

## Device, network, USSD, SMS

| Member | Notes |
| --- | --- |
| `NetworkInfo getNetworkInfo()` | operator, country, SIM state, phone type, roaming, slots |
| `List<SimCard> getSimCards()` | READ_PHONE_STATE |
| `int get signalLevel` | 0 to 4, -1 unknown |
| `NetworkGeneration get networkGeneration` | `g2..g5`, `label` |
| `Stream<NetworkEvent> get networkEvents` | `SignalStrengthChanged`, `ServiceStatusChanged`, `NetworkTypeChanged`, `DeviceCallStateChanged` |
| `String get voicemailNumber`, `void callVoicemail()` | |
| `Future<String> sendUssd(String code, {int? subscriptionId, Duration timeout = 30s})` | CALL_PHONE, Android 8+ |
| `Future<int> sendSms(String to, String text, {int? subscriptionId})` | SEND_SMS; completes with part count when sent |
| `List<SmsMessage> searchSms({String? query, SmsType? type, String? threadId, int limit = 100})` | READ_SMS |
