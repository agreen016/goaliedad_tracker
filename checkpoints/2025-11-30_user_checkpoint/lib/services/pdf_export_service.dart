import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'stats_aggregator.dart';
import '../models/player.dart';

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
            'Generated ${_dateFmt.format(DateTime.now())}',
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

  static pw.Widget _buildSimpleTable(List<Map<String, String>> rows) {
    if (rows.isEmpty) return pw.Text('No stats available');

    final headers = rows.first.keys.toList();
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows.map((r) => headers.map((h) => r[h] ?? '').toList()).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      cellAlignment: pw.Alignment.centerLeft,
    );
  }

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
            if (goalType.isNotEmpty) parts.add('Type: $goalType');
            if (time.isNotEmpty) parts.add('Time: $time');
            detailStr = parts.join(' - ');
          } else {
            // Generic event details: omit raw coordinate maps, show keys of interest
            final visible = <String>[];
            if (details is Map) {
              for (final k in details.keys) {
                if (k == 'dx' || k == 'dy' || k == 'onIce' || k == 'coords')
                  continue;
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
}
