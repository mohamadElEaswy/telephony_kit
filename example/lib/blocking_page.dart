import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// Call screening rules, the app and system block lists, and recently
/// screened calls.
class BlockingPage extends StatefulWidget {
  const BlockingPage({super.key});

  @override
  State<BlockingPage> createState() => _BlockingPageState();
}

class _BlockingPageState extends State<BlockingPage> {
  final _screened = <ScreenedCall>[];
  StreamSubscription<ScreenedCall>? _sub;

  CallScreeningSettings get _rules => _telephony.screening;

  @override
  void initState() {
    super.initState();
    _sub = _telephony.screenedCalls.listen(
      (call) => setState(() => _screened.insert(0, call)),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _addNumber({required bool prefix, required bool system}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prefix ? 'Block numbers starting with' : 'Block number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty) return;
    try {
      if (system) {
        _telephony.blockNumber(value);
      } else if (prefix) {
        _rules.blockPrefix(value);
      } else {
        _rules.blockNumber(value);
      }
    } on TelephonyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    setState(() {});
  }

  Widget _actionPicker(
    String title,
    ScreeningAction value,
    ValueChanged<ScreeningAction> onChanged,
  ) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<ScreeningAction>(
        value: value,
        onChanged: (v) {
          if (v != null) setState(() => onChanged(v));
        },
        items: [
          for (final a in ScreeningAction.values)
            DropdownMenuItem(value: a, child: Text(a.name)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<BlockedNumber> system = const [];
    String? systemError;
    try {
      if (_telephony.canBlockNumbers) {
        system = _telephony.getBlockedNumbers();
      } else {
        systemError = 'Only the default phone app can use the system list.';
      }
    } on TelephonyException catch (e) {
      systemError = e.message;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Blocking')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Call screening'),
            subtitle: const Text('Runs even when the app is closed'),
            value: _rules.enabled,
            onChanged: (v) => setState(() => _rules.enabled = v),
          ),
          _actionPicker(
            'Blocked numbers',
            _rules.blockedAction,
            (v) => _rules.blockedAction = v,
          ),
          _actionPicker(
            'Callers not in contacts',
            _rules.unknownCallerAction,
            (v) => _rules.unknownCallerAction = v,
          ),
          _actionPicker(
            'Hidden numbers',
            _rules.hiddenNumberAction,
            (v) => _rules.hiddenNumberAction = v,
          ),
          if (!_telephony.isDefaultDialer &&
              !_telephony.isCallScreeningRoleHeld)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text(
                'Screening needs the default phone app or the '
                'call screening role',
              ),
              trailing: TextButton(
                onPressed: _telephony.requestCallScreeningRole,
                child: const Text('Request'),
              ),
            ),
          const Divider(),
          _header(
            'App block list',
            () => _addNumber(prefix: false, system: false),
          ),
          for (final n in _rules.blockedNumbers)
            ListTile(
              title: Text(n),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _rules.unblockNumber(n)),
              ),
            ),
          _header(
            'Blocked prefixes',
            () => _addNumber(prefix: true, system: false),
          ),
          for (final p in _rules.blockedPrefixes)
            ListTile(
              title: Text('$p…'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => _rules.unblockPrefix(p)),
              ),
            ),
          const Divider(),
          _header(
            'System block list',
            systemError == null
                ? () => _addNumber(prefix: false, system: true)
                : null,
          ),
          if (systemError != null)
            ListTile(subtitle: Text(systemError))
          else
            for (final b in system)
              ListTile(
                title: Text(b.number),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      setState(() => _telephony.unblockNumber(b.number)),
                ),
              ),
          const Divider(),
          const ListTile(title: Text('Screened while open')),
          for (final c in _screened)
            ListTile(
              leading: Icon(
                c.action == ScreeningAction.allow ? Icons.call : Icons.block,
              ),
              title: Text(c.number.isEmpty ? 'Hidden number' : c.number),
              subtitle: Text('${c.action.name} · ${c.reason}'),
            ),
        ],
      ),
    );
  }

  Widget _header(String title, VoidCallback? onAdd) => ListTile(
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    trailing: onAdd == null
        ? null
        : IconButton(icon: const Icon(Icons.add), onPressed: onAdd),
  );
}
