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
