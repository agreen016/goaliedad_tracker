import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/goal.dart';
import 'package:goaliedad_tracker/models/game.dart';

Future<void> main() async {
  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Hive.init(hivePath);
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(GameAdapter());

  final goalBox = await Hive.openBox<Goal>('goals');
  final gameBox = await Hive.openBox<Game>('games');

  print('Hive path: $hivePath');
  print('Goals box open: ${goalBox.isOpen}, count: ${goalBox.length}');
  print('Games box open: ${gameBox.isOpen}, count: ${gameBox.length}');

  if (goalBox.isNotEmpty) {
    final sample = goalBox.values.take(5).toList();
    for (final g in sample) {
      print(
        'Goal: id=${g.id}, gameId=${g.gameId}, goalieId="${g.goalieId}", scorer=${g.scorerId}, type=${g.goalType}',
      );
    }
  }

  await Hive.close();
}
