import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_test/hive_test.dart';
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/game_event.dart';

void main() {
  setUp(() async {
    await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('recording a goal persists game and event', () async {
    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(GameAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(GameEventAdapter());
    }

    final gameBox = await Hive.openBox<Game>('games');

    final game = Game(
      id: 'g_test',
      teamId: 't1',
      dateTime: DateTime.now(),
      opponent: 'Opp',
      gameType: 'Regular',
      result: '',
    );

    await gameBox.put(game.id, game);

    // Simulate a home goal being recorded (UI would do both event add and score increment)
    final event = GameEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      gameId: game.id,
      teamId: game.teamId,
      type: 'goal',
      period: 1,
      playerId: 'p1',
      details: {'dx': 100.0, 'dy': 200.0},
    );

    // Append to game's events and increment score
    game.events = game.events ?? [];
    game.events!.add(event);
    game.homeScore = game.homeScore + 1;

    // Save game back to box
    await game.save();

    // Re-open box to ensure persistence
    await gameBox.compact();
    final loaded = gameBox.get(game.id) as Game;

    expect(loaded.homeScore, 1);
    expect(
      loaded.events != null && loaded.events!.any((e) => e.id == event.id),
      true,
    );

    await gameBox.close();
  });
}
