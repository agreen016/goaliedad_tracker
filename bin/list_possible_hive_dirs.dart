import 'dart:io';

void main() async {
  print('Listing possible Hive data directories...');
  final home = Platform.environment['HOME'] ?? '~';
  final candidates = [
    Directory.current.path,
    '$home',
    '$home/.local/share',
    '$home/.local/share/goaliedad_tracker',
    '$home/goaliedad_tracker',
    '$home/Documents',
    '$home/Documents/goaliedad_tracker',
    '$home/.dart_tool/hive_data',
    '/tmp',
  ];
  for (final dir in candidates) {
    print('\nDirectory: $dir');
    try {
      final d = Directory(dir);
      if (await d.exists()) {
        final files = d.listSync();
        for (final f in files) {
          print('  ${f.path}');
        }
      } else {
        print('  (does not exist)');
      }
    } catch (e) {
      print('  (error reading directory: $e)');
    }
  }
}
