import 'package:flutter/material.dart';

class StatBox extends StatelessWidget {
  final String title;
  final String value;
  final String? subtext;
  final String? breakdown;
  final Color accentColor;

  const StatBox({
    super.key,
    required this.title,
    required this.value,
    this.subtext,
    this.breakdown,
    required this.accentColor,
  });

  Color _getTextColor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _getTextColor(accentColor);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: accentColor.withAlpha((0.9 * 255).round()),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha((0.3 * 255).round()),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtext != null) ...[
            const SizedBox(height: 2),
            Text(
              subtext!,
              style: TextStyle(
                color: textColor.withAlpha((0.8 * 255).round()),
                fontSize: 12,
              ),
            ),
          ],
          if (breakdown != null) ...[
            const SizedBox(height: 2),
            Text(
              breakdown!,
              style: TextStyle(
                color: textColor.withAlpha((0.8 * 255).round()),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
