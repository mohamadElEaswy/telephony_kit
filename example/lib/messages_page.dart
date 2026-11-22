import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// Conversations, search, compose, and becoming the default SMS app.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.request});

  /// An sms: link or a tapped notification that opened the app.
  final SmsRequest? request;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with WidgetsBindingObserver {
  String _query = '';
  StreamSubscription<void>? _changes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_telephony.hasPermission(TelephonyPermission.readSms)) {
      _changes = _telephony.smsChanges.listen((_) {
        if (mounted) setState(() {});
      });
    }
    final request = widget.request;
    if (request != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (request.fromNotification && request.recipients.isNotEmpty) {
          _open(request.recipients.first);
        } else {
          _compose(to: request.recipients.join(', '), text: request.body);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changes?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the "default SMS app" prompt.
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void _open(String address) => Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ConversationPage(address: address)),
  );

  Future<void> _compose({String to = '', String text = ''}) async {
    final toField = TextEditingController(text: to);
    final body = TextEditingController(text: text);
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: toField,
              decoration: const InputDecoration(labelText: 'To'),
              keyboardType: TextInputType.phone,
              inputFormatters: [PhoneNumberInputFormatter()],
            ),
            TextField(
              controller: body,
              decoration: const InputDecoration(labelText: 'Message'),
              maxLines: 4,
              minLines: 1,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (send != true || toField.text.trim().isEmpty || body.text.isEmpty) {
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    for (final to in toField.text.split(',')) {
      if (to.trim().isEmpty) continue;
      try {
        await _telephony.sendSms(to.trim(), body.text);
      } on TelephonyException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    if (mounted) setState(() {});
  }

  Widget _defaultAppBanner() {
    if (_telephony.isDefaultSmsApp) return const SizedBox.shrink();
    return MaterialBanner(
      content: const Text(
        'Make this the default SMS app to receive, delete and mark messages.',
      ),
      actions: [
        TextButton(
          onPressed: _telephony.requestDefaultSmsApp,
          child: const Text('Set default'),
        ),
      ],
    );
  }

  Widget _threads() {
    final threads = _telephony.getSmsThreads(messageLimit: 500);
    if (threads.isEmpty) return const Center(child: Text('No messages.'));
    return ListView.builder(
      itemCount: threads.length,
      itemBuilder: (context, i) {
        final t = threads[i];
        final unread = t.unreadCount > 0;
        return ListTile(
          leading: CircleAvatar(child: Text('${t.messageCount}')),
          title: Text(
            _telephony.lookupNumberName(t.address),
            style: TextStyle(fontWeight: unread ? FontWeight.bold : null),
          ),
          subtitle: Text(
            t.snippet,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(_telephony.timeFormatter.relative(t.lastDate)),
          onTap: () => _open(t.address),
        );
      },
    );
  }

  Widget _search() {
    final messages = _telephony.searchSms(query: _query, limit: 200);
    if (messages.isEmpty) return const Center(child: Text('No messages.'));
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final m = messages[i];
        return ListTile(
          leading: Icon(
            m.type == SmsType.sent ? Icons.call_made : Icons.call_received,
          ),
          title: Text(m.address),
          subtitle: Text(m.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => _open(m.address),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!_telephony.hasPermission(TelephonyPermission.readSms)) {
      body = const Center(
        child: Text('Grant the SMS permission to read messages.'),
      );
    } else {
      try {
        body = _query.isEmpty ? _threads() : _search();
      } on TelephonyException catch (e) {
        body = Center(child: Text(e.message));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: FloatingActionButton(
        onPressed: _compose,
        child: const Icon(Icons.edit),
      ),
      body: Column(
        children: [
          _defaultAppBanner(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              hintText: 'Search messages',
              leading: const Icon(Icons.search),
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// One conversation with a reply box. Opening it marks it read and clears
/// its notification.
class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.address});

  final String address;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _reply = TextEditingController();
  StreamSubscription<void>? _changes;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _changes = _telephony.smsChanges.listen((_) {
      if (mounted) setState(_markRead);
    });
    _markRead();
  }

  @override
  void dispose() {
    _changes?.cancel();
    _reply.dispose();
    super.dispose();
  }

  List<SmsMessage> _messages() {
    final all = _telephony.searchSms(query: widget.address, limit: 300);
    return [
      for (final m in all)
        if (m.address == widget.address ||
            _telephony.isSamePhoneNumber(m.address, widget.address))
          m,
    ].reversed.toList();
  }

  void _markRead() {
    _telephony.clearSmsNotification(widget.address);
    if (!_telephony.isDefaultSmsApp) return;
    final threads = {
      for (final m in _messages())
        if (!m.isRead) m.threadId,
    };
    for (final id in threads) {
      _telephony.markSmsThreadRead(id);
    }
  }

  Future<void> _send() async {
    final text = _reply.text;
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _telephony.sendSms(widget.address, text);
      _reply.clear();
    } on TelephonyException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(_telephony.lookupNumberName(widget.address))),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[messages.length - 1 - i];
                final mine = m.type != SmsType.inbox;
                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: mine
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.body),
                        const SizedBox(height: 4),
                        Text(
                          [
                            _telephony.timeFormatter.dateTime(m.date),
                            if (m.type == SmsType.failed) 'Not sent',
                            if (m.type == SmsType.outbox) 'Sending…',
                          ].join(' · '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reply,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on TelephonyKit {
  /// The contact name for [address], or the number formatted.
  String lookupNumberName(String address) {
    try {
      final name = lookupNumber(address)?.displayName ?? '';
      if (name.isNotEmpty) return name;
      return formatPhoneNumber(address);
    } on TelephonyException {
      return address;
    }
  }
}
