import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/goal.dart';
import 'package:goaliedad_tracker/models/game_event.dart';

Future<void> main() async {
  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Hive.init(hivePath);
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(GameEventAdapter());

  final goalBox = await Hive.openBox<Goal>('goals');
  final g = Goal(
    id: 'sample-1',
    gameId: 'game-1',
    teamId: 'team-A',
    period: '1',
    scorerId: 'player-1',
    assistIds: ['player-2'],
    goalType: 'PP',
    time: '05:12',
    goalieId: 'goalie-9',
  );

  await goalBox.put(g.id, g);
  print('Wrote sample goal id=${g.id} to ${goalBox.path}');
  await Hive.close();
}
