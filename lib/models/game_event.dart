import 'package:hive/hive.dart';

part 'game_event.g.dart';

@HiveType(typeId: 9)
class GameEvent extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String gameId;

  @HiveField(2)
  final String teamId;

  @HiveField(3)
  final String type; // 'faceoff', 'penalty', 'line_change', 'substitution', etc.

  @HiveField(4)
  final int period; // 1, 2, 3, 4 (OT), 5 (SO), etc.

  @HiveField(5)
  final String? playerId; // Optional: who was involved

  @HiveField(6)
  final Map<String, dynamic> details; // Flexible payload

  GameEvent({
    required this.id,
    required this.gameId,
    required this.teamId,
    required this.type,
    required this.period,
    this.playerId,
    Map<String, dynamic>? details,
  }) : details = details ?? {};

  factory GameEvent.penalty({
    required String id,
    required String gameId,
    required String teamId,
    required int period,
    required String playerId,
    required String penaltyType,
    required int minutes,
  }) {
    return GameEvent(
      id: id,
      gameId: gameId,
      teamId: teamId,
      type: 'penalty',
      period: period,
      playerId: playerId,
      details: {'penalty': penaltyType, 'minutes': minutes},
    );
  }
}
