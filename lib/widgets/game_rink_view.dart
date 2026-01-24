import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import '../models/shot_marker.dart';
import '../models/team.dart';
import '../models/opponent.dart';

class GameRinkView extends StatelessWidget {
  final Game? game;
  final double width;
  final bool homeOnLeft;
  final Color teamColor;
  // Optional zone polygons to render as overlays. Coordinates are normalized (0..1)
  final List<dynamic>? zonePolygons;
  // Whether to render shot/goal markers from a provided game
  final bool showMarkers;
  // Optional per-zone stats keyed by zone id: { 'shots': int, 'goals': int, 'saves': int, 'sv_pct': double? }
  final Map<String, Map<String, dynamic>>? zoneStats;

  GameRinkView({
    super.key,
    this.game,
    this.width = 0.0,
    this.homeOnLeft = true,
    this.teamColor = Colors.blue,
    this.zonePolygons,
    this.showMarkers = true,
    this.zoneStats,
  });

  // key to measure the rendered image size for debugging/scaling
  // make instance-scoped to avoid duplicate GlobalKey when multiple GameRinkView
  // widgets are instantiated in the widget tree.
  final GlobalKey _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Render markers for all shot/goal events across all periods so the full game can be reviewed
    final events = (game?.events) ?? [];
    final markers = <ShotMarker>[];
    final opponentBox = Hive.box<Opponent>('opponents');
    final teamBox = Hive.box<Team>('teams');
    final opponentObj = (game?.opponentTeamId != null)
        ? opponentBox.get(game!.opponentTeamId)
        : null;
    // sort events by period then time for consistent rendering order (optional)
    final sorted = List<GameEvent>.from(events)
      ..sort(
        (a, b) => a.period == b.period
            ? a.id.compareTo(b.id)
            : a.period.compareTo(b.period),
      );

    // Use the provided width (the GameDetails screen passes a padded width)
    // so coordinates map 1:1 when this widget is embedded with horizontal
    // padding. Fall back to MediaQuery width if width is zero or null.
    final liveWidth = (width > 0) ? width : MediaQuery.of(context).size.width;

    // measure rendered image size to convert normalized coords -> pixels
    double imgW = liveWidth;
    double imgH = 800.0; // fixed aspect; Live tracker also uses height 800
    try {
      final rb = _imageKey.currentContext?.findRenderObject() as RenderBox?;
      if (rb != null && rb.hasSize) {
        imgW = rb.size.width;
        imgH = rb.size.height;
      }
    } catch (_) {}

    // dbgCount removed; production builds don't log debug coords.
    for (final e in sorted) {
      if (!(e.type == 'shot' || e.type == 'goal')) continue;
      final isHome = (e.details['isHomeShooting'] as bool?) ?? true;
      // prefer the opponent's configured color when not home
      final opponentColor = opponentObj?.color ?? Colors.grey;
      final color = isHome ? teamColor : opponentColor;
      final playerNumber = (e.playerId != null && e.playerId!.isNotEmpty)
          ? (Hive.box<Player>('players').get(e.playerId)?.number.toString())
          : null;

      // prefer normalized coordinates when available so review maps to current render size
      final dxRaw = (e.details['dx'] as num?)?.toDouble();
      final dyRaw = (e.details['dy'] as num?)?.toDouble();
      final dxNorm = (e.details['dxNorm'] as num?)?.toDouble();
      final dyNorm = (e.details['dyNorm'] as num?)?.toDouble();

      final dxVal = dxNorm != null ? (dxNorm * imgW) : (dxRaw ?? 0.0);
      final dyVal = dyNorm != null ? (dyNorm * imgH) : (dyRaw ?? 0.0);
      // no-op debug logging in production

      markers.add(
        ShotMarker(
          dx: dxVal,
          dy: dyVal,
          isGoal: e.type == 'goal',
          teamColorValue: color.value,
          playerNumber: playerNumber,
          shooterId: e.playerId,
          goalScorerId: e.type == 'goal' ? e.playerId : null,
          assist1Id: e.details['assist1Id'] as String?,
          assist2Id: e.details['assist2Id'] as String?,
          eventId: e.id,
        ),
      );
    }

    final rinkWidget = LayoutBuilder(
      builder: (context, constraints) {
        final topLabelY = constraints.maxHeight * 0.325;
        final bottomLabelY = constraints.maxHeight * 0.675;
              
              return Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset('assets/ice_rink.png', fit: BoxFit.contain),
                  ),
                      // Draw zones - exactly like zone editor
                      if (zonePolygons != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ZonesPainterMulti(
                              polygons: zonePolygons!,
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              stats: zoneStats,
                            ),
                          ),
                        ),
                      // Team labels
                      Positioned(
                        top: topLabelY,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            homeOnLeft ? (teamBox.get(game?.teamId)?.name ?? game?.name ?? 'Team') : (opponentObj?.name ?? game?.opponent ?? 'Opponent'),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: homeOnLeft ? teamColor : (opponentObj?.color ?? Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: bottomLabelY,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            homeOnLeft ? (opponentObj?.name ?? game?.opponent ?? 'Opponent') : (teamBox.get(game?.teamId)?.name ?? game?.name ?? 'Team'),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: homeOnLeft ? (opponentObj?.color ?? Colors.grey) : teamColor,
                            ),
                          ),
                        ),
                      ),
                      // Markers
                      if (game != null && showMarkers)
                        ...markers.map((marker) {
                      final sizeW = 20.0;
                      final sizeH = 20.0;
                      double left = (marker.dx) - (sizeW / 2.0);
                      double top = (marker.dy) - (sizeH / 2.0);
                      if (left < 0) left = 0;
                      if (left + sizeW > constraints.maxWidth) left = constraints.maxWidth - sizeW;
                      if (top < 0) top = 0;
                      if (top + sizeH > constraints.maxHeight) top = constraints.maxHeight - sizeH;

                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: sizeW,
                          height: sizeH,
                          decoration: BoxDecoration(
                            color: marker.teamColor,
                            shape: marker.isGoal ? BoxShape.rectangle : BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: marker.isGoal && marker.playerNumber != null
                              ? Text(
                                  marker.playerNumber!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }),
                ],
              );
            },
          );

    // When no game, return just the rink widget directly (no Column wrapper)
    if (game == null) {
      return rinkWidget;
    }

    // When there's a game, wrap in Column with title
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            'Rink (shots & goals)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: rinkWidget),
      ],
    );
  }
}

