import 'package:flutter/material.dart';

class StatGrid extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> totals;
  final Color accentColor;

  const StatGrid({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
    required this.totals,
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
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll<Color>(accentColor),
            headingTextStyle: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
            columns: columns
                .map(
                  (col) => DataColumn(
                    label: Text(col, style: TextStyle(color: textColor)),
                  ),
                )
                .toList(),
            rows: [
              ...rows.map((row) {
                return DataRow(
                  cells: columns.map((col) {
                    final val = row[col];
                    return DataCell(Text(val?.toString() ?? '0'));
                  }).toList(),
                );
              }),
              DataRow(
                cells: columns.map((col) {
                  final val = totals[col];
                  return DataCell(
                    Text(
                      val?.toString() ?? '0',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
