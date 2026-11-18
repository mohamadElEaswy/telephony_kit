import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/src/contacts.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  group('orderContactsByIds', () {
    const a = ContactDetails(id: '1', displayName: 'A');
    const b = ContactDetails(id: '2', displayName: 'B');
    const c = ContactDetails(id: '3', displayName: 'C');

    test('follows the id order, not the query order', () {
      final out = orderContactsByIds(['3', '1', '2'], [a, b, c]);
      expect(out.map((x) => x.id), ['3', '1', '2']);
    });

    test('skips ids whose contact is gone', () {
      final out = orderContactsByIds(['1', '9', '3'], [c, a]);
      expect(out.map((x) => x.id), ['1', '3']);
    });

    test('handles empty input', () {
      expect(orderContactsByIds([], [a]), isEmpty);
      expect(orderContactsByIds(['1'], []), isEmpty);
    });
  });

  group('ContactPage', () {
    test('hasMore until nextOffset reaches the total', () {
      const first = ContactPage(
        contacts: [ContactDetails(id: '1')],
        offset: 0,
        nextOffset: 50,
        totalCount: 120,
      );
      expect(first.hasMore, isTrue);
      const last = ContactPage(
        contacts: [],
        offset: 100,
        nextOffset: 120,
        totalCount: 120,
      );
      expect(last.hasMore, isFalse);
    });

    test('empty has nothing more', () {
      expect(ContactPage.empty.hasMore, isFalse);
      expect(ContactPage.empty.contacts, isEmpty);
    });

    test('pages walk the whole list once', () {
      // Simulates a 5000 id snapshot read 50 at a time.
      final ids = [for (var i = 0; i < 5000; i++) '$i'];
      final seen = <String>[];
      var offset = 0;
      var pages = 0;
      while (true) {
        final slice = ids.skip(offset).take(50).toList();
        final page = ContactPage(
          contacts: [for (final id in slice) ContactDetails(id: id)],
          offset: offset,
          nextOffset: offset + slice.length,
          totalCount: ids.length,
        );
        seen.addAll(page.contacts.map((c) => c.id));
        pages++;
        if (!page.hasMore) break;
        offset = page.nextOffset;
      }
      expect(pages, 100);
      expect(seen, ids);
    });
  });
}
