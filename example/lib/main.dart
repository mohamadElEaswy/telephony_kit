import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony_kit/telephony_kit.dart';

import 'blocking_page.dart';
import 'call_extras.dart';
import 'call_history_page.dart';
import 'contacts_page.dart';
import 'in_call_controls.dart';
import 'messages_page.dart';
import 'network_section.dart';
import 'tools_page.dart';

void main() {
  runApp(const DialerApp());
}

final telephony = TelephonyKit.instance;

class DialerApp extends StatelessWidget {
  const DialerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'telephony_kit dialer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;
  bool _isDefaultDialer = false;
  StreamSubscription<CallEvent>? _subscription;
  List<PhoneCall> _calls = const [];

  /// Numbers from dial intents, shown on the keypad.
  final _dialRequests = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
    _refresh();
    _takeDialNumber();
    _takeCallScreenRequest();
    _setUpCallBubble();
    _subscription = telephony.callEvents.listen((event) {
      if (event is PostDialWait && mounted) _askPostDial(event);
      // Answered from the notification, or Open tapped on the bubble.
      if (event is CallScreenRequested) _showCallScreen();
      if (event is CallDisconnected && event.cause.isFailure && mounted) {
        // For example "Busy" or "Call failed".
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(event.cause.displayText)));
      }
      _refresh();
    });
  }

  /// Asks whether to send the digits after a wait (;) in the dialed number.
  Future<void> _askPostDial(PostDialWait event) async {
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send remaining digits?'),
        content: Text(event.remaining),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    telephony.call(event.callId).continuePostDial(send ?? false);
  }

  /// The in-call screen replaces this page's body whenever a call is live,
  /// so showing it means closing whatever is pushed on top.
  void _showCallScreen() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _refresh();
  }

  /// The app was opened (or brought back) from the call notification or the
  /// call bubble.
  void _takeCallScreenRequest() {
    if (telephony.takeCallScreenRequest() != null) _showCallScreen();
  }

  /// The floating call bubble is switched on in the Device tab. Its
  /// labels are English by default; pass translations here.
  void _setUpCallBubble() {
    telephony.callBubble.labels = const CallBubbleLabels();
  }

  /// Shows the number of a dial intent (a tapped tel: link) on the keypad.
  void _takeDialNumber() {
    String? number;
    try {
      number = telephony.takeDialNumber();
    } on TelephonyException {
      number = null;
    }
    if (number == null || !mounted) return;
    setState(() => _tab = 0);
    _dialRequests.value = number;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _dialRequests.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _takeDialNumber();
      _takeCallScreenRequest();
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.phone,
      Permission.contacts,
      Permission.notification,
      Permission.sms,
      Permission.location,
      Permission.bluetoothConnect,
    ].request();
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    final calls = telephony.calls.where((c) => c.state.isLive).toList();
    if (_calls.isEmpty && calls.isNotEmpty) {
      // The in-call screen replaces this page's body, so close pages,
      // dialogs and sheets opened on top of it (Messages, Blocking).
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    setState(() {
      _isDefaultDialer = telephony.isDefaultDialer;
      _calls = calls;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calls inside a conference are shown through the conference itself.
    final topLevel = _calls.where((c) => c.parent == null).toList();
    if (topLevel.isNotEmpty) {
      // Show the ringing call first, then the active one, then the newest.
      final call = topLevel.firstWhere(
        (c) => c.state == CallState.ringing,
        orElse: () => topLevel.firstWhere(
          (c) => c.state == CallState.active,
          orElse: () => topLevel.last,
        ),
      );
      return InCallScreen(
        key: ValueKey(call.id),
        call: call,
        allCalls: _calls,
        onChanged: _refresh,
      );
    }
    final pages = [
      KeypadPage(dialRequests: _dialRequests),
      const RecentsPage(),
      const ContactsPage(),
      const DevicePage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone'),
        actions: [
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(Icons.sms_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MessagesPage()),
            ),
          ),
          IconButton(
            tooltip: 'More tools',
            icon: const Icon(Icons.build_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const ToolsPage())),
          ),
          IconButton(
            tooltip: 'Blocking',
            icon: const Icon(Icons.block),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BlockingPage()),
            ),
          ),
        ],
        bottom: _isDefaultDialer
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: _DefaultDialerBanner(
                  onRequest: () {
                    telephony.requestDefaultDialer();
                  },
                ),
              ),
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dialpad), label: 'Keypad'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Recents'),
          NavigationDestination(icon: Icon(Icons.contacts), label: 'Contacts'),
          NavigationDestination(
            icon: Icon(Icons.sim_card_outlined),
            label: 'Device',
          ),
        ],
      ),
    );
  }
}

