import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'screens/teams_screen.dart';
import 'screens/splash_screen.dart';
import 'models/team.dart';
import 'models/player.dart';
import 'models/game.dart';
import 'models/opponent.dart';
import 'models/goal.dart';
import 'models/line.dart';
import 'models/game_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);
  Hive.registerAdapter(TeamAdapter());
  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(OpponentAdapter());
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(LineAdapter());
  Hive.registerAdapter(GameEventAdapter());
  await Hive.openBox<Goal>('goals');
  await Hive.openBox<Team>('teams');
  await Hive.openBox<Player>('players');
  await Hive.openBox<Game>('games');
  await Hive.openBox<Opponent>('opponents');
  await Hive.openBox<Line>('lines');
  await Hive.openBox('positionAssignments');

  runApp(const GoalieDadStatsTrackerApp());
}

class GoalieDadStatsTrackerApp extends StatelessWidget {
  const GoalieDadStatsTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goalie Dad Stats Tracker',
      theme: ThemeData.dark(),
      home: SplashScreen(next: const TeamsScreen()),
    );
  }
}
