import 'package:hive/hive.dart';

part 'goal.g.dart';

@HiveType(typeId: 7) // Make sure this typeId is unique in your project
class Goal extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String gameId;

  @HiveField(2)
  String teamId;

  @HiveField(3)
  String period; // '1', '2', '3', 'OT', 'SO'

  @HiveField(4)
  String scorerId;

  @HiveField(5)
  List<String> assistIds;

  @HiveField(6)
  String goalType; // 'EV', 'PP', 'SH', etc.

  @HiveField(7)
  String time; // '12:34'

  @HiveField(8)
  String goalieId; // id of the goalie on the ice for this goal (may be empty)

  Goal({
    required this.id,
    required this.gameId,
    required this.teamId,
    required this.period,
    required this.scorerId,
    required this.assistIds,
    required this.goalType,
    required this.time,
    required this.goalieId,
  });
}
