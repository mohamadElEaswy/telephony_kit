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
| `String? takeCallScreenRequest()` | Call id ('' = current call) the user asked to see from the notification or bubble, once |

`TelephonyPermission`: `callPhone`, `readPhoneState`, `readCallLog`,
`writeCallLog`, `answerPhoneCalls`, `readContacts`, `writeContacts`, `sendSms`,
`readSms`, `postNotifications`, `bluetoothConnect`, `readPhoneNumbers`,
`accessFineLocation`.

## Placing calls

| Member | Notes |
| --- | --- |
| `void openDialer(String number)` | No permission |
| `void placeCall(String number, {String? phoneAccountId, bool video = false})` | CALL_PHONE; `video` starts a video call (state only, no frames) |
| `List<String> getPhoneAccounts()` | Account ids, usually one per SIM |
| `List<PhoneAccount> getPhoneAccountDetails()` | `id`, `label`, `slotIndex` (Android 11+), `displayName` |
| `bool isEmergencyNumber(String number)` | |
| `bool get isInCall` | Any app; READ_PHONE_STATE |

## Calls (default dialer only)

| Member | Notes |
| --- | --- |
| `Stream<CallEvent> get callEvents` | `CallAdded`, `CallStateChanged`, `CallDisconnected(callId, cause)`, `CallRemoved`, `PostDialWait(callId, remaining)`, `AudioStateChanged`, `CallScreenRequested(callId)` (sealed) |
| `List<PhoneCall> get calls` / `PhoneCall call(String id)` | |
| `set showCallNotifications(bool)` / `set launchAppOnIncomingCall(bool)` | Both default true |
| `bool get isMuted`, `bool setMuted(bool)`, `bool setSpeakerOn(bool)` | |
| `AudioRoute get audioRoute`, `Set<AudioRoute> get supportedAudioRoutes`, `bool setAudioRoute(AudioRoute)` | |
| `List<BluetoothAudioDevice> get bluetoothDevices`, `bool selectBluetoothDevice(String address)` | Android 9+ |
| `bool swapCalls()` | Call waiting |
| `bool proximitySensorEnabled` (get/set), `bool get isProximityLockHeld` | Default on |
| `bool missedCallNotificationsEnabled` (get/set), `void clearMissedCallNotification()` | Needs the missed call receiver |
| `List<String> quickReplies` | Default reject-with-message texts, settable |
| `bool get isInCallServiceBound` | |
| `CallBubbleSettings get callBubble` | `enabled` (get/set, saved), `hasPermission`, `requestPermission()` (opens Settings, false if granted), `isShowing`, `hide()`, `labels = CallBubbleLabels(...)`; needs SYSTEM_ALERT_WINDOW |

`PhoneCall`: `id`, `state` (`CallState`), `number`, `displayName`,
`isIncoming`, `connectedAt`, `answer()`, `reject({String? message})`,
`cannedTextResponses`, `hangUp()`, `hold()`,
`unhold()`, `playDtmf(digit)`, `stopDtmf()`, `isConference`, `canMerge`,
`canSwap`, `children`, `parent`, `merge()`, `conferenceWith(other)`, `swap()`,
`splitFromConference()`, `phoneAccount`, `selectablePhoneAccounts`,
`selectPhoneAccount(id, {setDefault})`, `disconnectCause`
(`DisconnectCause`: `code`, `label`, `description`, `reason`, `displayText`,
`isFailure`), `postDialRemaining`, `continuePostDial(bool)`. Actions return
`false` if the call is gone.

More on `PhoneCall`: `videoState` (0 audio, 1 TX, 2 RX, 3 both), `isVideo`,
`answerWithVideo()`, `numberVerification` (`NumberVerification.passed/
notVerified/failed/unknown`, Android 11+), `isWifiCall`, `isHdAudio`; real-time
text (Android 9+): `isRttActive`, `requestRtt()`, `stopRtt()`,
`pendingRttRequestId`, `respondToRtt(accept:)`, `sendRttText(text)`,
`readRttText()` (non blocking, poll it). RTT and video changes arrive as
`CallStateChanged` events.

`CallState`: `newCall, dialing, ringing, holding, active, disconnected,
selectPhoneAccount, connecting, disconnecting, pulling, audioProcessing,
simulatedRinging, unknown`; `isLive`.

