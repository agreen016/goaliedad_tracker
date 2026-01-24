import '../models/game.dart';
import '../models/goal.dart';
import '../models/player.dart';
import '../models/zone.dart';

/// Shared helpers to aggregate player and goalie stats for a single game.
class StatsAggregator {
  /// Returns a list of player stat maps (player id -> stat map) and the ordered columns.
  static Map<String, dynamic> aggregatePlayerStats(
    Game game,
    List<Player> rosterPlayers,
    String teamId,
  ) {
    final columns = [
      'G',
      'A',
      'P',
      'S',
      'PPG',
      'SHG',
      'GWG',
      '+/-',
      'PIM',
      'FW',
      'FL',
      'FW%',
    ];

    final Map<String, Map<String, int>> stats = {};
    for (var p in rosterPlayers) {
      stats[p.id] = {for (var c in columns) c: 0};
      stats[p.id]!['P'] = 0;
    }

    // Goals
    List<Goal> goalsForGame = [];
    try {
      if (game.events != null) {
        goalsForGame = game.events!.where((e) => e.type == 'goal').map((e) {
          final details = e.details;
          // Use scorerId, goalScorer, or fallback to event.playerId
          final scorerId = (details['scorerId'] ?? details['goalScorer'] ?? e.playerId ?? '').toString();
          final assistIds = (details['assistIds'] is List)
              ? List<String>.from(details['assistIds'])
              : <String>[];
          final goalType = (details['goalType'] ?? '').toString();
          final time = (details['time'] ?? '').toString();
          final goalieId = (details['goalieId'] ?? '').toString();
          // ensure period is a string
          final periodStr = e.period.toString();
          return Goal(
            id: e.id,
            gameId: e.gameId,
            teamId: e.teamId,
            period: periodStr,
            scorerId: scorerId,
            assistIds: assistIds,
            goalType: goalType,
            time: time,
            goalieId: goalieId,
          );
        }).toList();
      }
    } catch (_) {
      goalsForGame = [];
    }

    for (var g in goalsForGame) {
      final scorer = g.scorerId;
      final assists = g.assistIds;
      if (scorer.isNotEmpty && stats.containsKey(scorer)) {
        stats[scorer]!['G'] = (stats[scorer]!['G'] ?? 0) + 1;
        stats[scorer]!['P'] = (stats[scorer]!['P'] ?? 0) + 1;
        // Ensure goals also count as shots for the scorer
        stats[scorer]!['S'] = (stats[scorer]!['S'] ?? 0) + 1;
      }
      for (var a in assists) {
        if (a.toString().isNotEmpty && stats.containsKey(a)) {
          stats[a]!['A'] = (stats[a]!['A'] ?? 0) + 1;
          stats[a]!['P'] = (stats[a]!['P'] ?? 0) + 1;
        }
      }
    }

    // Events
    final events = game.events ?? [];
    for (var e in events) {
      if (e.type == 'faceoff') {
        try {
          final pid = e.playerId;
          if (pid != null && stats.containsKey(pid)) {
            final details = e.details;
            final res = (details['result'] ?? '').toString();
            if (res.toLowerCase() == 'won') {
              stats[pid]!['FW'] = (stats[pid]!['FW'] ?? 0) + 1;
            } else if (res.toLowerCase() == 'lost') {
              stats[pid]!['FL'] = (stats[pid]!['FL'] ?? 0) + 1;
            }
          }
        } catch (_) {}
        continue;
      }

      if (e.type == 'shot' || e.type == 'goal') {
        final pid = e.playerId;
        if (pid != null && stats.containsKey(pid)) {
          stats[pid]!['S'] = (stats[pid]!['S'] ?? 0) + 1;
        }

        try {
          final details = e.details;
          if (details['onIce'] != null && details['onIce'] is Map) {
            final onIce = Map<String, dynamic>.from(details['onIce']);
            if (e.type == 'goal') {
              final scoringTeamId = e.teamId;
              for (final entry in onIce.entries) {
                final playerId = (entry.value ?? '').toString();
                if (playerId.isEmpty) continue;
                if (stats.containsKey(playerId)) {
                  if (scoringTeamId == teamId) {
                    stats[playerId]!['+/-'] =
                        (stats[playerId]!['+/-'] ?? 0) + 1;
                  } else {
                    stats[playerId]!['+/-'] =
                        (stats[playerId]!['+/-'] ?? 0) - 1;
                  }
                }
              }
            }
          }
        } catch (_) {}
      }
    }

    // Compute FW%
    stats.forEach((playerId, map) {
      final fw = map['FW'] ?? 0;
      final fl = map['FL'] ?? 0;
      final pct = (fw + fl) > 0 ? ((fw * 100) / (fw + fl)).round() : 0;
      map['FW%'] = pct;
    });

    return {'columns': columns, 'stats': stats};
  }

