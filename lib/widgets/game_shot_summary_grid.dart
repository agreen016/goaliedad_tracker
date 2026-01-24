import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/team.dart';
import '../models/opponent.dart';

class ShotSummaryGrid extends StatelessWidget {
  final Game game;
  final Team team;
  final Color accentColor;

  const ShotSummaryGrid({
    super.key,
    required this.game,
    required this.team,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ['1', '2', '3', 'OT', 'Total'];
    final opponentBox = Hive.box<Opponent>('opponents');

    final Opponent? opponentTeam = game.opponentTeamId != null
        ? opponentBox.get(game.opponentTeamId)
        : null;

    final opponentName = opponentTeam?.name ?? 'Opponent';

    final textColor = accentColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    final homeShots = game.homeShotsByPeriod ?? {};
    final visitorShots = game.visitorShotsByPeriod ?? {};

    Map<String, int> getShotCounts(Map<String, int> shots) {
      final counts = {'1': 0, '2': 0, '3': 0, 'OT': 0};
      for (var key in counts.keys) {
        counts[key] = shots[key] ?? 0;
      }
      final total = counts.values.reduce((a, b) => a + b);
      return {...counts, 'Total': total};
    }

    final homeShotCounts = getShotCounts(homeShots);
    final visitorShotCounts = getShotCounts(visitorShots);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Shot Summary',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withAlpha((0.1 * 255).round()),
            border: Border.all(color: accentColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(accentColor),
              headingTextStyle: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
              columns: [
                const DataColumn(label: Text('Team')),
                ...columns.map((col) => DataColumn(label: Text(col))),
              ],
              rows: [
                DataRow(
                  cells: [
                    DataCell(Text(team.name)),
                    ...columns.map(
                      (col) => DataCell(Text('${homeShotCounts[col]}')),
                    ),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        opponentName,
                        style: TextStyle(
                          fontStyle: opponentTeam == null
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: opponentTeam == null
                              ? Colors.grey
                              : Colors.white,
                        ),
                      ),
                    ),
                    ...columns.map(
                      (col) => DataCell(Text('${visitorShotCounts[col]}')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
