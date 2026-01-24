import 'package:flutter/material.dart';
import '../models/player.dart';

class EditPlayerScreen extends StatefulWidget {
  final Player player;

  const EditPlayerScreen({super.key, required this.player});

  @override
  State<EditPlayerScreen> createState() => _EditPlayerScreenState();
}

class _EditPlayerScreenState extends State<EditPlayerScreen> {
  late TextEditingController nameController;
  late TextEditingController numberController;
  late String selectedPosition;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.player.name);
    numberController = TextEditingController(
      text: widget.player.number.toString(),
    );
    selectedPosition = widget.player.position;
  }

  void _updatePlayer() {
    final name = nameController.text.trim();
    final number = int.tryParse(numberController.text.trim()) ?? 99;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a player name')),
      );
      return;
    }

    widget.player.name = name;
    widget.player.number = number;
    widget.player.position = selectedPosition;
    widget.player.save();

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Player')),
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
                  setState(() => selectedPosition = val ?? selectedPosition),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _updatePlayer,
              icon: const Icon(Icons.save),
              label: const Text('Update Player'),
            ),
          ],
        ),
      ),
    );
  }
}
