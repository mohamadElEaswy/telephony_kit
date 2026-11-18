import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// Contacts tab: every contact in a list that loads 50 at a time as you
/// scroll, a search that waits for you to stop typing, and add, edit,
/// favorite and delete.
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  static const _pageSize = 50;

  final _scroll = ScrollController();
  final _contacts = <ContactDetails>[];
  String _query = '';
  int _nextOffset = 0;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadScheduled = false;
  bool _stale = false;
  String? _error;
  Timer? _debounce;
  StreamSubscription<void>? _changes;
  DateTime _ignoreChangesUntil = DateTime(0);

  bool get _canRead =>
      _telephony.hasPermission(TelephonyPermission.readContacts);

  @override
  void initState() {
    super.initState();
    if (!_canRead) return;
    _reload();
    _changes = _telephony.contactChanges.listen((_) => _onContactsChanged());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _changes?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// Starts the list again from the top: counts the matches and loads the
  /// first page.
  void _reload() {
    _contacts.clear();
    _nextOffset = 0;
    _total = 0;
    _hasMore = true;
    _stale = false;
    _error = null;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _loadMore();
  }

  /// Loads the next page. Each page is small, so this takes a few
  /// milliseconds even with thousands of contacts.
  void _loadMore() {
    if (_loading || !_hasMore) return;
    _loading = true;
    try {
      final page = _telephony.getContactsPage(
        query: _query,
        offset: _nextOffset,
        pageSize: _pageSize,
      );
      _contacts.addAll(page.contacts);
      _nextOffset = page.nextOffset;
      _total = page.totalCount;
      _hasMore = page.hasMore;
    } on TelephonyException catch (e) {
      _error = e.message;
      _hasMore = false;
    } finally {
      _loading = false;
    }
    if (mounted) setState(() {});
  }

  /// Asks for the next page after this frame, when the list nears its end.
  void _scheduleLoadMore() {
    if (_loadScheduled || _loading || !_hasMore) return;
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) _loadMore();
    });
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || text.trim() == _query.trim()) return;
      _query = text;
      _reload();
    });
  }

  void _onContactsChanged() {
    if (!mounted || DateTime.now().isBefore(_ignoreChangesUntil)) return;
    // Near the top a silent reload is invisible. Further down it would make
    // the list jump, so offer a refresh instead.
    if (!_scroll.hasClients || _scroll.offset < 200) {
      _reload();
    } else {
      setState(() => _stale = true);
    }
  }

  Future<void> _open(int index) async {
    final id = _contacts[index].id;
    // Otherwise the search field gets focus back on return and the
    // keyboard pops up over the list.
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactDetailsPage(contactId: id),
      ),
    );
    if (!mounted) return;
    // Update just this row so the list keeps its place.
    _ignoreChangesUntil = DateTime.now().add(const Duration(seconds: 2));
    final i = _contacts.indexWhere((c) => c.id == id);
    if (i < 0) return;
    final fresh = _telephony.getContact(id);
    setState(() {
      if (fresh == null) {
        _contacts.removeAt(i);
        _total = _total > 0 ? _total - 1 : 0;
      } else {
        _contacts[i] = fresh;
      }
    });
  }

  Future<void> _add() async {
    FocusScope.of(context).unfocus();
    final id = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ContactEditPage()));
    if (id != null && mounted) {
      _toast('Contact added');
      _reload();
    }
  }

  Widget _tile(int i) {
    final c = _contacts[i];
    final name = c.displayName.isNotEmpty
        ? c.displayName
        : (c.phones.isNotEmpty && c.phones.first.number.isNotEmpty
              ? c.phones.first.number
              : '(no name)');
    return ListTile(
      leading: CircleAvatar(child: Text(String.fromCharCode(name.runes.first))),
      title: Row(
        children: [
          Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
          if (c.isStarred)
            const Icon(Icons.star, size: 16, color: Colors.amber),
        ],
      ),
      subtitle: Text(
        c.phones.isNotEmpty
            ? '${c.phones.first}'
            : (c.emails.isNotEmpty ? '${c.emails.first}' : ''),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _open(i),
    );
  }

  Widget _list() {
    if (_error != null && _contacts.isEmpty) {
      return Center(child: Text(_error!));
    }
    if (_contacts.isEmpty) {
      return Center(
        child: _hasMore
            ? const CircularProgressIndicator()
            : const Text('No contacts found.'),
      );
    }
    // One extra row at the end shows a spinner while more pages remain.
    final count = _contacts.length + (_hasMore ? 1 : 0);
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (context, i) {
          if (i >= _contacts.length - 15) _scheduleLoadMore();
          if (i >= _contacts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _tile(i);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRead) {
      return const Center(
        child: Text('Grant the contacts permission to see contacts.'),
      );
    }
    return Scaffold(
      floatingActionButton:
          _telephony.hasPermission(TelephonyPermission.writeContacts)
          ? FloatingActionButton(
              onPressed: _add,
              tooltip: 'Add contact',
              child: const Icon(Icons.person_add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SearchBar(
              hintText: 'Search by name, number or email',
              leading: const Icon(Icons.search),
              onChanged: _onSearch,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _total == 1 ? '1 contact' : '$_total contacts',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                if (_stale)
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Contacts changed'),
                  ),
              ],
            ),
          ),
          Expanded(child: _list()),
        ],
      ),
    );
  }
}

