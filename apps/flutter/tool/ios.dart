// Standalone Dart: uses the SDK bundled with Flutter, with no Node dependency.
import 'dart:convert';
import 'dart:io';

const usage = '''WashKrew iPhone build tools (run from any directory)
  bash apps/flutter/tool/run-ios.sh                     Build + install both apps
  bash apps/flutter/tool/run-ios.sh customer            Customer only
  bash apps/flutter/tool/run-ios.sh captain             Captain only
  bash apps/flutter/tool/run-ios.sh --prepare           Resolve plugins; prepare Xcode
  bash apps/flutter/tool/run-ios.sh --no-codesign       Compile both; no phone/signing
  bash apps/flutter/tool/run-ios.sh --device IPHONE_ID  Select one physical phone
  bash apps/flutter/tool/run-ios.sh --build-number 2    Set an iOS build number
  bash apps/flutter/tool/live.sh customer              Hot reload (captain also works)
  dart apps/flutter/tool/ios.dart check                Read-only source checks
Add --demo only for the labelled sample app. Firebase is the default.
Mac prerequisites: Flutter 3.38.6 (tested), Xcode with iOS SDK, CocoaPods.
See docs/MAC-HANDOFF.md for signing, Apple push setup and device acceptance.''';

class IosArguments {
  IosArguments(List<String> arguments) {
    if (arguments.isEmpty)
      throw const FormatException('Choose build, run or check.');
    action = arguments.first;
    if (!['build', 'run', 'check'].contains(action))
      throw FormatException('Unknown action: $action');
    for (var i = 1; i < arguments.length; i++) {
      final arg = arguments[i];
      switch (arg) {
        case 'customer':
        case 'captain':
        case 'all':
        case 'customer captain':
          if (selection != null)
            throw const FormatException('Choose the apps once.');
          selection = arg;
        case '--demo':
          demo = true;
        case '--prepare':
          prepare = true;
        case '--no-codesign':
          noCodesign = true;
        case '--device':
        case '--build-number':
          if (++i == arguments.length || arguments[i].startsWith('--'))
            throw FormatException('$arg needs a value.');
          if (arg == '--device') {
            device = arguments[i];
          } else {
            buildNumber = arguments[i];
            if (!RegExp(r'^[1-9][0-9]*$').hasMatch(buildNumber!))
              throw const FormatException(
                'Build number must be a positive integer.',
              );
          }
        default:
          throw FormatException('Unknown argument: $arg');
      }
    }
    if (action != 'build' && (prepare || noCodesign || buildNumber != null))
      throw const FormatException('Build options require run-ios.sh.');
    if ((prepare || noCodesign) && device != null)
      throw const FormatException(
        '--device is only used when installing/running.',
      );
    if (prepare && noCodesign)
      throw const FormatException('Choose --prepare or --no-codesign.');
    if (action == 'check' && (demo || device != null))
      throw const FormatException(
        'Source checks do not accept runtime options.',
      );
    if (action == 'run' && ['all', 'customer captain'].contains(selection))
      throw const FormatException('Hot reload runs one app at a time.');
  }
  late final String action;
  String? selection, device, buildNumber;
  bool demo = false, prepare = false, noCodesign = false;
  List<String> get apps => switch (selection) {
    'customer' => ['customer'],
    'captain' => ['captain'],
    _ => action == 'run' ? ['customer'] : ['customer', 'captain'],
  };
  List<String> get defines => demo ? ['--dart-define=WHEELIO_DEMO=true'] : [];
}

String selectDevice(Object? decoded, String? requested) {
  if (decoded is! List)
    throw const FormatException('Unexpected Flutter device list.');
  final devices = decoded
      .whereType<Map>()
      .where(
        (d) =>
            d['targetPlatform'] == 'ios' &&
            d['emulator'] == false &&
            d['isSupported'] != false &&
            d['id'] is String &&
            (d['id'] as String).isNotEmpty,
      )
      .toList();
  if (requested != null) {
    if (devices.any((d) => d['id'] == requested)) return requested;
    throw StateError(
      'The selected physical iPhone is not available. Unlock it and trust this Mac.',
    );
  }
  if (devices.isEmpty)
    throw StateError(
      'No physical iPhone found. Connect and unlock it, trust this Mac, and enable Developer Mode.',
    );
  if (devices.length > 1)
    throw StateError(
      'Several iPhones are connected. Use --device with one ID:\n${devices.map((d) => '${d['name']}: ${d['id']}').join('\n')}',
    );
  return devices.single['id'] as String;
}

