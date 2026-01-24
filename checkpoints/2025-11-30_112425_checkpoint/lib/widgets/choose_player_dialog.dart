import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/player.dart';

class ChoosePlayerDialog extends StatelessWidget {
  final String position;
  final List<String> availablePlayerIds;
  final Map<String, String> positionAssignments;

  const ChoosePlayerDialog({
    super.key,
    required this.position,
    required this.availablePlayerIds,
    required this.positionAssignments,
  });

  @override
  Widget build(BuildContext context) {
    final playerBox = Hive.box<Player>('players');
    final eligiblePlayers = playerBox.values
        .where(
          (p) =>
              availablePlayerIds.contains(p.id) &&
              p.position.toLowerCase() != 'goalie',
        )
        .toList();

    final assignedPlayerId = positionAssignments[position];
    final assignedPlayer = assignedPlayerId != null
        ? playerBox.get(assignedPlayerId)
        : null;

    return AlertDialog(
      title: Text('Choose Player for $position'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assignedPlayer != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Currently Assigned: ${assignedPlayer.name} (#${assignedPlayer.number})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          SizedBox(
            width: double.maxFinite,
            height: 300, // 👈 Fixed height to avoid layout error
            child: ListView.builder(
              itemCount: eligiblePlayers.length,
              itemBuilder: (context, index) {
                final player = eligiblePlayers[index];
                return ListTile(
                  title: Text('${player.name} (#${player.number})'),
                  onTap: () => Navigator.pop(context, player),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
