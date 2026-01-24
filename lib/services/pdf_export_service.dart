import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'stats_aggregator.dart';
import '../models/player.dart';
import '../models/game.dart';
import '../models/goal.dart';

/// Minimal PDF export service for game and season exports.
class PdfExportService {
  static final _dateFmt = DateFormat.yMMMd().add_jm();

  /// Build a simple single-game PDF. [heatmapPng] is optional PNG image bytes
  /// (e.g. captured from a RepaintBoundary) to include in the report.
  static Future<Uint8List> buildGamePdf({
    required dynamic game,
    required dynamic team,
    Uint8List? rinkPng,
    Uint8List? heatmapPng,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            '${team.name} vs ${game.opponent}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Generated ${PdfExportService._dateFmt.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text('Game: ${_dateFmt.format(game.dateTime)}'),
          pw.SizedBox(height: 8),
          pw.Text(
            'Score: ${game.getDisplayResult()}',
            style: pw.TextStyle(fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          // Optional rink image (shots & goals) placed above the heatmap.
          if (rinkPng != null)
            pw.LayoutBuilder(
              builder: (ctx, constraints) {
                final maxH = ctx.page.pageFormat.availableHeight * 0.35;
                return pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(rinkPng),
                    width:
                        (constraints?.maxWidth) ??
                        ctx.page.pageFormat.availableWidth,
                    height: maxH,
                    fit: pw.BoxFit.contain,
                  ),
                );
              },
            ),
          if (heatmapPng != null)
            pw.LayoutBuilder(
              builder: (ctx, constraints) {
                final maxH = ctx.page.pageFormat.availableHeight * 0.6;
                return pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(heatmapPng),
                    width:
                        (constraints?.maxWidth) ??
                        ctx.page.pageFormat.availableWidth,
                    height: maxH,
                    fit: pw.BoxFit.contain,
                  ),
                );
              },
            ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Shots (all teams)',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildShotsTable(game, team),
          pw.SizedBox(height: 12),
          pw.Text(
            'Scoring Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildScoringSummary(game, team),
          pw.SizedBox(height: 12),
          pw.Text(
            'Events',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildEventsTable(game),
          pw.SizedBox(height: 12),
          pw.Text(
            'Player Stats',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildPlayerStatsTable(game, team),
          pw.SizedBox(height: 12),
          pw.Text(
            'Goalie Stats',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildGoalieStatsTable(game, team),
        ],
      ),
    );

    return doc.save();
  }

  // _buildSimpleTable removed — not referenced. Keep explicit table builders instead.

  static pw.Widget _buildScoringSummary(dynamic game, dynamic team) {
    final List<List<String>> rows = [];
    try {
      final playerBox = Hive.box<Player>('players');
      final goals = game.events?.where((e) => e.type == 'goal').toList() ?? [];
      for (var g in goals) {
        final details = g.details ?? {};
        final goalType = (details['goalType'] ?? '').toString();
        final scorerId = (details['scorerId'] ?? g.playerId ?? '').toString();
        final assistRaw = details['assistIds'];
        final assists = <String>[];
        if (assistRaw is List) {
          for (var a in assistRaw) {
            final id = a?.toString() ?? '';
            if (id.isNotEmpty) {
              final p = playerBox.values.firstWhere(
                (pl) => pl.id == id,
                orElse: () => Player(
                  id: id,
                  name: id,
                  teamId: '',
                  number: 0,
                  position: '',
                ),
              );
              assists.add(p.name);
            }
          }
        }
        final scorerName = scorerId.isNotEmpty
            ? (playerBox.values
                  .firstWhere(
                    (pl) => pl.id == scorerId,
                    orElse: () => Player(
                      id: scorerId,
                      name: scorerId,
                      teamId: '',
                      number: 0,
                      position: '',
                    ),
                  )
                  .name)
            : '';
        final scoringTeam = (g.teamId == team.id)
            ? team.name
            : (game.opponent ?? g.teamId.toString());
        final descParts = <String>[];
        descParts.add('$scoringTeam scored');
        if (scorerName.isNotEmpty) descParts.add('Scorer: $scorerName');
        if (assists.isNotEmpty) descParts.add('Assists: ${assists.join(', ')}');
        if (goalType.isNotEmpty) descParts.add('Type: $goalType');
        // Do not include goalie name or raw coordinates in scoring description.
        final desc = descParts.join(' - ');
        rows.add([g.period.toString(), desc]);
      }
    } catch (_) {}
    if (rows.isEmpty) return pw.Text('No scoring events');
    return pw.TableHelper.fromTextArray(
      headers: ['Period', 'Description'],
      data: rows,
    );
  }

  static pw.Widget _buildEventsTable(dynamic game) {
    final List<List<String>> rows = [];
    try {
      final playerBox = Hive.box<Player>('players');
      final evs = game.events ?? [];
      for (var e in evs) {
        final period = e.period.toString();
        final type = e.type ?? '';
        final playerId = e.playerId ?? '';
        final playerName = playerId.isNotEmpty
            ? (playerBox.values
                  .firstWhere(
                    (pl) => pl.id == playerId,
                    orElse: () => Player(
                      id: playerId,
                      name: playerId,
                      teamId: '',
                      number: 0,
                      position: '',
                    ),
                  )
                  .name)
            : '';

        final details = e.details ?? {};
        String detailStr = '';
        try {
          if (e.type == 'faceoff') {
            detailStr = (details['result'] ?? '').toString();
          } else if (e.type == 'goal' || e.type == 'shot') {
            final goalType = (details['goalType'] ?? '').toString();
            // Do not include goalie names or raw coordinates in the event details.
            final time = (details['time'] ?? '').toString();
            final parts = <String>[];
            if (goalType.isNotEmpty) {
              parts.add('Type: $goalType');
            }
            if (time.isNotEmpty) {
              parts.add('Time: $time');
            }
            detailStr = parts.join(' - ');
          } else {
            // Generic event details: omit raw coordinate maps, show keys of interest
            final visible = <String>[];
            if (details is Map) {
              for (final k in details.keys) {
                if (k == 'dx' || k == 'dy' || k == 'onIce' || k == 'coords') {
                  continue;
                }
                visible.add('$k: ${details[k]}');
              }
            }
            detailStr = visible.join(', ');
          }
        } catch (_) {
          detailStr = e.details.toString();
        }

        rows.add([period, type, playerName, detailStr]);
      }
    } catch (_) {}
    if (rows.isEmpty) return pw.Text('No events');
    return pw.TableHelper.fromTextArray(
      headers: ['Period', 'Type', 'Player', 'Details'],
      data: rows,
    );
  }

  static pw.Widget _buildShotsTable(dynamic game, dynamic team) {
    final List<List<String>> rows = [];
    try {
      final playerBox = Hive.box<Player>('players');
      final evs = game.events ?? [];
      final shots = evs.where((e) => e.type == 'shot' || e.type == 'goal');
      for (var e in shots) {
        final period = e.period.toString();
        final teamName = (e.teamId == team.id)
            ? team.name
            : (game.opponent ?? e.teamId.toString());
        final playerId = e.playerId ?? '';
        final playerName = playerId.isNotEmpty
            ? (playerBox.values
                  .firstWhere(
                    (pl) => pl.id == playerId,
                    orElse: () => Player(
                      id: playerId,
                      name: playerId,
                      teamId: '',
                      number: 0,
                      position: '',
                    ),
                  )
                  .name)
            : '';
        final details = e.details ?? {};
        final result = e.type == 'goal' ? 'Goal' : 'Shot';
        final goalType = (details['goalType'] ?? '').toString();
        // Do not include goalie names or raw coordinates in shots table.
        final parts = <String>[];
        parts.add(result);
        if (goalType.isNotEmpty) parts.add(goalType);
        rows.add([period, teamName, playerName, parts.join(' - ')]);
      }
    } catch (_) {}
    if (rows.isEmpty) return pw.Text('No shots recorded');
    return pw.TableHelper.fromTextArray(
      headers: ['Period', 'Team', 'Player', 'Result'],
      data: rows,
    );
  }

  static pw.Widget _buildPlayerStatsTable(dynamic game, dynamic team) {
    try {
      final playerBox = Hive.box<Player>('players');
      final rosterPlayers = playerBox.values
          .where((p) => p.teamId == team.id)
          .where((p) => p.position.toLowerCase() != 'goalie')
          .toList();

      final agg = StatsAggregator.aggregatePlayerStats(
        game,
        rosterPlayers,
        team.id,
      );
      final columns = (agg['columns'] as List<String>?) ?? <String>[];
      final stats = (agg['stats'] as Map<String, Map<String, int>>?) ?? {};

      final List<List<String>> rows = [];
      for (var p in rosterPlayers) {
        final row = <String>[];
        row.add(p.name);
        final s = stats[p.id] ?? {for (var c in columns) c: 0};
        for (var c in columns) {
          row.add((s[c] ?? 0).toString());
        }
        rows.add(row);
      }

      if (rows.isEmpty) return pw.Text('No player stats available');
      final headerList = ['Player', ...columns];
      return pw.TableHelper.fromTextArray(headers: headerList, data: rows);
    } catch (_) {
      return pw.Text('No player stats available');
    }
  }

  static pw.Widget _buildGoalieStatsTable(dynamic game, dynamic team) {
    try {
      final playerBox = Hive.box<Player>('players');
      final goalies = playerBox.values
          .where((p) => p.teamId == team.id)
          .where((p) => p.position.toLowerCase() == 'goalie')
          .toList();
      final agg = StatsAggregator.aggregateGoalieStats(game, goalies, team.id);
      final List<List<String>> rows = [];
      for (var gid in agg.keys) {
        final s = agg[gid]!;
        final p = playerBox.values.firstWhere(
          (pl) => pl.id == gid,
          orElse: () =>
              Player(id: gid, name: gid, teamId: '', number: 0, position: ''),
        );
        rows.add([
          p.name,
          (s['MIN'] ?? 0).toString(),
          (s['SOG'] ?? 0).toString(),
          (s['GA'] ?? 0).toString(),
          (s['SV'] ?? 0).toString(),
          (s['SV%'] ?? 0).toString(),
          (s['SO'] ?? 0).toString(),
          (s['PIM'] ?? 0).toString(),
        ]);
      }
      if (rows.isEmpty) return pw.Text('No goalie stats available');
      return pw.TableHelper.fromTextArray(
        headers: ['Goalie', 'MIN', 'SOG', 'GA', 'SV', 'SV%', 'SO', 'PIM'],
        data: rows,
      );
    } catch (_) {
      return pw.Text('No goalie stats available');
    }
  }

  /// Share the PDF bytes via platform printing/sharing.
  static Future<void> shareGamePdf(
    Uint8List pdfBytes, {
    String filename = 'game_report.pdf',
  }) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  /// Build a season-level PDF for [team]. Optionally include a season heatmap
  /// PNG produced elsewhere (aggregate of all shots for the season).
  static Future<Uint8List> buildSeasonPdf({
    required dynamic team,
    Uint8List? seasonHeatmapPng,
  }) async {
    final doc = pw.Document();

    // Collect games for this team from Hive 'games' box
    final gameBox = Hive.box<Game>('games');
    final games = <dynamic>[];
    try {
      for (var g in gameBox.values) {
        try {
          if (g.teamId == team.id) games.add(g);
        } catch (_) {}
      }
      // Sort by date
      games.sort((a, b) => (a.dateTime as DateTime).compareTo(b.dateTime));
    } catch (_) {}

    // Prepare roster lists and accumulators
    final playerBox = Hive.box<Player>('players');
    final rosterPlayers = playerBox.values
        .where((p) => p.teamId == team.id)
        .where((p) => p.position.toLowerCase() != 'goalie')
        .toList();
    final goaliePlayers = playerBox.values
        .where((p) => p.teamId == team.id)
        .where((p) => p.position.toLowerCase() == 'goalie')
        .toList();

    // Aggregate season player & goalie stats by summing per-game aggregates
    final playerAggColumns = <String>[];
    final Map<String, Map<String, int>> playerStats = {};
    final Map<String, Map<String, num>> goalieStats = {};

    try {
      for (var game in games) {
        try {
          final pAgg = StatsAggregator.aggregatePlayerStats(
            game,
            rosterPlayers,
            team.id,
          );
          final cols = (pAgg['columns'] as List<String>?) ?? <String>[];
          if (playerAggColumns.isEmpty) playerAggColumns.addAll(cols);
          final Map<String, Map<String, int>> pstats =
              (pAgg['stats'] as Map<String, Map<String, int>>?) ?? {};
          for (var pid in pstats.keys) {
            playerStats.putIfAbsent(
              pid,
              () => {for (var c in playerAggColumns) c: 0},
            );
            final s = pstats[pid]!;
            for (var c in s.keys) {
              playerStats[pid]![c] = (playerStats[pid]![c] ?? 0) + (s[c] ?? 0);
            }
          }

          final gAgg = StatsAggregator.aggregateGoalieStats(
            game,
            goaliePlayers,
            team.id,
          );
          for (var gid in gAgg.keys) {
            goalieStats.putIfAbsent(
              gid,
              () => {for (var k in gAgg[gid]!.keys) k: 0},
            );
            final s = gAgg[gid]!;
            for (var k in s.keys) {
              final existing = goalieStats[gid]![k] ?? 0;
              goalieStats[gid]![k] = (existing + (s[k] ?? 0));
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    doc.addPage(
      pw.MultiPage(
        header: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            '${team.name} - Season ${team.seasonStartYear}/${team.seasonEndYear}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Generated ${PdfExportService._dateFmt.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          // Team summary and leaders (mirror Team Hub top section)
          _buildSeasonTopSection(
            team,
            games,
            playerAggColumns,
            playerStats,
            goalieStats,
          ),
          pw.SizedBox(height: 12),
          pw.Text('Games (${games.length})'),
          pw.SizedBox(height: 8),
          if (seasonHeatmapPng != null)
            pw.LayoutBuilder(
              builder: (ctx, constraints) {
                final maxH = ctx.page.pageFormat.availableHeight * 0.5;
                return pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(seasonHeatmapPng),
                    width:
                        (constraints?.maxWidth) ??
                        ctx.page.pageFormat.availableWidth,
                    height: maxH,
                    fit: pw.BoxFit.contain,
                  ),
                );
              },
            ),
          pw.SizedBox(height: 12),
          _buildSeasonGamesTable(games),
          pw.SizedBox(height: 12),
          pw.Text(
            'Season Player Stats',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildSeasonPlayerStatsTable(playerAggColumns, playerStats),
          pw.SizedBox(height: 12),
          pw.Text(
            'Season Goalie Stats',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildSeasonGoalieStatsTable(goalieStats),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildSeasonGamesTable(List<dynamic> games) {
    final rows = <List<String>>[];
    try {
      for (var g in games) {
        final date = (g.dateTime is DateTime)
            ? DateFormat.yMMMd().format(g.dateTime)
            : g.dateTime.toString();
        final opp = g.opponent ?? '';
        String res;
        try {
          res = (g.getDisplayResult() ?? '').toString();
        } catch (_) {
          res = (g.result ?? '').toString();
        }
        rows.add([date, opp, res]);
      }
    } catch (_) {}
    if (rows.isEmpty) return pw.Text('No games found');
    return pw.TableHelper.fromTextArray(
      headers: ['Date', 'Opponent', 'Result'],
      data: rows,
    );
  }

  static pw.Widget _buildSeasonPlayerStatsTable(
    List<String> columns,
    Map<String, Map<String, int>> stats,
  ) {
    final playerBox = Hive.box<Player>('players');
    final rows = <List<String>>[];
    try {
      for (var pid in stats.keys) {
        final p = playerBox.values.firstWhere(
          (pl) => pl.id == pid,
          orElse: () =>
              Player(id: pid, name: pid, teamId: '', number: 0, position: ''),
        );
        final row = <String>[];
        row.add(p.name);
        final s = stats[pid]!;
        for (var c in columns) {
          row.add((s[c] ?? 0).toString());
        }
        rows.add(row);
      }
    } catch (_) {}
    if (rows.isEmpty) return pw.Text('No player stats');
    final header = ['Player', ...columns];
    return pw.TableHelper.fromTextArray(headers: header, data: rows);
  }

  static pw.Widget _buildSeasonGoalieStatsTable(
    Map<String, Map<String, num>> stats,
  ) {
    final playerBox = Hive.box<Player>('players');
    final rows = <List<String>>[];
    try {
      for (var gid in stats.keys) {
        final s = stats[gid]!;
        final p = playerBox.values.firstWhere(
          (pl) => pl.id == gid,
          orElse: () =>
              Player(id: gid, name: gid, teamId: '', number: 0, position: ''),
        );
        rows.add([
          p.name,
          (s['MIN'] ?? 0).toString(),
          (s['SOG'] ?? 0).toString(),
          (s['GA'] ?? 0).toString(),
          (s['SV'] ?? 0).toString(),
          (s['SV%'] ?? 0).toString(),
          (s['SO'] ?? 0).toString(),
          (s['PIM'] ?? 0).toString(),
        ]);
      }
    } catch (_) {}
    if (rows.isEmpty) return pw.Text('No goalie stats');
    return pw.TableHelper.fromTextArray(
      headers: ['Goalie', 'MIN', 'SOG', 'GA', 'SV', 'SV%', 'SO', 'PIM'],
      data: rows,
    );
  }

  // Render a compact top section for the season PDF: team totals and leaders
  static pw.Widget _buildSeasonTopSection(
    dynamic team,
    List<dynamic> games,
    List<String> playerAggColumns,
    Map<String, Map<String, int>> playerStats,
    Map<String, Map<String, num>> goalieStats,
  ) {
    final totalGames = games.length;
    int goalsFor = 0;
    int goalsAgainst = 0;
    int totalShots = 0;
    int ppGoalsFor = 0;
    int ppGoalsAgainst = 0;
    int teamPPO = 0;
    int oppPPO = 0;
    int penaltyMinutes = 0;

    try {
      final Box<Goal> goalBox = Hive.box<Goal>('goals');
      for (final g in games) {
        try {
          goalsFor += (g.homeScore ?? 0) as int? ?? 0;
          goalsAgainst += (g.visitorScore ?? 0) as int? ?? 0;
          totalShots += (g.homeShots ?? 0) as int? ?? 0;
          teamPPO += (g.homePPO ?? 0) as int? ?? 0;
          oppPPO += (g.visitorPPO ?? 0) as int? ?? 0;

          // PP/SH goals
          try {
            final gameGoals = goalBox.values.where((gg) => gg.gameId == g.id);
            for (final goal in gameGoals) {
              final gt = goal.goalType.toUpperCase();
              if (goal.teamId == team.id) {
                if (gt == 'PP') ppGoalsFor++;
              } else {
                if (gt == 'PP') ppGoalsAgainst++;
              }
            }
          } catch (_) {}

          final evs = g.events ?? [];
          for (final ev in evs) {
            if (ev.type == 'penalty') {
              try {
                penaltyMinutes += (ev.details['minutes'] ?? 0) as int? ?? 0;
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    final avgGoals = totalGames > 0 ? (goalsFor / totalGames) : 0.0;
    final avgShots = totalGames > 0 ? (totalShots / totalGames) : 0.0;
    final ppPercent = teamPPO > 0 ? (ppGoalsFor / teamPPO) * 100 : 0.0;
    final pkPercent = oppPPO > 0
        ? ((oppPPO - ppGoalsAgainst) / oppPPO) * 100
        : 0.0;

    // Build player rows from aggregated stats to compute leaders
    final playerRows = <Map<String, dynamic>>[];
    try {
      final playerBox = Hive.box<Player>('players');
      for (final pid in playerStats.keys) {
        final p = playerBox.values.firstWhere(
          (pl) => pl.id == pid,
          orElse: () =>
              Player(id: pid, name: pid, teamId: '', number: 0, position: ''),
        );
        final s = playerStats[pid]!;
        final row = <String, dynamic>{'Name': p.name};
        for (final c in playerAggColumns) {
          row[c] = (s[c] ?? 0);
        }
        playerRows.add(row);
      }
    } catch (_) {}

    final leaders = <String, String>{};
    try {
      if (playerRows.isNotEmpty) {
        final byG = List.from(playerRows)
          ..sort((a, b) => (b['G'] ?? 0).compareTo(a['G'] ?? 0));
        final byA = List.from(playerRows)
          ..sort((a, b) => (b['A'] ?? 0).compareTo(a['A'] ?? 0));
        final byP = List.from(playerRows)
          ..sort((a, b) => (b['P'] ?? 0).compareTo(a['P'] ?? 0));
        leaders['Goals'] = '${byG.first['Name']} (${byG.first['G'] ?? 0})';
        leaders['Assists'] = '${byA.first['Name']} (${byA.first['A'] ?? 0})';
        leaders['Points'] = '${byP.first['Name']} (${byP.first['P'] ?? 0})';
      }
    } catch (_) {}

    try {
      final goalieRows = <Map<String, dynamic>>[];
      final gbox = Hive.box<Player>('players');
      for (final gid in goalieStats.keys) {
        final p = gbox.values.firstWhere(
          (pl) => pl.id == gid,
          orElse: () =>
              Player(id: gid, name: gid, teamId: '', number: 0, position: ''),
        );
        final s = goalieStats[gid]!;
        goalieRows.add({
          'Name': p.name,
          'SV': s['SV'] ?? 0,
          'SV%': s['SV%'] ?? 0,
          'SO': s['SO'] ?? 0,
          'GAA': s['GAA'] ?? 0,
        });
      }
      if (goalieRows.isNotEmpty) {
        final bySv = List.from(goalieRows)
          ..sort((a, b) => (b['SV'] ?? 0).compareTo(a['SV'] ?? 0));
        final bySvPct = List.from(goalieRows)
          ..sort((a, b) => (b['SV%'] ?? 0).compareTo(a['SV%'] ?? 0));
        final bySo = List.from(goalieRows)
          ..sort((a, b) => (b['SO'] ?? 0).compareTo(a['SO'] ?? 0));
        leaders['SV'] = '${bySv.first['Name']} (${bySv.first['SV']})';
        leaders['SV%'] = '${bySvPct.first['Name']} (${bySvPct.first['SV%']})';
        leaders['SO'] = '${bySo.first['Name']} (${bySo.first['SO']})';
      }
    } catch (_) {}

    final leftBoxes = <pw.Widget>[];
    leftBoxes.addAll([
      _smallStatBox('${team.name} - Season', 'Games: $totalGames'),
      _smallStatBox(
        'Goals',
        '$goalsFor',
        'Avg: ${avgGoals.toStringAsFixed(1)}',
      ),
      _smallStatBox(
        'Goals Against',
        '$goalsAgainst',
        'Avg: ${totalGames > 0 ? (goalsAgainst / totalGames).toStringAsFixed(1) : '0.0'}',
      ),
      _smallStatBox(
        'Shots',
        '$totalShots',
        'Avg: ${avgShots.toStringAsFixed(1)}',
      ),
      _smallStatBox(
        'Penalty Min',
        '$penaltyMinutes',
        'Avg: ${totalGames > 0 ? (penaltyMinutes / totalGames).toStringAsFixed(1) : '0.0'}',
      ),
      _smallStatBox(
        'PP %',
        '${ppPercent.toStringAsFixed(1)}%',
        '$ppGoalsFor / $teamPPO',
      ),
      _smallStatBox(
        'PK %',
        '${pkPercent.toStringAsFixed(1)}%',
        '${(oppPPO - ppGoalsAgainst)} / $oppPPO',
      ),
    ]);

    final leadersWidgets = <pw.Widget>[];
    leaders.forEach((k, v) {
      leadersWidgets.add(
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text('$k:'), pw.Text(v)],
        ),
      );
      leadersWidgets.add(pw.SizedBox(height: 6));
    });

    final leaderColumnChildren = <pw.Widget>[
      pw.Text(
        'Leaders',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      ...leadersWidgets,
    ];

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 2, child: pw.Column(children: leftBoxes)),
        pw.SizedBox(width: 12),
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: leaderColumnChildren,
          ),
        ),
      ],
    );
  }

  static pw.Widget _smallStatBox(
    String title,
    String value, [
    String? subtext,
  ]) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      margin: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(value),
          if (subtext != null)
            pw.Text(subtext, style: pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}
