// Run with: dart apps/flutter/tool/ios_test.dart (no Mac or package install needed).
import 'dart:io';
import 'ios.dart' as ios;
import 'ios_store.dart' as store;

void expect(bool result, String message) {
  if (!result) throw StateError(message);
}

void rejects(void Function() action, String message) {
  try {
    action();
  } on FormatException {
    return;
  } on StateError {
    return;
  }
  throw StateError(message);
}

void main() {
  final normal = ios.IosArguments(['build']);
  expect(
    normal.apps.join(',') == 'customer,captain' && normal.defines.isEmpty,
    'Normal builds must install both real Firebase apps.',
  );
  expect(
    ios.IosArguments(['build', 'captain', '--demo']).defines.single ==
        '--dart-define=WHEELIO_DEMO=true',
    'Demo requires an explicit flag.',
  );
  for (final args in [
    ['build', '--dmeo'],
    ['build', 'Customer'],
    ['build', '--device'],
    ['build', '--prepare', '--device', 'phone'],
    ['build', '--prepare', '--no-codesign'],
    ['run', 'all'],
    ['run', '--no-codesign'],
    ['build', '--build-number', '1.5'],
    ['archive', '--demo'],
    ['archive', '--no-codesign'],
    ['archive', '--device', 'phone'],
    ['archive', '--prepare'],
  ]) {
    rejects(
      () => ios.IosArguments(args),
      'Unsafe/unknown arguments accepted: $args',
    );
  }
  expect(
    ios.IosArguments(['archive']).apps.length == 2,
    'Store export must build both apps by default without selecting a device.',
  );
  store.checkSdk('26.1\n');
  rejects(
    () => store.checkSdk('18.5'),
    'Old SDK must fail before store archive.',
  );
  final storeInfo = <String, dynamic>{
    'CFBundleIdentifier': 'com.amanmaheshwari.wheelio.customer',
    'CFBundleShortVersionString': '1.0.4',
    'CFBundleVersion': '6',
    'DTSDKName': 'iphoneos26.0',
  };
  final distribution = <String, dynamic>{
    'application-identifier': '28JNT7H8KA.com.amanmaheshwari.wheelio.customer',
    'com.apple.developer.team-identifier': '28JNT7H8KA',
    'aps-environment': 'production',
    'get-task-allow': false,
  };
  store.checkDistribution(storeInfo, distribution, 'customer');
  for (final invalid in [
    {...distribution, 'aps-environment': 'development'},
    {...distribution, 'get-task-allow': true},
    {...distribution, 'com.apple.developer.team-identifier': '8CCQQM7TP3'},
    {
      ...distribution,
      'application-identifier': '28JNT7H8KA.com.amanmaheshwari.wheelio.captain',
    },
  ]) {
    rejects(
      () => store.checkDistribution(storeInfo, invalid, 'customer'),
      'Development/wrong-team/wrong-role IPA must not pass as a store export.',
    );
  }
  final phone = {
    'id': 'phone-1',
    'name': 'iPhone',
    'targetPlatform': 'ios',
    'emulator': false,
    'isSupported': true,
  };
  final simulator = {...phone, 'id': 'simulator', 'emulator': true};
  final unsupported = {...phone, 'id': 'unsupported', 'isSupported': false};
  expect(
    ios.selectDevice([simulator, unsupported, phone], null) == 'phone-1',
    'Only supported physical iPhones can be installed.',
  );
  rejects(
    () => ios.selectDevice([simulator], null),
    'Simulator was selected for camera/UPI acceptance.',
  );
  rejects(
    () => ios.selectDevice([
      phone,
      {...phone, 'id': 'phone-2'},
    ], null),
    'Multiple phones must require explicit selection.',
  );
  rejects(
    () => ios.selectDevice([phone], 'missing'),
    'Missing requested device must fail.',
  );
  expect(
    ios.selectDevice([
          phone,
          {...phone, 'id': 'phone-2'},
        ], 'phone-2') ==
        'phone-2',
    'Explicit selection must be honored.',
  );
  final manifest = <String, dynamic>{
    'plugins': {
      'ios': [
        {'name': 'firebase_core', 'native_build': true},
        {'name': 'razorpay_flutter', 'native_build': true},
        {'name': 'ffi_only_plugin', 'native_build': false},
      ],
    },
  };
  const stale =
      'DEPENDENCIES:\n  - firebase_core (from `plugins/firebase_core/ios`)\nSPEC REPOS:\n  trunk:\n    - razorpay_flutter\n';
  expect(
    ios.missingPods(manifest, stale).join(',') == 'razorpay_flutter',
    'A checksum/repo mention cannot replace an installed native plugin.',
  );
  expect(
    ios
        .missingPods(
          manifest,
          stale.replaceFirst(
            'SPEC REPOS:',
            '  - razorpay_flutter (from `plugins/razorpay_flutter/ios`)\nSPEC REPOS:',
          ),
        )
        .isEmpty,
    'Compatible native plugins should pass.',
  );
  ios.checkSource(Directory.fromUri(Platform.script.resolve('../../../')), [
    'customer',
    'captain',
  ]);
  final root = Directory.fromUri(Platform.script.resolve('../../../'));
  final native = '${root.path}/apps/flutter/customer/ios';
  final info = File('$native/Runner/Info.plist').readAsStringSync();
  final project = File(
    '$native/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();
  final entitlements = File(
    '$native/Runner/Runner.entitlements',
  ).readAsStringSync();
  final podfile = File('$native/Podfile').readAsStringSync();
  final scheme = File(
    '$native/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme',
  ).readAsStringSync();
  void capabilities({
    String? p,
    String? e,
    String? pod,
    String? s,
    String? i,
  }) => ios.checkCapabilities(
    app: 'customer',
    info: i ?? info,
    project: p ?? project,
    entitlements: e ?? entitlements,
    podfile: pod ?? podfile,
    scheme: s ?? scheme,
  );
  rejects(
    () => capabilities(p: project.replaceFirst('28JNT7H8KA', '8CCQQM7TP3')),
    'One stale signing configuration must fail before building.',
  );
  rejects(
    () => capabilities(
      e: entitlements.replaceFirst('aps-environment', 'missing-entitlement'),
    ),
    'A signing entitlement cannot be replaced by a background mode.',
  );
  rejects(
    () => capabilities(
      pod: podfile.replaceFirst('BYPASS_PERMISSION_LOCATION_ALWAYS=1', ''),
    ),
    'Foreground-only location must not depend on manual Mac changes.',
  );
  rejects(
    () => capabilities(
      s: scheme.replaceFirst(
        'buildConfiguration = "Release"',
        'buildConfiguration = "Debug"',
      ),
    ),
    'Disconnected-device acceptance must not accidentally install a Debug app.',
  );
  rejects(
    () => capabilities(i: info.replaceFirst('<string>phonepe</string>', '')),
    'The native payment-app query schemes must be preserved.',
  );
  stdout.writeln(
    'iOS tooling checks passed: arguments, device selection, native dependency completeness and both app configurations.',
  );
}
