import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/goal.dart';
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/team.dart';
import 'package:goaliedad_tracker/models/opponent.dart';

Future<void> main() async {
  final appDocsPath = Platform.environment['HOME']! + 
      '/.local/share/goaliedad_tracker/goaliedad_tracker';
  
  Hive.init(appDocsPath);
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(TeamAdapter());
  Hive.registerAdapter(OpponentAdapter());

  final goalBox = await Hive.openBox<Goal>('goals');
  final gameBox = await Hive.openBox<Game>('games');
  final teamBox = await Hive.openBox<Team>('teams');
  final opponentBox = await Hive.openBox<Opponent>('opponents');

  print('=== TEAMS ===');
  for (final team in teamBox.values) {
    print('Team: ${team.name} (id: ${team.id})');
  }

  print('\n=== OPPONENTS ===');
  for (final opp in opponentBox.values) {
    print('Opponent: ${opp.name} (key: ${opp.key})');
  }

  print('\n=== GAMES ===');
  for (final game in gameBox.values) {
    print('Game: ${game.id}');
    print('  opponentTeamId: ${game.opponentTeamId}');
    print('  homeScore: ${game.homeScore}, visitorScore: ${game.visitorScore}');
  }

  print('\n=== GOALS ===');
  print('Total goals: ${goalBox.length}');
  for (final goal in goalBox.values) {
    print('Goal: ${goal.id}');
    print('  gameId: ${goal.gameId}');
    print('  teamId: ${goal.teamId}');
    print('  goalieId: ${goal.goalieId}');
    print('  scorerId: ${goal.scorerId}');
    print('  period: ${goal.period}');
    print('  goalType: ${goal.goalType}');
  }

  await Hive.close();
}
