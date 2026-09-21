import 'dart:io';

import 'package:booleanmaths_flutter_sdk/src/version.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the one place `wrapper_version` can silently go wrong.
///
/// [packageVersion] is what every event reports as `setup.wrapper_version`. It
/// has to be a compile-time constant (Dart cannot read its own package version
/// at run time), which means it is a copy — and the previous release shipped
/// with that copy a version behind, reporting `0.1.2` from `0.1.3`. Nothing
/// failed at the time, because nothing was checking.
void main() {
  test('packageVersion matches version: in pubspec.yaml', () {
    final RegExpMatch? match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync());

    expect(match, isNotNull, reason: 'no top-level `version:` in pubspec.yaml');
    expect(
      packageVersion,
      match!.group(1),
      reason:
          'lib/src/version.dart has drifted from pubspec.yaml. '
          'Run `dart run tool/sync_version.dart`.',
    );
  });
}