  static Map<String, Map<String, num>> aggregateGoalieStats(
    Game game,
    List<Player> goalies,
    String teamId,
  ) {
    final Map<String, Map<String, num>> stats = {};
    for (var p in goalies) {
      stats[p.id] = {
        'MIN': 0,
        'SOG': 0,
        'GA': 0,
        'SV': 0,
        'SV%': 0,
        'SO': 0,
        'PIM': 0,
        'G': 0,
        'A': 0,
        'P': 0,
      };
    }

    // Goal records may exist in goal box; also use events
    final events = game.events ?? [];
    for (var ev in events) {
      if (ev.type == 'shot' || ev.type == 'goal') {
        final details = ev.details;
        String goalieId = (details['goalieId'] ?? '').toString();
        if (goalieId.isEmpty &&
            details['onIce'] != null &&
            details['onIce'] is Map) {
          try {
            final onIce = Map<String, dynamic>.from(details['onIce']);
            goalieId = (onIce['G'] ?? '').toString();
          } catch (_) {}
        }
        if (goalieId.isEmpty && (game.startingGoalie ?? '').isNotEmpty) {
          goalieId = game.startingGoalie!;
        }
        if (goalieId.isNotEmpty && stats.containsKey(goalieId)) {
          if (ev.teamId != teamId) {
            stats[goalieId]!['SOG'] = (stats[goalieId]!['SOG'] ?? 0) + 1;
          }
          if (ev.type == 'goal' && ev.teamId != teamId) {
            stats[goalieId]!['GA'] = (stats[goalieId]!['GA'] ?? 0) + 1;
          }
        }
      }
    }

    for (var k in stats.keys) {
      final sog = stats[k]!['SOG'] ?? 0;
      final ga = stats[k]!['GA'] ?? 0;
      final sv = sog - ga;
      stats[k]!['SV'] = sv;
      stats[k]!['SV%'] = sog > 0 ? ((sv / sog) * 100) : 0;
    }

    // MIN heuristic
    final Map<String, Set<int>> goaliePeriods = {};
    for (var ev in events) {
      try {
        if (ev.details['onIce'] != null && ev.details['onIce'] is Map) {
          final onIce = Map<String, dynamic>.from(ev.details['onIce']);
          final gId = (onIce['G'] ?? '').toString();
          if (gId.isNotEmpty) {
            goaliePeriods.putIfAbsent(gId, () => <int>{}).add(ev.period);
          }
        }
      } catch (_) {}
    }
    for (var k in stats.keys) {
      final periods = goaliePeriods[k] ?? <int>{};
      final minutes = periods.isNotEmpty ? (periods.length * 20) : 0;
      stats[k]!['MIN'] = minutes;
    }

    return stats;
  }

  /// Aggregate goalie shots/goals by custom polygonal zones for a collection of games (season-level).
  ///
  /// Returns a map: goalieId -> zoneId -> { 'shots': int, 'goals': int, 'saves': int, 'sv_pct': double? }
  static Map<String, Map<String, Map<String, dynamic>>>
  aggregateGoalieZoneStats(
    List<Game> games,
    List<Player> goalies,
    String teamId,
    List<ZonePolygon> zones,
  ) {
    // initialize structure
    final Map<String, Map<String, Map<String, dynamic>>> out = {};
    for (var g in goalies) {
      out[g.id] = {};
      for (var z in zones) {
        out[g.id]![z.id] = {'shots': 0, 'goals': 0, 'saves': 0, 'sv_pct': null};
      }
    }

    // helper: point-in-polygon using ray casting on normalized coords
    bool pointInPolygon(double x, double y, List<ZonePoint> poly) {
      var inside = false;
      for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
        final xi = poly[i].x, yi = poly[i].y;
        final xj = poly[j].x, yj = poly[j].y;
        final intersect =
            ((yi > y) != (yj > y)) &&
            (x < (xj - xi) * (y - yi) / (yj - yi + 0.0) + xi);
        if (intersect) inside = !inside;
      }
      return inside;
    }

    for (final game in games) {
      final events = game.events ?? [];
      for (final ev in events) {
        if (!(ev.type == 'shot' || ev.type == 'goal')) continue;
        // normalized coords preferred
        final dxNorm = (ev.details['dxNorm'] as num?)?.toDouble();
        final dyNorm = (ev.details['dyNorm'] as num?)?.toDouble();
        if (dxNorm == null || dyNorm == null) continue;

        // determine goalie id for the event (who faced the shot)
        String goalieId = (ev.details['goalieId'] ?? '').toString();
        if (goalieId.isEmpty &&
            ev.details['onIce'] != null &&
            ev.details['onIce'] is Map) {
          try {
            final onIce = Map<String, dynamic>.from(ev.details['onIce']);
            goalieId = (onIce['G'] ?? '').toString();
          } catch (_) {}
        }
        if (goalieId.isEmpty && (game.startingGoalie ?? '').isNotEmpty) {
          goalieId = game.startingGoalie!;
        }

        if (goalieId.isEmpty) continue;
        if (!out.containsKey(goalieId)) continue; // goalie not in provided list

        // Only count shots against the team's opponents
        if (ev.teamId == teamId) continue;

        // find zone membership (first matching)
        String? hitZoneId;
        for (final z in zones) {
          if (z.points.isEmpty) continue;
          if (pointInPolygon(dxNorm, dyNorm, z.points)) {
            hitZoneId = z.id;
            break;
          }
        }
        if (hitZoneId == null) continue; // shot outside all zones

        out[goalieId]![hitZoneId]!['shots'] =
            (out[goalieId]![hitZoneId]!['shots'] as int) + 1;
        if (ev.type == 'goal') {
          out[goalieId]![hitZoneId]!['goals'] =
              (out[goalieId]![hitZoneId]!['goals'] as int) + 1;
        }
      }
    }

    // finalize saves & sv_pct
    for (final gid in out.keys) {
      for (final zid in out[gid]!.keys) {
        final shots = out[gid]![zid]!['shots'] as int;
        final goals = out[gid]![zid]!['goals'] as int;
        final saves = shots - goals;
        out[gid]![zid]!['saves'] = saves;
        // store as decimal fraction (0..1) or null if no shots
        out[gid]![zid]!['sv_pct'] = shots > 0 ? (saves / shots) : null;
      }
    }

    return out;
  }
}
