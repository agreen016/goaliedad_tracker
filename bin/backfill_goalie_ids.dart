import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/goal.dart';
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/game_event.dart';

// Simple backfill utility. Run with `dart run bin/backfill_goalie_ids.dart` from repo root.
// It opens Hive boxes, scans Goal records with empty goalieId and tries to assign a goalieId from
// (1) nearby GameEvent with a goalieId, (2) the game's startingGoalie, or (3) leaves empty.

Future<void> main() async {
  // Initialize Hive without Flutter. Use a local directory under the repo so
  // the same data files are used when running from the project root.
  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Directory(hivePath).createSync(recursive: true);

  Hive.init(hivePath);
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(GameEventAdapter());

  final goalBox = await Hive.openBox<Goal>('goals');
  final gameBox = await Hive.openBox<Game>('games');

  int updated = 0;

  for (final goal in goalBox.values) {
    if (goal.goalieId.isEmpty) {
      final game = gameBox.get(goal.gameId);
      String inferred = '';
      if (game != null) {
        // try to find a game event in the same game and period that has a goalieId
        final events = game.events ?? [];
        for (final ev in events) {
          if ((ev.type == 'shot' || ev.type == 'goal') &&
              (ev.details['goalieId'] ?? '').toString().isNotEmpty) {
            inferred = ev.details['goalieId'] as String;
            break;
          }
        }
        // fallback
        if (inferred.isEmpty && (game.startingGoalie ?? '').isNotEmpty) {
          inferred = game.startingGoalie!;
        }
      }

      if (inferred.isNotEmpty) {
        goal.goalieId = inferred;
        await goal.save();
        updated++;
      }
    }
  }

  print('Backfill complete. Updated: $updated goals');
  await Hive.close();
}
