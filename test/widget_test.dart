// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:goaliedad_tracker/main.dart';
import 'package:goaliedad_tracker/models/team.dart';
import 'package:goaliedad_tracker/models/player.dart';
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/opponent.dart';
import 'package:goaliedad_tracker/models/goal.dart';
import 'package:goaliedad_tracker/models/line.dart';
import 'package:goaliedad_tracker/models/game_event.dart';

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
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
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GoalieDadStatsTrackerApp());

    // Advance time by the splash duration so the delayed navigation occurs,
    // then settle animations and pending frames.
    await tester.pump(const Duration(milliseconds: 6000));
    await tester.pumpAndSettle();

    // The app should now be showing the Teams screen title.
    expect(find.text('Teams'), findsOneWidget);
  });
}
