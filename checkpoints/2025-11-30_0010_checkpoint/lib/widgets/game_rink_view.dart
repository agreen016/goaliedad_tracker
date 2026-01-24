import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import '../models/shot_marker.dart';
import '../models/team.dart';
import '../models/opponent.dart';

class GameRinkView extends StatelessWidget {
  final Game game;
  final double width;
  final bool homeOnLeft;
  final Color teamColor;

  const GameRinkView({
    super.key,
    required this.game,
    required this.width,
    required this.homeOnLeft,
    required this.teamColor,
  });

  // key to measure the rendered image size for debugging/scaling
  static final GlobalKey _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Render markers for all shot/goal events across all periods so the full game can be reviewed
    final events = game.events ?? [];
    final markers = <ShotMarker>[];
    final opponentBox = Hive.box<Opponent>('opponents');
    final teamBox = Hive.box<Team>('teams');
    final opponentObj = game.opponentTeamId != null
        ? opponentBox.get(game.opponentTeamId)
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

    var dbgCount = 0;
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
      if (dbgCount < 5) {
        debugPrint(
          'Review event=${e.id} dxVal=$dxVal dyVal=$dyVal dxNorm=$dxNorm dyNorm=$dyNorm',
        );
        dbgCount++;
      }

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
        SingleChildScrollView(
          child: Stack(
            children: [
              // Match live tracker layout: width constrained, height determined by image (BoxFit.cover)
              SizedBox(
                key: _imageKey,
                width: liveWidth,
                height: 800.0,
                child: Image.asset('assets/ice_rink.png', fit: BoxFit.fill),
              ),
              // metrics overlay removed
              // team labels positioned relative to the rendered image height
              Builder(
                builder: (ctx) {
                  // determine rendered image height for label placement
                  double imgW = liveWidth;
                  double imgH = 800.0;
                  try {
                    final rb =
                        _imageKey.currentContext?.findRenderObject()
                            as RenderBox?;
                    if (rb != null && rb.hasSize) {
                      imgW = rb.size.width;
                      imgH = rb.size.height;
                    }
                  } catch (_) {}
                  // Use absolute offsets to match the LiveGameTracker placement
                  // which uses `top: 260` and `bottom: 260` on a rink height of 800.
                  // Keep imgH available for bottom positioning calculation.
                  final topLabelY = 260.0;
                  final bottomLabelY = (imgH - 260.0);
                  final opponent = opponentObj;
                  String _safe(String? s, String fallback) {
                    if (s == null) return fallback;
                    final t = s.trim();
                    return t.isEmpty ? fallback : t;
                  }

                  final opponentName = _safe(
                    opponent?.name,
                    (game.opponent.isNotEmpty ? game.opponent : 'Opponent'),
                  );

                  final teamObj = teamBox.get(game.teamId);
                  final teamName = _safe(
                    teamObj?.name ?? game.name ?? game.teamId,
                    'Team',
                  );

                  // We're rendering at the live tracker width so no additional
                  // scaling is needed — use recorded local coordinates directly.

                  return Positioned.fill(
                    child: Stack(
                      children: [
                        Positioned(
                          top: topLabelY,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              homeOnLeft ? teamName : opponentName,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: homeOnLeft
                                    ? teamColor
                                    : (opponent?.color ?? Colors.grey),
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
                              homeOnLeft ? opponentName : teamName,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: homeOnLeft
                                    ? (opponent?.color ?? Colors.grey)
                                    : teamColor,
                              ),
                            ),
                          ),
                        ),
                        // Markers: place using the same local coordinates recorded by the live tracker.
                        ...markers.map((marker) {
                          // Marker size in local coords (scale down/up with view)
                          final sizeW = 20.0;
                          final sizeH = 20.0;
                          double left = (marker.dx) - (sizeW / 2.0);
                          double top = (marker.dy) - (sizeH / 2.0);
                          // clamp inside image bounds
                          if (left < 0) left = 0;
                          if (left + sizeW > imgW) left = imgW - sizeW;
                          if (top < 0) top = 0;
                          if (top + sizeH > imgH) top = imgH - sizeH;

                          return Positioned(
                            left: left,
                            top: top,
                            child: Container(
                              width: sizeW,
                              height: sizeH,
                              decoration: BoxDecoration(
                                color: marker.teamColor,
                                shape: marker.isGoal
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child:
                                  marker.isGoal && marker.playerNumber != null
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
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
