// Regenerates `lib/src/version.dart` from `version:` in pubspec.yaml.
//
// Run after every version bump:
//
//   dart run tool/sync_version.dart
//
// `test/version_test.dart` asserts the two agree, so forgetting this fails the
// test suite rather than shipping a wrong `wrapper_version` to the backend.
//
// Deliberately parses pubspec.yaml with a regex instead of taking a `yaml`
// dependency: this runs outside the published package and `version:` at the
// top level is the one line it needs.
import 'dart:io';

void main() {
  final File pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln('Run this from the package root (pubspec.yaml not found).');
    exit(1);
  }

  final RegExpMatch? match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());

  if (match == null) {
    stderr.writeln('No top-level `version:` found in pubspec.yaml.');
    exit(1);
  }

  final String version = match.group(1)!;
  final File target = File('lib/src/version.dart');
  final String existing = target.readAsStringSync();
  final String updated = existing.replaceFirst(
    RegExp(r"const String packageVersion = '[^']*';"),
    "const String packageVersion = '$version';",
  );

  if (existing == updated) {
    stdout.writeln('lib/src/version.dart already at $version.');
    return;
  }

  target.writeAsStringSync(updated);
  stdout.writeln('lib/src/version.dart updated to $version.');
}
