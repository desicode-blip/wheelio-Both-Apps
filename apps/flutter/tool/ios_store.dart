// App Store archive verification. No account credentials and no upload operations.
import 'dart:convert';
import 'dart:io';

void checkSdk(String value) {
  final major = int.tryParse(value.trim().split('.').first);
  if (major == null || major < 26) {
    throw StateError(
      'App Store uploads require iOS SDK 26 or later (Xcode 26+). Select full Xcode with xcode-select.',
    );
  }
}

void checkDistribution(
  Map<String, dynamic> info,
  Map<String, dynamic> entitlements,
  String role,
) {
  final bundle = 'com.amanmaheshwari.wheelio.$role';
  if (info['CFBundleIdentifier'] != bundle ||
      !RegExp(
        r'^\d+\.\d+\.\d+$',
      ).hasMatch('${info['CFBundleShortVersionString']}') ||
      !RegExp(r'^[1-9]\d*$').hasMatch('${info['CFBundleVersion']}')) {
    throw StateError('$role: incorrect exported package/version.');
  }
  if (entitlements['com.apple.developer.team-identifier'] != '28JNT7H8KA' ||
      entitlements['application-identifier'] != '28JNT7H8KA.$bundle' ||
      entitlements['aps-environment'] != 'production' ||
      entitlements['get-task-allow'] == true) {
    throw StateError(
      '$role: the exported app needs team 28JNT7H8KA, production APNs and distribution signing (get-task-allow off). Check the distribution profile; do not disable verification.',
    );
  }
  checkSdk('${info['DTSDKName']}'.replaceFirst('iphoneos', ''));
}

void checkSource(Directory root, List<String> roles) {
  final options = File(
    '${root.path}/apps/flutter/tool/AppStoreExportOptions.plist',
  ).readAsStringSync();
  if (!options.contains('<string>app-store-connect</string>') ||
      !options.contains('<key>destination</key><string>export</string>') ||
      !options.contains('<key>teamID</key><string>28JNT7H8KA</string>')) {
    throw StateError(
      'App Store export must be local-only and use the existing paid team.',
    );
  }
  for (final role in roles) {
    final path = '${root.path}/apps/flutter/$role/ios';
    final privacy = File(
      '$path/Runner/PrivacyInfo.xcprivacy',
    ).readAsStringSync();
    final project = File(
      '$path/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    if (!project.contains('PrivacyInfo.xcprivacy in Resources') ||
        !privacy.contains('<key>NSPrivacyTracking</key>') ||
        !privacy.contains('NSPrivacyCollectedDataTypePhoneNumber') ||
        !privacy.contains('C617.1')) {
      throw StateError(
        '$role: the app privacy manifest must be bundled in Runner resources.',
      );
    }
  }
}

Future<String> _run(String command, List<String> args, String cwd) async {
  final result = await Process.run(command, args, workingDirectory: cwd);
  if (result.exitCode != 0)
    throw ProcessException(
      command,
      args,
      'Archive validation failed. ${result.stderr}',
      result.exitCode,
    );
  return result.stdout.toString();
}

Future<Map<String, dynamic>> _plist(File file, String cwd) async =>
    jsonDecode(
          await _run('plutil', ['-convert', 'json', '-o', '-', file.path], cwd),
        )
        as Map<String, dynamic>;

