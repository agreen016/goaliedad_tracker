import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/team.dart';
import 'team_hub_screen.dart';

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final nameController = TextEditingController();
  Color selectedColor = Colors.blue;
  File? logoFile;

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => logoFile = File(picked.path));
    }
  }

  void _pickColor(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Team Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: selectedColor,
            onColorChanged: (color) => setState(() => selectedColor = color),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _saveTeam() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a team name')));
      return;
    }

    final newTeam = Team(
      id: const Uuid().v4(),
      name: name,
      league: '',
      division: '',
      seasonStartYear: DateTime.now().year,
      seasonEndYear: DateTime.now().year + 1,
      primaryColorHex: _colorToHex(selectedColor),
      secondaryColorHex: '#FFFFFF',
      logoPath: logoFile?.path,
    );

    Hive.box<Team>('teams').add(newTeam);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TeamHubScreen(team: newTeam)),
    );
  }

  String _colorToHex(Color c) {
    // Convert RGB (0.0-1.0) to #RRGGBB using component accessors
    final rInt = ((c.r * 255.0).round() & 0xff)
        .toRadixString(16)
        .padLeft(2, '0');
    final gInt = ((c.g * 255.0).round() & 0xff)
        .toRadixString(16)
        .padLeft(2, '0');
    final bInt = ((c.b * 255.0).round() & 0xff)
        .toRadixString(16)
        .padLeft(2, '0');
    return '#$rInt$gInt$bInt'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Team')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Team Name'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Team Color:'),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _pickColor(context),
                  child: CircleAvatar(
                    backgroundColor: selectedColor,
                    radius: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Team Logo:'),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _pickLogo,
                  child: logoFile != null
                      ? CircleAvatar(
                          backgroundImage: FileImage(logoFile!),
                          radius: 16,
                        )
                      : const CircleAvatar(
                          radius: 16,
                          child: Icon(Icons.image),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _saveTeam,
              icon: const Icon(Icons.save),
              label: const Text('Create Team'),
            ),
          ],
        ),
      ),
    );
  }
}
