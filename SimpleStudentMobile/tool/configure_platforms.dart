// Generates the android/ and ios/ folders and allows HTTP calls to the
// local SimpleStudentApi.
//
//   cd SimpleStudentMobile
//   flutter pub get
//   dart run tool/configure_platforms.dart
//
// Safe to run many times: existing files are not overwritten and every
// change is applied only once.
//
// Why is this needed?
// * The repository keeps only the Dart code (lib/, test/, pubspec.yaml).
//   `flutter create .` generates the native Android / iOS projects for the
//   Flutter version installed on YOUR computer.
// * Minimum iOS version is set to 17.0 (Xcode project + Podfile).
// * The lab API runs on plain HTTP (http://...:6001). Android 9+ and iOS block
//   plain HTTP by default, so we allow it (for development only!).

import 'dart:io';

const org = 'lt.kaunokolegija';
const projectName = 'simple_student_mobile';
const appLabel = 'Simple Student';
const iosMinVersion = '17.0';

Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this script from the SimpleStudentMobile folder.');
    exit(1);
  }

  await _createPlatformFolders();
  _patchAndroidManifest();
  _patchInfoPlist();
  _patchIosMinVersion();

  stdout.writeln('\nDone. Next steps:');
  stdout.writeln('  flutter devices');
  stdout.writeln('  flutter run');
}

Future<void> _createPlatformFolders() async {
  final needsAndroid = !Directory('android').existsSync();
  final needsIos = !Directory('ios').existsSync();
  if (!needsAndroid && !needsIos) {
    stdout.writeln('✔ android/ and ios/ already exist – flutter create skipped.');
    return;
  }

  stdout.writeln('→ flutter create . --platforms=android,ios ...');
  final result = await Process.run(
    'flutter',
    [
      'create',
      '.',
      '--platforms=android,ios',
      '--org',
      org,
      '--project-name',
      projectName,
    ],
    runInShell: true, // needed on Windows (flutter.bat)
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln('flutter create failed (exit code ${result.exitCode}).');
    exit(result.exitCode);
  }
}

/// android/app/src/main/AndroidManifest.xml
/// * INTERNET permission (debug builds have it, release builds need it)
/// * usesCleartextTraffic="true" – allow http:// (the lab API has no HTTPS)
/// * app name shown under the icon
void _patchAndroidManifest() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    stdout.writeln('! ${file.path} not found – Android skipped.');
    return;
  }
  var xml = file.readAsStringSync();
  final original = xml;

  if (!xml.contains('android.permission.INTERNET')) {
    xml = xml.replaceFirst(
      '<application',
      '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
    );
  }
  if (!xml.contains('usesCleartextTraffic')) {
    xml = xml.replaceFirst(
      '<application',
      '<application\n        android:usesCleartextTraffic="true"',
    );
  }
  xml = xml.replaceFirst('android:label="$projectName"', 'android:label="$appLabel"');

  if (xml != original) {
    file.writeAsStringSync(xml);
    stdout.writeln('✔ ${file.path}: INTERNET + cleartext HTTP allowed.');
  } else {
    stdout.writeln('✔ ${file.path}: already configured.');
  }
}

/// ios/Runner/Info.plist
/// * NSAppTransportSecurity – allow http:// (App Transport Security)
/// * NSLocalNetworkUsageDescription – text of the "Local Network" permission
///   that a real iPhone/iPad shows when the app calls your PC in the same Wi-Fi
/// * CFBundleDisplayName – app name under the icon
void _patchInfoPlist() {
  final file = File('ios/Runner/Info.plist');
  if (!file.existsSync()) {
    stdout.writeln('! ${file.path} not found – iOS skipped.');
    return;
  }
  var plist = file.readAsStringSync();
  final original = plist;

  final closingIndex = plist.lastIndexOf('</dict>');
  if (closingIndex < 0) {
    stdout.writeln('! ${file.path}: unexpected format – please edit it by hand (see README).');
    return;
  }

  final additions = StringBuffer();
  if (!plist.contains('NSAppTransportSecurity')) {
    additions
      ..writeln('\t<key>NSAppTransportSecurity</key>')
      ..writeln('\t<dict>')
      ..writeln('\t\t<key>NSAllowsArbitraryLoads</key>')
      ..writeln('\t\t<true/>')
      ..writeln('\t\t<key>NSAllowsLocalNetworking</key>')
      ..writeln('\t\t<true/>')
      ..writeln('\t</dict>');
  }
  if (!plist.contains('NSLocalNetworkUsageDescription')) {
    additions
      ..writeln('\t<key>NSLocalNetworkUsageDescription</key>')
      ..writeln('\t<string>The app connects to SimpleStudentApi running on your computer.</string>');
  }
  if (additions.isNotEmpty) {
    plist = plist.substring(0, closingIndex) + additions.toString() + plist.substring(closingIndex);
  }

  plist = plist.replaceFirst(
    RegExp(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)'),
    '<key>CFBundleDisplayName</key>\n\t<string>$appLabel</string>',
  );

  if (plist != original) {
    file.writeAsStringSync(plist);
    stdout.writeln('✔ ${file.path}: HTTP + local network allowed.');
  } else {
    stdout.writeln('✔ ${file.path}: already configured.');
  }
}

/// Minimum iOS version: ios/Runner.xcodeproj (IPHONEOS_DEPLOYMENT_TARGET)
/// and ios/Podfile (platform :ios + the same target for every pod).
void _patchIosMinVersion() {
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  if (project.existsSync()) {
    final text = project.readAsStringSync();
    final patched = text.replaceAll(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;'),
      'IPHONEOS_DEPLOYMENT_TARGET = $iosMinVersion;',
    );
    if (patched != text) {
      project.writeAsStringSync(patched);
      stdout.writeln('✔ ${project.path}: minimum iOS $iosMinVersion.');
    }
  }

  final podfile = File('ios/Podfile');
  if (!podfile.existsSync()) return;
  var pods = podfile.readAsStringSync();
  final original = pods;
  pods = pods.replaceFirst(
    RegExp(r"^#?\s*platform :ios, '[0-9.]+'", multiLine: true),
    "platform :ios, '$iosMinVersion'",
  );
  if (!pods.contains("config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']")) {
    pods = pods.replaceFirst(
      '    flutter_additional_ios_build_settings(target)\n',
      '    flutter_additional_ios_build_settings(target)\n'
          '    target.build_configurations.each do |config|\n'
          "      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '$iosMinVersion'\n"
          '    end\n',
    );
  }
  if (pods != original) {
    podfile.writeAsStringSync(pods);
    stdout.writeln('✔ ${podfile.path}: platform :ios, \'$iosMinVersion\'.');
  } else {
    stdout.writeln('✔ ${podfile.path}: already configured.');
  }
}
