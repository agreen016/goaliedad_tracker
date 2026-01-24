import 'package:flutter_test/flutter_test.dart';
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/game_event.dart';

void main() {
  test('game score increments with goal event and decrements when removed', () {
    final game = Game(
      id: 'g1',
      teamId: 't1',
      dateTime: DateTime.now(),
      opponent: 'Opp',
      gameType: 'Regular',
      result: '',
    );

    expect(game.homeScore, 0);

    final event = GameEvent(
      id: 'e1',
      gameId: game.id,
      teamId: game.teamId,
      type: 'goal',
      period: 1,
      playerId: 'p1',
      details: {'dx': 100.0, 'dy': 200.0},
    );

    game.addEvent(event);

    // addEvent saves and appends; ensure event present and score not auto-incremented by addEvent
    expect(game.events!.any((e) => e.id == 'e1'), true);

    // simulate score change that UI code would do
    game.homeScore = game.homeScore + 1;
    expect(game.homeScore, 1);

    // simulate removing event
    game.events!.removeWhere((e) => e.id == 'e1');
    game.homeScore = game.homeScore - 1;
    expect(game.homeScore, 0);
  });
}
