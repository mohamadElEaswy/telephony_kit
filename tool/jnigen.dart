// Regenerates the JNI bindings in lib/src/bindings.g.dart.
//
// Usage (from the package root, with ANDROID_SDK_ROOT set):
//   flutter pub get
//   dart run tool/jnigen.dart

import 'dart:io';

import 'package:jnigen/jnigen.dart';

/// Android framework members that the package uses. Everything else on these
/// classes is left out so the bindings stay small and only expose public,
/// stable APIs.
const _androidAllowList = <String, Set<String>>{
  'android.content.Context': {
    'getSystemService',
    'getContentResolver',
    'getPackageName',
    'checkSelfPermission',
    'startActivity',
    'TELECOM_SERVICE',
    'TELEPHONY_SERVICE',
    'TELEPHONY_SUBSCRIPTION_SERVICE',
    'ROLE_SERVICE',
  },
  'android.app.Activity': {'startActivityForResult'},
  'android.content.Intent': {
    '<init>',
    'addFlags',
    'putExtra',
    'ACTION_DIAL',
    'FLAG_ACTIVITY_NEW_TASK',
  },
  'android.net.Uri': {'parse', 'fromParts'},
  'android.os.Build\$VERSION': {'SDK_INT'},
  'android.app.role.RoleManager': {
    'isRoleAvailable',
    'isRoleHeld',
    'createRequestRoleIntent',
    'ROLE_DIALER',
  },
  'android.telecom.TelecomManager': {
    'placeCall',
    'getDefaultDialerPackage',
    'isInCall',
    'endCall',
    'getCallCapablePhoneAccounts',
    'ACTION_CHANGE_DEFAULT_DIALER',
    'EXTRA_CHANGE_DEFAULT_DIALER_PACKAGE_NAME',
    'EXTRA_PHONE_ACCOUNT_HANDLE',
  },
  'android.telephony.TelephonyManager': {
    'getNetworkOperatorName',
    'getNetworkOperator',
    'getNetworkCountryIso',
    'getSimOperatorName',
    'getSimCountryIso',
    'getSimState',
    'getPhoneType',
    'isNetworkRoaming',
    'isVoiceCapable',
    'getPhoneCount',
    'getActiveModemCount',
  },
  'android.telephony.SubscriptionManager': {'getActiveSubscriptionInfoList'},
  'android.telephony.SubscriptionInfo': {
    'getSubscriptionId',
    'getSimSlotIndex',
    'getDisplayName',
    'getCarrierName',
    'getCountryIso',
    'isEmbedded',
  },
  'android.content.ContentResolver': {'query'},
  'android.database.Cursor': {
    'moveToNext',
    'getColumnIndex',
    'getString',
    'getLong',
    'getInt',
    'isNull',
    'close',
  },
  'android.provider.CallLog\$Calls': {
    'CONTENT_URI',
    'NUMBER',
    'CACHED_NAME',
    'TYPE',
    'DATE',
    'DURATION',
    'INCOMING_TYPE',
    'OUTGOING_TYPE',
    'MISSED_TYPE',
    'VOICEMAIL_TYPE',
    'REJECTED_TYPE',
    'BLOCKED_TYPE',
    'DEFAULT_SORT_ORDER',
  },
  'android.telecom.PhoneAccountHandle': {'getId'},
  'android.os.Bundle': {'<init>', 'putParcelable'},
  'android.os.Parcelable': <String>{},
};

const _ownPackage = 'dev.telephonykit.telephony_kit.';

final class _AllowListVisitor extends Visitor {
  _AllowListVisitor() : super.base();

  Set<String>? _allowed;

  @override
  void visitClass(ClassDecl c) {
    if (c.binaryName == '${_ownPackage}TelephonyKitInCallService') {
      // Only the system talks to the service; Dart uses CallManager.
      c.isIncluded = false;
      _allowed = const {};
      return;
    }
    if (c.binaryName.startsWith(_ownPackage)) {
      _allowed = null; // Bind everything public in our own classes.
      return;
    }
    final allowed = _androidAllowList[c.binaryName];
    if (allowed == null) {
      // Nested or helper classes pulled in by an outer class (for example
      // Build.VERSION_CODES) are not needed.
      c.isIncluded = false;
      _allowed = const {};
      return;
    }
    _allowed = allowed;
  }

  @override
  void visitMethod(Method method) {
    final allowed = _allowed;
    if (allowed == null) return;
    final key = method.isConstructor ? '<init>' : method.originalName;
    method.isIncluded = allowed.contains(key);
  }

  @override
  void visitField(Field field) {
    final allowed = _allowed;
    if (allowed == null) return;
    field.isIncluded = allowed.contains(field.originalName);
  }
}

Uri _sdkRoot() {
  final env = Platform.environment;
  final path = env['ANDROID_SDK_ROOT'] ?? env['ANDROID_HOME'];
  if (path == null || path.isEmpty) {
    stderr.writeln(
      'Set ANDROID_SDK_ROOT (or ANDROID_HOME) to your Android SDK.',
    );
    exit(1);
  }
  return Uri.directory(path);
}

void main() async {
  final packageRoot = Platform.script.resolve('../');

  final generator = JniGenerator(
    input: Input(
      classes: [
        'dev.telephonykit.telephony_kit',
        'android.content.Context',
        'android.app.Activity',
        'android.content.Intent',
        'android.net.Uri',
        'android.os.Build',
        'android.os.Bundle',
        'android.os.Parcelable',
        'android.app.role.RoleManager',
        'android.telecom.TelecomManager',
        'android.telecom.PhoneAccountHandle',
        'android.telephony.TelephonyManager',
        'android.telephony.SubscriptionManager',
        'android.telephony.SubscriptionInfo',
        'android.content.ContentResolver',
        'android.database.Cursor',
        'android.provider.CallLog',
      ],
      sourcePath: [packageRoot.resolve('android/src/main/java/')],
      androidSdk: AndroidSdk(versions: [36, 35], sdkRoot: _sdkRoot()),
    ),
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/bindings.g.dart'),
        structure: OutputStructure.singleFile,
      ),
      preamble:
          '// Generated by tool/jnigen.dart. Do not edit by hand.\n'
          '// ignore_for_file: type=lint, unused_element, unused_field, '
          'unused_import\n',
    ),
    visitors: [_AllowListVisitor()],
  );

  await generator.generate();
}