class _DefaultDialerBanner extends StatelessWidget {
  const _DefaultDialerBanner({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('Set as default phone app to handle calls.'),
          ),
          FilledButton.tonal(
            onPressed: onRequest,
            child: const Text('Set default'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Keypad
// -----------------------------------------------------------------------------

class KeypadPage extends StatefulWidget {
  const KeypadPage({super.key, required this.dialRequests});

  /// Numbers to show, from dial intents.
  final ValueNotifier<String?> dialRequests;

  @override
  State<KeypadPage> createState() => _KeypadPageState();
}

class _KeypadPageState extends State<KeypadPage> {
  String _number = '';
  List<PhoneAccount> _accounts = const [];
  String? _account;

  @override
  void initState() {
    super.initState();
    try {
      _accounts = telephony.getPhoneAccountDetails();
    } on TelephonyException {
      _accounts = const [];
    }
    _number = widget.dialRequests.value ?? '';
    widget.dialRequests.value = null;
    widget.dialRequests.addListener(_showRequested);
  }

  @override
  void dispose() {
    widget.dialRequests.removeListener(_showRequested);
    super.dispose();
  }

  void _showRequested() {
    final number = widget.dialRequests.value;
    if (number == null) return;
    widget.dialRequests.value = null;
    setState(() => _number = number);
  }

  bool _isEmergency(String number) {
    if (number.length < 2) return false;
    try {
      return telephony.isEmergencyNumber(number);
    } on TelephonyException {
      return false;
    }
  }

  void _call() {
    if (_number.isEmpty) return;
    if (!telephony.hasPermission(TelephonyPermission.callPhone)) {
      telephony.openDialer(_number);
      return;
    }
    try {
      telephony.placeCall(_number, phoneAccountId: _account);
    } on TelephonyException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_number, style: Theme.of(context).textTheme.displaySmall),
              if (_isEmergency(_number))
                Text(
                  'Emergency number',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        if (_accounts.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String?>(
              segments: [
                const ButtonSegment(value: null, label: Text('Ask')),
                for (var i = 0; i < _accounts.length; i++)
                  ButtonSegment(
                    value: _accounts[i].id,
                    label: Text(
                      _accounts[i].slotIndex >= 0
                          ? 'SIM ${_accounts[i].slotIndex + 1}'
                          : 'SIM ${i + 1}',
                    ),
                  ),
              ],
              selected: {_account},
              onSelectionChanged: (s) => setState(() => _account = s.first),
            ),
          ),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          childAspectRatio: 1.6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final key in keys)
              TextButton(
                onPressed: () => setState(() => _number += key),
                // Long press: * adds a pause (,) and # a wait (;).
                onLongPress: switch (key) {
                  '*' => () => setState(() => _number += ','),
                  '#' => () => setState(() => _number += ';'),
                  _ => null,
                },
                child: Text(key, style: const TextStyle(fontSize: 28)),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 56),
              const SizedBox(width: 24),
              FloatingActionButton.large(
                heroTag: 'call',
                backgroundColor: Colors.green,
                onPressed: _call,
                child: const Icon(Icons.call, color: Colors.white),
              ),
              const SizedBox(width: 24),
              IconButton(
                iconSize: 32,
                onPressed: _number.isEmpty
                    ? null
                    : () => setState(
                        () =>
                            _number = _number.substring(0, _number.length - 1),
                      ),
                icon: const Icon(Icons.backspace_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Recents
// -----------------------------------------------------------------------------

class RecentsPage extends StatefulWidget {
  const RecentsPage({super.key});

  @override
  State<RecentsPage> createState() => _RecentsPageState();
}

class _RecentsPageState extends State<RecentsPage> {
  String _query = '';
  bool _missedOnly = false;

  @override
  Widget build(BuildContext context) {
    if (!telephony.hasPermission(TelephonyPermission.readCallLog)) {
      return const _Message(
        'Grant the call log permission to see recent calls.',
      );
    }
    Widget list;
    try {
      final entries = telephony.searchCallLog(
        query: _query,
        types: _missedOnly ? {CallLogType.missed} : null,
        limit: 200,
      );
      final times = callTimes;
      final days = groupByDay(entries, (e) => e.date, formatter: times);
      list = entries.isEmpty
          ? const _Message('No calls found.')
          : ListView(
              children: [
                for (final day in days) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      times.day(day.key),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  for (final entry in day.value) _tile(entry, times),
                ],
              ],
            );
    } on TelephonyException catch (e) {
      list = _Message(e.message);
    }
    return Column(
      children: [
        _SearchField(
          hint: 'Search calls by name or number',
          onChanged: (q) => setState(() => _query = q),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              FilterChip(
                label: const Text('Missed'),
                selected: _missedOnly,
                onSelected: (v) => setState(() => _missedOnly = v),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _run(() => telephony.markMissedCallsRead()),
                child: const Text('Mark missed as seen'),
              ),
            ],
          ),
        ),
        Expanded(child: list),
      ],
    );
  }

  void _run(void Function() action) {
    try {
      action();
    } on TelephonyException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
    setState(() {});
  }

  Future<void> _menu(CallLogEntry entry) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete this entry'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Delete all calls with this number'),
              onTap: () => Navigator.pop(context, 'delete_all'),
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: const Text('Block number'),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'delete':
        _run(() => telephony.deleteCallLogEntries([entry.id]));
      case 'delete_all':
        _run(() => telephony.deleteCallLogForNumber(entry.number));
      case 'block':
        _run(() {
          if (telephony.canBlockNumbers) {
            telephony.blockNumber(entry.number);
          } else {
            telephony.screening.blockNumber(entry.number);
          }
        });
    }
  }

  Widget _tile(CallLogEntry entry, CallTimeFormatter times) => ListTile(
    onTap: () async {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CallDetailsPage(entryId: entry.id, fallback: entry),
        ),
      );
      if (mounted) setState(() {});
    },
    onLongPress: () => _menu(entry),
    leading: Icon(
      callTypeIcon(entry.type),
      color: callTypeColor(context, entry.type),
    ),
    title: Text(
      entry.displayName.isEmpty ? 'Unknown' : entry.displayName,
      style: entry.isNew ? const TextStyle(fontWeight: FontWeight.bold) : null,
    ),
    subtitle: Text(
      [
        times.relative(entry.date, ago: true),
        if (entry.wasConnected) times.duration(entry.duration),
        if (entry.geocodedLocation.isNotEmpty) entry.geocodedLocation,
      ].join(' · '),
    ),
    trailing: IconButton(
      icon: const Icon(Icons.call),
      onPressed: () => telephony.openDialer(entry.number),
    ),
  );
}

