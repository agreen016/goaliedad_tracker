import 'package:hive/hive.dart';

part 'player.g.dart';

@HiveType(typeId: 1)
class Player extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String teamId;

  @HiveField(2)
  String name;

  @HiveField(3)
  int number;

  @HiveField(4)
  String position;

  Player({
    required this.id,
    required this.teamId,
    required this.name,
    required this.number,
    required this.position,
  });
}
