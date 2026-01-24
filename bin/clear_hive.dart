import 'dart:io';
import 'package:path/path.dart' as p;

/// Deletes a Hive data directory. Pass an explicit path to delete:
///
/// dart run bin/clear_hive.dart /path/to/hive_data
///
/// If no path is provided the script will try the repository-local
/// '.dart_tool/hive_data' and otherwise print guidance where
/// Hive data is typically stored for desktop Flutter apps.
void main(List<String> args) {
  final repoRoot = Directory.current.path;
  String hivePath;

  if (args.isNotEmpty) {
    hivePath = args.first;
  } else {
    hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  }

  final dir = Directory(hivePath);
  if (!dir.existsSync()) {
    print('No hive data directory found at $hivePath');
    if (args.isEmpty) {
      print('\nCommon locations for Hive data (desktop):');
      print('  - macOS: ~/Library/Application Support/<app>');
      print('  - Linux: ~/.local/share/<app> or ~/.config/<app>');
      print(
        'If you run the app on desktop the actual Hive path is the application documents directory for the platform.',
      );
      print(
        'To delete your app data, re-run this script with the path to your Hive data directory:',
      );
      print('  dart run bin/clear_hive.dart /path/to/hive_data');
    }
    exit(1);
  }

  try {
    dir.deleteSync(recursive: true);
    print('Deleted hive data directory: $hivePath');
  } catch (e) {
    print('Failed to delete hive data directory: $e');
    exit(2);
  }
}