## Call log and contacts

| Member | Notes |
| --- | --- |
| `List<CallLogEntry> searchCallLog({String? query, Set<CallLogType>? types, DateTime? from, DateTime? to, int limit = 100, bool details = false})` | READ_CALL_LOG; `details` reads the detail fields |
| `CallLogEntry? getCallLogEntry(String id)` | READ_CALL_LOG; with details |
| `CallHistory getCallHistory(String number, {int limit = 500})` | READ_CALL_LOG; same number in any format |
| `CallHistory getContactCallHistory(String contactId, {int limit = 500})` | READ_CALL_LOG + READ_CONTACTS; all the contact's numbers |
| `List<CallLogEntry> getCallLog({int limit = 100})` | |
| `int deleteCallLogEntries(Iterable<String> ids)`, `int deleteCallLogForNumber(String)`, `int markMissedCallsRead()` | WRITE_CALL_LOG |
| `List<Contact> searchContacts(String query, {int limit = 100})` | READ_CONTACTS; empty query lists all |
| `Contact? lookupNumber(String number)` | READ_CONTACTS |
| `List<ContactDetails> getContacts({String query = '', int limit = 100})` | READ_CONTACTS; includes contacts without numbers; query matches name, email or number |
| `ContactPage getContactsPage({String query = '', int offset = 0, int pageSize = 50, bool? refresh})` | READ_CONTACTS; for long lists. `ContactPage.contacts`, `totalCount`, `nextOffset`, `hasMore`; offset 0 rebuilds the id list (or pass `refresh`); `pageSize` 1..500 |
| `void clearContactPages()` | drops the cached id lists |
| `ContactDetails? getContact(String id)` | READ_CONTACTS |
| `String addContact(ContactDetails, {String? accountType, String? accountName})` | WRITE_CONTACTS; returns the new id |
| `bool updateContact(ContactDetails)` | WRITE_CONTACTS; needs `id`; false if the contact is gone |
| `bool setContactStarred(String id, bool starred)` | WRITE_CONTACTS |
| `bool deleteContact(String id)`, `int deleteContacts(Iterable<String> ids)` | WRITE_CONTACTS; cannot be undone |
| `Uint8List? getContactPhoto(String id, {bool fullSize = false})`, `bool setContactPhoto(String id, Uint8List? image)` | READ / WRITE_CONTACTS; null removes |
| `List<ContactAccount> getContactAccounts()` | READ_CONTACTS |
| `List<ContactGroup> getContactGroups({bool includeSystem})`, `String addContactGroup(title, {accountType, accountName})`, `bool renameContactGroup(id, title)`, `bool deleteContactGroup(id)` | READ / WRITE_CONTACTS |
| `List<String> getContactGroupIds(contactId)`, `List<ContactDetails> getGroupMembers(groupId)`, `bool addContactToGroup(contactId, groupId)`, `bool removeContactFromGroup(...)` | |
| `List<List<ContactDetails>> findDuplicateContacts()`, `String? mergeContacts(ids)`, `int splitContact(id)` | merge/split need WRITE_CONTACTS |
| `String exportContactsAsVCard({ids})`, `List<String> importVCard(String)` | pure Dart `exportVCard(contacts)`, `parseVCard(text)` need no permission |
| `bool showContact(id)`, `bool openContactEditor(id)`, `void openNewContactScreen({name, phone, email})` | system screens; the new contact screen needs no permission |
| `Stream<void> get contactChanges` / `callLogChanges` / `smsChanges` | debounced; need the matching read permission |
| `String addCallLogEntry({number, type, date, duration, name, subscriptionId})` | WRITE_CALL_LOG |
| `List<CallLogNumberStats> getCallLogStats({from, to, limit})`, `List<CallLogGroup> getGroupedCallLog({limit})` | READ_CALL_LOG; pure Dart `callLogStats`, `groupCallLog` |

