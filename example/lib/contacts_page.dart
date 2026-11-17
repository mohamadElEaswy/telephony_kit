import 'package:material_ui/material_ui.dart';
import 'package:telephony_kit/telephony_kit.dart';

final _telephony = TelephonyKit.instance;

/// Contacts tab: search, open a contact to see everything saved on it, add,
/// edit, favorite and delete.
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  String _query = '';

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _open(ContactDetails contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactDetailsPage(contactId: contact.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _add() async {
    final id = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const ContactEditPage()));
    if (id != null && mounted) {
      _toast('Contact added');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_telephony.hasPermission(TelephonyPermission.readContacts)) {
      return const Center(
        child: Text('Grant the contacts permission to see contacts.'),
      );
    }
    Widget list;
    try {
      final contacts = _telephony.getContacts(query: _query, limit: 300);
      list = contacts.isEmpty
          ? const Center(child: Text('No contacts found.'))
          : ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, i) {
                final c = contacts[i];
                final name = c.displayName.isEmpty
                    ? (c.phones.isEmpty ? '(no name)' : c.phones.first.number)
                    : c.displayName;
                return ListTile(
                  leading: CircleAvatar(child: Text(name[0])),
                  title: Row(
                    children: [
                      Flexible(child: Text(name)),
                      if (c.isStarred)
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                    ],
                  ),
                  subtitle: Text(
                    c.phones.isNotEmpty
                        ? '${c.phones.first}'
                        : (c.emails.isNotEmpty ? '${c.emails.first}' : ''),
                  ),
                  onTap: () => _open(c),
                );
              },
            );
    } on TelephonyException catch (e) {
      list = Center(child: Text(e.message));
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              hintText: 'Search by name, number or email',
              leading: const Icon(Icons.search),
              onChanged: (q) => setState(() => _query = q),
            ),
          ),
          Expanded(child: list),
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