/// Everything saved on one contact, with favorite, edit and delete.
class ContactDetailsPage extends StatefulWidget {
  const ContactDetailsPage({super.key, required this.contactId});

  final String contactId;

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  Future<void> _edit(ContactDetails contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactEditPage(contact: contact),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _delete(ContactDetails contact) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete contact?'),
        content: Text(
          '${contact.displayName} will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    try {
      _telephony.deleteContact(contact.id);
      Navigator.of(context).pop();
    } on TelephonyException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = _telephony.getContact(widget.contactId);
    if (contact == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This contact no longer exists.')),
      );
    }
    final canWrite = _telephony.hasPermission(
      TelephonyPermission.writeContacts,
    );
    final photo = _telephony.getContactPhoto(contact.id, fullSize: true);
    final groups = {for (final g in _telephony.getContactGroups()) g.id: g};
    final memberOf = _telephony.getContactGroupIds(contact.id);

    Widget section(String title, List<Widget> children) => children.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              ...children,
            ],
          );

    String nameParts() => [
      contact.namePrefix,
      contact.givenName,
      contact.middleName,
      contact.familyName,
      contact.nameSuffix,
    ].where((p) => p.isNotEmpty).join(' ');

    return Scaffold(
      appBar: AppBar(
        title: Text(contact.displayName),
        actions: [
          if (canWrite) ...[
            IconButton(
              tooltip: 'Favorite',
              icon: Icon(contact.isStarred ? Icons.star : Icons.star_border),
              onPressed: () {
                _telephony.setContactStarred(contact.id, !contact.isStarred);
                setState(() {});
              },
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: () => _edit(contact),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete),
              onPressed: () => _delete(contact),
            ),
          ],
        ],
      ),
      body: ListView(
        children: [
          if (photo != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: CircleAvatar(
                  radius: 56,
                  backgroundImage: MemoryImage(photo),
                ),
              ),
            ),
          section('Name', [
            if (nameParts().isNotEmpty) ListTile(title: Text(nameParts())),
            if (contact.nickname.isNotEmpty)
              ListTile(
                title: Text(contact.nickname),
                subtitle: const Text('Nickname'),
              ),
          ]),
          section('Phone', [
            for (final p in contact.phones)
              ListTile(
                title: Text(p.number),
                subtitle: Text(p.label),
                trailing: const Icon(Icons.call),
                onTap: () => _telephony.openDialer(p.number),
              ),
          ]),
          section('Email', [
            for (final e in contact.emails)
              ListTile(title: Text(e.address), subtitle: Text(e.label)),
          ]),
          section('Address', [
            for (final a in contact.addresses)
              ListTile(title: Text(a.address), subtitle: Text(a.label)),
          ]),
          section('Work', [
            if (contact.company.isNotEmpty || contact.jobTitle.isNotEmpty)
              ListTile(
                title: Text(contact.company),
                subtitle: Text(
                  [
                    contact.jobTitle,
                    contact.department,
                  ].where((v) => v.isNotEmpty).join(' · '),
                ),
              ),
          ]),
          section('Websites', [
            for (final w in contact.websites) ListTile(title: Text(w)),
          ]),
          section('Messaging and relations', [
            for (final im in contact.ims)
              ListTile(title: Text(im.address), subtitle: Text(im.protocol)),
            for (final r in contact.relations)
              ListTile(title: Text(r.name), subtitle: Text(r.label)),
            for (final s in contact.sipAddresses)
              ListTile(title: Text(s), subtitle: const Text('Internet call')),
          ]),
          section('Groups', [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final g in groups.values)
                    FilterChip(
                      label: Text(g.title),
                      selected: memberOf.contains(g.id),
                      onSelected: canWrite
                          ? (on) {
                              on
                                  ? _telephony.addContactToGroup(
                                      contact.id,
                                      g.id,
                                    )
                                  : _telephony.removeContactFromGroup(
                                      contact.id,
                                      g.id,
                                    );
                              setState(() {});
                            }
                          : null,
                    ),
                ],
              ),
            ),
          ]),
          section('System screens', [
            ListTile(
              title: const Text('Show in Contacts app'),
              onTap: () => _telephony.showContact(contact.id),
            ),
            ListTile(
              title: const Text('Edit in Contacts app'),
              onTap: () => _telephony.openContactEditor(contact.id),
            ),
            if (canWrite && photo != null)
              ListTile(
                title: const Text('Remove photo'),
                onTap: () {
                  _telephony.setContactPhoto(contact.id, null);
                  setState(() {});
                },
              ),
          ]),
          section('Other', [
            if (contact.birthday != null)
              ListTile(
                title: Text(contact.birthday!),
                subtitle: const Text('Birthday'),
              ),
            if (contact.note.isNotEmpty)
              ListTile(title: Text(contact.note), subtitle: const Text('Note')),
          ]),
        ],
      ),
    );
  }
}