// -----------------------------------------------------------------------------
// Contacts
// -----------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: SearchBar(
      hintText: hint,
      leading: const Icon(Icons.search),
      onChanged: onChanged,
    ),
  );
}

// -----------------------------------------------------------------------------
// Device
// -----------------------------------------------------------------------------

class DevicePage extends StatelessWidget {
  const DevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final NetworkInfo info;
    try {
      info = telephony.getNetworkInfo();
    } on TelephonyException catch (e) {
      return _Message(e.message);
    }
    List<SimCard> sims = const [];
    if (telephony.hasPermission(TelephonyPermission.readPhoneState)) {
      try {
        sims = telephony.getSimCards();
      } on TelephonyException {
        sims = const [];
      }
    }
    return ListView(
      children: [
        _row('Network', info.networkOperatorName),
        _row('Network country', info.networkCountryIso),
        _row('SIM operator', info.simOperatorName),
        _row('SIM state', info.simState.name),
        _row('Phone type', info.phoneType.name),
        _row('Roaming', info.isRoaming ? 'Yes' : 'No'),
        _row('Voice capable', info.isVoiceCapable ? 'Yes' : 'No'),
        _row('SIM slots', '${info.slotCount}'),
        _row('Time zone', _timeZone()),
        _row('Default dialer', telephony.defaultDialerPackage ?? '-'),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            title: const Text('Missed call notifications'),
            subtitle: const Text('Shown while this is the default dialer'),
            value: telephony.missedCallNotificationsEnabled,
            onChanged: (v) =>
                setState(() => telephony.missedCallNotificationsEnabled = v),
          ),
        ),
        const CallBubbleTile(),
        StatefulBuilder(
          builder: (context, setState) => SwitchListTile(
            title: const Text('Screen off near ear'),
            subtitle: const Text('Uses the proximity sensor during calls'),
            value: telephony.proximitySensorEnabled,
            onChanged: (v) =>
                setState(() => telephony.proximitySensorEnabled = v),
          ),
        ),
        const Divider(),
        const NetworkSection(),
        const Divider(),
        for (final sim in sims)
          ListTile(
            leading: const Icon(Icons.sim_card),
            title: Text(sim.displayName),
            subtitle: Text(
              'Slot ${sim.slotIndex + 1} · ${sim.carrierName}'
              '${sim.isEmbedded ? ' · eSIM' : ''}',
            ),
          ),
      ],
    );
  }

  String _timeZone() {
    try {
      final zone = telephony.timeZone;
      final format = telephony.uses24HourFormat ? '24h' : '12h';
      return '${zone.id} · ${callTimes.offsetLabel(DateTime.now())} · $format';
    } on TelephonyException {
      return '';
    }
  }

  Widget _row(String label, String value) => ListTile(
    dense: true,
    title: Text(label),
    trailing: Text(value.isEmpty ? '-' : value),
  );
}