`CallLogEntry`: `id`, `number`, `name`, `type` (`CallLogType`), `date`,
`duration`, `isNew`, `geocodedLocation`, `subscriptionId`, `features`,
`hasVideo`, `isWifi`, `isHd`, `isRtt`, `isRead`, `countryIso`; details:
`formattedNumber`, `numberLabel`, `postDialDigits`, `viaNumber`,
`presentation` (`NumberPresentation.allowed/restricted/unknown/payphone/
unavailable`), `lookupUri`, `voicemailUri`, `transcription`, `blockReason`,
`screeningAppName`, `lastModified`; getters `displayName`, `displayNumber`,
`endTime`, `wasConnected`. `CallHistory`: `numbers`, `entries` (newest
first), `name`, `contactId`, `total`, `incoming`, `outgoing`, `missed`,
`rejected`, `blocked`, `totalDuration`, `longestCall`, `lastCall`,
`firstCall`, `entriesFor(number)`, `CallHistory.from(entries, numbers)`. `Contact`: `id`, `displayName`, `phones`
(`ContactPhone(number, label)`), `photoUri`, `isStarred`. `ContactDetails`:
`id`, `lookupKey`, `displayName`, `givenName`, `middleName`, `familyName`,
`namePrefix`, `nameSuffix`, `nickname`, `company`, `department`, `jobTitle`,
`phones`, `emails` (`ContactEmail(address, label)`), `addresses`
(`ContactAddress(address, label)`), `websites`, `note`, `birthday`
(`yyyy-MM-dd` or `--MM-dd`), `ims` (`ContactIm(address, protocol)`), `relations`
(`ContactRelation(name, label)`), `sipAddresses`, `photoUri`, `isStarred`, and
`copyWith(...)`. `ContactPage`: `contacts`, `offset`, `nextOffset`,
`totalCount`, `hasMore`.
All fields are optional, so `ContactDetails(displayName: 'Sara')` is valid.

## Dates, times and time zones

| Member | Notes |
| --- | --- |
| `DeviceTimeZone get timeZone` | `id` (IANA), `name`, `shortName`, `offset`, `standardOffset`, `usesDaylightTime`, `inDaylightTime` |
| `bool get uses24HourFormat` | The phone's 12/24-hour setting |
| `CallTimeFormatter get timeFormatter` | A formatter following that setting |

`CallTimeFormatter({use24HourFormat = true, labels = const CallTimeLabels(), Duration? utcOffset})`:
`time(t, {seconds})`, `date(t, {now, withYear, long})`, `day(t)` (Today /
Yesterday / weekday / date), `relative(t, {ago})`, `dateTime(t)`,
`full(t, {timeZone})`, `offsetLabel(t)` (`GMT+02:00`), `duration(d)`
(`2:05`), `durationWords(d)` (`2 min 5 s`), `wallClock(t)`, `offsetAt(t)`.
`CallTimeLabels` holds every word for translation.
`groupByDay(items, dateOf, {formatter})` returns `MapEntry(firstTime, items)`
per calendar day.

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
| `List<SmsThread> getSmsThreads({int messageLimit = 1000})` | READ_SMS; pure Dart `groupSmsThreads` |
| `Stream<SmsMessage> get incomingSms` | READ_SMS; watches the inbox, no receiver needed |
| `List<MmsMessage> getMmsMessages({String? threadId, int limit = 50})` | READ_SMS; read only (`text`, `parts`, `addresses`) |
| `bool get isDefaultSmsApp`, `String? get defaultSmsPackage`, `bool requestDefaultSmsApp()` | the app must declare the SMS components, see manifest.md |
| `int deleteSmsMessages(ids)`, `int deleteSmsThread(id)`, `int markSmsRead(ids)`, `int markSmsThreadRead(id)` | default SMS app only, others get 0 |
| `Future<String> setCallForwarding(CallForwardingCondition, number)`, `cancelCallForwarding(c)`, `queryCallForwarding(c)` | via USSD (`**21*n#`); `unconditional/busy/noReply/notReachable` |
| `Future<String> setCallWaiting(bool)`, `queryCallWaiting()` | via USSD `*43#`, `#43#`, `*#43#` |
| `List<PhoneNumberInfo> getPhoneNumbers()` | READ_PHONE_NUMBERS; number often empty |
| `List<CellInfo> getCellInfo()`, `int? get signalDbm` | ACCESS_FINE_LOCATION for cells; dBm needs Android 10+ |
| `bool get isMobileDataEnabled`, `bool get isDataRoamingAllowed`, `DataConnectionState get dataConnectionState` | READ_PHONE_STATE |
| `EsimInfo getEsimInfo()` | `isSupported`, `eid` (carrier apps only), `profiles` |
