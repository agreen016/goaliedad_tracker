import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/game_event.dart';
import 'package:goaliedad_tracker/models/player.dart';
import 'package:goaliedad_tracker/models/goal.dart';

Future<void> main() async {
  final hivePath = '/home/andygreen/Documents';
  print('Attempting to open Hive at: $hivePath');
  try {
    Hive.init(hivePath);
    Hive.registerAdapter(GameAdapter());
    Hive.registerAdapter(GameEventAdapter());
    Hive.registerAdapter(PlayerAdapter());
    Hive.registerAdapter(GoalAdapter());
    final gameBox = await Hive.openBox<Game>('games');
    print('Games box open: \u001b[32m${gameBox.isOpen}\u001b[0m, count: \u001b[32m${gameBox.length}\u001b[0m');
    if (gameBox.isNotEmpty) {
      for (final game in gameBox.values) {
        print('Game: id=${game.id}, events=${game.events?.length ?? 0}');
        if (game.events != null) {
          for (final e in game.events!) {
            print('  Event: type=${e.type}, playerId=${e.playerId}, details=${e.details}');
          }
        }
      }
    } else {
      print('No games found in box.');
    }
    await Hive.close();
  } catch (e, st) {
    print('Error opening or reading Hive box: $e\n$st');
  }
}