class _ZonePainter extends CustomPainter {
  final dynamic polygon;
  final double imgW;
  final double imgH;
  final Map<String, Map<String, dynamic>>? stats;

  _ZonePainter({
    required this.polygon,
    required this.imgW,
    required this.imgH,
    this.stats,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final points = (polygon['points'] as List)
          .map((p) => p is Map ? p : Map<String, dynamic>.from(p))
          .toList();
      final path = Path();
      bool first = true;
      final pts = <Offset>[];
      for (final p in points) {
        final x = (p['x'] as num).toDouble() * imgW;
        final y = (p['y'] as num).toDouble() * imgH;
        pts.add(Offset(x, y));
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();

      // determine fill color from stats if available
      Color fillColor = Colors.blue.withOpacity(0.3);
      try {
        final zid = polygon['id'] as String?;
        if (zid != null && stats != null && stats![zid] != null) {
          final svPct = stats![zid]!['sv_pct'];
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
      } catch (_) {}

      final paint = Paint()..color = fillColor;
      canvas.drawPath(path, paint);

      // Draw polygon border - thicker when no stats
      final border = Paint()
        ..color = (stats == null) ? Colors.blue : Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (stats == null) ? 2.5 : 1.0;
      canvas.drawPath(path, border);

      // Draw label at centroid with save% or name
      final centroid = _centroid(pts);
      String label = '';
      try {
        final zid = polygon['id'] as String?;
        if (zid != null && stats != null && stats![zid] != null) {
          final shots = stats![zid]!['shots'] as int? ?? 0;
          final svPct = stats![zid]!['sv_pct'];
          if (shots == 0) {
            label = 'No Data';
          } else if (svPct == null) {
            label = 'N/A';
          } else {
            // format as .DDD (three decimal places) e.g. .935
            final v = (svPct as num).toDouble();
            label = v.toStringAsFixed(3).replaceFirst(RegExp(r'^0'), '');
          }
        } else {
          label = polygon['name'] ?? '';
        }
      } catch (_) {
        label = polygon['name'] ?? '';
      }

      if (label.isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
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
    } catch (_) {
      // ignore drawing errors
    }
  }

  Offset _centroid(List<Offset> pts) {
    if (pts.isEmpty) return Offset(imgW / 2, imgH / 2);
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZonesPainterMulti extends CustomPainter {
  final List<dynamic> polygons;
  final double width;
  final double height;
  final Map<String, Map<String, dynamic>>? stats;

  _ZonesPainterMulti({
    required this.polygons,
    required this.width,
    required this.height,
    this.stats,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final polygon in polygons) {
      try {
        final points = (polygon['points'] as List)
            .map((p) => p is Map ? p : Map<String, dynamic>.from(p))
            .toList();
        if (points.length < 3) continue;

        final path = Path();
        final pts = <Offset>[];
        path.moveTo(
          (points[0]['x'] as num).toDouble() * width,
          (points[0]['y'] as num).toDouble() * height,
        );
        pts.add(Offset(
          (points[0]['x'] as num).toDouble() * width,
          (points[0]['y'] as num).toDouble() * height,
        ));
        
        for (int j = 1; j < points.length; j++) {
          final x = (points[j]['x'] as num).toDouble() * width;
          final y = (points[j]['y'] as num).toDouble() * height;
          path.lineTo(x, y);
          pts.add(Offset(x, y));
        }
        path.close();

        // determine fill color from stats if available
        Color fillColor = Colors.blue.withOpacity(0.3);
        try {
          final zid = polygon['id'] as String?;
          if (zid != null && stats != null && stats![zid] != null) {
            final svPct = stats![zid]!['sv_pct'];
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
        } catch (_) {}

        final paint = Paint()..color = fillColor;
        canvas.drawPath(path, paint);

        // Draw polygon border - thicker when no stats
        final border = Paint()
          ..color = (stats == null) ? Colors.blue : Colors.black.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (stats == null) ? 2.5 : 1.0;
        canvas.drawPath(path, border);

        // Draw label at centroid with save% or name
        final centroid = _centroid(pts);
        String label = '';
        try {
          final zid = polygon['id'] as String?;
          if (zid != null && stats != null && stats![zid] != null) {
            final shots = stats![zid]!['shots'] as int? ?? 0;
            final svPct = stats![zid]!['sv_pct'];
            if (shots == 0) {
              label = 'No Data';
            } else if (svPct == null) {
              label = 'N/A';
            } else {
              // format as .DDD (three decimal places) e.g. .935
              final v = (svPct as num).toDouble();
              label = v.toStringAsFixed(3).replaceFirst(RegExp(r'^0'), '');
            }
          } else {
            label = polygon['name'] ?? '';
          }
        } catch (_) {
          label = polygon['name'] ?? '';
        }

        if (label.isNotEmpty) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
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
      } catch (_) {
        // ignore drawing errors
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
