import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/opponent.dart';
import '../services/premium_service.dart';
import '../widgets/upgrade_dialog.dart';

class OpponentSelectionScreen extends StatefulWidget {
  final void Function(Opponent) onSelect;

  const OpponentSelectionScreen({required this.onSelect, super.key});

  @override
  State<OpponentSelectionScreen> createState() =>
      _OpponentSelectionScreenState();
}

class _OpponentSelectionScreenState extends State<OpponentSelectionScreen> {
  final _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  late Box<Opponent> _opponentBox;

  @override
  void initState() {
    super.initState();
    _opponentBox = Hive.box<Opponent>('opponents');
  }

  Future<void> _createOpponent() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // Check premium limit
    final canCreate = await PremiumService.canCreateOpponent();
    if (!canCreate && mounted) {
      showDialog(
        context: context,
        builder: (_) => UpgradeToPremiumDialog(
          title: 'Opponent Limit Reached',
          message: 'Free users can create up to ${PremiumService.maxFreeOpponents} opponents. Upgrade to premium for unlimited opponents.',
        ),
      );
      return;
    }

    // Compute ARGB int using component-accessor conversion to bytes
    final aInt = ((_selectedColor.a * 255.0).round() & 0xff);
    final r = ((_selectedColor.r * 255.0).round() & 0xff);
    final g = ((_selectedColor.g * 255.0).round() & 0xff);
    final b = ((_selectedColor.b * 255.0).round() & 0xff);
    final argb = (aInt << 24) | (r << 16) | (g << 8) | b;
    final newOpponent = Opponent(name: name, colorValue: argb);
    _opponentBox.add(newOpponent);
    _nameController.clear();
    setState(() {}); // Refresh list
  }

  void _pickColor(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Opponent Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
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

  @override
  Widget build(BuildContext context) {
    final opponents = _opponentBox.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Opponent')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Existing Opponents
            Expanded(
              child: opponents.isEmpty
                  ? const Center(child: Text('No opponents yet'))
                  : ListView.builder(
                      itemCount: opponents.length,
                      itemBuilder: (_, index) {
                        final opponent = opponents[index];
                        return Card(
                          color: opponent.color,
                          child: ListTile(
                            title: Text(
                              opponent.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              widget.onSelect(opponent);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 32),

            // Create New Opponent
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Opponent Name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Opponent Color:'),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _pickColor(context),
                  child: CircleAvatar(
                    backgroundColor: _selectedColor,
                    radius: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _createOpponent,
              child: const Text('Create Opponent'),
            ),
          ],
        ),
      ),
    );
  }
}
