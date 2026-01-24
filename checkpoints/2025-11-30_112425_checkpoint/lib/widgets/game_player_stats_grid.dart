import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/goal.dart';

class GamePlayerStatsGrid extends StatelessWidget {
  final Game game;
  final Team team;
  final Color accentColor;

  const GamePlayerStatsGrid({
    super.key,
    required this.game,
    required this.team,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
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

    final textColor = accentColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    final playerBox = Hive.box<Player>('players');
    final teamPlayers = playerBox.values
        .where((p) => p.teamId == team.id)
        .where(
          (p) =>
              game.availablePlayerIds.contains(p.id) ||
              game.unavailablePlayerReasons.containsKey(p.id),
        )
        .where((p) => p.position.toLowerCase() != 'goalie')
        .toList();

    // Aggregate stats from goals and events. Guard against Hive box not being open
    List<Goal> goalsForGameList = [];
    try {
      final Box<Goal> goalBox = Hive.box<Goal>('goals');
      goalsForGameList = goalBox.values
          .where((g) => g.gameId == game.id)
          .toList();
    } catch (_) {
      // box not open yet or other HiveError; treat as empty for UI stability
      goalsForGameList = [];
    }

    // Map playerId -> stats map
    final Map<String, Map<String, int>> stats = {};
    for (var p in teamPlayers) {
      stats[p.id] = {for (var c in columns) c: 0};
      stats[p.id]!['P'] = 0; // points
    }

    for (var g in goalsForGameList) {
      final scorer = g.scorerId;
      final assists = g.assistIds;
      if (scorer.isNotEmpty && stats.containsKey(scorer)) {
        stats[scorer]!['G'] = (stats[scorer]!['G'] ?? 0) + 1;
        stats[scorer]!['P'] = (stats[scorer]!['P'] ?? 0) + 1;
      }
      for (var a in assists) {
        if (a.toString().isNotEmpty && stats.containsKey(a)) {
          stats[a]!['A'] = (stats[a]!['A'] ?? 0) + 1;
          stats[a]!['P'] = (stats[a]!['P'] ?? 0) + 1;
        }
      }
    }

    // Process events: shots/goals/faceoffs
    final events = game.events ?? [];
    for (var e in events) {
      if (e.type == 'faceoff') {
        // faceoff result stored in details['result'] as 'Won' or 'Lost'
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
        // Use onIce snapshot to attribute +/- (for goals) and SA (shots against)
        try {
          final details = e.details;
          if (details['onIce'] != null && details['onIce'] is Map) {
            final onIce = Map<String, dynamic>.from(details['onIce']);
            // if this event was a goal, +/- applies
            if (e.type == 'goal') {
              final scoringTeamId = e.teamId;
              // for each player id in onIce snapshot, adjust +/- depending on team
              for (final entry in onIce.entries) {
                final playerId = (entry.value ?? '').toString();
                if (playerId.isEmpty) continue;
                // if player is on this grid's team, adjust +/ -
                if (stats.containsKey(playerId)) {
                  if (scoringTeamId == team.id) {
                    // plus for teammates when team scored
                    stats[playerId]!['+/-'] =
                        (stats[playerId]!['+/-'] ?? 0) + 1;
                  } else {
                    // minus when opposition scored
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

    // No per-player Shots Against or S% in this grid — keep S only
    // Ensure keys exist for each player
    stats.forEach((playerId, map) {
      map['S'] = (map['S'] ?? 0);
    });

    // Compute FW% per player
    stats.forEach((playerId, map) {
      final fw = map['FW'] ?? 0;
      final fl = map['FL'] ?? 0;
      final pct = (fw + fl) > 0 ? ((fw * 100) / (fw + fl)).round() : 0;
      map['FW%'] = pct; // store integer percent
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Player Stats',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all<Color?>(accentColor),
            headingTextStyle: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
            columns: [
              const DataColumn(label: Text('Player')),
              ...columns.map((col) => DataColumn(label: Text(col))),
            ],
            rows: teamPlayers.map((player) {
              final isUnavailable = game.unavailablePlayerReasons.containsKey(
                player.id,
              );
              final playerStyle = isUnavailable
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.red,
                      decorationThickness: 2,
                      color: Colors.red,
                    )
                  : const TextStyle();

              final s = stats[player.id] ?? {for (var c in columns) c: 0};

              return DataRow(
                cells: [
                  DataCell(Text(player.name, style: playerStyle)),
                  DataCell(Text('${s['G'] ?? 0}')),
                  DataCell(Text('${s['A'] ?? 0}')),
                  DataCell(Text('${s['P'] ?? 0}')),
                  DataCell(Text('${s['S'] ?? 0}')),
                  DataCell(Text('${s['PPG'] ?? 0}')),
                  DataCell(Text('${s['SHG'] ?? 0}')),
                  DataCell(Text('${s['GWG'] ?? 0}')),
                  DataCell(Text('${s['+/-'] ?? 0}')),
                  DataCell(Text('${s['PIM'] ?? 0}')),
                  DataCell(Text('${s['FW'] ?? 0}')),
                  DataCell(Text('${s['FL'] ?? 0}')),
                  DataCell(Text('${s['FW%'] ?? 0}%')),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
