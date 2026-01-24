import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/game.dart';
import '../models/zone.dart';
import '../services/stats_aggregator.dart';
import '../widgets/game_rink_view.dart';
import '../widgets/shot_heatmap.dart';
import 'goalie_zone_save_pct_screen.dart';

class GoalieAnalysisScreen extends StatefulWidget {
  final Team team;
  const GoalieAnalysisScreen({super.key, required this.team});

  @override
  State<GoalieAnalysisScreen> createState() => _GoalieAnalysisScreenState();
}

class _GoalieAnalysisScreenState extends State<GoalieAnalysisScreen> {
  String? selectedGoalieId;
  List<ZonePolygon> zones = [];
  Map<String, Map<String, dynamic>>? zoneStats; // zoneId -> stats
  List<Offset> heatmapPoints = [];

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    // Always load from permanent zones file
    try {
      final txt = await rootBundle.loadString('assets/zones/default_goalie_zones.json');
      final arr = jsonDecode(txt) as List;
      setState(
        () => zones = arr
            .map((e) => ZonePolygon.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } catch (e) {
      print('Error loading zones: $e');
    }
  }

  void _onGoalieSelected(String? gid) async {
    setState(() => selectedGoalieId = gid);
    if (gid == null) return;
    // collect season games
    final gameBox = Hive.box<Game>('games');
    final games = gameBox.values
        .where((g) => g.teamId == widget.team.id)
        .toList();
    final playerBox = Hive.box<Player>('players');
    final goalie = playerBox.get(gid);
    if (goalie == null) return;
    final res = StatsAggregator.aggregateGoalieZoneStats(
      games,
      [goalie],
      widget.team.id,
      zones,
    );
    setState(() {
      zoneStats = res[gid];
      // heatmap points same collection used previously in team_hub
      heatmapPoints = _collectSeasonPointsForGoalie(gid);
    });
  }

  List<Offset> _collectSeasonPointsForGoalie(String goalieId) {
    final pts = <Offset>[];
    final games = Hive.box<Game>(
      'games',
    ).values.where((g) => g.teamId == widget.team.id).toList();
    for (final g in games) {
      final events = g.events ?? [];
      for (final ev in events) {
        if (!(ev.type == 'shot' || ev.type == 'goal')) continue;
        String gid = (ev.details['goalieId'] ?? '').toString();
        if (gid.isEmpty && ev.details['onIce'] != null) {
          try {
            final onIce = Map<String, dynamic>.from(ev.details['onIce']);
            gid = (onIce['G'] ?? '').toString();
          } catch (_) {}
        }
        if (gid.isEmpty && (g.startingGoalie ?? '').isNotEmpty)
          gid = g.startingGoalie!;
        if (gid != goalieId) continue;
        final dx = (ev.details['dxNorm'] as num?)?.toDouble();
        final dy = (ev.details['dyNorm'] as num?)?.toDouble();
        if (dx == null || dy == null) continue;
        pts.add(Offset(dx, dy));
      }
    }
    return pts;
  }

  @override
  Widget build(BuildContext context) {
    final playerBox = Hive.box<Player>('players');
    final goalies = playerBox.values
        .where(
          (p) =>
              p.teamId == widget.team.id &&
              p.position.toLowerCase() == 'goalie',
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Goalie Analysis')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<String>(
                  value: selectedGoalieId,
                  hint: const Text('Select goalie'),
                  isExpanded: true,
                  items: goalies
                      .map(
                        (g) => DropdownMenuItem(
                          value: g.id,
                          child: Text(g.name),
                        ),
                      )
                      .toList(),
                  onChanged: _onGoalieSelected,
                ),
              ),
              const SizedBox(height: 8),
              // Zone save percentage view
              Expanded(
                child: zoneStats == null
                    ? const Center(
                        child: Text('Select a goalie to compute zone save%'),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return ClipRect(
                            child: Align(
                              alignment: Alignment.topCenter,
                              heightFactor: 0.5,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Image.asset(
                                      'assets/ice_rink.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  // Draw zones
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _GoalieZonesPainter(
                                        zones: zones,
                                        width: constraints.maxWidth,
                                        height: constraints.maxHeight,
                                        stats: zoneStats,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          // Zone statistics list overlaid at bottom
          if (zoneStats != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 200,
                color: Colors.white,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: zones.length,
                  itemBuilder: (context, index) {
                    final zone = zones[index];
                    final stat = zoneStats![zone.id];
                    
                    String svPctText = 'N/A';
                    Color bgColor = Colors.grey.shade200;
                    
                    if (stat != null) {
                      final shots = stat['shots'] as int? ?? 0;
                      final svPct = stat['sv_pct'];
                      
                      if (shots == 0) {
                        svPctText = 'No Data';
                      } else if (svPct != null) {
                        final v = (svPct as num).toDouble();
                        svPctText = v.toStringAsFixed(3);
                        
                        if (v >= 0.9) {
                          bgColor = Colors.green.withOpacity(0.7);
                        } else if (v >= 0.8) {
                          bgColor = Colors.yellow.withOpacity(0.7);
                        } else {
                          bgColor = Colors.red.withOpacity(0.7);
                        }
                      }
                    }
                    
                    return Card(
                      color: bgColor,
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        title: Text(
                          zone.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        trailing: Text(
                          svPctText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GoalieZonesPainter extends CustomPainter {
  final List<ZonePolygon> zones;
  final double width;
  final double height;
  final Map<String, Map<String, dynamic>>? stats;

  _GoalieZonesPainter({
    required this.zones,
    required this.width,
    required this.height,
    required this.stats,
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

      // Determine fill color from stats
      Color fillColor = Colors.blue.withOpacity(0.3);
      if (stats != null && stats![zone.id] != null) {
        final svPct = stats![zone.id]!['sv_pct'];
        if (svPct == null) {
          fillColor = Colors.white;
        } else if (svPct >= 0.9) {
          fillColor = Colors.green.withOpacity(0.7);
        } else if (svPct >= 0.8) {
          fillColor = Colors.yellow.withOpacity(0.7);
        } else {
          fillColor = Colors.red.withOpacity(0.7);
        }
      }

      // Fill
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Border
      final borderPaint = Paint()
        ..color = (stats == null) ? Colors.blue : Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (stats == null) ? 2.5 : 1.0;
      canvas.drawPath(path, borderPaint);

      // Draw label at centroid
      final pts = zone.points
          .map((p) => Offset(p.x * width, p.y * height))
          .toList();
      final centroid = _centroid(pts);
      
      String label = '';
      if (stats != null && stats![zone.id] != null) {
        final shots = stats![zone.id]!['shots'] as int? ?? 0;
        final svPct = stats![zone.id]!['sv_pct'];
        if (shots == 0) {
          label = 'No Data';
        } else if (svPct == null) {
          label = 'N/A';
        } else {
          final v = (svPct as num).toDouble();
          label = v.toStringAsFixed(3).replaceFirst(RegExp(r'^0'), '');
        }
      }

      if (label.isNotEmpty) {
        // Calculate zone bounds to determine available space
        final bounds = path.getBounds();
        final zoneWidth = bounds.width;
        final zoneHeight = bounds.height;
        
        // Try different font sizes based on zone size
        double fontSize = 12.0;
        if (zoneWidth < 50 || zoneHeight < 30) {
          fontSize = 8.0;
        } else if (zoneWidth < 70 || zoneHeight < 40) {
          fontSize = 10.0;
        }
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        // Only draw text if it fits within the zone bounds
        if (textPainter.width < zoneWidth - 8 && textPainter.height < zoneHeight - 8) {
          final rectPaint = Paint()..color = Colors.black.withOpacity(0.6);
          final pad = 4.0;
          final rect = Rect.fromLTWH(
            centroid.dx - textPainter.width / 2 - pad,
            centroid.dy - textPainter.height / 2 - pad,
            textPainter.width + pad * 2,
            textPainter.height + pad * 2,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4.0)),
            rectPaint,
          );
          textPainter.paint(
            canvas,
            Offset(
              centroid.dx - textPainter.width / 2,
              centroid.dy - textPainter.height / 2,
            ),
          );
        }
      }
    }
  }

  Offset _centroid(List<Offset> pts) {
    if (pts.isEmpty) return Offset(width / 2, height / 2);
    double signedArea = 0.0;
    double cx = 0.0;
    double cy = 0.0;
    for (int i = 0; i < pts.length; i++) {
      final x0 = pts[i].dx;
      final y0 = pts[i].dy;
      final x1 = pts[(i + 1) % pts.length].dx;
      final y1 = pts[(i + 1) % pts.length].dy;
      final a = x0 * y1 - x1 * y0;
      signedArea += a;
      cx += (x0 + x1) * a;
      cy += (y0 + y1) * a;
    }
    signedArea *= 0.5;
    if (signedArea == 0.0) return pts.first;
    cx = cx / (6 * signedArea);
    cy = cy / (6 * signedArea);
    return Offset(cx, cy);
  }

  @override
  bool shouldRepaint(_GoalieZonesPainter oldDelegate) => true;
}
