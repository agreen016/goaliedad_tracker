import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// One-off runner to print the application documents directory used by
/// `getApplicationDocumentsDirectory()` (the location where the app
/// stores Hive files when using `Hive.initFlutter`).
///
/// Run with:
/// flutter run -d linux -t bin/print_app_docs_dir.dart

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final dir = await getApplicationDocumentsDirectory();
    print('Application documents directory: ${dir.path}');
    exit(0);
  } catch (e) {
    print('Failed to get application documents directory: $e');
    exit(2);
  }
}
