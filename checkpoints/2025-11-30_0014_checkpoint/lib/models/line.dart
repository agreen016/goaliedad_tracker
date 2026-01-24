import 'package:hive/hive.dart';

part 'line.g.dart';

@HiveType(typeId: 8)
class Line extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String teamId;

  @HiveField(2)
  final String name; // e.g. L1, L2

  @HiveField(3)
  final String lwId;

  @HiveField(4)
  final String cId;

  @HiveField(5)
  final String rwId;

  @HiveField(6)
  final String ldId;

  @HiveField(7)
  final String rdId;

  Line({
    required this.id,
    required this.teamId,
    required this.name,
    required this.lwId,
    required this.cId,
    required this.rwId,
    required this.ldId,
    required this.rdId,
  });
}
