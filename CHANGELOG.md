## 0.9.0

Silence the ringer
* `silenceRinger()` stops the ringtone and vibration of the ringing call
  without rejecting it (default dialer only). The call keeps ringing on
  screen and can still be answered or declined.

Phone number formatting (Android's `PhoneNumberUtils`, no extra dependency)
* `formatPhoneNumber(number)`: national format for local numbers
  (`010 01234567`), international for others (`+44 20 7946 0000`).
* `formatPhoneNumberAsYouType(input)` and the `PhoneNumberInputFormatter`
  text input formatter: format while typing like the system dialer, keeping
  the cursor in place (deleting a space deletes the digit before it).
* `phoneNumberToE164(number)`, `normalizePhoneNumber(number)` (letters to
  digits), `isSamePhoneNumber(a, b)` (`areSamePhoneNumber` on Android 12+)
  and `isGlobalPhoneNumber(number)`.
* Country detection: `defaultCountryIso` (network, then SIM, then locale)
  is used when no `countryIso` is passed; `phoneNumberCountry(number)`
  returns a `PhoneNumberCountry` (`isoCode`, `callingCode`,
  `nationalNumber`, `flag`).
* Pure Dart `callingCodeOf`, `countryOfNumber` (North American and +7
  numbers told apart by area code), `regionsForCallingCode`,
  `callingCodeForRegion`, `formattedCursorOffset` and `isDialableChar`.

Example
* The keypad formats the number as you type and shows its country. The
  incoming call screen has a Silence button. More tools has a phone number
  section with an as-you-type field, formatting and comparing.

## 0.8.0

Call details and history
* `getCallLogEntry(id)`: one call with every detail. New `CallLogEntry`
  fields `formattedNumber`, `numberLabel`, `postDialDigits`, `viaNumber`,
  `presentation` (`NumberPresentation`), `lookupUri`, `voicemailUri`,
  `transcription`, `blockReason`, `screeningAppName`, `lastModified`, and
  the getters `displayName`, `displayNumber`, `endTime`, `wasConnected`.
* `getCallHistory(number)` and `getContactCallHistory(contactId)` return a
  `CallHistory` with every call with that number (in any format) or with
  all of a contact's numbers, plus counts, talk time, first, last and
  longest call. `CallHistory.from` builds one from entries you have.
* `searchCallLog(details: true)` reads the detail fields too.
* Pure Dart `callLogEntryFromRow`.

Dates, times and time zones
* `CallTimeFormatter`: call times as phone apps show them (`14:05`,
  `Yesterday`, `Monday`, `12 Nov`, `5 min ago`), full date with the UTC
  offset, stopwatch and worded durations, 12/24-hour, fixed `utcOffset`,
  and `CallTimeLabels` for translations. `groupByDay` for section headers.
* `TelephonyKit.timeZone` (`DeviceTimeZone`: IANA id, names, current and
  standard offset, daylight saving), `uses24HourFormat` and
  `timeFormatter`.

Call screen
* Answering from the call notification now opens the app on the call
  screen, also on Android 12+ where a notification button may not open an
  app from a broadcast receiver. Tapping the incoming or ongoing call
  notification does the same. New invisible `CallActionActivity` in the
  library manifest (nothing to add to the app).
* New `CallScreenRequested` call event and `takeCallScreenRequest()` so apps
  with a call screen route can open it.

Floating call bubble
* `TelephonyKit.callBubble`: a draggable bubble over other apps while a
  call is live and the app is in the background, with mute, speaker, end,
  answer, decline and Open (back to the call screen). `enabled` (saved),
  `hasPermission`, `requestPermission()` (opens the "display over other
  apps" setting), `isShowing`, `hide()`, `labels` (`CallBubbleLabels`).
  Needs `SYSTEM_ALERT_WINDOW` in the app manifest.

Example
* Recents grouped by day with relative times; tapping a call opens a
  details screen with the full history of the number or contact. Contact
  details show recent calls and link to the full history. The Device tab
  shows the time zone and a call bubble switch with the permission flow.
  The in-call screen opens when answering from the notification.

## 0.7.0

* Contact paging: `getContactsPage(query:, offset:, pageSize:)` returns a
  `ContactPage` with `contacts`, `totalCount`, `nextOffset` and `hasMore`.
  The matching ids are collected natively once per search (new
  `ContactPager` Java helper), and each page loads only its own contacts, so
  lists of thousands of contacts scroll smoothly and use little memory.
  Search matches the name, an email or a phone number in any format, with no
  cap on the number of matches. `clearContactPages()` drops the cached ids.
* Example: the Contacts tab is now an infinite-scroll list that loads 50
  contacts at a time, shows the total, debounces the search, supports pull to
  refresh and keeps its place after editing a contact. Before, it showed only
  the first 300 contacts and re-queried on every keystroke.

## 0.6.0

Contacts
* Photos: `getContactPhoto`, `setContactPhoto`.
* Groups: `getContactGroups`, `addContactGroup`, `renameContactGroup`,
  `deleteContactGroup`, `getContactGroupIds`, `getGroupMembers`,
  `addContactToGroup`, `removeContactFromGroup`; `getContactAccounts`.
* Duplicates: `findDuplicateContacts`, `mergeContacts`, `splitContact`.
* vCard: `exportContactsAsVCard`, `importVCard`, and the pure Dart
  `exportVCard` and `parseVCard`.
* New contact fields `ContactDetails.ims`, `relations` and `sipAddresses`
  (`ContactIm`, `ContactRelation`), saved by `addContact` and `updateContact`.
* System screens: `showContact`, `openContactEditor`, `openNewContactScreen`.
* `contactChanges` stream.

Call log
* `CallLogEntry` gains `geocodedLocation`, `subscriptionId`, `features`
  (`hasVideo`, `isWifi`, `isHd`, `isRtt`), `isRead` and `countryIso`.
* `addCallLogEntry`, `getCallLogStats`, `getGroupedCallLog`, and the pure
  Dart `callLogStats` and `groupCallLog`. `callLogChanges` stream.

SMS
* `getSmsThreads` (and `groupSmsThreads`), `getMmsMessages` (read only),
  `incomingSms` and `smsChanges` streams.
* Default SMS app: `isDefaultSmsApp`, `defaultSmsPackage`,
  `requestDefaultSmsApp`; then `deleteSmsMessages`, `deleteSmsThread`,
  `markSmsRead`, `markSmsThreadRead`. The package does not ship the receivers
  a default SMS app needs; see the README.

Calls
* Video: `placeCall(video: true)`, `PhoneCall.videoState`, `isVideo`,
  `answerWithVideo`. Frames are not rendered.
* `PhoneCall.numberVerification` (STIR/SHAKEN, Android 11+),
  `isWifiCall`, `isHdAudio`.
* Real-time text: `isRttActive`, `requestRtt`, `stopRtt`,
  `pendingRttRequestId`, `respondToRtt`, `sendRttText`, `readRttText`.
* Call forwarding and call waiting through GSM codes: `setCallForwarding`,
  `cancelCallForwarding`, `queryCallForwarding`, `setCallWaiting`,
  `queryCallWaiting`.

Device and network
* `getPhoneNumbers`, `getCellInfo`, `signalDbm`, `isMobileDataEnabled`,
  `isDataRoamingAllowed`, `dataConnectionState`, `getEsimInfo`.
* New permission names `TelephonyPermission.accessFineLocation`.

Other
* Java helpers `ChangeMonitor`, `ContactTools`, `DeviceTools`, and more
  `CallManager` and `SmsHelper` methods; bindings regenerated.
* The example app has a "More tools" page and richer contact and in-call screens.
* Android does not expose these to third-party apps, so they are not
  included: reading whether Wi-Fi calling is enabled, a public call waiting
  query, and sending MMS.

## 0.5.0

* Full contact management: `getContacts` and `getContact` return
  `ContactDetails` with name parts, phones, emails, addresses, company, job
  title, nickname, websites, note, birthday, photo and favorite (contacts
  without a phone number are included). `addContact`, `updateContact`,
  `deleteContact`, `deleteContacts` and `setContactStarred` change the address
  book. New models `ContactDetails`, `ContactEmail`, `ContactAddress` and
  permission name `TelephonyPermission.writeContacts` (`WRITE_CONTACTS`). No
  new bindings were needed. The example Contacts tab can now open a contact,
  add, edit, favorite and delete.
* Agent skill and docs updated with the new contacts API.

## 0.4.0

* Agent support: `AGENTS.md` for contributors and an agent skill in
  `skills/telephony-kit/` for apps that use the package.

* Which SIM a call uses: `PhoneCall.phoneAccount` (id, carrier label, slot;
  `displayName` such as `SIM 2 · Vodafone`). `PhoneAccount.slotIndex` is
  filled on Android 11+. The example shows it on the in-call screen and uses
  slots on the keypad SIM selector.
* Reject with a message: `PhoneCall.reject(message: ...)` texts the caller
  (Telecom sends it, no SMS permission needed); `reject()` still works.
  `PhoneCall.cannedTextResponses` (the user's replies from the phone
  settings) and `TelephonyKit.quickReplies` (defaults, changeable). Example:
  Reply button on the incoming screen.
* Emergency numbers: `isEmergencyNumber(number)`. Call screening never
  blocks or silences emergency numbers (reason `emergency`). The example
  keypad labels them.
* Post-dial digits: a wait (`;`) in the dialed number sends a
  `PostDialWait` event; answer with `PhoneCall.continuePostDial(proceed)`.
  `PhoneCall.postDialRemaining`. Pauses (`,`) need nothing. Example: a
  "Send remaining digits?" dialog; long press `*` for `,` and `#` for `;`.
* Disconnect cause: `PhoneCall.disconnectCause` (`DisconnectCause` with
  `code`, `label`, `description`, `reason`, `displayText`,
  `isFailure`), still readable for the last 20 calls after removal, and a new
  `CallDisconnected` event sent just before `CallRemoved`. Breaking: an
  exhaustive `switch` over `CallEvent` needs a `CallDisconnected` case.
  The example shows failures such as "Busy" or "Radio off".
* Proximity sensor: the screen turns off near the ear while a call is
  active or dialing on the earpiece or a wired headset (not while ringing,
  on speaker or Bluetooth). `proximitySensorEnabled` (default true),
  `isProximityLockHeld`. The package now declares `WAKE_LOCK`.
* Missed call notifications: declare `TelephonyKitMissedCallReceiver` for
  `android.telecom.action.SHOW_MISSED_CALLS_NOTIFICATION` (exported, with
  `android:permission="android.permission.MODIFY_PHONE_STATE"` so only
  Telecom can send it; see the example manifest). As the default dialer the
  app then shows the missed call notification (count, last caller, Call back
  button) instead of the system. `missedCallNotificationsEnabled`,
  `clearMissedCallNotification()`; `markMissedCallsRead()` clears it too.
* SIM choice for outgoing calls: while a call is in
  `CallState.selectPhoneAccount` (multi SIM, no default SIM), read
  `PhoneCall.selectablePhoneAccounts` and call
  `PhoneCall.selectPhoneAccount(id, setDefault: ...)`. New `PhoneAccount`
  model (id, label, slot) and `getPhoneAccountDetails()`. The example shows a
  SIM picker.
* `takeDialNumber()` reads the number of the dial intent (`tel:` link) that
  opened the app. The example shows it on the keypad instead of crashing on
  an unknown Flutter route.
* `searchCallLog` fills `CallLogEntry.id` and `isNew` (deleting single
  entries works).
* `searchContacts` finds partial numbers anywhere in a number (`650` finds
  `+1 650-555-6789`).
* `canBlockNumbers` is only true for the default dialer or SMS app.
* `sendUssd` fails after a timeout (30 seconds by default) when the network
  does not reply.
* Conference changes are reported on `callEvents`; `swapCalls` only resumes
  the held call and lets Telecom hold the active one.
* Bindings regenerated; overload suffixes changed in the private bindings.
* Example: in-call screen shows over pushed pages, conferences show as
  "Conference (n)", Messages shows an empty state.

## 0.3.0

* Incoming call notification with answer and decline buttons that shows full
  screen on the lock screen, and an ongoing call notification with hang up.
  `showCallNotifications` turns them off.
* Call screening: `TelephonyKitCallScreeningService` applies block rules
  (numbers, prefixes, callers not in contacts, hidden numbers) even when the
  app is closed. Configure through `TelephonyKit.screening`; watch
  `screenedCalls`. `requestCallScreeningRole` for non-dialer apps.
* System block list: `getBlockedNumbers`, `blockNumber`, `unblockNumber`,
  `isNumberBlocked`, `canBlockNumbers`.
* Multi-call and conference: `swapCalls`, and on `PhoneCall` `merge`,
  `conferenceWith`, `swap`, `splitFromConference`, `children`, `parent`.
* Audio routes: `supportedAudioRoutes`, `setAudioRoute`, `bluetoothDevices`,
  `selectBluetoothDevice`.
* `networkEvents` stream (signal level, service state, 2G to 5G, device call
  state), plus `signalLevel` and `networkGeneration`.
* Call log changes: `deleteCallLogEntries`, `deleteCallLogForNumber`,
  `markMissedCallsRead`. `CallLogEntry` has `id` and `isNew`.
* `voicemailNumber`, `callVoicemail`, and `sendUssd` for codes like `*100#`.
* SMS: `sendSms` and `searchSms`.
* Example: blocking page, messages page, live network, USSD, audio route and
  keypad sheets, swap and merge, and long press actions on recent calls.
* The example manifest now lets the system play the ringtone
  (`IN_CALL_SERVICE_RINGING` false).

## 0.2.0

* `searchCallLog`: filter the call log by name or number, call type and date
  range. Number search ignores formatting and matches local and international
  forms.
* `searchContacts`: search contacts by name or number, with all their numbers,
  photo and favorite flag.
* `lookupNumber`: find the contact saved for a number, for caller names.
* `TelephonyPermission.readContacts`.
* Example: search on Recents, a missed calls filter, a Contacts tab, and
  caller names on the in-call screen.

## 0.1.0

* Initial release, Android only.
* Place calls (with SIM choice) and open the system dialer.
* Check and request the default dialer role.
* In-call control through `TelephonyKitInCallService`: call events stream,
  answer, reject, hang up, hold, DTMF, mute and speaker.
* Network, SIM and phone details.
* Read the call log.
* All Android access goes through JNI bindings generated by jnigen.
