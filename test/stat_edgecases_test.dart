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
    tmpDir = await Directory.systemTemp.createTemp('goaliedad_edge_');
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

  test('multi-game player GP and goals aggregate across games', () async {
    final players = Hive.box<Player>('players');
    final games = Hive.box<Game>('games');
    final goals = Hive.box<Goal>('goals');

    final teamId = 'tm1';
    final p = Player(
      id: 'pA',
      teamId: teamId,
      name: 'PlayerA',
      number: 11,
      position: 'C',
    );
    await players.put(p.id, p);

    final g1 = Game(
      id: 'g1',
      teamId: teamId,
      dateTime: DateTime.now(),
      opponent: '',
      gameType: 'League',
      result: '',
      availablePlayerIds: [p.id],
    );
    final g2 = Game(
      id: 'g2',
      teamId: teamId,
      dateTime: DateTime.now(),
      opponent: '',
      gameType: 'League',
      result: '',
      availablePlayerIds: [p.id],
    );
    await games.put(g1.id, g1);
    await games.put(g2.id, g2);

    // one goal in first game
    final gr = Goal(
      id: 'gr1',
      gameId: g1.id,
      teamId: teamId,
      period: '1',
      scorerId: p.id,
      assistIds: [],
      goalType: 'EV',
      time: '05:00',
      goalieId: '',
    );
    await goals.put(gr.id, gr);

    // Aggregate: goals across both games should be 1; GP should be 2 due to availablePlayerIds
    int goalsTotal = 0;
    int gp = 0;
    for (final g in games.values.where((gg) => gg.teamId == teamId)) {
      final Set<String> playersSeen = {};
      final gameGoals = goals.values.where((gg) => gg.gameId == g.id);
      for (final grec in gameGoals) {
        if (grec.teamId == teamId && grec.scorerId == p.id) goalsTotal++;
        if (grec.scorerId == p.id) playersSeen.add(p.id);
      }
      // also available players
      try {
        for (final pid in g.availablePlayerIds ?? [])
          playersSeen.add(pid.toString());
      } catch (_) {}
      if (playersSeen.contains(p.id)) gp++;
    }

    expect(goalsTotal, 1);
    expect(gp, 2);
  });

  test('goalie with GP>0 and 0 GA yields 0.00 GAA', () async {
    final players = Hive.box<Player>('players');
    final games = Hive.box<Game>('games');
    final goals = Hive.box<Goal>('goals');

    final teamId = 'tm2';
    final gk = Player(
      id: 'gk2',
      teamId: teamId,
      name: 'GK2',
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
    await games.put(game.id, game);

    // No goals against in goals box for this game
    int ga = 0;
    for (final grec in goals.values.where((gg) => gg.gameId == game.id)) {
      if (grec.goalieId == gk.id && grec.teamId != teamId) ga++;
    }
    final gp = 1;
    final gaa = gp > 0 ? (ga / gp) : 0.0;
    expect(ga, 0);
    expect(gaa, 0.0);
  });

  test('shots without goalieId are not counted toward SOG for goalie', () async {
    final players = Hive.box<Player>('players');
    final games = Hive.box<Game>('games');
    final goals = Hive.box<Goal>('goals');

    final teamId = 'tm3';
    final gk = Player(
      id: 'gk3',
      teamId: teamId,
      name: 'GK3',
      number: 1,
      position: 'Goalie',
    );
    await players.put(gk.id, gk);

    final game = Game(
      id: 'g3',
      teamId: teamId,
      dateTime: DateTime.now(),
      opponent: '',
      gameType: 'League',
      result: '',
    );
    // event is a shot by opponent but no goalieId, no startingGoalie
    final ev = GameEvent(
      id: 'e1',
      gameId: game.id,
      teamId: 'opp',
      type: 'shot',
      period: 1,
      playerId: 'opx',
      details: {},
    );
    game.events = [ev];
    await games.put(game.id, game);

    // Because we did not provide goalieId, onIce G, or startingGoalie, the code should not attribute SOG to our goalie
    int sogCounted = 0;
    for (final ev2 in game.events ?? []) {
      String goalieId = (ev2.details['goalieId'] ?? '').toString();
      if (goalieId.isEmpty) {
        try {
          final onIce = ev2.details['onIce'];
          if (onIce != null) goalieId = (onIce['G'] ?? '').toString();
        } catch (_) {}
      }
      if (goalieId.isEmpty && (game.startingGoalie ?? '').isNotEmpty)
        goalieId = game.startingGoalie!;
      if (goalieId.isNotEmpty && ev2.teamId != teamId) sogCounted++;
    }

    expect(sogCounted, 0);
  });

  test('multi-game goalie GAA averages across games', () async {
    final players = Hive.box<Player>('players');
    final games = Hive.box<Game>('games');
    final goals = Hive.box<Goal>('goals');

    final teamId = 'tm4';
    final gk = Player(
      id: 'gk4',
      teamId: teamId,
      name: 'GK4',
      number: 1,
      position: 'Goalie',
    );
    await players.put(gk.id, gk);

    final ga1 = Game(
      id: 'ga1',
      teamId: teamId,
      dateTime: DateTime.now(),
      opponent: '',
      gameType: 'League',
      result: '',
      startingGoalie: gk.id,
    );
    final ga2 = Game(
      id: 'ga2',
      teamId: teamId,
      dateTime: DateTime.now(),
      opponent: '',
      gameType: 'League',
      result: '',
      startingGoalie: gk.id,
    );
    await games.put(ga1.id, ga1);
    await games.put(ga2.id, ga2);

    // One goal against across the two games (in second game)
    final gg = Goal(
      id: 'g_g1',
      gameId: ga2.id,
      teamId: 'opp',
      period: '1',
      scorerId: 'op1',
      assistIds: [],
      goalType: 'EV',
      time: '07:00',
      goalieId: gk.id,
    );
    await goals.put(gg.id, gg);

    // compute total GA and GP
    int totalGa = 0;
    int totalGp = 0;
    for (final g in games.values.where((ggg) => ggg.teamId == teamId)) {
      // goalie appears due to startingGoalie
      if ((g.startingGoalie ?? '') == gk.id) totalGp++;
    }
    for (final grec in goals.values.where((ggg) => ggg.goalieId == gk.id)) {
      if (grec.teamId != teamId) totalGa++;
    }
    final gaa = totalGp > 0 ? (totalGa / totalGp) : 0.0;
    expect(totalGp, 2);
    expect(totalGa, 1);
    expect(gaa, closeTo(0.5, 0.0001));
  });
}
