import 'package:flutter/material.dart';

enum HeatmapMode { smooth, grid }

class ShotHeatmap extends StatelessWidget {
  final double width;
  final double height;
  final List<Offset> points; // normalized 0..1 coordinates
  final Color color;
  final HeatmapMode mode;
  final int gridCols; // only used for grid mode
  final int gridRows;

  final void Function(int col, int row, int count, Offset globalPosition)?
  onCellTap;

  const ShotHeatmap({
    super.key,
    required this.width,
    required this.height,
    required this.points,
    this.color = Colors.red,
    this.mode = HeatmapMode.smooth,
    this.gridCols = 40,
    this.gridRows = 20,
    this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // Rink background image so shots sit on the ice
          Positioned.fill(
            child: Image.asset('assets/ice_rink.png', fit: BoxFit.fill),
          ),
          // Heatmap overlay (with tap handling for grid cells)
          Positioned.fill(
            child: Builder(
              builder: (ctx) {
                if (mode == HeatmapMode.grid) {
                  final cols = gridCols.clamp(4, 200);
                  final rows = gridRows.clamp(2, 200);
                  // aggregate counts once here so painter and tap handler share it
                  final counts = List.generate(
                    cols,
                    (_) => List<int>.filled(rows, 0),
                  );
                  var maxCount = 0;
                  for (final p in points) {
                    if (p.dx.isNaN || p.dy.isNaN) continue;
                    final cx = (p.dx.clamp(0.0, 1.0));
                    final cy = (p.dy.clamp(0.0, 1.0));
                    final c = (cx * cols).floor().clamp(0, cols - 1);
                    final r = (cy * rows).floor().clamp(0, rows - 1);
                    counts[c][r]++;
                    if (counts[c][r] > maxCount) maxCount = counts[c][r];
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      if (onCellTap == null) return;
                      final local = details.localPosition;
                      final w =
                          (ctx.findRenderObject() as RenderBox).size.width;
                      final h =
                          (ctx.findRenderObject() as RenderBox).size.height;
                      final col = ((local.dx / w) * cols).floor().clamp(
                        0,
                        cols - 1,
                      );
                      final row = ((local.dy / h) * rows).floor().clamp(
                        0,
                        rows - 1,
                      );
                      final cnt = counts[col][row];
                      final global = (ctx.findRenderObject() as RenderBox)
                          .localToGlobal(local);
                      onCellTap?.call(col, row, cnt, global);
                    },
                    child: CustomPaint(
                      painter: _HeatmapPainter(
                        points: points,
                        color: color,
                        mode: mode,
                        gridCols: gridCols,
                        gridRows: gridRows,
                        counts: counts,
                        maxCount: maxCount,
                      ),
                    ),
                  );
                }

                return CustomPaint(
                  painter: _HeatmapPainter(
                    points: points,
                    color: color,
                    mode: mode,
                    gridCols: gridCols,
                    gridRows: gridRows,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final HeatmapMode mode;
  final int gridCols;
  final int gridRows;
  final List<List<int>>? counts;
  final int? maxCount;

  _HeatmapPainter({
    required this.points,
    required this.color,
    this.mode = HeatmapMode.smooth,
    this.gridCols = 40,
    this.gridRows = 20,
    this.counts,
    this.maxCount,
  });

  static const _perPointColors = [
    Color(0xFF2B70FF), // blue
    Color(0xFF00D1FF), // cyan
    Color(0xFFFFE34D), // yellow
    Color(0xFFFFA041), // orange
    Color(0xFFFF4D4D), // red
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == HeatmapMode.smooth) {
      // Draw per-point multi-color soft blobs. Points are normalized in [0,1].
      final paint = Paint()..style = PaintingStyle.fill;

      for (final p in points) {
        if (p.dx.isNaN || p.dy.isNaN) continue;
        final cx = (p.dx.clamp(0.0, 1.0)) * size.width;
        final cy = (p.dy.clamp(0.0, 1.0)) * size.height;
        // radius scaled for rink size
        final r = size.width * 0.04; // slightly larger for visibility
        // draw concentric circles with different colors to create a ramp
        for (int i = 0; i < _perPointColors.length; i++) {
          final frac = 1.0 - (i / (_perPointColors.length + 1));
          final alpha = (0.14 * frac * 255).clamp(0, 255).toInt();
          paint.color = _perPointColors[i].withAlpha(alpha);
          canvas.drawCircle(Offset(cx, cy), r * (1.0 - i * 0.12), paint);
        }
      }
    } else {
      // Grid mode: aggregate counts into cells and draw rects with color mapping
      final cols = gridCols.clamp(4, 200);
      final rows = gridRows.clamp(2, 200);
      final cellW = size.width / cols;
      final cellH = size.height / rows;
      List<List<int>> localCounts;
      int localMax = 0;
      if (counts != null &&
          counts!.length == cols &&
          counts![0].length == rows) {
        localCounts = counts!;
        localMax = maxCount ?? 0;
      } else {
        localCounts = List.generate(cols, (_) => List<int>.filled(rows, 0));
        for (final p in points) {
          if (p.dx.isNaN || p.dy.isNaN) continue;
          final cx = (p.dx.clamp(0.0, 1.0));
          final cy = (p.dy.clamp(0.0, 1.0));
          final c = (cx * cols).floor().clamp(0, cols - 1);
          final r = (cy * rows).floor().clamp(0, rows - 1);
          localCounts[c][r]++;
          if (localCounts[c][r] > localMax) localMax = localCounts[c][r];
        }
      }

      // draw cells
      for (int x = 0; x < cols; x++) {
        for (int y = 0; y < rows; y++) {
          final cnt = localCounts[x][y];
          if (cnt == 0) continue; // skip empty
          final norm = localMax > 0 ? (cnt / localMax) : 0.0;
          final colorIdx = (norm * (_perPointColors.length - 1))
              .clamp(0, _perPointColors.length - 1)
              .toInt();
          final alpha = (0.9 * (0.4 + 0.6 * norm) * 255).clamp(0, 255).toInt();
          final cellColor = _perPointColors[colorIdx].withAlpha(alpha);
          final paintCell = Paint()
            ..style = PaintingStyle.fill
            ..color = cellColor;
          final left = x * cellW;
          final top = y * cellH;
          final rect = Rect.fromLTWH(left, top, cellW, cellH);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(2.0)),
            paintCell,
          );
        }
      }
    }

    // Draw crease / net overlay (approximate) so users can orient the heatmap.
    final creasePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withAlpha((0.9 * 255).toInt())
      ..strokeWidth = size.width * 0.007;

    // Approximate goal crease as a semicircle near the bottom center.
    final center = Offset(size.width * 0.5, size.height * 0.12);
    final creaseRadius = size.width * 0.12;
    final rect = Rect.fromCircle(center: center, radius: creaseRadius);
    // draw semicircle (from -160deg to -20deg) to approximate the crease
    final path = Path();
    path.addArc(rect, -3.0, 2.2); // radians ~ -171deg .. 126deg; visual approx
    canvas.drawPath(path, creasePaint);

    // small net indicator
    final netPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withAlpha((0.9 * 255).toInt());
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.06),
        width: size.width * 0.06,
        height: size.height * 0.01,
      ),
      netPaint,
    );

    // Faint border around rink
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withAlpha((0.12 * 255).toInt())
      ..strokeWidth = 1.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), border);

    // Legend: small horizontal gradient and labels (low -> high)
    const legendW = 140.0;
    const legendH = 12.0;
    final legendLeft = 8.0;
    final legendTop = size.height - 28.0;

    final legendRect = Rect.fromLTWH(legendLeft, legendTop, legendW, legendH);
    final shader = LinearGradient(
      colors: [
        _perPointColors.first,
        _perPointColors[1],
        _perPointColors[2],
        _perPointColors[3],
        _perPointColors.last,
      ],
    ).createShader(legendRect);
    final legendPaint = Paint()..shader = shader;
    canvas.drawRRect(
      RRect.fromRectAndRadius(legendRect, Radius.circular(4.0)),
      legendPaint,
    );

    // legend border
    final legendBorder = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withAlpha((0.6 * 255).toInt())
      ..strokeWidth = 0.8;
    canvas.drawRRect(
      RRect.fromRectAndRadius(legendRect, Radius.circular(4.0)),
      legendBorder,
    );

    // legend text: Low and High
    final tpLow = TextPainter(
      text: TextSpan(
        text: 'Low',
        style: TextStyle(
          color: Colors.white.withAlpha((0.9 * 255).toInt()),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpLow.paint(canvas, Offset(legendLeft, legendTop - 16));

    final tpHigh = TextPainter(
      text: TextSpan(
        text: 'High',
        style: TextStyle(
          color: Colors.white.withAlpha((0.9 * 255).toInt()),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpHigh.paint(
      canvas,
      Offset(legendLeft + legendW - tpHigh.width, legendTop - 16),
    );
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.points.length != points.length ||
        oldDelegate.color != color;
  }
}