// -----------------------------------------------------------------------------
// In-call screen
// -----------------------------------------------------------------------------

class InCallScreen extends StatefulWidget {
  const InCallScreen({
    super.key,
    required this.call,
    required this.allCalls,
    required this.onChanged,
  });

  final PhoneCall call;
  final List<PhoneCall> allCalls;
  final VoidCallback onChanged;

  @override
  State<InCallScreen> createState() => _InCallScreenState();
}

class _InCallScreenState extends State<InCallScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _elapsed() {
    final start = widget.call.connectedAt;
    if (start == null) return '';
    return callTimes.duration(DateTime.now().difference(start));
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final state = call.state;
    final ringing = state == CallState.ringing;
    final name = call.isConference
        ? 'Conference (${call.children.length})'
        : call.displayName.isNotEmpty
        ? call.displayName
        : (_contactName(call.number) ?? call.number);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Text(
              name.isEmpty ? 'Unknown' : name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(switch (state) {
              CallState.active => _elapsed(),
              CallState.ringing => 'Incoming call',
              CallState.dialing || CallState.connecting => 'Calling…',
              CallState.holding => 'On hold',
              CallState.selectPhoneAccount => 'Choose a SIM',
              CallState.disconnecting || CallState.disconnected => 'Call ended',
              _ => state.name,
            }, style: Theme.of(context).textTheme.titleMedium),
            if (call.phoneAccount case final account?
                when account.displayName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sim_card_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(account.displayName),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CallBadges(call: call),
            ),
            const Spacer(),
            if (state == CallState.active || call.pendingRttRequestId != null)
              RttPanel(call: call, onChanged: widget.onChanged),
            if (state == CallState.selectPhoneAccount)
              _SimPicker(call: call, onPicked: widget.onChanged)
            else if (!ringing)
              InCallControls(
                call: call,
                allCalls: widget.allCalls,
                onChanged: () {
                  widget.onChanged();
                  setState(() {});
                },
              ),
            if (ringing && call.isVideo)
              TextButton.icon(
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Answer with video'),
                onPressed: () {
                  call.answerWithVideo();
                  widget.onChanged();
                },
              ),
            if (ringing)
              TextButton.icon(
                icon: const Icon(Icons.message_outlined),
                label: const Text('Reply'),
                onPressed: () => _replyAndReject(call),
              ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (ringing)
                  FloatingActionButton.large(
                    heroTag: 'answer',
                    backgroundColor: Colors.green,
                    onPressed: () {
                      call.answer();
                      widget.onChanged();
                    },
                    child: const Icon(Icons.call, color: Colors.white),
                  ),
                FloatingActionButton.large(
                  heroTag: 'hangup',
                  backgroundColor: Colors.red,
                  onPressed: () {
                    ringing ? call.reject() : call.hangUp();
                    widget.onChanged();
                  },
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  /// Rejects the call and texts the caller a quick reply.
  Future<void> _replyAndReject(PhoneCall call) async {
    final canned = call.cannedTextResponses;
    final replies = canned.isNotEmpty ? canned : telephony.quickReplies;
    final message = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final reply in replies)
              ListTile(
                title: Text(reply),
                onTap: () => Navigator.pop(context, reply),
              ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Write your own…'),
              onTap: () async {
                final text = await _writeReply();
                if (context.mounted) Navigator.pop(context, text);
              },
            ),
          ],
        ),
      ),
    );
    if (message == null || message.isEmpty) return;
    call.reject(message: message);
    widget.onChanged();
  }

  Future<String?> _writeReply() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reply'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Send'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  String? _cachedName;
  bool _lookedUp = false;

  String? _contactName(String number) {
    if (_lookedUp) return _cachedName;
    _lookedUp = true;
    _cachedName = _lookup(number);
    return _cachedName;
  }

  String? _lookup(String number) {
    if (number.isEmpty ||
        !telephony.hasPermission(TelephonyPermission.readContacts)) {
      return null;
    }
    try {
      return telephony.lookupNumber(number)?.displayName;
    } on TelephonyException {
      return null;
    }
  }
}

