import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/stats_aggregator.dart';

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

    // Use shared StatsAggregator so UI and PDF match exactly.
    final agg = StatsAggregator.aggregatePlayerStats(
      game,
      teamPlayers,
      team.id,
    );
    final columnsFromAgg = agg['columns'] as List<String>? ?? columns;
    final stats = agg['stats'] as Map<String, Map<String, int>>? ?? {};

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
            headingRowColor: WidgetStatePropertyAll<Color>(accentColor),
            headingTextStyle: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
            columns: [
              const DataColumn(label: Text('Player')),
              ...columnsFromAgg.map((col) => DataColumn(label: Text(col))),
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

              final s =
                  stats[player.id] ?? {for (var c in columnsFromAgg) c: 0};

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
