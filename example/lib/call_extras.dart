import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

/// Small badges for what the call carries: caller verification (STIR/SHAKEN),
/// video, Wi-Fi calling and HD voice.
class CallBadges extends StatelessWidget {
  const CallBadges({super.key, required this.call});

  final PhoneCall call;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      switch (call.numberVerification) {
        NumberVerification.passed => const Chip(
          avatar: Icon(Icons.verified, size: 16, color: Colors.green),
          label: Text('Verified number'),
        ),
        NumberVerification.failed => const Chip(
          avatar: Icon(Icons.warning_amber, size: 16, color: Colors.red),
          label: Text('Possible spoof'),
        ),
        _ => const SizedBox.shrink(),
      },
      if (call.isVideo) const Chip(label: Text('Video')),
      if (call.isWifiCall) const Chip(label: Text('Wi-Fi calling')),
      if (call.isHdAudio) const Chip(label: Text('HD voice')),
    ];
    return Wrap(spacing: 8, alignment: WrapAlignment.center, children: badges);
  }
}

/// Real-time text for a call: ask for it, answer the other side's request,
/// type, and read what they type.
class RttPanel extends StatefulWidget {
  const RttPanel({super.key, required this.call, required this.onChanged});

  final PhoneCall call;
  final VoidCallback onChanged;

  @override
  State<RttPanel> createState() => _RttPanelState();
}

class _RttPanelState extends State<RttPanel> {
  final _input = TextEditingController();
  final _received = StringBuffer();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final text = widget.call.readRttText();
      if (text.isNotEmpty) setState(() => _received.write(text));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    if (call.pendingRttRequestId != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Real-time text request'),
          TextButton(
            onPressed: () {
              call.respondToRtt(accept: true);
              widget.onChanged();
            },
            child: const Text('Accept'),
          ),
          TextButton(
            onPressed: () {
              call.respondToRtt(accept: false);
              widget.onChanged();
            },
            child: const Text('Decline'),
          ),
        ],
      );
    }
    if (!call.isRttActive) {
      return TextButton.icon(
        icon: const Icon(Icons.keyboard),
        label: const Text('Start real-time text'),
        onPressed: () {
          call.requestRtt();
          widget.onChanged();
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_received.isNotEmpty) Text('They: $_received'),
          TextField(
            controller: _input,
            decoration: InputDecoration(
              hintText: 'Type to send',
              suffixIcon: IconButton(
                tooltip: 'Stop real-time text',
                icon: const Icon(Icons.close),
                onPressed: () {
                  call.stopRtt();
                  widget.onChanged();
                },
              ),
            ),
            onSubmitted: (text) {
              call.sendRttText('$text\n');
              _input.clear();
            },
          ),
        ],
      ),
    );
  }
}
