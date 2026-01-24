import 'package:flutter/material.dart';

class GameStatGrid extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> rows;
  final List<String>? rowLabels;
  final bool showTotals;
  final List<String>? totals;
  final Color accentColor;

  const GameStatGrid({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    this.rowLabels,
    this.showTotals = false,
    this.totals,
    required this.accentColor,
  });

  Color _getTextColor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _getTextColor(accentColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            border: TableBorder.all(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              if (rowLabels != null) 0: const FixedColumnWidth(100),
              for (int i = 0; i < columns.length; i++)
                rowLabels != null ? i + 1 : i: const FlexColumnWidth(),
            },
            children: [
              TableRow(
                children: [
                  if (rowLabels != null)
                    const SizedBox(), // Empty top-left cell
                  ...columns.map(
                    (col) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        col,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ...List.generate(rows.length, (i) {
                final row = rows[i];
                return TableRow(
                  children: [
                    if (rowLabels != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          rowLabels![i],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ...row.map(
                      (cell) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(cell),
                      ),
                    ),
                  ],
                );
              }),
              if (showTotals && totals != null)
                TableRow(
                  children: [
                    if (rowLabels != null)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Total',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ...totals!.map(
                      (val) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          val,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
