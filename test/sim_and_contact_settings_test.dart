import 'package:flutter_test/flutter_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

SimCard sim(int id, int slot, [String name = 'SIM']) => SimCard(
  subscriptionId: id,
  slotIndex: slot,
  displayName: name,
  carrierName: name,
  countryIso: 'eg',
  isEmbedded: false,
);

void main() {
  group('diffSimCards', () {
    test('no change', () {
      final a = [sim(1, 0), sim(2, 1)];
      expect(diffSimCards(a, [sim(1, 0, 'renamed'), sim(2, 1)]), isEmpty);
    });

    test('inserted', () {
      final events = diffSimCards([sim(1, 0)], [sim(1, 0), sim(2, 1)]);
      expect(events, hasLength(1));
      expect((events.single as SimInserted).sim.subscriptionId, 2);
    });

    test('removed', () {
      final events = diffSimCards([sim(1, 0), sim(2, 1)], [sim(2, 1)]);
      expect((events.single as SimRemoved).sim.subscriptionId, 1);
    });

    test('swapped in the same slot', () {
      final events = diffSimCards([sim(1, 0, 'Old')], [sim(5, 0, 'New')]);
      final changed = events.single as SimChanged;
      expect(changed.before.displayName, 'Old');
      expect(changed.after.displayName, 'New');
      expect(changed.slotIndex, 0);
    });

    test('unknown slots are not paired', () {
      final events = diffSimCards([sim(1, -1)], [sim(2, -1)]);
      expect(events.first, isA<SimRemoved>());
      expect(events.last, isA<SimInserted>());
    });

    test('all removed and all inserted', () {
      expect(diffSimCards([sim(1, 0)], const []).single, isA<SimRemoved>());
      expect(diffSimCards(const [], [sim(1, 0)]).single, isA<SimInserted>());
    });

    test('events are readable', () {
      expect('${SimInserted(sim(1, 0, 'Vodafone'))}', contains('Vodafone'));
    });
  });

  test('ContactCallSettings', () {
    const settings = ContactCallSettings();
    expect(settings.usesDefaultRingtone, isTrue);
    expect(settings.sendToVoicemail, isFalse);
    const custom = ContactCallSettings(
      ringtoneUri: 'content://media/1',
      ringtoneTitle: 'Bells',
      sendToVoicemail: true,
    );
    expect(custom.usesDefaultRingtone, isFalse);
    expect('$custom', contains('voicemail: true'));
  });

  test('RingtoneInfo equality', () {
    expect(
      const RingtoneInfo(title: 'A', uri: 'u'),
      const RingtoneInfo(title: 'A', uri: 'u'),
    );
  });

  test('answerPhoneCalls permission name', () {
    expect(
      TelephonyPermission.answerPhoneCalls,
      'android.permission.ANSWER_PHONE_CALLS',
    );
  });
}
