import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../services/premium_service.dart';
import '../widgets/upgrade_dialog.dart';
import 'create_player_screen.dart';
import 'edit_player_screen.dart';
import 'line_editor_screen.dart'; // <-- Make sure this screen exists

class PlayersScreen extends StatefulWidget {
  final Team team;

  const PlayersScreen({super.key, required this.team});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  void _deletePlayer(Player player) {
    player.delete();
    setState(() {});
  }

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
                  .where((p) => p.teamId == widget.team.id)
                  .toList();

              if (teamPlayers.isEmpty) {
                return const Center(child: Text('No players yet'));
              }

              return ListView.builder(
                itemCount: teamPlayers.length,
                itemBuilder: (context, index) {
                  final player = teamPlayers[index];
                  return Dismissible(
                    key: Key(player.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deletePlayer(player),
                    child: Card(
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
                              widget.team.primaryColorHex.replaceFirst('#', '0xFF'),
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
                              widget.team.primaryColorHex.replaceFirst('#', '0xFF'),
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
              onPressed: () async {
                final canAccess = await PremiumService.isPremium();
                if (!canAccess && mounted) {
                  showDialog(
                    context: context,
                    builder: (_) => UpgradeToPremiumDialog(
                      title: 'Lines Management',
                      message: 'Create and manage player lines for your team.',
                    ),
                  );
                  return;
                }
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LineEditorScreen(team: widget.team),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.view_list),
              label: const Text('Lines'),
            ),
          ),
        ],
      ),

      // Add Player FAB stays in Bottom Right
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final canCreate = await PremiumService.canCreatePlayer(widget.team.id);
          if (!canCreate && mounted) {
            showDialog(
              context: context,
              builder: (_) => UpgradeToPremiumDialog(
                title: 'Player Limit Reached',
                message: 'Free users can add up to ${PremiumService.maxFreePlayers} players per team. Upgrade to premium for unlimited players.',
              ),
            );
            return;
          }
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreatePlayerScreen(team: widget.team),
              ),
            );
          }
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
