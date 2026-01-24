import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/zone.dart';
import '../widgets/game_rink_view.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/game.dart';
import '../services/stats_aggregator.dart';

class GoalieZoneSavePctScreen extends StatefulWidget {
  final Team team;

  const GoalieZoneSavePctScreen({super.key, required this.team});

  @override
  State<GoalieZoneSavePctScreen> createState() =>
      _GoalieZoneSavePctScreenState();
}

class _GoalieZoneSavePctScreenState extends State<GoalieZoneSavePctScreen> {
  List<ZonePolygon> zones = [];
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    // Always load from the permanent zones file
    final txt = await rootBundle.loadString(
      'assets/zones/default_goalie_zones.json',
    );
    final arr = jsonDecode(txt) as List;
    setState(
      () => zones = arr
          .map((e) => ZonePolygon.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final matrix = _transformationController.value.clone();
    matrix.scale(1.3);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformationController.value.clone();
    matrix.scale(0.7);
    _transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Goalie Zones')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text('${zones.length} zones', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: _zoomIn,
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Zoom In',
                ),
                IconButton(
                  onPressed: _zoomOut,
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Zoom Out',
                ),
                IconButton(
                  onPressed: _resetZoom,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reset Zoom',
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              'Use pinch or zoom buttons to zoom. Pan by dragging.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 5.0,
                  boundaryMargin: const EdgeInsets.all(double.infinity),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/ice_rink.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      // Draw zones
                      if (zones.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ZonesPainter(
                              zones: zones,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ZonesPainter extends CustomPainter {
  final List<ZonePolygon> zones;
  final double width;
  final double height;

  _ZonesPainter({
    required this.zones, 
    required this.width, 
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < zones.length; i++) {
      final zone = zones[i];
      if (zone.points.length < 3) continue;

      final path = Path();
      path.moveTo(zone.points[0].x * width, zone.points[0].y * height);
      for (int j = 1; j < zone.points.length; j++) {
        path.lineTo(zone.points[j].x * width, zone.points[j].y * height);
      }
      path.close();

      // Fill
      final fillPaint = Paint()
        ..color = Colors.blue.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Border
      final borderPaint = Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawPath(path, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_ZonesPainter oldDelegate) => true;
}
