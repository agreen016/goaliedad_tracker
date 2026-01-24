import 'dart:io';
import 'package:flutter/material.dart';
import '../models/team.dart';

class TeamCard extends StatelessWidget {
  final Team team;
  final VoidCallback? onTap;

  const TeamCard({super.key, required this.team, this.onTap});

  Color _getTextColor(Color bg) {
    // Simple luminance check for contrast
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(
      int.parse(team.primaryColorHex.replaceFirst('#', '0xFF')),
    );
    final textColor = _getTextColor(bgColor);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.1 * 255).round()),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: team.logoPath != null
                  ? FileImage(File(team.logoPath!))
                  : const AssetImage('assets/default_team_logo.png')
                        as ImageProvider,
              backgroundColor: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                team.name,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
