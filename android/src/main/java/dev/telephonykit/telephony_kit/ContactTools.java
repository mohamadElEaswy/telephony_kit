package dev.telephonykit.telephony_kit;

import android.content.ContentResolver;
import android.content.ContentUris;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.ContactsContract;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;

/** Contact photos and the system contact screens. */
public final class ContactTools {
  private ContactTools() {}

  private static Uri contactUri(String contactId) {
    return ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, Long.parseLong(contactId));
  }

  /**
   * The contact's photo bytes (JPEG or PNG), or an empty array if it has
   * none. {@code full} reads the high resolution photo when there is one.
   * Needs READ_CONTACTS.
   */
  public static byte[] readPhoto(Context context, String contactId, boolean full) {
    ContentResolver resolver = context.getContentResolver();
    try (InputStream in =
        ContactsContract.Contacts.openContactPhotoInputStream(resolver, contactUri(contactId), full)) {
      if (in == null) return new byte[0];
      ByteArrayOutputStream out = new ByteArrayOutputStream();
      byte[] buffer = new byte[8192];
      int n;
      while ((n = in.read(buffer)) > 0) out.write(buffer, 0, n);
      return out.toByteArray();
    } catch (IOException e) {
      return new byte[0];
    }
  }

  /**
   * Sets the contact's photo to {@code bytes} (an encoded image), or removes
   * it when {@code bytes} is empty. Returns false if the contact does not
   * exist. Needs WRITE_CONTACTS.
   */
  public static boolean writePhoto(Context context, String contactId, byte[] bytes) {
    ContentResolver resolver = context.getContentResolver();
    long rawId = -1;
    try (Cursor c =
        resolver.query(
            ContactsContract.RawContacts.CONTENT_URI,
            new String[] {ContactsContract.RawContacts._ID},
            ContactsContract.RawContacts.CONTACT_ID + " = ? AND " + ContactsContract.RawContacts.DELETED + " = 0",
            new String[] {contactId},
            ContactsContract.RawContacts._ID + " ASC")) {
      if (c != null && c.moveToFirst()) rawId = c.getLong(0);
    }
    if (rawId < 0) return false;

    String photoMime = ContactsContract.CommonDataKinds.Photo.CONTENT_ITEM_TYPE;
    String where = ContactsContract.Data.RAW_CONTACT_ID + " = ? AND " + ContactsContract.Data.MIMETYPE + " = ?";
    String[] args = {String.valueOf(rawId), photoMime};
    if (bytes == null || bytes.length == 0) {
      resolver.delete(ContactsContract.Data.CONTENT_URI, where, args);
      return true;
    }
    ContentValues values = new ContentValues();
    values.put(ContactsContract.CommonDataKinds.Photo.PHOTO, bytes);
    int updated = resolver.update(ContactsContract.Data.CONTENT_URI, values, where, args);
    if (updated == 0) {
      values.put(ContactsContract.Data.RAW_CONTACT_ID, rawId);
      values.put(ContactsContract.Data.MIMETYPE, photoMime);
      resolver.insert(ContactsContract.Data.CONTENT_URI, values);
    }
    return true;
  }

  /** Opens the system screen that shows the contact. Returns false if it does not exist. */
  public static boolean view(Context context, String contactId) {
    return open(context, Intent.ACTION_VIEW, contactId);
  }

  /** Opens the system screen that edits the contact. Returns false if it does not exist. */
  public static boolean edit(Context context, String contactId) {
    return open(context, Intent.ACTION_EDIT, contactId);
  }

  private static boolean open(Context context, String action, String contactId) {
    Uri lookup = ContactsContract.Contacts.getLookupUri(context.getContentResolver(), contactUri(contactId));
    if (lookup == null) return false;
    Intent intent = new Intent(action, lookup).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    context.startActivity(intent);
    return true;
  }

  /**
   * Opens the system "new contact" screen, filled with whatever of {@code
   * name}, {@code phone} and {@code email} is not empty. The user saves it
   * there, so no permission is needed.
   */
  public static void insert(Context context, String name, String phone, String email) {
    Intent intent =
        new Intent(Intent.ACTION_INSERT, ContactsContract.Contacts.CONTENT_URI)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    if (name != null && !name.isEmpty()) intent.putExtra(ContactsContract.Intents.Insert.NAME, name);
    if (phone != null && !phone.isEmpty()) intent.putExtra(ContactsContract.Intents.Insert.PHONE, phone);
    if (email != null && !email.isEmpty()) intent.putExtra(ContactsContract.Intents.Insert.EMAIL, email);
    context.startActivity(intent);
  }
}
