import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../services/pdf_export_service.dart';

class GameDetailsScreen extends StatefulWidget {
  final dynamic game;
  final dynamic team;

  const GameDetailsScreen({Key? key, required this.game, required this.team})
    : super(key: key);

  @override
  _GameDetailsScreenState createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  final GlobalKey _rinkKey = GlobalKey();
  final GlobalKey _heatmapKey = GlobalKey();

  Future<Uint8List?> _capturePng(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final img = await boundary.toImage(
        pixelRatio: ui.window.devicePixelRatio,
      );
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _exportGamePdf() async {
    final rinkPng = await _capturePng(_rinkKey);
    final heatmapPng = await _capturePng(_heatmapKey);
    final pdf = await PdfExportService.buildGamePdf(
      game: widget.game,
      team: widget.team,
      rinkPng: rinkPng,
      heatmapPng: heatmapPng,
    );
    await PdfExportService.shareGamePdf(
      pdf,
      filename: 'game_${widget.game.id}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Game Details'),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _exportGamePdf,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            RepaintBoundary(
              key: _rinkKey,
              child: SizedBox(
                height: 300,
                child: Center(child: Text('Rink view goes here')),
              ),
            ),
            SizedBox(height: 12),
            RepaintBoundary(
              key: _heatmapKey,
              child: SizedBox(
                height: 300,
                child: Center(child: Text('Heatmap goes here')),
              ),
            ),
            // ... other details ...
          ],
        ),
      ),
    );
  }
}
