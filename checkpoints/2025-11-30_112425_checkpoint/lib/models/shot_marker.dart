import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'shot_marker.g.dart';

@HiveType(typeId: 10)
class ShotMarker extends HiveObject {
  @HiveField(0)
  final double dx;
  @HiveField(1)
  final double dy;
  @HiveField(2)
  final bool isGoal;
  @HiveField(3)
  final int teamColorValue;
  @HiveField(4)
  final String? playerNumber;

  @HiveField(9)
  final String? eventId;

  @HiveField(5)
  final String? shooterId;
  @HiveField(6)
  final String? goalScorerId;
  @HiveField(7)
  final String? assist1Id;
  @HiveField(8)
  final String? assist2Id;

  ShotMarker({
    required this.dx,
    required this.dy,
    required this.isGoal,
    required this.teamColorValue,
    this.playerNumber,
    this.shooterId,
    this.goalScorerId,
    this.assist1Id,
    this.assist2Id,
    this.eventId,
  });

  Offset get position => Offset(dx, dy);
  Color get teamColor => Color(teamColorValue);
}