Future<void> verifyAndCollect(Directory root, String role) async {
  final cwd = '${root.path}/apps/flutter/$role';
  final archive = Directory('$cwd/build/ios/archive/Runner.xcarchive');
  if (!archive.existsSync() ||
      !Directory('${archive.path}/dSYMs').existsSync()) {
    throw StateError(
      '$role: archive/dSYMs missing. Nothing is ready for upload.',
    );
  }
  final ipaDir = Directory('$cwd/build/ios/ipa');
  final ipas = ipaDir.existsSync()
      ? ipaDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.ipa'))
            .toList()
      : <File>[];
  if (ipas.length != 1)
    throw StateError(
      '$role: a successful archive is not enough; expected exactly one exported IPA. Check Xcode distribution signing/export logs.',
    );
  final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );
  final output = Directory('${root.path}/build/store/ios/$role-$stamp')
    ..createSync(recursive: true);
  // Extract only our freshly exported IPA into a unique generated directory.
  final inspection = Directory('${output.path}/inspection')..createSync();
  await _run('ditto', ['-x', '-k', ipas.single.path, inspection.path], cwd);
  final apps = Directory('${inspection.path}/Payload')
      .listSync()
      .whereType<Directory>()
      .where((d) => d.path.endsWith('.app'))
      .toList();
  if (apps.length != 1) throw StateError('$role: invalid IPA payload.');
  final app = apps.single;
  final info = await _plist(File('${app.path}/Info.plist'), cwd);
  await _run('codesign', ['--verify', '--deep', '--strict', app.path], cwd);
  // Capture entitlements privately; emit only the validation outcome.
  final signed = await _run('codesign', [
    '-d',
    '--entitlements',
    ':-',
    app.path,
  ], cwd);
  final xml = signed.indexOf('<?xml');
  if (xml < 0) throw StateError('$role: signed entitlements not readable.');
  final entFile = File('${inspection.path}/signed-entitlements.plist')
    ..writeAsStringSync(signed.substring(xml));
  checkDistribution(info, await _plist(entFile, cwd), role);
  final privacy = await _plist(File('${app.path}/PrivacyInfo.xcprivacy'), cwd);
  if (privacy['NSPrivacyTracking'] != false ||
      (privacy['NSPrivacyCollectedDataTypes'] as List?)?.isEmpty != false) {
    throw StateError(
      '$role: exported app privacy manifest missing/incomplete.',
    );
  }
  final profileFile = File('${app.path}/embedded.mobileprovision');
  final profileXml = await _run('security', [
    'cms',
    '-D',
    '-i',
    profileFile.path,
  ], cwd);
  // Provisioning profiles contain Date/Data values that plutil cannot convert
  // wholesale to JSON. Inspect the distribution markers in the decoded XML.
  if (profileXml.contains('<key>ProvisionedDevices</key>') ||
      RegExp(
        r'<key>ProvisionsAllDevices</key>\s*<true\s*/>',
      ).hasMatch(profileXml)) {
    throw StateError(
      '$role: export is development/ad-hoc/enterprise, not App Store distribution.',
    );
  }
  final prefix =
      'WashKrew-${role == 'customer' ? 'Customer' : 'Captain'}-${info['CFBundleShortVersionString']}-${info['CFBundleVersion']}';
  final copy = ipas.single.copySync('${output.path}/$prefix.ipa');
  await _run('ditto', [archive.path, '${output.path}/Runner.xcarchive'], cwd);
  final hash = (await _run('shasum', [
    '-a',
    '256',
    copy.path,
  ], cwd)).split(' ').first;
  final source = (await _run('git', ['rev-parse', 'HEAD'], root.path)).trim();
  final dirty = (await _run('git', [
    'status',
    '--porcelain',
    '--untracked-files=no',
  ], root.path)).trim().isNotEmpty;
  File('${output.path}/release.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'role': role, 'bundle': info['CFBundleIdentifier'], 'version': info['CFBundleShortVersionString'], 'build': info['CFBundleVersion'], 'sdk': info['DTSDKName'], 'sourceCommit': source, 'sourceDirty': dirty, 'sha256': hash, 'productionApns': true, 'distributionSignatureVerified': true, 'status': 'Exported locally; not uploaded or submitted. Generate/review Xcode aggregate privacy report before submission.'})}\n',
  );
  // All paths were created by this invocation beneath the generated output.
  if (!inspection.absolute.path.startsWith(
    '${output.absolute.path}${Platform.pathSeparator}',
  ))
    throw StateError('Unsafe generated inspection path.');
  inspection.deleteSync(recursive: true);
  stdout.writeln(
    '$role: verified App Store IPA, archive and dSYMs at ${output.path}',
  );
}
