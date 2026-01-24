import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../lib/models/game.dart';
import '../lib/models/game_event.dart';
import '../lib/models/player.dart';
import '../lib/models/team.dart';
import '../lib/models/opponent.dart';
import '../lib/models/goal.dart';
import '../lib/models/line.dart';

// Backfill script: scans all games and their events and computes dxNorm/dyNorm
// for events that are missing these fields. Uses canonical rink render size
// width=1080, height=800 for normalization. Run from project root with:
// dart run bin/backfill_dxnorm.dart

Future<void> main() async {
  final appDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDir.path);
  Hive.registerAdapter(TeamAdapter());
  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(OpponentAdapter());
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(LineAdapter());
  Hive.registerAdapter(GameEventAdapter());

  final gameBox = await Hive.openBox<Game>('games');

  final canonicalW = 1080.0;
  final canonicalH = 800.0;

  var updatedCount = 0;
  for (final g in gameBox.values) {
    if (g.events == null) continue;
    var changed = false;
    for (var i = 0; i < g.events!.length; i++) {
      final e = g.events![i];
      final dx = (e.details['dx'] as num?)?.toDouble();
      final dy = (e.details['dy'] as num?)?.toDouble();
      final hasDxNorm =
          e.details.containsKey('dxNorm') && e.details['dxNorm'] != null;
      final hasDyNorm =
          e.details.containsKey('dyNorm') && e.details['dyNorm'] != null;
      if (!hasDxNorm && dx != null) {
        e.details['dxNorm'] = dx / canonicalW;
        changed = true;
      }
      if (!hasDyNorm && dy != null) {
        e.details['dyNorm'] = dy / canonicalH;
        changed = true;
      }
      if (changed) updatedCount++;
    }
    if (changed) {
      try {
        await g.save();
      } catch (err) {
        print('Failed to save game ${g.id}: $err');
      }
    }
  }

  print('Backfill complete. Updated $updatedCount events.');
  await gameBox.close();
  exit(0);
}
