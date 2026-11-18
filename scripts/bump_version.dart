// Bumps the `version:` field in pubspec.yaml without external dependencies.
// Usage: dart run scripts/bump_version.dart --level auto --message "feat: …"
// `auto` follows Conventional Commit intent; the build number always advances.
import 'dart:io';

void main(List<String> args) {
  var level = 'auto';
  var message = '';
  for (var index = 0; index < args.length; index++) {
    if (args[index] == '--level' && index + 1 < args.length) {
      level = args[++index].toLowerCase();
    } else if (args[index] == '--message' && index + 1 < args.length) {
      message = args[++index];
    }
  }
  if (!{'auto', 'patch', 'minor', 'major'}.contains(level)) {
    stderr.writeln('level must be auto, patch, minor, or major');
    exitCode = 64;
    return;
  }

  if (level == 'auto') level = _levelFor(message);
  final file = File('pubspec.yaml');
  final source = file.readAsStringSync();
  final match = RegExp(
    r'^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?\s*$',
    multiLine: true,
  ).firstMatch(source);
  if (match == null) {
    stderr.writeln('Unable to parse pubspec.yaml version');
    exitCode = 65;
    return;
  }

  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  final build = (int.tryParse(match.group(4) ?? '') ?? 0) + 1;
  switch (level) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
    case 'minor':
      minor++;
      patch = 0;
    case 'patch':
      patch++;
  }
  final version = '$major.$minor.$patch+$build';
  file.writeAsStringSync(
    source.replaceRange(match.start, match.end, 'version: $version'),
  );
  stdout.writeln(version);
}

String _levelFor(String message) {
  final normalized = message.toLowerCase();
  if (normalized.contains('breaking change') ||
      RegExp(r'^[a-z]+(?:\([^)]*\))?!:').hasMatch(normalized)) {
    return 'major';
  }
  if (RegExp(r'^feat(?:\([^)]*\))?:').hasMatch(normalized)) return 'minor';
  return 'patch';
}
