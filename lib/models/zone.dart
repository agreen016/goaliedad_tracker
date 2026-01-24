import 'dart:convert';

class ZonePoint {
  final double x;
  final double y;

  ZonePoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  static ZonePoint fromJson(Map<String, dynamic> j) =>
      ZonePoint((j['x'] as num).toDouble(), (j['y'] as num).toDouble());
}

class ZonePolygon {
  final String id;
  final String name;
  final List<ZonePoint> points;

  ZonePolygon({required this.id, required this.name, required this.points});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'points': points.map((p) => p.toJson()).toList(),
  };

  static ZonePolygon fromJson(Map<String, dynamic> j) => ZonePolygon(
    id: j['id'] as String,
    name: j['name'] as String,
    points: (j['points'] as List)
        .map((e) => ZonePoint.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
  );

  String toJsonString() => jsonEncode(toJson());
}
