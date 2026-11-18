package dev.telephonykit.telephony_kit;

import android.content.ContentResolver;
import android.content.Context;
import android.database.Cursor;
import android.provider.ContactsContract;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Builds the ordered list of contact ids for a search once, natively, and
 * hands out pages of it.
 *
 * <p>Scanning thousands of rows through JNI one cell at a time would block
 * the UI, so this class does the scan in Java and keeps only the ids (a few
 * bytes per contact). Dart then loads the details of one page at a time.
 *
 * <p>Each query keeps a snapshot until {@link #prepare} is called again with
 * {@code refresh} set, so offsets stay stable while the user scrolls even if
 * contacts change. The four most recently used queries are cached.
 */
public final class ContactPager {
  private ContactPager() {}

  private static final String SORT =
      ContactsContract.Contacts.STARRED
          + " DESC, "
          + ContactsContract.Contacts.DISPLAY_NAME
          + " COLLATE LOCALIZED ASC";

  /** Strips the formatting Android stores in phone numbers before LIKE. */
  private static final String DIGITS_ONLY =
      "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(data1, ' ', ''), "
          + "'-', ''), '(', ''), ')', ''), '.', '')";

  private static final int MAX_SNAPSHOTS = 4;

  private static final Map<String, String[]> snapshots =
      new LinkedHashMap<String, String[]>(MAX_SNAPSHOTS, 0.75f, true) {
        @Override
        protected boolean removeEldestEntry(Map.Entry<String, String[]> eldest) {
          return size() > MAX_SNAPSHOTS;
        }
      };

  /**
   * Builds (or, with {@code refresh} false, reuses) the snapshot for
   * {@code query} and returns how many contacts match. An empty query matches
   * every contact. Needs READ_CONTACTS.
   */
  public static synchronized int prepare(Context context, String query, boolean refresh) {
    String key = normalize(query);
    String[] ids = refresh ? null : snapshots.get(key);
    if (ids == null) {
      ids = build(context.getContentResolver(), key);
      snapshots.put(key, ids);
    }
    return ids.length;
  }

  /**
   * Up to {@code limit} contact ids starting at {@code offset}, in list order
   * (favorites first, then by name). Builds the snapshot first if needed.
   */
  public static synchronized String[] page(Context context, String query, int offset, int limit) {
    String key = normalize(query);
    String[] ids = snapshots.get(key);
    if (ids == null) {
      ids = build(context.getContentResolver(), key);
      snapshots.put(key, ids);
    }
    if (offset < 0) offset = 0;
    if (limit <= 0 || offset >= ids.length) return new String[0];
    int end = (int) Math.min((long) offset + limit, ids.length);
    return Arrays.copyOfRange(ids, offset, end);
  }

  /** Drops every cached snapshot, for example after contacts changed. */
  public static synchronized void clear() {
    snapshots.clear();
  }

  private static String normalize(String query) {
    return query == null ? "" : query.trim();
  }

  private static String[] build(ContentResolver resolver, String query) {
    if (query.isEmpty()) return sortedIds(resolver, null);

    Set<String> matches = new HashSet<>();
    // Names.
    collect(
        resolver,
        ContactsContract.Contacts.CONTENT_URI,
        ContactsContract.Contacts._ID,
        ContactsContract.Contacts.DISPLAY_NAME + " LIKE ?",
        new String[] {"%" + query + "%"},
        matches);

    // Emails, and phone numbers in any format.
    List<String> patterns = numberPatterns(query);
    StringBuilder where =
        new StringBuilder("(" + ContactsContract.Data.MIMETYPE + " = ? AND data1 LIKE ?)");
    List<String> args = new ArrayList<>();
    args.add(ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE);
    args.add("%" + query + "%");
    if (!patterns.isEmpty()) {
      where.append(" OR (").append(ContactsContract.Data.MIMETYPE).append(" = ? AND (");
      args.add(ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE);
      for (int i = 0; i < patterns.size(); i++) {
        if (i > 0) where.append(" OR ");
        where.append(DIGITS_ONLY).append(" LIKE ?");
        args.add("%" + patterns.get(i) + "%");
      }
      where.append("))");
    }
    collect(
        resolver,
        ContactsContract.Data.CONTENT_URI,
        ContactsContract.Data.CONTACT_ID,
        where.toString(),
        args.toArray(new String[0]),
        matches);

    if (matches.isEmpty()) return new String[0];
    return sortedIds(resolver, matches);
  }

  /** Every contact id in list order, keeping only {@code keep} when given. */
  private static String[] sortedIds(ContentResolver resolver, Set<String> keep) {
    List<String> out = new ArrayList<>();
    try (Cursor c =
        resolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            new String[] {ContactsContract.Contacts._ID},
            null,
            null,
            SORT)) {
      if (c == null) return new String[0];
      while (c.moveToNext()) {
        String id = c.getString(0);
        if (id != null && (keep == null || keep.contains(id))) out.add(id);
      }
    }
    return out.toArray(new String[0]);
  }

  private static void collect(
      ContentResolver resolver,
      android.net.Uri uri,
      String column,
      String selection,
      String[] args,
      Set<String> into) {
    try (Cursor c = resolver.query(uri, new String[] {column}, selection, args, null)) {
      if (c == null) return;
      while (c.moveToNext()) {
        String id = c.getString(0);
        if (id != null) into.add(id);
      }
    }
  }

  /**
   * Same rules as numberSearchPatterns in lib/src/search.dart: digits only,
   * at least 2 of them, plus the variant without leading zeros.
   */
  static List<String> numberPatterns(String query) {
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < query.length(); i++) {
      char ch = query.charAt(i);
      if (ch >= '0' && ch <= '9') sb.append(ch);
    }
    String digits = sb.toString();
    List<String> out = new ArrayList<>();
    if (digits.length() < 2) return out;
    out.add(digits);
    String withoutTrunk = digits.replaceFirst("^0+", "");
    if (withoutTrunk.length() >= 2 && !withoutTrunk.equals(digits)) out.add(withoutTrunk);
    return out;
  }
}
