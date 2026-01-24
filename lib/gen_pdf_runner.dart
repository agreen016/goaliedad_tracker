import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/player.dart';
import 'package:goaliedad_tracker/models/team.dart';
import 'package:goaliedad_tracker/services/pdf_export_service.dart';

/// One-off Flutter runner that generates a PDF for the second game in the
/// repository Hive store and writes it to /tmp/game_report_2.pdf then exits.
/// Run with: flutter run -d linux -t lib/gen_pdf_runner.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Hive.init(hivePath);
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(TeamAdapter());

  final gameBox = await Hive.openBox<Game>('games');
  final teamBox = await Hive.openBox<Team>('teams');

  if (gameBox.isEmpty) {
    await Hive.close();
    exit(1);
  }

  final game = gameBox.values.toList()[1 < gameBox.length ? 1 : 0];

  Team? team;
  try {
    team = teamBox.values.firstWhere((t) => t.id == game.teamId);
  } catch (_) {
    team = null;
  }

  try {
    final bytes = await PdfExportService.buildGamePdf(
      game: game,
      team:
          team ??
          Team(
            id: game.teamId,
            name: 'Team',
            league: '',
            division: '',
            seasonStartYear: 0,
            seasonEndYear: 0,
            primaryColorHex: 'FFFFFFFF',
            secondaryColorHex: 'FFFFFFFF',
          ),
      heatmapPng: null,
    );
    final outPath = '/tmp/game_report_2.pdf';
    final out = File(outPath);
    await out.writeAsBytes(bytes);
  } catch (e) {
    await Hive.close();
    exit(2);
  }

  await Hive.close();
  // Exit the process so flutter run terminates.
  exit(0);
}