List<String> missingPods(Map<String, dynamic> manifest, String lock) {
  final plugins = (manifest['plugins'] as Map)['ios'] as List;
  final dependencies = lock
      .split('DEPENDENCIES:')
      .skip(1)
      .join('DEPENDENCIES:')
      .split('SPEC REPOS:')
      .first;
  return plugins
      .whereType<Map>()
      .where((p) => p['native_build'] != false)
      .map((p) => p['name'] as String)
      .where((name) => !dependencies.contains('- $name ('))
      .toList();
}

void checkSource(Directory root, List<String> apps) {
  final options = File(
    '${root.path}/apps/flutter/packages/washkrew_firebase/lib/src/ios_options.dart',
  ).readAsStringSync();
  for (final app in apps) {
    final ios = '${root.path}/apps/flutter/$app/ios';
    final info = File('$ios/Runner/Info.plist').readAsStringSync();
    final firebase = File(
      '$ios/Runner/GoogleService-Info.plist',
    ).readAsStringSync();
    final project = File(
      '$ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final bundle = 'com.amanmaheshwari.wheelio.$app';
    final id = app == 'customer'
        ? 'e608aa639acba895ef9686'
        : 'a3ecaa80486a8314ef9686';
    for (final key in [
      'NSCameraUsageDescription',
      'NSPhotoLibraryUsageDescription',
      'NSMicrophoneUsageDescription',
      'NSLocationWhenInUseUsageDescription',
    ]) {
      if (!RegExp('<key>$key</key>\\s*<string>[^<]+</string>').hasMatch(info))
        throw StateError('$app: missing $key.');
    }
    if (!info.contains('app-1-763324255731-ios-$id') ||
        !firebase.contains('1:763324255731:ios:$id') ||
        !firebase.contains(bundle) ||
        !options.contains(bundle) ||
        !options.contains('1:763324255731:ios:$id') ||
        !project.contains('PRODUCT_BUNDLE_IDENTIFIER = $bundle;')) {
      throw StateError(
        '$app: Firebase registration, Auth callback and bundle ID must agree.',
      );
    }
    if (RegExp(
      r'<key>FirebaseAppDelegateProxyEnabled</key>\s*<false\s*/>',
    ).hasMatch(info))
      throw StateError(
        '$app: Firebase Auth/Messaging delegate integration is disabled.',
      );
    final delegate = File('$ios/Runner/AppDelegate.swift').readAsStringSync();
    if (!delegate.contains('import GoogleMaps') ||
        !delegate.contains('washkrew/maps') ||
        !delegate.contains('GMSServices.provideAPIKey')) {
      throw StateError(
        '$app: runtime Maps key setup is missing from AppDelegate.',
      );
    }
    for (final file in ['Debug', 'Release']) {
      final config = File('$ios/Flutter/$file.xcconfig').readAsStringSync();
      if (!config.contains('Pods-Runner.') ||
          !config.contains('Generated.xcconfig'))
        throw StateError(
          '$app: $file must include CocoaPods and Flutter settings.',
        );
    }
    final icons = Directory('$ios/Runner/Assets.xcassets/AppIcon.appiconset');
    final catalog =
        jsonDecode(File('${icons.path}/Contents.json').readAsStringSync())
            as Map;
    for (final icon in catalog['images'] as List) {
      if (icon['filename'] != null &&
          !File('${icons.path}/${icon['filename']}').existsSync())
        throw StateError('$app: a declared app icon is missing.');
    }
    stdout.writeln('$app: native source configuration OK.');
  }
}

class Commands {
  Future<String> run(
    String executable,
    List<String> args,
    String cwd, {
    bool capture = false,
  }) async {
    stdout.writeln('> $executable ${args.join(' ')}');
    try {
      if (capture) {
        final result = await Process.run(
          executable,
          args,
          workingDirectory: cwd,
        );
        if (result.exitCode != 0) {
          stderr.write(result.stderr);
          throw ProcessException(
            executable,
            args,
            'Command failed.',
            result.exitCode,
          );
        }
        return result.stdout.toString();
      }
      final process = await Process.start(
        executable,
        args,
        workingDirectory: cwd,
        mode: ProcessStartMode.inheritStdio,
      );
      final code = await process.exitCode;
      if (code != 0)
        throw ProcessException(executable, args, 'Command failed.', code);
      return '';
    } on ProcessException {
      stderr.writeln(
        'Failed in $cwd. See docs/MAC-HANDOFF.md for setup and signing fixes.',
      );
      rethrow;
    }
  }
}

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout.writeln(usage);
    return;
  }
  try {
    final args = IosArguments(arguments);
    final root = Directory.fromUri(Platform.script.resolve('../../../'));
    checkSource(root, args.apps);
    if (args.action == 'check') return;
    if (!Platform.isMacOS)
      throw StateError(
        'iPhone compilation needs macOS and Xcode. Source checks passed on this machine.',
      );
    final commands = Commands();
    final flutter = Platform.environment['FLUTTER_BIN'] ?? 'flutter';
    final version =
        jsonDecode(
              await commands.run(
                flutter,
                ['--version', '--machine'],
                root.path,
                capture: true,
              ),
            )
            as Map;
    stdout.writeln(
      'Flutter ${version['frameworkVersion']}; tested with 3.38.6. Locked Dart dependencies will be enforced.',
    );
    await commands.run('xcodebuild', ['-version'], root.path);
    await commands.run('xcrun', [
      '--sdk',
      'iphoneos',
      '--show-sdk-path',
    ], root.path);
    await commands.run('pod', ['--version'], root.path);
    String? device;
    if (!args.prepare && !args.noCodesign)
      device = selectDevice(
        jsonDecode(
          await commands.run(
            flutter,
            ['devices', '--machine'],
            root.path,
            capture: true,
          ),
        ),
        args.device,
      );
    await commands.run(flutter, ['precache', '--ios'], root.path);
    stdout.writeln(
      args.demo
          ? 'LABELLED DEMO BUILD — sample data only.'
          : 'FIREBASE BUILD — payment mode comes from the server (currently test).',
    );
    for (final app in args.apps) {
      final cwd = '${root.path}/apps/flutter/$app';
      stdout.writeln('\nPreparing $app');
      await commands.run('plutil', [
        '-lint',
        'ios/Runner/Info.plist',
        'ios/Runner/GoogleService-Info.plist',
      ], cwd);
      // A copied Windows checkout can contain generated absolute paths. Let
      // Flutter remove and regenerate its own files, retaining source/pod locks.
      await commands.run(flutter, ['clean'], cwd);
      await commands.run(flutter, ['pub', 'get', '--enforce-lockfile'], cwd);
      // Refresh specs and add new native plugins; retain compatible locked pods.
      // Flutter pub get regenerates Generated.xcconfig/plugin metadata on Mac.
      await commands.run('pod', ['install', '--repo-update'], '$cwd/ios');
      final manifest =
          jsonDecode(
                File('$cwd/.flutter-plugins-dependencies').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final missing = missingPods(
        manifest,
        File('$cwd/ios/Podfile.lock').readAsStringSync(),
      );
      if (missing.isNotEmpty)
        throw StateError(
          '$app: native plugins missing after pod install: ${missing.join(', ')}',
        );
      final buildFlags = [
        ...args.defines,
        if (args.buildNumber != null) '--build-number=${args.buildNumber}',
      ];
      if (args.prepare) {
        await commands.run(flutter, [
          'build',
          'ios',
          '--release',
          '--config-only',
          '--no-codesign',
          '--no-pub',
          ...buildFlags,
        ], cwd);
        stdout.writeln('Ready to open $cwd/ios/Runner.xcworkspace in Xcode.');
      } else if (args.action == 'run') {
        await commands.run(flutter, [
          'run',
          '--no-pub',
          '-d',
          device!,
          ...args.defines,
        ], cwd);
      } else {
        await commands.run(flutter, [
          'build',
          'ios',
          '--release',
          '--no-pub',
          if (args.noCodesign) '--no-codesign',
          ...buildFlags,
        ], cwd);
        if (!args.noCodesign)
          await commands.run(flutter, [
            'install',
            '--release',
            '-d',
            device!,
          ], cwd);
      }
    }
    stdout.writeln(
      '\n${args.prepare
          ? 'Xcode preparation'
          : args.noCodesign
          ? 'Unsigned compilation'
          : 'iPhone build/run'} complete. Commit Mac-resolved Podfile.lock changes after a successful build.',
    );
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n$usage');
    exitCode = 2;
  } on Object catch (e) {
    stderr.writeln(e);
    exitCode = 1;
  }
}
