import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'dart:io';

import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/game_event.dart';
import 'package:goaliedad_tracker/models/shot_marker.dart';

void main() {
  group('Marker options flow', () {
    late String tempDir;

    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('hive_test').path;
      Hive.init(tempDir);
      Hive.registerAdapter(GameAdapter());
      Hive.registerAdapter(GameEventAdapter());
      Hive.registerAdapter(ShotMarkerAdapter());
    });

    tearDownAll(() async {
      await Hive.close();
      try {
        Directory(tempDir).deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Edit -> Details -> Delete flow', () async {
      final box = await Hive.openBox<Game>('games');

      // Create a game
      final game = Game(
        id: 'g1',
        teamId: 't1',
        dateTime: DateTime.now(),
        opponent: 'op',
        gameType: 'reg',
        result: '',
      );

      // Start with 0-0 and 0 shots
      await box.put(game.id, game);

      // Simulate adding a shot event for home team
      final eventId = 'e1';
      final event = GameEvent(
        id: eventId,
        gameId: game.id,
        teamId: game.teamId,
        type: 'shot',
        period: 1,
        playerId: 'p1',
        details: {'dx': 100.0, 'dy': 200.0, 'isHomeShooting': true},
      );

      game.addEvent(event);
      game.homeShots = game.homeShots + 1;
      await game.save();

      // Verify saved
      final loaded = box.get(game.id)!;
      expect(loaded.homeShots, 1);
      expect(loaded.events?.any((e) => e.id == eventId), true);

      // --- Edit flow: change shooter -> create updated event and marker replacement ---
      final updatedPlayerId = 'p2';
      final updatedDetails = Map<String, dynamic>.from(event.details);
      updatedDetails['assist1Id'] = 'a1';
      updatedDetails['assist2Id'] = 'a2';

      final updatedEvent = GameEvent(
        id: event.id,
        gameId: event.gameId,
        teamId: event.teamId,
        type: event.type,
        period: event.period,
        playerId: updatedPlayerId,
        details: updatedDetails,
      );

      final evIdx = game.events?.indexWhere((e) => e.id == event.id) ?? -1;
      expect(evIdx, greaterThanOrEqualTo(0));
      if (evIdx != -1 && game.events != null) {
        game.events![evIdx] = updatedEvent;
        await game.save();
      }

      // Verify edit persisted
      final afterEdit = box.get(game.id)!;
      final fetched = afterEdit.events!.firstWhere((e) => e.id == event.id);
      expect(fetched.playerId, updatedPlayerId);
      expect(fetched.details['assist1Id'], 'a1');

      // --- Details: just ensure the event and marker positions/details are accessible ---
      expect(fetched.details['dx'], 100.0);
      expect(fetched.details['dy'], 200.0);

      // --- Delete flow: remove event and roll back shots ---
      afterEdit.events!.removeWhere((e) => e.id == event.id);
      final existAfterRemove = afterEdit.events!.any((e) => e.id == event.id);
      expect(existAfterRemove, false);

      // Decrement shots
      afterEdit.homeShots = (afterEdit.homeShots - 1).clamp(0, 9999);
      await afterEdit.save();

      final finalLoad = box.get(game.id)!;
      expect(finalLoad.homeShots, 0);
      expect(finalLoad.events?.any((e) => e.id == event.id), false);

      await box.delete(game.id);
    });
  });
}
