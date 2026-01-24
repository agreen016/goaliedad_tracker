import 'package:hive/hive.dart';
import 'game_event.dart';

part 'game.g.dart';

@HiveType(typeId: 2)
class Game extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String teamId;

  @HiveField(2)
  DateTime dateTime;

  @HiveField(3)
  String opponent;

  @HiveField(4)
  String gameType;

  @HiveField(5)
  String result;

  @HiveField(6)
  String? name;

  @HiveField(7)
  String? location;

  @HiveField(8)
  int homeScore;

  @HiveField(9)
  int visitorScore;

  @HiveField(10)
  int homeShots;

  @HiveField(11)
  int visitorShots;

  @HiveField(12)
  bool isFinal;

  @HiveField(13)
  String? startingGoalie;

  @HiveField(14)
  List<String> availablePlayerIds;

  @HiveField(15)
  Map<String, String> unavailablePlayerReasons;

  @HiveField(16)
  int? opponentTeamId;

  @HiveField(17)
  Map<String, int>? homeShotsByPeriod;

  @HiveField(18)
  Map<String, int>? visitorShotsByPeriod;

  @HiveField(19)
  int homePPO;

  @HiveField(20)
  int visitorPPO;


  @HiveField(21)
  bool isUserTeamVisitor;

  @HiveField(22)
  List<GameEvent>? events;

  Game({
    required this.id,
    required this.teamId,
    required this.dateTime,
    required this.opponent,
    required this.gameType,
    required this.result,
    this.isUserTeamVisitor = false,
    this.name,
    this.location,
    this.homeScore = 0,
    this.visitorScore = 0,
    this.homeShots = 0,
    this.visitorShots = 0,
    this.isFinal = false,
    this.startingGoalie,
    List<GameEvent>? events,
    List<String>? availablePlayerIds,
    Map<String, String>? unavailablePlayerReasons,
    this.opponentTeamId,
    this.homeShotsByPeriod,
    this.visitorShotsByPeriod,
    this.homePPO = 0,
    this.visitorPPO = 0,
  }) : events = events ?? [],
       availablePlayerIds = availablePlayerIds ?? [],
       unavailablePlayerReasons = unavailablePlayerReasons ?? {};

  void addEvent(GameEvent event) {
    events ??= [];
    // Defensive copy: copy the event and its details Map so later mutations
    // to the original Map (from UI code) won't affect the persisted record.
    final copiedDetails = Map<String, dynamic>.from(event.details);
    final copiedEvent = GameEvent(
      id: event.id,
      gameId: event.gameId,
      teamId: event.teamId,
      type: event.type,
      period: event.period,
      playerId: event.playerId,
      details: copiedDetails,
    );
    events!.add(copiedEvent);
    // Perf/logging: no-op in production; tests/integration rely on state only.
    // Only call save if this Game is stored in a Hive box. In unit tests the
    // Game instance may be created without being attached to a box which
    // causes Hive to throw "This object is currently not in a box.".
    try {
      if (isInBox) save();
    } catch (_) {}
  }

  String getDisplayResult() {
    if (!isFinal) {
      return '$homeScore - $visitorScore';
    }

    final diff = homeScore - visitorScore;
    final isTie = homeScore == visitorScore;

    if (isTie) return '$homeScore - $visitorScore (T)';

    final win = diff > 0;
    final suffix = gameType.contains('OT')
        ? (win ? 'OT-W' : 'OT-L')
        : gameType.contains('SO')
        ? (win ? 'SO-W' : 'SO-L')
        : (win ? 'W' : 'L');

    return '$homeScore - $visitorScore ($suffix)';
  }
}
