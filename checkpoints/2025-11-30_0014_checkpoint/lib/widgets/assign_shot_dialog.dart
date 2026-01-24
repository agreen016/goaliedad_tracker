import 'package:flutter/material.dart';
import '../models/player.dart';

class AssignShotDialog extends StatefulWidget {
  final bool isGoal;
  final List<Player> onIcePlayers;
  final List<Player> benchPlayers;
  final bool
  allowSelectShooter; // when false, hide shooter selection (used for opponent shots)

  const AssignShotDialog({
    required this.isGoal,
    required this.onIcePlayers,
    required this.benchPlayers,
    this.allowSelectShooter = true,
    super.key,
  });

  @override
  State<AssignShotDialog> createState() => _AssignShotDialogState();
}

class _AssignShotDialogState extends State<AssignShotDialog> {
  String? shooterId;
  String? goalScorerId;
  String? assist1Id;
  String? assist2Id;
  String _goalType = 'EV'; // EV, PP, SH, EN

  void toggle(String? current, String id, void Function(String?) setter) {
    setter(current == id ? null : id);
  }

  Widget buildSection(
    String label,
    String? selectedId,
    void Function(String?) setter,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...widget.onIcePlayers.map(
              (p) => buildButton(p, selectedId, setter, true),
            ),
            ...widget.benchPlayers.map(
              (p) => buildButton(p, selectedId, setter, false),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget buildButton(
    Player p,
    String? selectedId,
    void Function(String?) setter,
    bool isOnIce,
  ) {
    final isSelected = selectedId == p.id;
    return ElevatedButton(
      onPressed: () => setState(() => toggle(selectedId, p.id, setter)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Colors.blue
            : isOnIce
            ? Colors.green
            : Colors.grey,
        foregroundColor: Colors.white,
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      child: Text('${p.number}', style: const TextStyle(fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isGoal ? 'Assign Goal' : 'Assign Shooter'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isGoal && widget.allowSelectShooter)
              buildSection('Shooter', shooterId, (val) => shooterId = val),
            if (widget.isGoal) ...[
              buildSection(
                'Goal Scorer',
                goalScorerId,
                (val) => goalScorerId = val,
              ),
              // Goal type selector
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Text('Goal Type: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _goalType,
                      items: const [
                        DropdownMenuItem(value: 'EV', child: Text('Even')),
                        DropdownMenuItem(
                          value: 'PP',
                          child: Text('Power Play'),
                        ),
                        DropdownMenuItem(
                          value: 'SH',
                          child: Text('Short-Handed'),
                        ),
                        DropdownMenuItem(value: 'EN', child: Text('Empty Net')),
                      ],
                      onChanged: (v) => setState(() => _goalType = v ?? 'EV'),
                    ),
                  ],
                ),
              ),
              buildSection('Assist 1', assist1Id, (val) => assist1Id = val),
              buildSection('Assist 2', assist2Id, (val) => assist2Id = val),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = widget.isGoal
                ? {
                    'goalScorerId': goalScorerId,
                    'assist1Id': assist1Id,
                    'assist2Id': assist2Id,
                    'goalType': _goalType,
                  }
                : {'shooterId': shooterId};
            Navigator.pop(context, result);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
