import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// SMS search and a compose button.
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  String _query = '';

  Future<void> _compose() async {
    final to = TextEditingController();
    final body = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: to,
              decoration: const InputDecoration(labelText: 'To'),
              keyboardType: TextInputType.phone,
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
    if (send != true || to.text.trim().isEmpty || body.text.isEmpty) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final parts = await _telephony.sendSms(to.text.trim(), body.text);
      messenger.showSnackBar(SnackBar(content: Text('Sent ($parts part)')));
      setState(() {});
    } on TelephonyException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
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
        final messages = _telephony.searchSms(query: _query, limit: 200);
        body = ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final m = messages[i];
            return ListTile(
              leading: Icon(
                m.type == SmsType.sent ? Icons.call_made : Icons.call_received,
              ),
              title: Text(m.address),
              subtitle: Text(
                m.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                '${m.date.toLocal()}'.split(' ').first,
                style: TextStyle(
                  fontWeight: m.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
            );
          },
        );
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
