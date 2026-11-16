import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// Mute, audio route, keypad, hold, swap and merge buttons for a live call.
class InCallControls extends StatelessWidget {
  const InCallControls({
    super.key,
    required this.call,
    required this.allCalls,
    required this.onChanged,
  });

  final PhoneCall call;
  final List<PhoneCall> allCalls;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final muted = _telephony.isMuted;
    final route = _telephony.audioRoute;
    final held = call.state == CallState.holding;
    final hasOtherCall = allCalls.any(
      (c) => c.id != call.id && c.parent == null,
    );

    return Wrap(
      spacing: 24,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _Toggle(
          icon: Icons.mic_off,
          label: 'Mute',
          on: muted,
          onTap: () {
            _telephony.setMuted(!muted);
            onChanged();
          },
        ),
        _Toggle(
          icon: _routeIcon(route),
          label: _routeLabel(route),
          on: route != AudioRoute.earpiece,
          onTap: () async {
            await showModalBottomSheet<void>(
              context: context,
              builder: (_) => const _AudioRouteSheet(),
            );
            onChanged();
          },
        ),
        _Toggle(
          icon: Icons.dialpad,
          label: 'Keypad',
          on: false,
          onTap: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => _DtmfSheet(call: call),
          ),
        ),
        _Toggle(
          icon: Icons.pause,
          label: held ? 'Resume' : 'Hold',
          on: held,
          onTap: () {
            held ? call.unhold() : call.hold();
            onChanged();
          },
        ),
        if (hasOtherCall)
          _Toggle(
            icon: Icons.swap_calls,
            label: 'Swap',
            on: false,
            onTap: () {
              _telephony.swapCalls();
              onChanged();
            },
          ),
        if (hasOtherCall && call.canMerge)
          _Toggle(
            icon: Icons.call_merge,
            label: 'Merge',
            on: false,
            onTap: () {
              call.merge();
              onChanged();
            },
          ),
        if (call.isConference && call.canSwap)
          _Toggle(
            icon: Icons.swap_horiz,
            label: 'Switch',
            on: false,
            onTap: () {
              call.swap();
              onChanged();
            },
          ),
      ],
    );
  }

  static IconData _routeIcon(AudioRoute route) => switch (route) {
    AudioRoute.speaker => Icons.volume_up,
    AudioRoute.bluetooth => Icons.bluetooth_audio,
    AudioRoute.wiredHeadset => Icons.headset,
    _ => Icons.phone_in_talk,
  };

  static String _routeLabel(AudioRoute route) => switch (route) {
    AudioRoute.speaker => 'Speaker',
    AudioRoute.bluetooth => 'Bluetooth',
    AudioRoute.wiredHeadset => 'Headset',
    _ => 'Phone',
  };
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton.filledTonal(
        isSelected: on,
        iconSize: 28,
        onPressed: onTap,
        icon: Icon(icon),
      ),
      Text(label),
    ],
  );
}

class _AudioRouteSheet extends StatelessWidget {
  const _AudioRouteSheet();

  @override
  Widget build(BuildContext context) {
    final current = _telephony.audioRoute;
    final routes = _telephony.supportedAudioRoutes;
    final devices = _telephony.bluetoothDevices;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final route in routes)
            if (route != AudioRoute.bluetooth || devices.isEmpty)
              ListTile(
                leading: Icon(InCallControls._routeIcon(route)),
                title: Text(InCallControls._routeLabel(route)),
                trailing: route == current ? const Icon(Icons.check) : null,
                onTap: () {
                  _telephony.setAudioRoute(route);
                  Navigator.pop(context);
                },
              ),
          for (final device in devices)
            ListTile(
              leading: const Icon(Icons.bluetooth_audio),
              title: Text(device.name.isEmpty ? device.address : device.name),
              trailing: device.isActive && current == AudioRoute.bluetooth
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                _telephony.selectBluetoothDevice(device.address);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _DtmfSheet extends StatefulWidget {
  const _DtmfSheet({required this.call});

  final PhoneCall call;

  @override
  State<_DtmfSheet> createState() => _DtmfSheetState();
}

class _DtmfSheetState extends State<_DtmfSheet> {
  String _typed = '';

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _typed,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            childAspectRatio: 2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final key in keys)
                GestureDetector(
                  onTapDown: (_) => widget.call.playDtmf(key),
                  onTapUp: (_) => widget.call.stopDtmf(),
                  onTapCancel: () => widget.call.stopDtmf(),
                  onTap: () => setState(() => _typed += key),
                  child: Center(
                    child: Text(key, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
