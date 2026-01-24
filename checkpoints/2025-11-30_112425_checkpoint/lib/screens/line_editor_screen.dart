import 'package:flutter/material.dart';
import '../models/team.dart';
import '../models/player.dart';
import '../models/line.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class LineEditorScreen extends StatefulWidget {
  final Team team;

  const LineEditorScreen({super.key, required this.team});

  @override
  State<LineEditorScreen> createState() => _LineEditorScreenState();
}

class _LineEditorScreenState extends State<LineEditorScreen> {
  final List<Map<String, Player?>> lines = [];
  final List<String?> lineIds = [];
  int activeLineIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadSavedLines();
  }

  void _loadSavedLines() {
    final lineBox = Hive.box<Line>('lines');
    final playerBox = Hive.box<Player>('players');

    Player? getPlayerById(String id) {
      try {
        return playerBox.values.firstWhere((p) => p.id == id);
      } catch (_) {
        return null;
      }
    }

    final savedLines = lineBox.values
        .where((l) => l.teamId == widget.team.id)
        .toList();

    final List<Map<String, Player?>> loadedLines = [];
    final List<String?> loadedIds = [];

    for (var line in savedLines) {
      loadedLines.add(
        Map<String, Player?>.from({
          'LW': getPlayerById(line.lwId),
          'C': getPlayerById(line.cId),
          'RW': getPlayerById(line.rwId),
          'LD': getPlayerById(line.ldId),
          'RD': getPlayerById(line.rdId),
        }),
      );
      loadedIds.add(line.id);
    }

    setState(() {
      lines
        ..clear()
        ..addAll(loadedLines);
      lineIds
        ..clear()
        ..addAll(loadedIds);
    });
  }

  void addNewLine() {
    setState(() {
      lines.add({'LW': null, 'C': null, 'RW': null, 'LD': null, 'RD': null});
      lineIds.add(null);
      activeLineIndex = lines.length - 1;
    });
  }

  void selectPlayer(String position) async {
    if (activeLineIndex == -1) return;

    final playerBox = Hive.box<Player>('players');
    final eligible = playerBox.values
        .where(
          (p) =>
              p.teamId == widget.team.id &&
              p.position.toLowerCase() != 'goalie',
        )
        .toList();

    final chosen = await showModalBottomSheet<Player>(
      context: context,
      builder: (_) => ListView(
        children: eligible.map((p) {
          return ListTile(
            title: Text('${p.name} (#${p.number})'),
            onTap: () => Navigator.pop(context, p),
          );
        }).toList(),
      ),
    );

    if (!mounted) return;

    if (chosen != null) {
      final alreadyUsed = lines.any(
        (line) => line.entries.any((entry) => entry.value?.id == chosen.id),
      );

      if (alreadyUsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${chosen.name} is already assigned')),
        );
        return;
      }

      setState(() {
        lines[activeLineIndex][position] = chosen;
      });
    }
  }

  void saveLine(int index) {
    final selectedPlayers = lines[index];
    if (selectedPlayers.values.any((p) => p == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign all positions')),
      );
      return;
    }

    final lineBox = Hive.box<Line>('lines');
    final existingId = lineIds[index];

    if (existingId != null) {
      final existingLine = lineBox.values.firstWhere((l) => l.id == existingId);
      final updatedLine = Line(
        id: existingLine.id,
        teamId: widget.team.id,
        name: existingLine.name,
        lwId: selectedPlayers['LW']!.id,
        cId: selectedPlayers['C']!.id,
        rwId: selectedPlayers['RW']!.id,
        ldId: selectedPlayers['LD']!.id,
        rdId: selectedPlayers['RD']!.id,
      );
      final boxIndex = lineBox.values.toList().indexOf(existingLine);
      lineBox.putAt(boxIndex, updatedLine);
    } else {
      final lineCount = lineBox.values
          .where((l) => l.teamId == widget.team.id)
          .length;
      final newLine = Line(
        id: const Uuid().v4(),
        teamId: widget.team.id,
        name: 'L${lineCount + 1}',
        lwId: selectedPlayers['LW']!.id,
        cId: selectedPlayers['C']!.id,
        rwId: selectedPlayers['RW']!.id,
        ldId: selectedPlayers['LD']!.id,
        rdId: selectedPlayers['RD']!.id,
      );
      lineBox.add(newLine);
      lineIds[index] = newLine.id;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Line saved')));
  }

  void deleteLine(int index) {
    final lineId = lineIds[index];
    if (lineId != null) {
      final lineBox = Hive.box<Line>('lines');
      final lineToDelete = lineBox.values.firstWhere((l) => l.id == lineId);
      lineToDelete.delete();
    }

    setState(() {
      lines.removeAt(index);
      lineIds.removeAt(index);
      if (activeLineIndex == index) activeLineIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeLine = activeLineIndex >= 0 ? lines[activeLineIndex] : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Line Editor')),
      body: Column(
        children: [
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/center_ice.png',
                    fit: BoxFit.cover,
                  ),
                ),
                if (activeLine != null)
                  ...['LW', 'C', 'RW', 'LD', 'RD'].map((pos) {
                    final player = activeLine[pos];
                    final label = player != null ? '${player.number}' : pos;

                    return Positioned(
                      top: _getTop(pos),
                      left: _getLeft(pos),
                      child: GestureDetector(
                        onTap: () => selectPlayer(pos),
                        child: Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha((0.75 * 255).round()),
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: addNewLine,
              icon: const Icon(Icons.add),
              label: const Text('Add Line'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                return Dismissible(
                  key: Key(lineIds[index] ?? 'temp_$index'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => deleteLine(index),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'L${index + 1}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: ['LW', 'C', 'RW'].map((pos) {
                              final player = line[pos];
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => activeLineIndex = index);
                                    selectPlayer(pos);
                                  },
                                  child: Text(
                                    '$pos: ${player?.name ?? 'Select'} ${player?.number ?? ''}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: ['LD', 'RD'].map((pos) {
                              final player = line[pos];
                              return GestureDetector(
                                onTap: () {
                                  setState(() => activeLineIndex = index);
                                  selectPlayer(pos);
                                },
                                child: Text(
                                  '$pos: ${player?.name ?? 'Select'} ${player?.number ?? ''}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () => saveLine(index),
                              child: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  double _getTop(String pos) {
    switch (pos) {
      case 'LW':
        return 200;
      case 'C':
        return 180;
      case 'RW':
        return 200;
      case 'LD':
        return 260;
      case 'RD':
        return 260;
      default:
        return 0;
    }
  }

  double _getLeft(String pos) {
    final screenWidth = MediaQuery.of(context).size.width;
    switch (pos) {
      case 'LW':
        return 40;
      case 'C':
        return screenWidth / 2 - 30;
      case 'RW':
        return screenWidth - 100;
      case 'LD':
        return 80;
      case 'RD':
        return screenWidth - 120;
      default:
        return 0;
    }
  }
}
