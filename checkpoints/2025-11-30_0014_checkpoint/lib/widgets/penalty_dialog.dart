// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/game_event.dart';

class PenaltyDialog extends StatefulWidget {
  final Game game;
  final Player defaultPlayer;
  final int currentPeriod;

  const PenaltyDialog({
    required this.game,
    required this.defaultPlayer,
    required this.currentPeriod,
    super.key,
  });

  @override
  State<PenaltyDialog> createState() => _PenaltyDialogState();
}

class _PenaltyDialogState extends State<PenaltyDialog> {
  late Player selectedPlayer;
  String selectedPenalty = 'Hooking';
  int selectedMinutes = 2;

  final penaltyTypes = [
    'Hooking',
    'Tripping',
    'Slashing',
    'Interference',
    'High-Sticking',
    'Boarding',
    'Roughing',
    'Delay of Game',
    'Too Many Men',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    selectedPlayer = widget.defaultPlayer;
  }

  void saveEvent() async {
    final event = GameEvent(
      id: const Uuid().v4(),
      gameId: widget.game.id,
      teamId: widget.game.teamId,
      type: 'penalty',
      period: widget.currentPeriod,
      playerId: selectedPlayer.id,
      details: {'penalty': selectedPenalty, 'minutes': selectedMinutes},
    );

    widget.game.events = [...?widget.game.events, event];
    await widget.game.save();

    Navigator.pop(context);
  }

  void choosePlayer() async {
    final playerBox = Hive.box<Player>('players');
    final eligible = playerBox.values
        .where((p) => widget.game.availablePlayerIds.contains(p.id))
        .toList();

    final localContext = context;
    final picked = await showModalBottomSheet<Player>(
      context: localContext,
      builder: (_) => ListView(
        children: eligible.map((p) {
          return ListTile(
            title: Text('${p.name} (#${p.number})'),
            onTap: () => Navigator.pop(localContext, p),
          );
        }).toList(),
      ),
    );

    if (picked != null) {
      if (!mounted) return;
      setState(() {
        selectedPlayer = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Penalty'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Penalty Type'),
          Wrap(
            spacing: 8,
            children: penaltyTypes.map((type) {
              final isSelected = selectedPenalty == type;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.red : Colors.grey[300],
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() => selectedPenalty = type),
                child: Text(type),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Duration'),
          Wrap(
            spacing: 8,
            children: [2, 5, 10].map((min) {
              final isSelected = selectedMinutes == min;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? Colors.orange
                      : Colors.grey[300],
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() => selectedMinutes = min),
                child: Text('$min min'),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Player Number'),
          GestureDetector(
            onTap: choosePlayer,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('#${selectedPlayer.number}'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: saveEvent, child: const Text('Confirm')),
      ],
    );
  }
}
