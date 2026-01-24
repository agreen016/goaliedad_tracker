import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/player.dart';
import '../models/line.dart';

class ChooseLineDialog extends StatelessWidget {
  final String teamId;

  const ChooseLineDialog({super.key, required this.teamId});

  @override
  Widget build(BuildContext context) {
    final lineBox = Hive.box<Line>('lines');
    final playerBox = Hive.box<Player>('players');

    final lines = lineBox.values.where((l) => l.teamId == teamId).toList();

    Player? getPlayer(String id) {
      try {
        return playerBox.values.firstWhere((p) => p.id == id);
      } catch (_) {
        return null;
      }
    }

    return AlertDialog(
      title: const Text('Choose Line'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: lines.length,
          itemBuilder: (context, index) {
            final line = lines[index];
            final lw = getPlayer(line.lwId);
            final c = getPlayer(line.cId);
            final rw = getPlayer(line.rwId);
            final ld = getPlayer(line.ldId);
            final rd = getPlayer(line.rdId);

            return ListTile(
              title: Text(line.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LW: ${lw?.number ?? ''}  C: ${c?.number ?? ''}  RW: ${rw?.number ?? ''}',
                  ),
                  Text('LD: ${ld?.number ?? ''}  RD: ${rd?.number ?? ''}'),
                ],
              ),
              onTap: () => Navigator.pop(context, line),
            );
          },
        ),
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
