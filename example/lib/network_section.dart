import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// Live signal and network type, plus voicemail and USSD tools.
class NetworkSection extends StatefulWidget {
  const NetworkSection({super.key});

  @override
  State<NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends State<NetworkSection> {
  StreamSubscription<NetworkEvent>? _sub;
  int _signal = -1;
  NetworkGeneration _generation = NetworkGeneration.unknown;
  ServiceStatus _service = ServiceStatus.unknown;
  final _ussd = TextEditingController(text: '*100#');
  String _ussdReply = '';
  bool _ussdBusy = false;

  @override
  void initState() {
    super.initState();
    try {
      _signal = _telephony.signalLevel;
      _generation = _telephony.networkGeneration;
    } on TelephonyException {
      // Leave unknown.
    }
    _sub = _telephony.networkEvents.listen((event) {
      setState(() {
        switch (event) {
          case SignalStrengthChanged(:final level):
            _signal = level;
          case ServiceStatusChanged(:final status):
            _service = status;
          case NetworkTypeChanged():
            _generation = event.generation;
          case DeviceCallStateChanged():
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ussd.dispose();
    super.dispose();
  }

  Future<void> _sendUssd() async {
    setState(() {
      _ussdBusy = true;
      _ussdReply = '';
    });
    try {
      final reply = await _telephony.sendUssd(_ussd.text.trim());
      if (mounted) setState(() => _ussdReply = reply);
    } on TelephonyException catch (e) {
      if (mounted) setState(() => _ussdReply = e.message);
    } finally {
      if (mounted) setState(() => _ussdBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bars = _signal < 0 ? '-' : '$_signal / 4';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: Icon(_signalIcon(_signal)),
          title: const Text('Signal (live)'),
          trailing: Text(bars),
        ),
        ListTile(
          leading: const Icon(Icons.network_cell),
          title: const Text('Network (live)'),
          trailing: Text(
            [
              _generation.label,
              if (_service != ServiceStatus.unknown) _service.name,
            ].where((s) => s.isNotEmpty).join(' · '),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.voicemail),
          title: const Text('Call voicemail'),
          onTap: () {
            try {
              _telephony.callVoicemail();
            } on TelephonyException catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(e.message)));
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ussd,
                  decoration: const InputDecoration(labelText: 'USSD code'),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _ussdBusy ? null : _sendUssd,
                child: const Text('Send'),
              ),
            ],
          ),
        ),
        if (_ussdReply.isNotEmpty)
          Padding(padding: const EdgeInsets.all(16), child: Text(_ussdReply)),
      ],
    );
  }

  IconData _signalIcon(int level) => switch (level) {
    0 => Icons.signal_cellular_0_bar,
    1 || 2 => Icons.signal_cellular_alt_1_bar,
    3 => Icons.signal_cellular_alt_2_bar,
    4 => Icons.signal_cellular_alt,
    _ => Icons.signal_cellular_off,
  };
}
