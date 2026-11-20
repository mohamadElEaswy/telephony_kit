import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// Times in the phone's 12/24-hour format and local time zone.
CallTimeFormatter get callTimes {
  try {
    return _telephony.timeFormatter;
  } on TelephonyException {
    return const CallTimeFormatter();
  }
}

IconData callTypeIcon(CallLogType type) => switch (type) {
  CallLogType.incoming => Icons.call_received,
  CallLogType.outgoing => Icons.call_made,
  CallLogType.missed => Icons.call_missed,
  CallLogType.voicemail => Icons.voicemail,
  CallLogType.rejected || CallLogType.blocked => Icons.block,
  CallLogType.answeredExternally => Icons.devices_other,
  _ => Icons.call,
};

String callTypeLabel(CallLogType type) => switch (type) {
  CallLogType.incoming => 'Incoming call',
  CallLogType.outgoing => 'Outgoing call',
  CallLogType.missed => 'Missed call',
  CallLogType.voicemail => 'Voicemail',
  CallLogType.rejected => 'Declined call',
  CallLogType.blocked => 'Blocked call',
  CallLogType.answeredExternally => 'Answered on another device',
  _ => 'Call',
};

Color? callTypeColor(BuildContext context, CallLogType type) =>
    type == CallLogType.missed ? Theme.of(context).colorScheme.error : null;

/// One call log entry in full, then every call with the same person.
///
/// When the number belongs to a contact, the history covers all of the
/// contact's numbers.
class CallDetailsPage extends StatefulWidget {
  const CallDetailsPage({super.key, required this.entryId, this.fallback});

  /// The call log row to show.
  final String entryId;

  /// Shown when the row cannot be read again (for example it was deleted).
  final CallLogEntry? fallback;

  @override
  State<CallDetailsPage> createState() => _CallDetailsPageState();
}

