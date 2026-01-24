import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/stats_aggregator.dart';

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

    // Use shared aggregator to compute goalie stats
    final aggregated = StatsAggregator.aggregateGoalieStats(
      game,
      goalies,
      team.id,
    );

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
            headingRowColor: WidgetStatePropertyAll<Color>(accentColor),
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
                  aggregated[goalie.id] ??
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

              final svPct = (s['SV%'] is num)
                  ? (s['SV%'] as num).toDouble()
                  : 0.0;

              return DataRow(
                cells: [
                  DataCell(Text(goalie.name, style: goalieStyle)),
                  DataCell(Text('${s['MIN'] ?? 0}')),
                  DataCell(Text('${s['SOG'] ?? 0}')),
                  DataCell(Text('${s['GA'] ?? 0}')),
                  DataCell(Text('${s['SV'] ?? 0}')),
                  DataCell(Text('${svPct.toStringAsFixed(1)}%')),
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
