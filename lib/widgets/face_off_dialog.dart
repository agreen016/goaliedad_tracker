// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../models/game_event.dart';

class FaceOffDialog extends StatefulWidget {
  final Game game;
  final Player defaultPlayer;
  final int currentPeriod;

  const FaceOffDialog({
    required this.game,
    required this.defaultPlayer,
    required this.currentPeriod,
    super.key,
  });

  @override
  State<FaceOffDialog> createState() => _FaceOffDialogState();
}

class _FaceOffDialogState extends State<FaceOffDialog> {
  String selectedZone = 'Neutral';
  String selectedResult = '';
  late Player selectedPlayer;

  @override
  void initState() {
    super.initState();
    selectedPlayer = widget.defaultPlayer;
  }

  void saveEvent() async {
    if (selectedResult.isEmpty) return;

    final event = GameEvent(
      id: const Uuid().v4(),
      gameId: widget.game.id,
      teamId: widget.game.teamId,
      type: 'faceoff',
      period: widget.currentPeriod,
      playerId: selectedPlayer.id,
      details: {'zone': selectedZone, 'result': selectedResult},
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
      title: const Text('Face-Off'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Zone'),
          Wrap(
            spacing: 8,
            children: ['Offensive', 'Neutral', 'Defensive'].map((zone) {
              final isSelected = selectedZone == zone;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() => selectedZone = zone),
                child: Text(zone),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text('Result'),
          Wrap(
            spacing: 8,
            children: ['Won', 'Lost'].map((result) {
              final isSelected = selectedResult == result;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.green : Colors.grey[300],
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() => selectedResult = result),
                child: Text(result),
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
