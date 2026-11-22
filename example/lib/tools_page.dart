import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// One control for every extra telephony_kit API: contact groups, accounts,
/// duplicates, vCard, call log statistics, SMS conversations and MMS, call
/// forwarding, video calls and device details.
class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  final _log = <String>[];
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void initState() {
    super.initState();
    void watch(String name, Stream<Object?> stream) {
      try {
        _subs.add(
          stream.listen((event) {
            if (!mounted) return;
            setState(() {
              _log.insert(0, '$name: ${event ?? 'changed'}');
              if (_log.length > 8) _log.removeLast();
            });
          }, onError: (Object _) {}),
        );
      } on TelephonyException {
        // No permission: the section just shows nothing.
      }
    }

    if (_telephony.hasPermission(TelephonyPermission.readContacts)) {
      watch('Contacts', _telephony.contactChanges);
    }
    if (_telephony.hasPermission(TelephonyPermission.readCallLog)) {
      watch('Call log', _telephony.callLogChanges);
    }
    if (_telephony.hasPermission(TelephonyPermission.readSms)) {
      watch(
        'New SMS',
        _telephony.incomingSms.map((m) => '${m.address}: ${m.body}'),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  /// Runs [action] and shows what it returned, or the error.
  Future<void> _run(String title, FutureOr<String> Function() action) async {
    String text;
    try {
      text = await action();
    } on TelephonyException catch (e) {
      text = e.message;
    } on Object catch (e) {
      text = '$e';
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: SelectableText(text)),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<String?> _ask(String title, String label, {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
          maxLines: null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      ...children,
    ],
  );

  Widget _tile(String title, String subtitle, VoidCallback onTap) => ListTile(
    dense: true,
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.play_arrow),
    onTap: onTap,
  );

  // ---- Contacts ------------------------------------------------------------

  String _groupsText() {
    final groups = _telephony.getContactGroups();
    if (groups.isEmpty) return 'No groups.';
    return groups
        .map((g) => '${g.id}  ${g.title} (${g.memberCount})  ${g.accountName}')
        .join('\n');
  }

  Future<void> _addGroup() async {
    final title = await _ask('New group', 'Group name');
    if (title == null || title.trim().isEmpty) return;
    await _run(
      'Add group',
      () => 'Created group ${_telephony.addContactGroup(title)}',
    );
  }

  Future<void> _deleteGroup() async {
    final id = await _ask('Delete group', 'Group id (see the list)');
    if (id == null || id.trim().isEmpty) return;
    await _run(
      'Delete group',
      () => _telephony.deleteContactGroup(id.trim())
          ? 'Deleted.'
          : 'Not found or read only.',
    );
  }

  Future<void> _duplicates() async {
    await _run('Duplicate contacts', () {
      final groups = _telephony.findDuplicateContacts();
      if (groups.isEmpty) return 'No duplicates found.';
      return groups
          .map((g) => g.map((c) => '${c.displayName} (#${c.id})').join('  =  '))
          .join('\n');
    });
  }

  Future<void> _merge() async {
    final ids = await _ask('Merge contacts', 'Contact ids, comma separated');
    if (ids == null) return;
    await _run('Merge contacts', () {
      final id = _telephony.mergeContacts(ids.split(',').map((e) => e.trim()));
      return id == null
          ? 'Need two existing contacts.'
          : 'Merged into contact #$id';
    });
  }

  Future<void> _split() async {
    final id = await _ask('Split contact', 'Contact id');
    if (id == null) return;
    await _run(
      'Split contact',
      () => 'Split into ${_telephony.splitContact(id.trim())} contacts',
    );
  }

  Future<void> _importVCard() async {
    final text = await _ask('Import vCard', 'Paste vCard text');
    if (text == null || text.trim().isEmpty) return;
    await _run('Import vCard', () {
      final ids = _telephony.importVCard(text);
      return 'Added ${ids.length} contacts: ${ids.join(', ')}';
    });
  }

  // ---- Call log ------------------------------------------------------------

  Future<void> _addLogEntry() async {
    final number = await _ask('Add call log entry', 'Number');
    if (number == null || number.trim().isEmpty) return;
    await _run(
      'Add call log entry',
      () =>
          'Added entry ${_telephony.addCallLogEntry(number: number.trim(), type: CallLogType.outgoing, duration: const Duration(seconds: 42))}',
    );
  }

  // ---- SMS -----------------------------------------------------------------

  Future<void> _smsThreadAction(
    String title,
    int Function(String id) action,
  ) async {
    final id = await _ask(title, 'Thread id (see Conversations)');
    if (id == null || id.trim().isEmpty) return;
    await _run(title, () => '${action(id.trim())} messages changed');
  }

  // ---- Calls ---------------------------------------------------------------

  Future<void> _forward(CallForwardingCondition condition) async {
    final number = await _ask(
      'Forward ${condition.name}',
      'Forward to (empty = ask the carrier)',
    );
    if (number == null) return;
    await _run(
      'Forward ${condition.name}',
      () => number.trim().isEmpty
          ? _telephony.queryCallForwarding(condition)
          : _telephony.setCallForwarding(condition, number.trim()),
    );
  }

  Future<void> _videoCall() async {
    final number = await _ask('Video call', 'Number');
    if (number == null || number.trim().isEmpty) return;
    await _run('Video call', () {
      _telephony.placeCall(number.trim(), video: true);
      return 'Calling ${number.trim()} with video.';
    });
  }

  Future<void> _formatNumber() async {
    final number = await _ask('Format number', 'Phone number');
    if (number == null || number.trim().isEmpty) return;
    await _run('Format number', () {
      final country = _telephony.phoneNumberCountry(number);
      return [
        'Formatted: ${_telephony.formatPhoneNumber(number)}',
        'E.164: ${_telephony.phoneNumberToE164(number) ?? 'not valid'}',
        'Normalized: ${_telephony.normalizePhoneNumber(number)}',
        'Country: ${country == null ? '-' : '${country.flag} ${country.isoCode} +${country.callingCode}'}',
        'Device country: ${_telephony.defaultCountryIso}',
      ].join('\n');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('More tools')),
    body: ListView(
      children: [
        if (_log.isNotEmpty)
          _section('Live changes', [
            for (final line in _log) ListTile(dense: true, title: Text(line)),
          ]),
        _section('Phone numbers', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneNumberInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Formatted as you type',
                helperText: 'Country: ${_telephony.defaultCountryIso}',
              ),
            ),
          ),
          _tile(
            'Format a number',
            'National, international, E.164 and country',
            _formatNumber,
          ),
          _tile(
            'Compare two numbers',
            'Same number written differently?',
            () async {
              final pair = await _ask(
                'Compare',
                'Two numbers, comma separated',
              );
              if (pair == null || !pair.contains(',')) return;
              final parts = pair.split(',');
              await _run(
                'Compare',
                () => _telephony.isSamePhoneNumber(parts[0], parts[1])
                    ? 'Same number.'
                    : 'Different numbers.',
              );
            },
          ),
        ]),
        _section('Contacts', [
          _tile(
            'Accounts',
            'Where contacts can be saved',
            () => _run('Accounts', () {
              final a = _telephony.getContactAccounts();
              return a.isEmpty ? 'None found.' : a.join('\n');
            }),
          ),
          _tile(
            'Groups',
            'List contact groups (labels)',
            () => _run('Groups', _groupsText),
          ),
          _tile('Add group', 'Create a label', _addGroup),
          _tile('Delete group', 'By id', _deleteGroup),
          _tile('Find duplicates', 'Same name, number or email', _duplicates),
          _tile('Merge contacts', 'Join contacts by id', _merge),
          _tile('Split contact', 'Undo a merge', _split),
          _tile(
            'Export all as vCard',
            'Shows the .vcf text',
            () => _run(
              'vCard',
              () => _telephony.exportContactsAsVCard(limit: 50),
            ),
          ),
          _tile('Import vCard', 'Paste .vcf text', _importVCard),
          _tile(
            'New contact screen',
            "Android's own editor",
            () => _telephony.openNewContactScreen(name: 'New contact'),
          ),
        ]),
        _section('Call log', [
          _tile(
            'Statistics',
            'Calls per number',
            () => _run('Call log statistics', () {
              final s = _telephony.getCallLogStats(limit: 500).take(15);
              return s
                  .map(
                    (e) =>
                        '${e.name.isEmpty ? e.number : e.name}: ${e.total} calls, ${e.missed} missed, ${e.totalDuration.inMinutes} min',
                  )
                  .join('\n');
            }),
          ),
          _tile(
            'Grouped',
            'Consecutive calls joined',
            () => _run(
              'Grouped call log',
              () => _telephony
                  .getGroupedCallLog(limit: 60)
                  .take(20)
                  .map(
                    (g) =>
                        '${g.name.isEmpty ? g.number : g.name} (${g.entries.length}) ${g.latest.geocodedLocation}',
                  )
                  .join('\n'),
            ),
          ),
          _tile('Add test entry', 'Writes an outgoing call', _addLogEntry),
        ]),
        _section('SMS and MMS', [
          _tile(
            'Default SMS app',
            'Needed to delete or mark read',
            () => _run('Default SMS app', () {
              final held = _telephony.isDefaultSmsApp;
              if (!held) _telephony.requestDefaultSmsApp();
              return held
                  ? 'This app is the default SMS app.'
                  : 'Current: ${_telephony.defaultSmsPackage}. Asked to change.';
            }),
          ),
          _tile(
            'Conversations',
            'Threads, newest first',
            () => _run(
              'Conversations',
              () => _telephony
                  .getSmsThreads()
                  .take(20)
                  .map(
                    (t) =>
                        '${t.threadId}  ${t.address} (${t.messageCount}, ${t.unreadCount} unread)\n   ${t.snippet}',
                  )
                  .join('\n'),
            ),
          ),
          _tile(
            'Mark conversation read',
            'Default SMS app only',
            () => _smsThreadAction(
              'Mark conversation read',
              _telephony.markSmsThreadRead,
            ),
          ),
          _tile(
            'Delete conversation',
            'Default SMS app only',
            () => _smsThreadAction(
              'Delete conversation',
              _telephony.deleteSmsThread,
            ),
          ),
          _tile(
            'MMS',
            'Latest multimedia messages',
            () => _run('MMS', () {
              final list = _telephony.getMmsMessages(limit: 15);
              if (list.isEmpty) return 'No MMS.';
              return list
                  .map(
                    (m) =>
                        '${m.addresses.join(', ')}: ${m.text} [${m.parts.where((p) => !p.isText).map((p) => p.contentType).join(', ')}]',
                  )
                  .join('\n');
            }),
          ),
        ]),
        _section('Calls', [
          _tile('Video call', 'Places a call with video', _videoCall),
          for (final c in CallForwardingCondition.values)
            _tile(
              'Forward: ${c.name}',
              'Set a number, or leave empty to ask',
              () => _forward(c),
            ),
          _tile(
            'Cancel all forwarding',
            'Sends ##002#',
            () =>
                _run('Cancel forwarding', () => _telephony.sendUssd('##002#')),
          ),
          _tile(
            'Call waiting: ask',
            '*#43#',
            () => _run('Call waiting', _telephony.queryCallWaiting),
          ),
          _tile(
            'Call waiting: on',
            '*43#',
            () => _run('Call waiting', () => _telephony.setCallWaiting(true)),
          ),
          _tile(
            'Call waiting: off',
            '#43#',
            () => _run('Call waiting', () => _telephony.setCallWaiting(false)),
          ),
        ]),
        _section('Device and network', [
          _tile(
            'Phone numbers',
            'Of each SIM',
            () => _run('Phone numbers', () {
              final n = _telephony.getPhoneNumbers();
              return n.isEmpty ? 'None.' : n.join('\n');
            }),
          ),
          _tile(
            'Signal and cells',
            'dBm and nearby towers',
            () => _run('Signal and cells', () {
              final cells = _telephony.getCellInfo();
              return 'Serving signal: ${_telephony.signalDbm ?? 'unknown'} dBm\n${cells.join('\n')}';
            }),
          ),
          _tile(
            'Mobile data',
            'On/off, roaming, state',
            () => _run(
              'Mobile data',
              () =>
                  'Enabled: ${_telephony.isMobileDataEnabled}\nRoaming allowed: ${_telephony.isDataRoamingAllowed}\nState: ${_telephony.dataConnectionState.name}',
            ),
          ),
          _tile(
            'eSIM',
            'Support and profiles',
            () => _run('eSIM', () {
              final e = _telephony.getEsimInfo();
              return 'Supported: ${e.isSupported}\nEID: ${e.eid.isEmpty ? '(needs carrier privileges)' : e.eid}\nProfiles: ${e.profiles.join(', ')}';
            }),
          ),
        ]),
        const SizedBox(height: 24),
      ],
    ),
  );
}
