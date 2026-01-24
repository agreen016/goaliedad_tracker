import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'opponent.g.dart';

@HiveType(typeId: 3)
class Opponent extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int colorValue;

  Opponent({required this.name, required this.colorValue});

  Color get color => Color(colorValue);
}
