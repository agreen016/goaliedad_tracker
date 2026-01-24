import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'team.g.dart';

@HiveType(typeId: 0)
class Team extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String league;

  @HiveField(3)
  String division;

  @HiveField(4)
  int seasonStartYear;

  @HiveField(5)
  int seasonEndYear;

  @HiveField(6)
  String primaryColorHex;

  @HiveField(7)
  String secondaryColorHex;

  @HiveField(8)
  String? logoPath;

  Team({
    required this.id,
    required this.name,
    required this.league,
    required this.division,
    required this.seasonStartYear,
    required this.seasonEndYear,
    required this.primaryColorHex,
    required this.secondaryColorHex,
    this.logoPath,
  });

  Color get primaryColor => _hexToColor(primaryColorHex);
  Color get secondaryColor => _hexToColor(secondaryColorHex);

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex'; // Add full opacity if missing
    return Color(int.parse(hex, radix: 16));
  }
}
