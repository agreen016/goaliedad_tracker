import 'package:hive/hive.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

Future<void> main() async {
  // Initialize Hive with same path as app
  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Hive.init(hivePath);
  
  try {
    final box = await Hive.openBox('zone_layouts');
    print('Before clear: ${box.length} items');
    await box.clear();
    print('✓ Cleared all zone layouts from Hive');
    print('After clear: ${box.length} items');
  } catch (e) {
    print('Error: $e');
  }
  
  await Hive.close();
}
