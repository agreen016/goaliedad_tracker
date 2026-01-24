import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:hive/hive.dart';
import 'package:goaliedad_tracker/models/game.dart';
import 'package:goaliedad_tracker/models/player.dart';
import 'package:goaliedad_tracker/models/team.dart';
import 'package:goaliedad_tracker/services/pdf_export_service.dart';

Future<void> main() async {
  final repoRoot = Directory.current.path;
  final hivePath = p.join(repoRoot, '.dart_tool', 'hive_data');
  Hive.init(hivePath);
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(TeamAdapter());

  final gameBox = await Hive.openBox<Game>('games');
  final teamBox = await Hive.openBox<Team>('teams');

  if (gameBox.isEmpty) {
    print('No games found in Hive');
    await Hive.close();
    return;
  }

  if (gameBox.length < 2) {
    print('Less than 2 games in Hive, using first game');
  }

  final game = gameBox.values.toList()[1 < gameBox.length ? 1 : 0];

  // Try to find the game's team in teams box
  Team? team;
  try {
    team = teamBox.values.firstWhere((t) => t.id == game.teamId);
  } catch (_) {
    team = null;
  }

  print('Generating PDF for game id=${game.id}');
  Uint8List pdfBytes;
  try {
    pdfBytes = await PdfExportService.buildGamePdf(
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
  } catch (e, st) {
    print('Failed to build PDF: $e');
    print(st);
    await Hive.close();
    return;
  }

  final outPath = '/tmp/game_report_2.pdf';
  final outFile = File(outPath);
  await outFile.writeAsBytes(pdfBytes);
  print('Wrote PDF to $outPath');

  await Hive.close();
}
