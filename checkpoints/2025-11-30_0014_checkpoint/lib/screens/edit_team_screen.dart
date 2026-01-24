import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/team.dart';
import 'team_hub_screen.dart';

class EditTeamScreen extends StatefulWidget {
  final Team team;

  const EditTeamScreen({super.key, required this.team});

  @override
  State<EditTeamScreen> createState() => _EditTeamScreenState();
}

class _EditTeamScreenState extends State<EditTeamScreen> {
  late TextEditingController nameController;
  late Color selectedColor;
  File? logoFile;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.team.name);
    selectedColor = Color(
      int.parse(widget.team.primaryColorHex.replaceFirst('#', '0xFF')),
    );
    if (widget.team.logoPath != null) {
      logoFile = File(widget.team.logoPath!);
    }
  }

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

  void _updateTeam() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a team name')));
      return;
    }

    widget.team.name = name;
    widget.team.primaryColorHex = _colorToHex(selectedColor);
    widget.team.logoPath = logoFile?.path;
    widget.team.save();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TeamHubScreen(team: widget.team)),
    );
  }

  String _colorToHex(Color c) {
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
      appBar: AppBar(title: const Text('Edit Team')),
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
              onPressed: _updateTeam,
              icon: const Icon(Icons.save),
              label: const Text('Update Team'),
            ),
          ],
        ),
      ),
    );
  }
}
