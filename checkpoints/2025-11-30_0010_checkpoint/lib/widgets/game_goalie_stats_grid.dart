import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../models/goal.dart';

class GameGoalieStatsGrid extends StatelessWidget {
  final Game game;
  final Team team;
  final Color accentColor;

  const GameGoalieStatsGrid({
    super.key,
    required this.game,
    required this.team,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final columns = [
      'MIN',
      'SOG',
      'GA',
      'SV',
      'SV%',
      'SO',
      'PIM',
      'G',
      'A',
      'P',
    ];

    final textColor = accentColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    final playerBox = Hive.box<Player>('players');
    final goalies = playerBox.values
        .where((p) => p.teamId == team.id)
        .where(
          (p) =>
              game.availablePlayerIds.contains(p.id) ||
              game.unavailablePlayerReasons.containsKey(p.id),
        )
        .where((p) => p.position.toLowerCase() == 'goalie')
        .toList();

    // Aggregate goalie stats using persisted goalieId on Goal records and from GameEvent.details
    List<Goal> goalsForGame = [];
    try {
      final Box<Goal> goalBox = Hive.box<Goal>('goals');
      goalsForGame = goalBox.values.where((g) => g.gameId == game.id).toList();
    } catch (_) {
      goalsForGame = [];
    }

    // Build per-goalie stats
    final Map<String, Map<String, num>> stats = {};
    for (var p in goalies) {
      stats[p.id] = {
        'MIN': 0,
        'SOG': 0,
        'GA': 0,
        'SV': 0,
        'SO': 0,
        'PIM': 0,
        'G': 0,
        'A': 0,
        'P': 0,
      };
    }

    // Count shots on goal and goals against per goalie from Goal records
    for (var g in goalsForGame) {
      final String goalieId = g.goalieId;
      final String scoringTeamId = g.teamId;
      // A goal for 'scoringTeamId' means a GA for the opposing team's goalie(s). We attribute GA to the goalieId saved on the Goal record.
      if (goalieId.isNotEmpty && stats.containsKey(goalieId)) {
        // If the goal's teamId is opponent to this grid's team, it's a GA for this team's goalie
        if (scoringTeamId != team.id) {
          stats[goalieId]!['GA'] = (stats[goalieId]!['GA'] ?? 0) + 1;
        } else {
          // If the team scored, that's a goal for this team's goalie? no, it's a goal scored by this team, so opponent GA handled elsewhere
        }
      }

      // Also credit goals (G) and assists to goalies? keep G/A as 0 for goalies unless recording goalie scoring
    }

    // Use game.events to count SOG per goalie when goalieId is present in event.details
    final events = game.events ?? [];
    for (var ev in events) {
      if (ev.type == 'shot' || ev.type == 'goal') {
        final details = ev.details;
        // prefer explicit goalieId, fall back to onIce snapshot or game's startingGoalie
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
        // Count shots on goal against this goalie only when the event was
        // recorded for the OPPONENT team (i.e., ev.teamId != team.id). That
        // avoids counting shots by this goalie's own team.
        if (goalieId.isNotEmpty && stats.containsKey(goalieId)) {
          if (ev.teamId != team.id) {
            stats[goalieId]!['SOG'] = (stats[goalieId]!['SOG'] ?? 0) + 1;
          }
        }
      }
    }

    // Compute SV = SOG - GA and SV% = SV / SOG
    for (var k in stats.keys) {
      final sog = stats[k]!['SOG'] ?? 0;
      final ga = stats[k]!['GA'] ?? 0;
      final sv = sog - ga;
      stats[k]!['SV'] = sv;
      stats[k]!['SV%'] = sog > 0 ? ((sv / sog) * 100) : 0;
    }

    // Compute minutes played (simple heuristic: highest period seen * 20 minutes)
    // Compute minutes played per goalie: count distinct periods where the goalie appears in onIce snapshots
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

    // Assign MIN per goalie based on counted periods
    for (var k in stats.keys) {
      final periods = goaliePeriods[k] ?? <int>{};
      final minutes = periods.isNotEmpty ? (periods.length * 20) : 0;
      stats[k]!['MIN'] = minutes;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Goalie Stats',
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
              const DataColumn(label: Text('Goalie')),
              ...columns.map((col) => DataColumn(label: Text(col))),
            ],
            rows: goalies.map((goalie) {
              final isUnavailable = game.unavailablePlayerReasons.containsKey(
                goalie.id,
              );
              final goalieStyle = isUnavailable
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.red,
                      decorationThickness: 2,
                      color: Colors.red,
                    )
                  : const TextStyle();

              final s =
                  stats[goalie.id] ??
                  {
                    'MIN': 0,
                    'SOG': 0,
                    'GA': 0,
                    'SV': 0,
                    'SV%': 0.0,
                    'SO': 0,
                    'PIM': 0,
                    'G': 0,
                    'A': 0,
                    'P': 0,
                  };

              return DataRow(
                cells: [
                  DataCell(Text(goalie.name, style: goalieStyle)),
                  DataCell(Text('${s['MIN'] ?? 0}')),
                  DataCell(Text('${s['SOG'] ?? 0}')),
                  DataCell(Text('${s['GA'] ?? 0}')),
                  DataCell(Text('${s['SV'] ?? 0}')),
                  DataCell(
                    Text('${(s['SV%'] ?? 0).toDouble().toStringAsFixed(1)}%'),
                  ),
                  DataCell(Text('${s['SO'] ?? 0}')),
                  DataCell(Text('${s['PIM'] ?? 0}')),
                  DataCell(Text('${s['G'] ?? 0}')),
                  DataCell(Text('${s['A'] ?? 0}')),
                  DataCell(Text('${s['P'] ?? 0}')),
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
