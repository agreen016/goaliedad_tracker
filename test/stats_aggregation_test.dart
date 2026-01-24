import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/game_event.dart';
import 'package:goaliedad_tracker/models/player.dart';
import 'package:goaliedad_tracker/models/goal.dart';

// This test uses a temporary Hive directory to avoid touching app data.
void main() {
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('goaliedad_test_');
    Hive.init(tmpDir.path);

    // Register adapters used in the app. If adapters are generated, they must be
    // available at runtime for tests. We assume build_runner was run and the
    // generated adapters are present.
    Hive.registerAdapter(GameAdapter());
    Hive.registerAdapter(GameEventAdapter());
    Hive.registerAdapter(PlayerAdapter());
    Hive.registerAdapter(GoalAdapter());

    // Open boxes needed by aggregation code
    await Hive.openBox<Player>('players');
    await Hive.openBox<Game>('games');
    await Hive.openBox<Goal>('goals');
  });

  tearDownAll(() async {
    try {
      await Hive.box<Player>('players').close();
    } catch (_) {}
    try {
      await Hive.box<Game>('games').close();
    } catch (_) {}
    try {
      await Hive.box<Goal>('goals').close();
    } catch (_) {}
    try {
      await Hive.close();
    } catch (_) {}
    try {
      tmpDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test(
    'plus minus and goalie GAA aggregate correctly from events and goals',
    () async {
      final players = Hive.box<Player>('players');
      final games = Hive.box<Game>('games');
      final goals = Hive.box<Goal>('goals');

      // create a team and players
      final teamId = 'team-1';
      final goalie = Player(
        id: 'g1',
        teamId: teamId,
        name: 'Goalie One',
        number: 1,
        position: 'goalie',
      );
      final skaterA = Player(
        id: 'a1',
        teamId: teamId,
        name: 'Skater A',
        number: 9,
        position: 'LW',
      );
      final skaterB = Player(
        id: 'a2',
        teamId: teamId,
        name: 'Skater B',
        number: 10,
        position: 'C',
      );

      await players.put(goalie.id, goalie);
      await players.put(skaterA.id, skaterA);
      await players.put(skaterB.id, skaterB);

      // create a game and persist
      final game = Game(
        id: 'game-1',
        teamId: teamId,
        dateTime: DateTime.now(),
        opponent: '',
        gameType: 'League',
        result: '',
      );
      await games.put(game.id, game);

      // create events: one goal by our team while onIce shows goalie and skaters
      final onIce = {'LW': skaterA.id, 'C': skaterB.id, 'G': goalie.id};

      final ev1 = GameEvent(
        id: 'ev-1',
        gameId: game.id,
        teamId: teamId,
        type: 'goal',
        period: 1,
        playerId: skaterA.id,
        details: {'onIce': onIce},
      );

      final ev2 = GameEvent(
        id: 'ev-2',
        gameId: game.id,
        teamId: 'opponent',
        type: 'goal',
        period: 1,
        playerId: 'opp-scorer',
        details: {
          'onIce': {'G': 'oppG'},
        },
      );

      // persist events on the game
      final g = games.get(game.id)!;
      g.events = [ev1, ev2];
      await g.save();

      // create a Goal record for opponent goal attributing GA to our goalie
      final goalRecord = Goal(
        id: 'goal-1',
        gameId: game.id,
        teamId: 'opponent',
        period: '1',
        scorerId: 'opp-scorer',
        assistIds: [],
        goalType: 'EV',
        time: '10:00',
        goalieId: goalie.id,
      );
      await goals.put(goalRecord.id, goalRecord);

      // Now compute aggregates similarly to the app code
      // Compute +/- for players on our team: ev1 is a + for our skaters, ev2 is a -
      final Map<String, int> plusMinus = {
        skaterA.id: 0,
        skaterB.id: 0,
        goalie.id: 0,
      };
      for (final ev in g.events ?? []) {
        if (ev.type == 'goal') {
          final details = ev.details;
          if (details['onIce'] != null && details['onIce'] is Map) {
            final onIceLoc = Map<String, dynamic>.from(details['onIce']);
            for (final entry in onIceLoc.entries) {
              final pid = (entry.value ?? '').toString();
              if (pid.isEmpty) continue;
              if (pid == skaterA.id || pid == skaterB.id || pid == goalie.id) {
                if (ev.teamId == teamId) {
                  plusMinus[pid] = (plusMinus[pid] ?? 0) + 1;
                } else {
                  plusMinus[pid] = (plusMinus[pid] ?? 0) - 1;
                }
              }
            }
          }
        }
      }

      // Compute GA and minutes for goalie from goals and events
      int ga = 0;
      for (final gr in goals.values.where((gg) => gg.gameId == game.id)) {
        if (gr.goalieId == goalie.id && gr.teamId != teamId) {
          ga += 1;
        }
      }

      final Set<int> periodsSeen = {};
      for (final ev in g.events ?? []) {
        if (ev.details['onIce'] != null && ev.details['onIce'] is Map) {
          final onIceLoc = Map<String, dynamic>.from(ev.details['onIce']);
          if ((onIceLoc['G'] ?? '') == goalie.id) periodsSeen.add(ev.period);
        }
      }
      final minutes = periodsSeen.isNotEmpty ? (periodsSeen.length * 20) : 0;
      final gaa = minutes > 0 ? ((ga / minutes) * 60) : 0.0;

      expect(plusMinus[skaterA.id], 1);
      expect(plusMinus[skaterB.id], 1);
      expect(plusMinus[goalie.id], 1);
      expect(ga, 1);
      expect(minutes, 20);
      expect(gaa, closeTo(3.0, 0.0001));
    },
  );
}
