import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/zone_polygon.dart';

Future<void> main() async {
  // Normalized coordinates (0-1) where 0,0 is top-left
  // Hockey rink with net at bottom
  
  final zones = <ZonePolygon>[
    // 1. Left side of net
    ZonePolygon(
      id: 'zone_1',
      name: 'Left Side Net',
      points: [
        ZonePoint(0.35, 0.88),
        ZonePoint(0.35, 0.98),
        ZonePoint(0.45, 0.98),
        ZonePoint(0.45, 0.90),
      ],
    ),
    
    // 2. Right side of net
    ZonePolygon(
      id: 'zone_2',
      name: 'Right Side Net',
      points: [
        ZonePoint(0.55, 0.90),
        ZonePoint(0.55, 0.98),
        ZonePoint(0.65, 0.98),
        ZonePoint(0.65, 0.88),
      ],
    ),
    
    // 3. Crease (in front of net)
    ZonePolygon(
      id: 'zone_3',
      name: 'Crease',
      points: [
        ZonePoint(0.43, 0.88),
        ZonePoint(0.40, 0.83),
        ZonePoint(0.60, 0.83),
        ZonePoint(0.57, 0.88),
      ],
    ),
    
    // 4. Low Slot
    ZonePolygon(
      id: 'zone_4',
      name: 'Low Slot',
      points: [
        ZonePoint(0.38, 0.83),
        ZonePoint(0.38, 0.72),
        ZonePoint(0.62, 0.72),
        ZonePoint(0.62, 0.83),
      ],
    ),
    
    // 5. High Slot
    ZonePolygon(
      id: 'zone_5',
      name: 'High Slot',
      points: [
        ZonePoint(0.38, 0.72),
        ZonePoint(0.38, 0.58),
        ZonePoint(0.62, 0.58),
        ZonePoint(0.62, 0.72),
      ],
    ),
    
    // 6. Bottom-Left Faceoff Circle
    ZonePolygon(
      id: 'zone_6',
      name: 'Bottom-Left Circle',
      points: [
        ZonePoint(0.22, 0.68),
        ZonePoint(0.18, 0.72),
        ZonePoint(0.18, 0.78),
        ZonePoint(0.22, 0.82),
        ZonePoint(0.28, 0.82),
        ZonePoint(0.32, 0.78),
        ZonePoint(0.32, 0.72),
        ZonePoint(0.28, 0.68),
      ],
    ),
    
    // 7. Bottom-Right Faceoff Circle
    ZonePolygon(
      id: 'zone_7',
      name: 'Bottom-Right Circle',
      points: [
        ZonePoint(0.72, 0.68),
        ZonePoint(0.68, 0.72),
        ZonePoint(0.68, 0.78),
        ZonePoint(0.72, 0.82),
        ZonePoint(0.78, 0.82),
        ZonePoint(0.82, 0.78),
        ZonePoint(0.82, 0.72),
        ZonePoint(0.78, 0.68),
      ],
    ),
    
    // 8. Top-Left Faceoff Circle
    ZonePolygon(
      id: 'zone_8',
      name: 'Top-Left Circle',
      points: [
        ZonePoint(0.22, 0.22),
        ZonePoint(0.18, 0.26),
        ZonePoint(0.18, 0.32),
        ZonePoint(0.22, 0.36),
        ZonePoint(0.28, 0.36),
        ZonePoint(0.32, 0.32),
        ZonePoint(0.32, 0.26),
        ZonePoint(0.28, 0.22),
      ],
    ),
    
    // 9. Top-Right Faceoff Circle
    ZonePolygon(
      id: 'zone_9',
      name: 'Top-Right Circle',
      points: [
        ZonePoint(0.72, 0.22),
        ZonePoint(0.68, 0.26),
        ZonePoint(0.68, 0.32),
        ZonePoint(0.72, 0.36),
        ZonePoint(0.78, 0.36),
        ZonePoint(0.82, 0.32),
        ZonePoint(0.82, 0.26),
        ZonePoint(0.78, 0.22),
      ],
    ),
    
    // 10. Above Bottom-Left Circle
    ZonePolygon(
      id: 'zone_10',
      name: 'Above Bottom-Left Circle',
      points: [
        ZonePoint(0.18, 0.58),
        ZonePoint(0.18, 0.68),
        ZonePoint(0.32, 0.68),
        ZonePoint(0.32, 0.58),
      ],
    ),
    
    // 11. Above Bottom-Right Circle
    ZonePolygon(
      id: 'zone_11',
      name: 'Above Bottom-Right Circle',
      points: [
        ZonePoint(0.68, 0.58),
        ZonePoint(0.68, 0.68),
        ZonePoint(0.82, 0.68),
        ZonePoint(0.82, 0.58),
      ],
    ),
    
    // 12. Above Top-Left Circle
    ZonePolygon(
      id: 'zone_12',
      name: 'Above Top-Left Circle',
      points: [
        ZonePoint(0.18, 0.12),
        ZonePoint(0.18, 0.22),
        ZonePoint(0.32, 0.22),
        ZonePoint(0.32, 0.12),
      ],
    ),
    
    // 13. Above Top-Right Circle
    ZonePolygon(
      id: 'zone_13',
      name: 'Above Top-Right Circle',
      points: [
        ZonePoint(0.68, 0.12),
        ZonePoint(0.68, 0.22),
        ZonePoint(0.82, 0.22),
        ZonePoint(0.82, 0.12),
      ],
    ),
  ];

  // Save to Hive
  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Hive.init(hivePath);
  Hive.registerAdapter(ZonePolygonAdapter());
  Hive.registerAdapter(ZonePointAdapter());

  final box = await Hive.openBox('zone_layouts');
  
  // Save for all team IDs (you can adjust this)
  final layoutKey = 'zone_layout_1'; // Assuming team ID 1
  final json = jsonEncode(zones.map((z) => z.toJson()).toList());
  await box.put(layoutKey, json);
  
  print('✓ Generated ${zones.length} zones');
  print('✓ Saved to Hive with key: $layoutKey');
  
  // Also save to JSON file as backup
  final jsonFile = File(p.join(repoRoot, 'assets', 'zones', 'default_goalie_zones.json'));
  await jsonFile.writeAsString(JsonEncoder.withIndent('  ').convert(
    zones.map((z) => z.toJson()).toList()
  ));
  print('✓ Saved to ${jsonFile.path}');
  
  await Hive.close();
}
