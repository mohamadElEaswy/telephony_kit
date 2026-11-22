// Calls every read-only API once on a real device or emulator and checks that
// nothing crashes. Permission problems are fine (they throw
// TelephonyException); anything else fails the test. Prints counts only.
//
//   flutter test integration_test/read_apis_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:telephony_kit/telephony_kit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final t = TelephonyKit.instance;

  final reads = <String, Object? Function()>{
    'getContacts': () => t.getContacts(limit: 20).length,
    'getContacts(query)': () => t.getContacts(query: 'a', limit: 20).length,
    'getContactGroups': () => t.getContactGroups().length,
    'getContactGroups(system)': () =>
        t.getContactGroups(includeSystem: true).length,
    'getContactAccounts': () => t.getContactAccounts().length,
    'findDuplicateContacts': () => t.findDuplicateContacts(limit: 200).length,
    'exportContactsAsVCard': () => t.exportContactsAsVCard(limit: 20).length,
    'getCallLog': () => t.getCallLog(limit: 20).length,
    'getCallLogStats': () => t.getCallLogStats(limit: 100).length,
    'getGroupedCallLog': () => t.getGroupedCallLog(limit: 50).length,
    'defaultSmsPackage': () => t.defaultSmsPackage != null,
    'isDefaultSmsApp': () => t.isDefaultSmsApp,
    'getSmsThreads': () => t.getSmsThreads(messageLimit: 100).length,
    'getMmsMessages': () => t.getMmsMessages(limit: 5).length,
    'getPhoneNumbers': () => t.getPhoneNumbers().length,
    'getCellInfo': () => t.getCellInfo().length,
    'signalDbm': () => t.signalDbm != null,
    'isMobileDataEnabled': () => t.isMobileDataEnabled,
    'isDataRoamingAllowed': () => t.isDataRoamingAllowed,
    'dataConnectionState': () => t.dataConnectionState.name,
    'getEsimInfo': () => t.getEsimInfo().isSupported,
  };

  for (final entry in reads.entries) {
    testWidgets('${entry.key} does not crash', (tester) async {
      try {
        // ignore: avoid_print
        print('SMOKE ${entry.key}: ${entry.value()}');
      } on TelephonyException catch (e) {
        // ignore: avoid_print
        print('SMOKE ${entry.key}: TelephonyException ${e.message}');
      }
    });
  }

  testWidgets('streams can start and stop', (tester) async {
    for (final stream in [t.contactChanges, t.callLogChanges, t.smsChanges]) {
      try {
        final sub = stream.listen((_) {});
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await sub.cancel();
      } on TelephonyException catch (e) {
        // ignore: avoid_print
        print('SMOKE stream: TelephonyException ${e.message}');
      }
    }
  });
}