/// Lets the user pick the SIM for an outgoing call on a multi SIM phone
/// with no default SIM.
class _SimPicker extends StatefulWidget {
  const _SimPicker({required this.call, required this.onPicked});

  final PhoneCall call;
  final VoidCallback onPicked;

  @override
  State<_SimPicker> createState() => _SimPickerState();
}

class _SimPickerState extends State<_SimPicker> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final accounts = widget.call.selectablePhoneAccounts;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Call with', style: Theme.of(context).textTheme.titleMedium),
        for (final account in accounts)
          ListTile(
            leading: const Icon(Icons.sim_card),
            title: Text(
              account.displayName.isEmpty ? account.id : account.displayName,
            ),
            onTap: () {
              widget.call.selectPhoneAccount(account.id, setDefault: _remember);
              widget.onPicked();
            },
          ),
        CheckboxListTile(
          value: _remember,
          title: const Text('Remember this choice'),
          onChanged: (v) => setState(() => _remember = v ?? false),
        ),
      ],
    );
  }
}

/// Turns the floating call bubble on and off, and walks the user through
/// the "display over other apps" permission.
class CallBubbleTile extends StatefulWidget {
  const CallBubbleTile({super.key});

  @override
  State<CallBubbleTile> createState() => _CallBubbleTileState();
}

class _CallBubbleTileState extends State<CallBubbleTile>
    with WidgetsBindingObserver {
  /// Set while the user is in Settings, to finish turning on when they
  /// come back with the permission.
  bool _waitingForPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_waitingForPermission) return;
    _waitingForPermission = false;
    final bubble = telephony.callBubble;
    if (bubble.hasPermission) bubble.enabled = true;
    setState(() {});
  }

  Future<void> _toggle(bool on) async {
    final bubble = telephony.callBubble;
    if (!on) {
      setState(() => bubble.enabled = false);
      return;
    }
    if (bubble.hasPermission) {
      setState(() => bubble.enabled = true);
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allow display over other apps'),
        content: const Text(
          'The call bubble floats over other apps during a call. '
          'Android asks you to allow this in Settings: turn on '
          '"Allow display over other apps", then come back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (go != true) return;
    _waitingForPermission = bubble.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final bubble = telephony.callBubble;
    final allowed = bubble.hasPermission;
    return SwitchListTile(
      title: const Text('Floating call bubble'),
      subtitle: Text(
        allowed
            ? 'Shows call controls over other apps during a call'
            : 'Needs permission to display over other apps',
      ),
      value: bubble.enabled && allowed,
      onChanged: _toggle,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
