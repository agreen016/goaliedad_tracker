import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../models/team.dart';

class CreatePlayerScreen extends StatefulWidget {
  final Team team;

  const CreatePlayerScreen({super.key, required this.team});

  @override
  State<CreatePlayerScreen> createState() => _CreatePlayerScreenState();
}

class _CreatePlayerScreenState extends State<CreatePlayerScreen> {
  final nameController = TextEditingController();
  final numberController = TextEditingController();
  String selectedPosition = 'Forward';

  void _savePlayer() {
    final name = nameController.text.trim();
    final number = int.tryParse(numberController.text.trim()) ?? 99;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a player name')),
      );
      return;
    }

    final newPlayer = Player(
      id: const Uuid().v4(),
      teamId: widget.team.id,
      name: name,
      number: number,
      position: selectedPosition,
    );

    Hive.box<Player>('players').put(newPlayer.id, newPlayer);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Player')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Player Name'),
            ),
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jersey Number'),
            ),
            DropdownButtonFormField<String>(
              value: selectedPosition,
              decoration: const InputDecoration(labelText: 'Position'),
              items: const [
                DropdownMenuItem(value: 'Forward', child: Text('Forward')),
                DropdownMenuItem(value: 'Defense', child: Text('Defense')),
                DropdownMenuItem(value: 'Goalie', child: Text('Goalie')),
              ],
              onChanged: (val) =>
                  setState(() => selectedPosition = val ?? 'Forward'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _savePlayer,
              icon: const Icon(Icons.save),
              label: const Text('Save Player'),
            ),
          ],
        ),
      ),
    );
  }
}
