import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/game_event.dart';
import 'package:goaliedad_tracker/models/player.dart';
import 'package:goaliedad_tracker/models/goal.dart';

void main() {
  late Directory tmpDir;

  setUpAll(() async {
    tmpDir = await Directory.systemTemp.createTemp('goaliedad_stat_');
    Hive.init(tmpDir.path);
    Hive.registerAdapter(GameAdapter());
    Hive.registerAdapter(GameEventAdapter());
    Hive.registerAdapter(PlayerAdapter());
    Hive.registerAdapter(GoalAdapter());
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

  test('goals, assists, points, PPG, SHG aggregate correctly', () async {
    final players = Hive.box<Player>('players');
    final games = Hive.box<Game>('games');
    final goals = Hive.box<Goal>('goals');

    final teamId = 'team-t1';
    final p1 = Player(
      id: 'p1',
      teamId: teamId,
      name: 'One',
      number: 1,
      position: 'C',
    );
    final p2 = Player(
      id: 'p2',
      teamId: teamId,
      name: 'Two',
      number: 2,
      position: 'LW',
    );
    await players.put(p1.id, p1);
    await players.put(p2.id, p2);

    final g = Game(
      id: 'g1',
      teamId: teamId,
      dateTime: DateTime.now(),
      opponent: '',
      gameType: 'League',
      result: '',
    );
    await games.put(g.id, g);

    // create two goals: one even strength by p1 with assist p2, one PP by p2
    final goal1 = Goal(
      id: 'goal1',
      gameId: g.id,
      teamId: teamId,
      period: '1',
      scorerId: p1.id,
      assistIds: [p2.id],
      goalType: 'EV',
      time: '05:00',
      goalieId: '',
    );
    final goal2 = Goal(
      id: 'goal2',
      gameId: g.id,
      teamId: teamId,
      period: '2',
      scorerId: p2.id,
      assistIds: [],
      goalType: 'PP',
      time: '10:00',
      goalieId: '',
    );
    await goals.put(goal1.id, goal1);
    await goals.put(goal2.id, goal2);

    // Now compute simple aggregates similar to app behavior
    int p1g = 0, p1a = 0, p1p = 0;
    int p2g = 0, p2a = 0, p2p = 0, p2ppg = 0;
    for (final gr in goals.values.where((gg) => gg.gameId == g.id)) {
      if (gr.teamId == teamId) {
        if (gr.scorerId == p1.id) {
          p1g++;
          p1p++;
        }
        if (gr.scorerId == p2.id) {
          p2g++;
          p2p++;
        }
        for (final a in gr.assistIds) {
          if (a == p1.id) {
            p1a++;
            p1p++;
          }
          if (a == p2.id) {
            p2a++;
            p2p++;
          }
        }
        if ((gr.goalType ?? '').toString().toUpperCase() == 'PP') {
          if (gr.scorerId == p2.id) p2ppg++;
        }
      }
    }

    expect(p1g, 1);
    expect(p1a, 0);
    expect(p1p, 1);
    expect(p2g, 1);
    expect(p2a, 1);
    expect(p2p, 2);
    expect(p2ppg, 1);
  });

  test('plus/minus, faceoffs (FW%) and PIM aggregate correctly', () async {
    final players = Hive.box<Player>('players');
    final games = Hive.box<Game>('games');

    final teamId = 'team-t2';
    final sk1 = Player(
      id: 's1',
      teamId: teamId,
      name: 'S1',
      number: 3,
      position: 'RW',
    );
    final sk2 = Player(
      id: 's2',
      teamId: teamId,
      name: 'S2',
      number: 4,
      position: 'C',
    );
    await players.put(sk1.id, sk1);
    await players.put(sk2.id, sk2);

    final game = Game(
      id: 'g2',
      teamId: teamId,
      dateTime: DateTime.now(),
      opponent: '',
      gameType: 'League',
      result: '',
    );
    // create events with onIce snapshot and faceoffs and penalty
    final onIceGoal = {'RW': sk1.id, 'C': sk2.id, 'G': ''};
    final evGoal = GameEvent(
      id: 'e1',
      gameId: game.id,
      teamId: teamId,
      type: 'goal',
      period: 1,
      playerId: sk1.id,
      details: {'onIce': onIceGoal},
    );
    final evOppGoal = GameEvent(
      id: 'e2',
      gameId: game.id,
      teamId: 'opp',
      type: 'goal',
      period: 1,
      playerId: 'opp1',
      details: {
        'onIce': {'G': 'oppG'},
      },
    );
    final evF1 = GameEvent(
      id: 'e3',
      gameId: game.id,
      teamId: teamId,
      type: 'faceoff',
      period: 1,
      playerId: sk2.id,
      details: {'result': 'won'},
    );
    final evF2 = GameEvent(
      id: 'e4',
      gameId: game.id,
      teamId: teamId,
      type: 'faceoff',
      period: 1,
      playerId: sk2.id,
      details: {'result': 'lost'},
    );
    final evP = GameEvent(
      id: 'e5',
      gameId: game.id,
      teamId: teamId,
      type: 'penalty',
      period: 1,
      playerId: sk2.id,
      details: {'minutes': 2},
    );

    game.events = [evGoal, evOppGoal, evF1, evF2, evP];
    await games.put(game.id, game);

    // compute +/-
    final plusMinus = {sk1.id: 0, sk2.id: 0};
    for (final ev in game.events ?? []) {
      if (ev.type == 'goal') {
        final details = ev.details;
        if (details['onIce'] != null && details['onIce'] is Map) {
          final onIce = Map<String, dynamic>.from(details['onIce']);
          for (final entry in onIce.entries) {
            final pid = (entry.value ?? '').toString();
            if (pid.isEmpty) continue;
            if (pid == sk1.id || pid == sk2.id) {
              if (ev.teamId == teamId)
                plusMinus[pid] = (plusMinus[pid] ?? 0) + 1;
              else
                plusMinus[pid] = (plusMinus[pid] ?? 0) - 1;
            }
          }
        }
      } else if (ev.type == 'faceoff') {
        final pid = ev.playerId;
        if (pid == sk2.id) {
          final res = (ev.details['result'] ?? '').toString().toLowerCase();
          // track via counters
        }
      }
    }

    expect(plusMinus[sk1.id], 1);
    expect(plusMinus[sk2.id], 1);

    // faceoff FW%: sk2 has 1 won and 1 lost -> FW% = 50
    // compute FW/FL
    int fw = 0, fl = 0;
    for (final ev in game.events ?? []) {
      if (ev.type == 'faceoff' && ev.playerId == sk2.id) {
        final res = (ev.details['result'] ?? '').toString().toLowerCase();
        if (res == 'won')
          fw++;
        else if (res == 'lost')
          fl++;
      }
    }
    final fwPct = (fw + fl) > 0 ? ((fw * 100) / (fw + fl)).round() : 0;
    expect(fw, 1);
    expect(fl, 1);
    expect(fwPct, 50);

    // PIM from penalty
    int pim = 0;
    for (final ev in game.events ?? []) {
      if (ev.type == 'penalty' && ev.playerId == sk2.id) {
        pim += (ev.details['minutes'] ?? 0) as int? ?? 0;
      }
    }
    expect(pim, 2);
  });

  test('goalie aggregates: SOG, GA, GAA, SV, SV%', () async {
    final players = Hive.box<Player>('players');
    final games = Hive.box<Game>('games');
    final goals = Hive.box<Goal>('goals');

    final teamId = 'team-g';
    final gk = Player(
      id: 'gk1',
      teamId: teamId,
      name: 'Keeper',
      number: 1,
      position: 'Goalie',
    );
    await players.put(gk.id, gk);

    final game = Game(
      id: 'gg1',
      teamId: teamId,
      dateTime: DateTime.now(),
      opponent: '',
      gameType: 'League',
      result: '',
      startingGoalie: gk.id,
    );
    // events: two opponent shots, one goal among them
    final ev1 = GameEvent(
      id: 's1',
      gameId: game.id,
      teamId: 'opp',
      type: 'shot',
      period: 1,
      playerId: 'op1',
      details: {'goalieId': gk.id},
    );
    final ev2 = GameEvent(
      id: 's2',
      gameId: game.id,
      teamId: 'opp',
      type: 'shot',
      period: 1,
      playerId: 'op2',
      details: {'goalieId': gk.id},
    );
    game.events = [ev1, ev2];
    await games.put(game.id, game);

    // create a Goal record for one opponent goal attributed to our goalie
    final gr = Goal(
      id: 'ggoal1',
      gameId: game.id,
      teamId: 'opp',
      period: '1',
      scorerId: 'op1',
      assistIds: [],
      goalType: 'EV',
      time: '08:00',
      goalieId: gk.id,
    );
    await goals.put(gr.id, gr);

    // compute SOG: count shots where ev.teamId != teamId
    int sog = 0;
    for (final ev in game.events ?? []) {
      if ((ev.type == 'shot' || ev.type == 'goal') && ev.teamId != teamId)
        sog++;
    }
    // compute GA from Goal records where goalieId matches and goal.teamId != teamId
    int ga = 0;
    for (final grec in goals.values.where((gg) => gg.gameId == game.id)) {
      if (grec.goalieId == gk.id && grec.teamId != teamId) ga++;
    }
    final gp = 1; // starting goalie counted as appearing
    final gaa = gp > 0 ? (ga / gp) : 0.0;
    final sv = sog - ga;
    final svPct = sog > 0 ? (((sog - ga) / sog) * 100) : 0.0;

    expect(sog, 2);
    expect(ga, 1);
    expect(gaa, 1.0);
    expect(sv, 1);
    expect(svPct, closeTo(50.0, 0.001));
  });
}
