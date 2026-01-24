import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/game_event.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart bin/dump_game_events.dart <gameId>');
    exit(2);
  }
  final gameId = args[0];
  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Hive.init(hivePath);
  Hive.registerAdapter(GameEventAdapter());

  final box = await Hive.openBox<GameEvent>('game_events');
  final events = box.values.where((e) => e.gameId == gameId).toList();
  if (events.isEmpty) {
    print('No events found for gameId=$gameId');
  } else {
    for (final e in events) {
      print(
        'Event id=${e.id} type=${e.type} period=${e.period} player=${e.playerId}',
      );
      print(' details: ${e.details}');
    }
  }

  await Hive.close();
}
