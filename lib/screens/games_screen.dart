import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../models/team.dart';
import 'game_details_screen.dart';
import '../services/premium_service.dart';
import '../widgets/upgrade_dialog.dart';

class GamesScreen extends StatefulWidget {
  final Team team;

  const GamesScreen({required this.team, super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  String _sortBy = 'Date';

  List<Game> _getSortedGames() {
    final box = Hive.box<Game>('games');
    final games = box.values.where((g) {
      return g.teamId == widget.team.id || g.opponent == widget.team.name;
    }).toList();

    switch (_sortBy) {
      case 'Opponent':
        games.sort((a, b) => a.opponent.compareTo(b.opponent));
        break;
      case 'Result':
        games.sort((a, b) => a.result.compareTo(b.result));
        break;
      case 'Game Type':
        games.sort((a, b) => a.gameType.compareTo(b.gameType));
        break;
      default:
        games.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    }

    return games;
  }

  void _deleteGame(Game game) {
    game.delete();
    setState(() {});
  }

  void _addNewGame() async {
    // Check if user can create more games
    if (await PremiumService.canCreateGame(widget.team.id)) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameDetailsScreen(team: widget.team)),
      );
      setState(() {}); // Refresh after returning
    } else {
      final remaining = await PremiumService.getRemainingFreeGames(widget.team.id);
      showUpgradeDialog(
        context,
        title: 'Game Limit Reached',
        message: 'Free users can track up to ${PremiumService.maxFreeGames} games per team. You have used all $remaining games. Upgrade to Premium for unlimited games!',
        onUpgrade: () {
          // TODO: Navigate to purchase screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase screen coming soon!')),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = _getSortedGames();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addNewGame),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: ['Date', 'Opponent', 'Result', 'Game Type'].map((
                label,
              ) {
                final isSelected = _sortBy == label;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _sortBy = label),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: games.length,
              itemBuilder: (_, index) {
                final game = games[index];
                return Dismissible(
                  key: Key(game.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteGame(game),
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameDetailsScreen(
                              team: widget.team,
                              existingGame: game,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left side: opponent + game type + date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${game.opponent} (${game.gameType})',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(
                                      game.dateTime,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Right side: result
                            Text(
                              game.getDisplayResult(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: game.isFinal
                                    ? (game.homeScore > game.visitorScore
                                          ? Colors.green
                                          : game.homeScore < game.visitorScore
                                          ? Colors.red
                                          : Colors.orange)
                                    : Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