class _CallDetailsPageState extends State<CallDetailsPage> {
  CallLogEntry? _entry;
  Contact? _contact;
  CallHistory? _history;
  DeviceTimeZone? _zone;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    try {
      final entry =
          _telephony.getCallLogEntry(widget.entryId) ?? widget.fallback;
      _entry = entry;
      if (entry == null) return;
      _zone = _telephony.timeZone;
      if (entry.number.isNotEmpty &&
          _telephony.hasPermission(TelephonyPermission.readContacts)) {
        _contact = _telephony.lookupNumber(entry.number);
      }
      final contact = _contact;
      _history = contact != null
          ? _telephony.getContactCallHistory(contact.id)
          : _telephony.getCallHistory(entry.number);
    } on TelephonyException catch (e) {
      _error = e.message;
    }
  }

  String _simLabel(CallLogEntry entry) {
    final id = entry.subscriptionId;
    if (id == null) return '';
    try {
      for (final account in _telephony.getPhoneAccountDetails()) {
        if (account.id == '$id') {
          return account.displayName.isNotEmpty
              ? account.displayName
              : 'SIM ${account.slotIndex + 1}';
        }
      }
    } on TelephonyException {
      return '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Call details')),
        body: Center(
          child: Text(_error ?? 'This call is no longer in the log.'),
        ),
      );
    }
    final f = callTimes;
    final title =
        _contact?.displayName ??
        (entry.displayName.isEmpty ? 'Unknown' : entry.displayName);
    final features = [
      if (entry.hasVideo) 'Video',
      if (entry.isHd) 'HD voice',
      if (entry.isWifi) 'Wi-Fi calling',
      if (entry.isRtt) 'RTT',
    ];
    final zone = _zone;
    final sim = _simLabel(entry);

    Widget row(IconData icon, String label, String value) => ListTile(
      dense: true,
      leading: Icon(icon),
      title: Text(value),
      subtitle: Text(label),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call details'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _telephony.deleteCallLogEntries([entry.id]);
              Navigator.pop(context, true);
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 36,
              child: Text(
                title.isEmpty ? '?' : title.characters.first,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          if (entry.number.isNotEmpty && title != entry.displayNumber)
            Center(
              child: Text(
                [
                  entry.displayNumber,
                  entry.numberLabel,
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
            ),
          if (entry.geocodedLocation.isNotEmpty)
            Center(child: Text(entry.geocodedLocation)),
          const SizedBox(height: 12),
          if (entry.number.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Action(
                  icon: Icons.call,
                  label: 'Call',
                  onTap: () => _call(entry.number),
                ),
                _Action(
                  icon: Icons.content_copy,
                  label: 'Dial',
                  onTap: () => _telephony.openDialer(entry.number),
                ),
                _Action(
                  icon: Icons.block,
                  label: 'Block',
                  onTap: () => _block(entry.number),
                ),
              ],
            ),
          const Divider(),
          _Header('This call'),
          row(callTypeIcon(entry.type), 'Type', callTypeLabel(entry.type)),
          row(Icons.event, 'Started', f.full(entry.date)),
          if (entry.wasConnected) ...[
            row(
              Icons.timer_outlined,
              'Duration',
              '${f.durationWords(entry.duration)} (${f.duration(entry.duration)})',
            ),
            row(Icons.call_end, 'Ended', f.time(entry.endTime, seconds: true)),
          ],
          if (zone != null)
            row(
              Icons.public,
              'Time zone',
              '${zone.name} (${zone.id}, ${f.offsetLabel(entry.date)})',
            ),
          if (sim.isNotEmpty) row(Icons.sim_card_outlined, 'SIM', sim),
          if (features.isNotEmpty)
            row(Icons.network_cell, 'Network', features.join(', ')),
          if (entry.postDialDigits.isNotEmpty)
            row(Icons.dialpad, 'Extra digits', entry.postDialDigits),
          if (entry.viaNumber.isNotEmpty)
            row(Icons.call_split, 'Via', entry.viaNumber),
          if (entry.presentation != NumberPresentation.allowed)
            row(Icons.visibility_off, 'Number', switch (entry.presentation) {
              NumberPresentation.restricted => 'Hidden by the caller',
              NumberPresentation.payphone => 'Payphone',
              _ => 'Not available',
            }),
          if (entry.screeningAppName.isNotEmpty)
            row(Icons.shield_outlined, 'Screened by', entry.screeningAppName),
          if (entry.transcription.isNotEmpty)
            row(Icons.notes, 'Transcription', entry.transcription),
          if (entry.countryIso.isNotEmpty)
            row(Icons.flag_outlined, 'Country', entry.countryIso),
          if (_history case final history?) ...[
            const Divider(),
            CallHistorySummary(history: history),
            CallHistoryList(history: history, highlightId: entry.id, limit: 20),
            if (history.total > 20)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CallHistoryPage(
                      number: entry.number,
                      contactId: _contact?.id,
                      title: title,
                    ),
                  ),
                ),
                child: Text('See all ${history.total} calls'),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _call(String number) {
    try {
      if (_telephony.hasPermission(TelephonyPermission.callPhone)) {
        _telephony.placeCall(number);
      } else {
        _telephony.openDialer(number);
      }
    } on TelephonyException catch (e) {
      _snack(e.message);
    }
  }

  void _block(String number) {
    try {
      if (_telephony.canBlockNumbers) {
        _telephony.blockNumber(number);
      } else {
        _telephony.screening.blockNumber(number);
      }
      _snack('Blocked $number');
    } on TelephonyException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Every call with a contact (all of their numbers) or one number.
class CallHistoryPage extends StatelessWidget {
  const CallHistoryPage({
    super.key,
    this.contactId,
    this.number,
    this.title = 'Call history',
  });

  final String? contactId;
  final String? number;
  final String title;

  @override
  Widget build(BuildContext context) {
    Widget body;
    try {
      final id = contactId;
      final history = id != null
          ? _telephony.getContactCallHistory(id, limit: 2000)
          : _telephony.getCallHistory(number ?? '', limit: 2000);
      body = history.total == 0
          ? const Center(child: Text('No calls yet.'))
          : ListView(
              children: [
                CallHistorySummary(history: history),
                CallHistoryList(history: history),
              ],
            );
    } on TelephonyException catch (e) {
      body = Center(child: Text(e.message));
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

/// Counts and talk time for a history.
class CallHistorySummary extends StatelessWidget {
  const CallHistorySummary({super.key, required this.history});

  final CallHistory history;

  @override
  Widget build(BuildContext context) {
    final f = callTimes;
    final first = history.firstCall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          history.numbers.length > 1
              ? 'History with ${history.numbers.length} numbers'
              : 'History',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text('${history.total} calls')),
              if (history.incoming > 0)
                Chip(label: Text('${history.incoming} incoming')),
              if (history.outgoing > 0)
                Chip(label: Text('${history.outgoing} outgoing')),
              if (history.missed > 0)
                Chip(label: Text('${history.missed} missed')),
              Chip(
                label: Text(
                  'Talk time ${f.durationWords(history.totalDuration)}',
                ),
              ),
            ],
          ),
        ),
        if (first != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              'Since ${f.date(first.date, withYear: true)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// A history list with Today / Yesterday / date headers.
class CallHistoryList extends StatelessWidget {
  const CallHistoryList({
    super.key,
    required this.history,
    this.highlightId,
    this.limit,
  });

  final CallHistory history;
  final String? highlightId;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final f = callTimes;
    final entries = limit == null
        ? history.entries
        : history.entries.take(limit!).toList();
    final showNumber = history.numbers.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in groupByDay(entries, (e) => e.date, formatter: f)) ...[
          _Header(f.day(day.key)),
          for (final e in day.value)
            ListTile(
              dense: true,
              selected: e.id == highlightId,
              leading: Icon(
                callTypeIcon(e.type),
                color: callTypeColor(context, e.type),
              ),
              title: Text('${callTypeLabel(e.type)}, ${f.time(e.date)}'),
              subtitle: Text(
                [
                  if (e.wasConnected) f.durationWords(e.duration),
                  if (showNumber) e.displayNumber,
                ].join(' · '),
              ),
              onTap: e.id == highlightId || e.id.isEmpty
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            CallDetailsPage(entryId: e.id, fallback: e),
                      ),
                    ),
            ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      children: [
        IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
        Text(label),
      ],
    ),
  );
}
