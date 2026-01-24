import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/game.dart';
import '../models/team.dart';
import '../models/opponent.dart';
import '../models/goal.dart';

class SpecialTeamsGrid extends StatelessWidget {
  final Game game;
  final Team team;
  final Color accentColor;

  const SpecialTeamsGrid({
    super.key,
    required this.game,
    required this.team,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final columns = [
      'PPG', // Power Play Goals
      'PPO', // Power Play Opportunities
      'PP%', // Power Play Percentage
      'PPGA', // Power Play Goals Against
      'PPOA', // Power Play Opportunities Against
      'PK%', // Penalty Kill Percentage
      'SHG', // Shorthanded Goals
      'SHGA', // Shorthanded Goals Against
    ];

    final opponentBox = Hive.box<Opponent>('opponents');
    final Opponent? opponentTeam = game.opponentTeamId != null
        ? opponentBox.get(game.opponentTeamId)
        : null;

    final opponentName = opponentTeam?.name ?? 'Opponent';

    final textColor = accentColor.computeLuminance() > 0.5
        ? Colors.black
        : Colors.white;

    // Compute real special teams stats from goals box and game PPO counters
    final goalBox = Hive.box<Goal>('goals');
    final goalsForGame = goalBox.values.where((g) => g.gameId == game.id);

    int countGoalsByType(String teamId, String type) => goalsForGame
        .where((g) => g.teamId == teamId && g.goalType == type)
        .length;

    final homePPG = countGoalsByType(team.id, 'PP');
    final visitorPPG = countGoalsByType(
      (game.opponentTeamId != null ? game.opponentTeamId.toString() : ''),
      'PP',
    );

    final homeSHG = countGoalsByType(team.id, 'SH');
    final visitorSHG = countGoalsByType(
      opponentTeam?.key.toString() ?? '',
      'SH',
    );

    final homePPO = game.homePPO;
    final visitorPPO = game.visitorPPO;

    String percent(int goals, int opps) {
      if (opps == 0) return '0%';
      return '\${((goals * 100) / opps).round()}%';
    }

    final homeStats = {
      'PPG': homePPG,
      'PPO': homePPO,
      'PP%': percent(homePPG, homePPO),
      'PPGA': visitorPPG,
      'PPOA': visitorPPO,
      'PK%': percent(visitorPPG, visitorPPO),
      'SHG': homeSHG,
      'SHGA': visitorSHG,
    };

    final visitorStats = {
      'PPG': visitorPPG,
      'PPO': visitorPPO,
      'PP%': percent(visitorPPG, visitorPPO),
      'PPGA': homePPG,
      'PPOA': homePPO,
      'PK%': percent(homePPG, homePPO),
      'SHG': visitorSHG,
      'SHGA': homeSHG,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Special Teams',
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
                      (col) => DataCell(Text('${homeStats[col]}')),
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
                      (col) => DataCell(Text('${visitorStats[col]}')),
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
