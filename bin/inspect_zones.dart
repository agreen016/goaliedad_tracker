import 'dart:io';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/zone_polygon.dart';

Future<void> main() async {
  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Hive.init(hivePath);
  Hive.registerAdapter(ZonePolygonAdapter());
  Hive.registerAdapter(ZonePointAdapter());

  final zoneBox = await Hive.openBox('zone_layouts');

  print('Hive path: $hivePath');
  print('Zone layouts box open: ${zoneBox.isOpen}, count: ${zoneBox.length}');
  print('Keys: ${zoneBox.keys.toList()}');
  
  for (final key in zoneBox.keys) {
    final value = zoneBox.get(key);
    print('\nKey: $key');
    if (value is List) {
      print('Number of zones: ${value.length}');
      for (int i = 0; i < value.length; i++) {
        final zone = value[i] as ZonePolygon;
        print('  Zone $i: id=${zone.id}, name=${zone.name}, points=${zone.points.length}');
        // Print first few points for reference
        if (zone.points.isNotEmpty) {
          print('    Points: ${zone.points.map((p) => '(${p.x.toStringAsFixed(3)},${p.y.toStringAsFixed(3)})').take(5).join(', ')}...');
        }
      }
    }
  }

  await Hive.close();
}
