import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/player.dart';

class ChooseGoalieDialog extends StatelessWidget {
  final List<String> availablePlayerIds;
  final String? currentGoalieId;

  const ChooseGoalieDialog({
    super.key,
    required this.availablePlayerIds,
    required this.currentGoalieId,
  });

  @override
  Widget build(BuildContext context) {
    final playerBox = Hive.box<Player>('players');
    final eligibleGoalies = playerBox.values
        .where(
          (p) =>
              availablePlayerIds.contains(p.id) &&
              p.position.toLowerCase() == 'goalie',
        )
        .toList();

    final assignedGoalieId = currentGoalieId;
    final assignedGoalie =
        assignedGoalieId != null && assignedGoalieId.isNotEmpty
        ? playerBox.get(assignedGoalieId)
        : null;

    return AlertDialog(
      title: const Text('Choose Goalie'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (assignedGoalie != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Currently Assigned: ${assignedGoalie.name} (#${assignedGoalie.number})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: eligibleGoalies.length,
              itemBuilder: (context, index) {
                final goalie = eligibleGoalies[index];
                return ListTile(
                  title: Text('${goalie.name} (#${goalie.number})'),
                  onTap: () => Navigator.pop(context, goalie),
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