/// Add a contact (no [contact]) or edit one.
class ContactEditPage extends StatefulWidget {
  const ContactEditPage({super.key, this.contact});

  final ContactDetails? contact;

  @override
  State<ContactEditPage> createState() => _ContactEditPageState();
}

class _ContactEditPageState extends State<ContactEditPage> {
  late final _given = TextEditingController(
    text: widget.contact?.givenName.isNotEmpty == true
        ? widget.contact!.givenName
        : (widget.contact?.familyName.isNotEmpty == true
              ? ''
              : widget.contact?.displayName ?? ''),
  );
  late final _family = TextEditingController(text: widget.contact?.familyName);
  late final _company = TextEditingController(text: widget.contact?.company);
  late final _note = TextEditingController(text: widget.contact?.note);
  late final _phones = [
    for (final p in widget.contact?.phones ?? const <ContactPhone>[])
      TextEditingController(text: p.number),
    if (widget.contact?.phones.isEmpty ?? true) TextEditingController(),
  ];
  late final _emails = [
    for (final e in widget.contact?.emails ?? const <ContactEmail>[])
      TextEditingController(text: e.address),
    if (widget.contact?.emails.isEmpty ?? true) TextEditingController(),
  ];

  @override
  void dispose() {
    for (final c in [
      _given,
      _family,
      _company,
      _note,
      ..._phones,
      ..._emails,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Keeps each number's old label when the number is still in the list.
  String _labelFor(String number, List<ContactPhone> old) {
    for (final p in old) {
      if (p.number == number) return p.label;
    }
    return 'Mobile';
  }

  void _save() {
    final old = widget.contact;
    final phones = [
      for (final c in _phones)
        if (c.text.trim().isNotEmpty)
          ContactPhone(
            number: c.text.trim(),
            label: _labelFor(c.text.trim(), old?.phones ?? const []),
          ),
    ];
    final emails = [
      for (final c in _emails)
        if (c.text.trim().isNotEmpty) ContactEmail(address: c.text.trim()),
    ];
    try {
      if (old == null) {
        final id = _telephony.addContact(
          ContactDetails(
            givenName: _given.text,
            familyName: _family.text,
            company: _company.text,
            note: _note.text,
            phones: phones,
            emails: emails,
          ),
        );
        Navigator.of(context).pop(id);
      } else {
        _telephony.updateContact(
          old.copyWith(
            givenName: _given.text,
            familyName: _family.text,
            company: _company.text,
            note: _note.text,
            phones: phones,
            emails: emails,
          ),
        );
        Navigator.of(context).pop();
      }
    } on TelephonyException catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _field(TextEditingController c, String label, {TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.contact == null ? 'New contact' : 'Edit contact'),
      actions: [TextButton(onPressed: _save, child: const Text('Save'))],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _field(_given, 'First name'),
        _field(_family, 'Last name'),
        _field(_company, 'Company'),
        for (final c in _phones) _field(c, 'Phone', type: TextInputType.phone),
        TextButton.icon(
          onPressed: () => setState(() => _phones.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('Add phone'),
        ),
        for (final c in _emails)
          _field(c, 'Email', type: TextInputType.emailAddress),
        TextButton.icon(
          onPressed: () => setState(() => _emails.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text('Add email'),
        ),
        _field(_note, 'Note'),
      ],
    ),
  );
}
