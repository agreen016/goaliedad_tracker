import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/player.dart';
import '../models/team.dart';
import 'create_player_screen.dart';
import 'edit_player_screen.dart';
import 'line_editor_screen.dart'; // <-- Make sure this screen exists

class PlayersScreen extends StatelessWidget {
  final Team team;

  const PlayersScreen({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    final playerBox = Hive.box<Player>('players');

    return Scaffold(
      appBar: AppBar(title: const Text('Players')),
      body: Stack(
        children: [
          ValueListenableBuilder(
            valueListenable: playerBox.listenable(),
            builder: (context, Box<Player> box, _) {
              final teamPlayers = box.values
                  .where((p) => p.teamId == team.id)
                  .toList();

              if (teamPlayers.isEmpty) {
                return const Center(child: Text('No players yet'));
              }

              return ListView.builder(
                itemCount: teamPlayers.length,
                itemBuilder: (context, index) {
                  final player = teamPlayers[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditPlayerScreen(player: player),
                          ),
                        );
                      },
                      leading: CircleAvatar(
                        backgroundColor: Color(
                          int.parse(
                            team.primaryColorHex.replaceFirst('#', '0xFF'),
                          ),
                        ),
                        child: Text(
                          '${player.number}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(player.name),
                      subtitle: Text(player.position),
                      trailing: CircleAvatar(
                        backgroundColor: Color(
                          int.parse(
                            team.primaryColorHex.replaceFirst('#', '0xFF'),
                          ),
                        ),
                        child: Text(
                          _positionAbbreviation(player.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Lines Button in Bottom Left
          Positioned(
            bottom: 16,
            left: 16,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LineEditorScreen(team: team),
                  ),
                );
              },
              icon: const Icon(Icons.view_list),
              label: const Text('Lines'),
            ),
          ),
        ],
      ),

      // Add Player FAB stays in Bottom Right
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePlayerScreen(team: team),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Player'),
      ),
    );
  }

  String _positionAbbreviation(String position) {
    switch (position.toLowerCase()) {
      case 'forward':
        return 'F';
      case 'defense':
        return 'D';
      case 'goalie':
        return 'G';
      default:
        return '?';
    }
  }
}
