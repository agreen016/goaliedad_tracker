import '../models/player.dart';

/// Minimal stats aggregator used by UI and PDF to ensure parity.
class StatsAggregator {
  /// Aggregate per-player stats for a single game.
  /// Returns a map with 'columns' and 'stats'.
  static Map<String, dynamic> aggregatePlayerStats(
    dynamic game,
    List<Player> roster,
    String teamId,
  ) {
    final columns = <String>['G', 'A', 'P', 'SOG', 'TOI'];
    final stats = <String, Map<String, int>>{};
    for (var p in roster) {
      stats[p.id] = {for (var c in columns) c: 0};
    }

    final events = game.events ?? [];
    for (var e in events) {
      final pid = e.playerId ?? '';
      if (pid.isEmpty) continue;
      final isGoal = e.type == 'goal';
      final isShot = e.type == 'shot' || e.type == 'goal';
      if (!stats.containsKey(pid)) continue;
      if (isGoal) stats[pid]!['G'] = (stats[pid]!['G'] ?? 0) + 1;
      if (isShot) stats[pid]!['SOG'] = (stats[pid]!['SOG'] ?? 0) + 1;
      // Assists are recorded inside goal details
      if (e.type == 'goal') {
        final assists = e.details?['assistIds'];
        if (assists is List) {
          for (var a in assists) {
            if (a == null) continue;
            final aid = a.toString();
            if (!stats.containsKey(aid)) continue;
            stats[aid]!['A'] = (stats[aid]!['A'] ?? 0) + 1;
          }
        }
      }
    }

    // Compute points
    for (var id in stats.keys) {
      stats[id]!['P'] = (stats[id]!['G'] ?? 0) + (stats[id]!['A'] ?? 0);
    }

    return {'columns': columns, 'stats': stats};
  }

  static Map<String, Map<String, int>> aggregateGoalieStats(
    dynamic game,
    List<Player> goalies,
    String teamId,
  ) {
    final Map<String, Map<String, int>> result = {};
    for (var g in goalies) {
      result[g.id] = {
        'MIN': 0,
        'SOG': 0,
        'GA': 0,
        'SV': 0,
        'SV%': 0,
        'SO': 0,
        'PIM': 0,
      };
    }

    final events = game.events ?? [];
    for (var e in events) {
      if (e.type == 'shot' || e.type == 'goal') {
        final goalieId = e.details?['goalieId']?.toString() ?? '';
        if (goalieId.isEmpty) continue;
        if (!result.containsKey(goalieId)) continue;
        result[goalieId]!['SOG'] = (result[goalieId]!['SOG'] ?? 0) + 1;
        if (e.type == 'goal') {
          result[goalieId]!['GA'] = (result[goalieId]!['GA'] ?? 0) + 1;
        } else {
          result[goalieId]!['SV'] = (result[goalieId]!['SV'] ?? 0) + 1;
        }
      }
    }

    // compute SV% as integer percentage
    for (var gid in result.keys) {
      final sog = result[gid]!['SOG'] ?? 0;
      final sv = result[gid]!['SV'] ?? 0;
      result[gid]!['SV%'] = sog == 0 ? 0 : ((sv / sog) * 100).round();
    }

    return result;
  }
}
