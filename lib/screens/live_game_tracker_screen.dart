import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:math';
import '../models/game.dart';
import '../models/team.dart';
import '../models/opponent.dart';
import '../models/player.dart';
import '../models/line.dart';
import '../services/premium_service.dart';
import '../widgets/upgrade_dialog.dart';
import '../widgets/face_off_dialog.dart';
import '../widgets/penalty_dialog.dart';
import '../widgets/choose_player_dialog.dart';
import '../widgets/choose_line_dialog.dart';
import '../widgets/choose_goalie_dialog.dart';
import '../widgets/assign_shot_dialog.dart';
import '../models/shot_marker.dart';
import '../models/game_event.dart';
import '../models/goal.dart';

class LiveGameTrackerScreen extends StatefulWidget {
  final Game game;
  final Team team;
  final String? startingGoalieId;

  const LiveGameTrackerScreen({
    super.key,
    required this.game,
    required this.team,
    this.startingGoalieId,
  });

  @override
  State<LiveGameTrackerScreen> createState() => _LiveGameTrackerScreenState();
}

class _LiveGameTrackerScreenState extends State<LiveGameTrackerScreen> {
  late int homePPO;
  late int visitorPPO;
  late String currentPeriod;
  late Box<Game> _gameBox;
  late ValueListenable<Box<Game>> _gameListenable;
  Map<String, String> positionAssignments = {
    'LW': '',
    'C': '',
    'RW': '',
    'LD': '',
    'RD': '',
    'G': '',
  };
  Offset? tapPosition;

  bool homeOnLeft = true;
  Opponent? opponentTeam;

  final List<ShotMarker> markers = [];
  final GlobalKey stackKey = GlobalKey();
  final GlobalKey iceKey = GlobalKey();

  Color _contrastTextColor(Color bg) {
    // Use luminance to pick black or white text for sufficient contrast.
    // A simple threshold centered around 0.5 works well for typical colors.
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
  // debug state removed
  // recent-add tracking removed

  void addMarker(Offset position, bool isGoal) async {
    final iceBox = iceKey.currentContext?.findRenderObject() as RenderBox?;
    final iceHeight = iceBox?.size.height ?? 800;
    final centerIceY = iceHeight / 2;
    final isInTopZone = position.dy < centerIceY;

    final isHomeShooting = isInTopZone
        ? !homeOnLeft // top zone → home on left = opponent defending
        : homeOnLeft; // bottom zone → home on left = home defending

    final shootingTeamColor = isHomeShooting
        ? widget.team.primaryColor
        : opponentTeam?.color ?? Colors.grey;

    String? shooterId;
    String? goalScorerId;
    String? assist1Id;
    String? assist2Id;

    bool recorded = false;

    if (isHomeShooting) {
      final playerBox = Hive.box<Player>('players');
      final fullRoster = playerBox.values
          .where((p) => p.teamId == widget.team.id)
          .toList();

      final onIceIds = positionAssignments.values
          .where((id) => id.isNotEmpty)
          .toSet();

      final onIcePlayers = fullRoster
          .where((p) => onIceIds.contains(p.id))
          .toList();
      final benchPlayers = fullRoster
          .where((p) => !onIceIds.contains(p.id))
          .toList();

      final result = await showDialog<Map<String, String?>>(
        context: context,
        builder: (_) => AssignShotDialog(
          isGoal: isGoal,
          onIcePlayers: onIcePlayers,
          benchPlayers: benchPlayers,
        ),
      );

      if (result != null) {
        recorded = true;
        if (isGoal) {
          goalScorerId = result['goalScorerId'];
          assist1Id = result['assist1Id'];
          assist2Id = result['assist2Id'];
          final goalType = result['goalType'] ?? 'EV';
          widget.game.homeScore = widget.game.homeScore + 1;
          // Persist a Goal entry so scoring summary widgets can read it
          final goalId =
              'goal-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1000000)}';
          final goalieIdForGoal = positionAssignments['G'] ?? '';
          final goalBox = Hive.box<Goal>('goals');
          final goal = Goal(
            id: goalId,
            gameId: widget.game.id,
            teamId: widget.game.teamId,
            period: currentPeriod,
            scorerId: goalScorerId ?? '',
            assistIds: [
              if (assist1Id != null) assist1Id,
              if (assist2Id != null) assist2Id,
            ],
            goalType: goalType,
            time: DateTime.now().toIso8601String(),
            goalieId: goalieIdForGoal,
          );
          goalBox.put(goal.id, goal);
        } else {
          shooterId = result['shooterId'];
        }

        // Increment home shots for any recorded attempt
        widget.game.homeShots = widget.game.homeShots + 1;
        // Update homeShotsByPeriod
        widget.game.homeShotsByPeriod ??= {};
        widget.game.homeShotsByPeriod![currentPeriod] =
            (widget.game.homeShotsByPeriod![currentPeriod] ?? 0) + 1;
        await widget.game.save();
      }
    } else {
      // Opponent event: record immediately
      recorded = true;
      if (isGoal) {
        final goalType = 'EV';
        widget.game.visitorScore = widget.game.visitorScore + 1;
        // Persist opponent Goal entry (scorer unknown here)
        final goalId =
            'goal-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1000000)}';
        final goalieIdForGoal = positionAssignments['G'] ?? '';
        final goalBox = Hive.box<Goal>('goals');
        final goal = Goal(
          id: goalId,
          gameId: widget.game.id,
          teamId: widget.game.opponentTeamId?.toString() ?? '',
          period: currentPeriod,
          scorerId: '',
          assistIds: [],
          goalType: goalType,
          time: DateTime.now().toIso8601String(),
          goalieId: goalieIdForGoal,
        );
        goalBox.put(goal.id, goal);
      }
      widget.game.visitorShots = widget.game.visitorShots + 1;
      // Update visitorShotsByPeriod
      widget.game.visitorShotsByPeriod ??= {};
      widget.game.visitorShotsByPeriod![currentPeriod] =
          (widget.game.visitorShotsByPeriod![currentPeriod] ?? 0) + 1;
      await widget.game.save();
    }

    // Only add a marker to UI if the event was recorded (so cancelling dialogs won't leave orphan markers)
    if (recorded) {
      // Create a GameEvent for this marker with a robust unique id
      final rnd = Random();
      final eventId =
          '${DateTime.now().microsecondsSinceEpoch}-${rnd.nextInt(1000000)}';
      // recent-add tracking removed
      final periodInt = _parsePeriod(currentPeriod);
      final teamIdForEvent = isHomeShooting
          ? widget.game.teamId
          : (widget.game.opponentTeamId?.toString() ?? '');
      final eventType = isGoal ? 'goal' : 'shot';

      // capture current goalie assignment so we can attribute goalie stats later
      final currentGoalieId = positionAssignments['G'] ?? '';

      // capture an on-ice snapshot (positions -> playerId) so downstream
      // stat aggregation (plus/minus, goalie minutes/GAA) can be computed
      // from persisted events even if UI state has changed since the event.
      final onIceSnapshot = Map<String, String>.from(positionAssignments);

      final eventDetails = {
        'dx': position.dx,
        'dy': position.dy,
        'isHomeShooting': isHomeShooting,
        'onIce': onIceSnapshot,
        if (assist1Id != null) 'assist1Id': assist1Id,
        if (assist2Id != null) 'assist2Id': assist2Id,
        if (currentGoalieId.isNotEmpty) 'goalieId': currentGoalieId,
      };

      final playerIdForEvent = isGoal ? goalScorerId ?? shooterId : shooterId;

      final gameEvent = GameEvent(
        id: eventId,
        gameId: widget.game.id,
        teamId: teamIdForEvent,
        type: eventType,
        period: periodInt,
        playerId: playerIdForEvent,
        details: eventDetails,
      );

      // If this was a goal, we already persisted a Goal earlier when the dialog returned.
      // However, ensure that if a goalieId is available we update that Goal record.
      if (isGoal && currentGoalieId.isNotEmpty) {
        try {
          final goalBox = Hive.box<Goal>('goals');
          // find the most recent goal for this game and period with empty goalieId and update it
          final recent = goalBox.values
              .where(
                (g) => g.gameId == widget.game.id && g.period == currentPeriod,
              )
              .toList();
          if (recent.isNotEmpty) {
            // assume the last one is the one we just created
            final g = recent.last;
            g.goalieId = currentGoalieId;
            goalBox.put(g.id, g);
          }
        } catch (_) {
          // ignore failures here; it's non-critical
        }
      }

      final newMarker = ShotMarker(
        dx: position.dx,
        dy: position.dy,
        isGoal: isGoal,
        teamColorValue:
            (((shootingTeamColor.a * 255.0).round() & 0xff) << 24) |
            (((shootingTeamColor.r * 255.0).round() & 0xff) << 16) |
            (((shootingTeamColor.g * 255.0).round() & 0xff) << 8) |
            ((shootingTeamColor.b * 255.0).round() & 0xff),
        playerNumber: isGoal && goalScorerId != null
            ? Hive.box<Player>('players').get(goalScorerId)?.number.toString()
            : null,
        shooterId: shooterId,
        goalScorerId: goalScorerId,
        assist1Id: assist1Id,
        assist2Id: assist2Id,
        eventId: eventId,
      );

      // Place marker exactly where the user clicked. Do not nudge or move
      // existing markers. The UI should show all markers, even if they overlap.
      final ShotMarker markerToAdd = newMarker;

      // debug logs removed
      setState(() {
        // If an existing marker has the same eventId, replace it. Otherwise append.
        if (markerToAdd.eventId != null) {
          final idx = markers.indexWhere(
            (m) => m.eventId == markerToAdd.eventId,
          );
          if (idx != -1) {
            // replace existing marker
            markers[idx] = markerToAdd;
          } else {
            markers.add(markerToAdd);
          }
        } else {
          // no eventId: just add as local-only marker
          markers.add(markerToAdd);
        }
      });
      // debug logs removed
      // Persist the event after we've added the in-memory marker so rebuilds
      // triggered by the Hive listener will see the local marker and merge
      // instead of overwriting it. Ensure the persisted coords match any
      // nudging performed on the UI marker.
      try {
        // Persist the exact tap coordinates (no nudging) so review maps
        // markers 1:1 to where the user clicked.
        gameEvent.details['dx'] = (position.dx);
        gameEvent.details['dy'] = (position.dy);
        // Also store normalized coordinates relative to the ice image size so
        // the review rink can map markers 1:1 regardless of render width/height.
        try {
          final rb = iceKey.currentContext?.findRenderObject() as RenderBox?;
          final imgW = rb?.size.width ?? MediaQuery.of(context).size.width;
          final imgH = rb?.size.height ?? 800.0;
          if (imgW > 0 && imgH > 0) {
            gameEvent.details['dxNorm'] = (position.dx) / imgW;
            gameEvent.details['dyNorm'] = (position.dy) / imgH;
          }
        } catch (_) {}
      } catch (_) {}
      // Persist the event while temporarily suspending our games listener
      // so the save/rebuild cannot run while we're in the middle of adding
      // the in-memory marker. This avoids races where a rebuild would
      // overwrite the UI geometry with persisted coords.
      try {
        // persist debug log removed
        widget.game.addEvent(gameEvent);
        // post-persist handling removed
      } catch (_) {}
      // remove the recent-id flag after a short grace period so future rebuilds
      // won't be affected; keeping it short helps us detect immediate races.
      // recent-add tracking removed
    }
  }

  void showMarkerOptions(ShotMarker marker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marker Options'),
        content: const Text('Edit or delete this marker.'),
        actions: [
          TextButton(
            onPressed: () async {
              // Edit: allow modifying shooter/goal scorers/assists for this marker
              Navigator.pop(context);

              // Find matching event for this marker
              GameEvent? matched;
              if (marker.eventId != null && widget.game.events != null) {
                try {
                  matched = widget.game.events!.firstWhere(
                    (e) => e.id == marker.eventId,
                  );
                } catch (_) {
                  matched = null;
                }
              }

              // If no exact match, try coordinate fallback
              if (matched == null && widget.game.events != null) {
                try {
                  matched = widget.game.events!.firstWhere((e) {
                    final dx = (e.details['dx'] as num?)?.toDouble();
                    final dy = (e.details['dy'] as num?)?.toDouble();
                    if (dx == null || dy == null) return false;
                    return (dx - marker.dx).abs() < 1.0 &&
                        (dy - marker.dy).abs() < 1.0 &&
                        (e.type == 'shot' || e.type == 'goal');
                  });
                } catch (_) {
                  matched = null;
                }
              }

              // Prepare player lists for dialog
              final playerBox = Hive.box<Player>('players');
              final fullRoster = playerBox.values
                  .where((p) => p.teamId == widget.team.id)
                  .toList();
              final onIceIds = positionAssignments.values
                  .where((id) => id.isNotEmpty)
                  .toSet();
              final onIcePlayers = fullRoster
                  .where((p) => onIceIds.contains(p.id))
                  .toList();
              final benchPlayers = fullRoster
                  .where((p) => !onIceIds.contains(p.id))
                  .toList();

              // Pre-fill by showing AssignShotDialog and letting user re-save
              final result = await showDialog<Map<String, String?>>(
                context: context,
                builder: (_) => AssignShotDialog(
                  isGoal: marker.isGoal,
                  onIcePlayers: onIcePlayers,
                  benchPlayers: benchPlayers,
                ),
              );

              if (result != null) {
                // Create an updated ShotMarker replacing the old one
                final updatedMarker = ShotMarker(
                  dx: marker.dx,
                  dy: marker.dy,
                  isGoal: marker.isGoal,
                  teamColorValue: marker.teamColorValue,
                  playerNumber: marker.playerNumber,
                  shooterId: result['shooterId'] ?? marker.shooterId,
                  goalScorerId: result['goalScorerId'] ?? marker.goalScorerId,
                  assist1Id: result['assist1Id'] ?? marker.assist1Id,
                  assist2Id: result['assist2Id'] ?? marker.assist2Id,
                  eventId: marker.eventId,
                );

                // Replace in markers list
                setState(() {
                  final idx = markers.indexOf(marker);
                  if (idx != -1) markers[idx] = updatedMarker;
                });

                // Update matching persisted GameEvent if present by replacing it
                if (matched != null) {
                  final newPlayerId =
                      updatedMarker.goalScorerId ?? updatedMarker.shooterId;
                  final newDetails = Map<String, dynamic>.from(matched.details);
                  newDetails['assist1Id'] = updatedMarker.assist1Id;
                  newDetails['assist2Id'] = updatedMarker.assist2Id;

                  final updatedEvent = GameEvent(
                    id: matched.id,
                    gameId: matched.gameId,
                    teamId: matched.teamId,
                    type: matched.type,
                    period: matched.period,
                    playerId: newPlayerId,
                    details: newDetails,
                  );

                  final evIdx =
                      widget.game.events?.indexWhere(
                        (e) => e.id == matched!.id,
                      ) ??
                      -1;
                  if (evIdx != -1 && widget.game.events != null) {
                    widget.game.events![evIdx] = updatedEvent;
                    await widget.game.save();
                  }
                }
              }
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () async {
              // Details: show a read-only view of the event/marker
              Navigator.pop(context);

              GameEvent? matched;
              if (marker.eventId != null && widget.game.events != null) {
                try {
                  matched = widget.game.events!.firstWhere(
                    (e) => e.id == marker.eventId,
                  );
                } catch (_) {
                  matched = null;
                }
              }

              if (matched == null && widget.game.events != null) {
                try {
                  matched = widget.game.events!.firstWhere((e) {
                    final dx = (e.details['dx'] as num?)?.toDouble();
                    final dy = (e.details['dy'] as num?)?.toDouble();
                    if (dx == null || dy == null) return false;
                    return (dx - marker.dx).abs() < 1.0 &&
                        (dy - marker.dy).abs() < 1.0 &&
                        (e.type == 'shot' || e.type == 'goal');
                  });
                } catch (_) {
                  matched = null;
                }
              }

              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Marker Details'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Type: ${marker.isGoal ? 'Goal' : 'Shot'}'),
                        Text(
                          'Position: (${marker.dx.toStringAsFixed(1)}, ${marker.dy.toStringAsFixed(1)})',
                        ),
                        if (marker.goalScorerId != null)
                          Text('Goal Scorer ID: ${marker.goalScorerId}'),
                        if (marker.shooterId != null)
                          Text('Shooter ID: ${marker.shooterId}'),
                        if (marker.assist1Id != null)
                          Text('Assist 1 ID: ${marker.assist1Id}'),
                        if (marker.assist2Id != null)
                          Text('Assist 2 ID: ${marker.assist2Id}'),
                        if (matched != null) ...[
                          const SizedBox(height: 8),
                          const Text('Persisted Event:'),
                          Text('Event ID: ${matched.id}'),
                          Text('Event Type: ${matched.type}'),
                          Text('Player ID: ${matched.playerId ?? 'n/a'}'),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            child: const Text('Details'),
          ),
          TextButton(
            onPressed: () async {
              // Close the outer options dialog immediately using this builder's
              // context so we don't attempt ancestor lookups on a deactivated
              // dialog later.
              try {
                Navigator.pop(context);
              } catch (_) {}

              // Attempt to find and remove a matching GameEvent by eventId
              // or by coordinates, then persist changes and update UI.
              GameEvent? matched;
              if (marker.eventId != null && widget.game.events != null) {
                try {
                  matched = widget.game.events!.firstWhere(
                    (e) => e.id == marker.eventId,
                  );
                } catch (_) {
                  matched = null;
                }
              }

              if (matched == null && widget.game.events != null) {
                try {
                  matched = widget.game.events!.firstWhere((e) {
                    final dx = (e.details['dx'] as num?)?.toDouble();
                    final dy = (e.details['dy'] as num?)?.toDouble();
                    if (dx == null || dy == null) return false;
                    return (dx - marker.dx).abs() < 1.0 &&
                        (dy - marker.dy).abs() < 1.0 &&
                        (e.type == 'shot' || e.type == 'goal');
                  });
                } catch (_) {
                  matched = null;
                }
              }

              if (matched != null) {
                try {
                  if (matched.type == 'goal') {
                    if (matched.teamId == widget.game.teamId) {
                      widget.game.homeScore = widget.game.homeScore - 1;
                    } else {
                      widget.game.visitorScore = widget.game.visitorScore - 1;
                    }
                  }

                  if (matched.teamId == widget.game.teamId) {
                    widget.game.homeShots = (widget.game.homeShots - 1).clamp(
                      0,
                      9999,
                    );
                  } else {
                    widget.game.visitorShots = (widget.game.visitorShots - 1)
                        .clamp(0, 9999);
                  }

                  widget.game.events?.remove(matched);
                  await widget.game.save();
                } catch (_) {}
              }

              setState(() {
                markers.removeWhere(
                  (m) =>
                      identical(m, marker) ||
                      (m.eventId == marker.eventId &&
                          m.dx == marker.dx &&
                          m.dy == marker.dy),
                );
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    homePPO = widget.game.homePPO;
    visitorPPO = widget.game.visitorPPO;
    currentPeriod = '1';

    final box = Hive.box('positionAssignments');
    final saved = box.get(widget.game.id);
    if (saved != null && saved is Map) {
      positionAssignments = Map<String, String>.from(saved);
    }

    // If a starting goalie was provided, prefer that over saved assignments
    if (widget.startingGoalieId != null &&
        widget.startingGoalieId!.isNotEmpty) {
      positionAssignments['G'] = widget.startingGoalieId!;
      Hive.box('positionAssignments').put(widget.game.id, positionAssignments);
    }

    final opponentBox = Hive.box<Opponent>('opponents');
    opponentTeam = widget.game.opponentTeamId != null
        ? opponentBox.get(widget.game.opponentTeamId)
        : null;

    // Listen for changes to this game so we can rebuild shot/goal markers when events change
    try {
      _gameBox = Hive.box<Game>('games');
      _gameListenable = _gameBox.listenable(keys: [widget.game.id]);
      _gameListenable.addListener(_rebuildMarkersFromEvents);
    } catch (_) {
      // Non-fatal — if games box isn't available here for some reason, markers will still work for the session
    }

    // initial population of markers from persisted events (if any)
    _rebuildMarkersFromEvents();
  }

  void _rebuildMarkersFromEvents() {
    try {
      final stored = Hive.box<Game>('games').get(widget.game.id);
      final events = stored?.events ?? widget.game.events ?? [];

      // Build a map of persisted markers from events for quick lookup
      final Map<String, ShotMarker> persistedById = {};
      // measure rendered image size to convert normalized coords -> pixels
      double imgW = MediaQuery.of(context).size.width;
      double imgH = 800.0;
      try {
        final rb = iceKey.currentContext?.findRenderObject() as RenderBox?;
        if (rb != null && rb.hasSize) {
          imgW = rb.size.width;
          imgH = rb.size.height;
        }
      } catch (_) {}

      for (final e in events) {
        if (!(e.type == 'shot' || e.type == 'goal')) continue;
        // Only show markers for the current period (compare numerically)
        final currentPeriodInt = _parsePeriod(currentPeriod);
        if (e.period != currentPeriodInt) continue;

        final isHomeShooting = (e.details['isHomeShooting'] as bool?) ?? true;
        final shootingColor = isHomeShooting
            ? widget.team.primaryColor
            : opponentTeam?.color ?? Colors.grey;

        final playerNumber = (e.playerId != null && e.playerId!.isNotEmpty)
            ? (Hive.box<Player>('players').get(e.playerId)?.number.toString())
            : null;

        // Prefer normalized coords when available so review/live compute the
        // same pixel positions. Compute dx/dy from dxNorm/dyNorm using the
        // current rendered image size so persisted markers align with the
        // in-memory markers created at tap time.
        final dxNorm = (e.details['dxNorm'] as num?)?.toDouble();
        final dyNorm = (e.details['dyNorm'] as num?)?.toDouble();
        final computedDx = dxNorm != null
            ? (dxNorm * imgW)
            : ((e.details['dx'] as num?)?.toDouble() ?? 0.0);
        final computedDy = dyNorm != null
            ? (dyNorm * imgH)
            : ((e.details['dy'] as num?)?.toDouble() ?? 0.0);

        final persistedMarker = ShotMarker(
          dx: computedDx,
          dy: computedDy,
          isGoal: e.type == 'goal',
          teamColorValue:
              (((shootingColor.a * 255.0).round() & 0xff) << 24) |
              (((shootingColor.r * 255.0).round() & 0xff) << 16) |
              (((shootingColor.g * 255.0).round() & 0xff) << 8) |
              ((shootingColor.b * 255.0).round() & 0xff),
          playerNumber: playerNumber,
          shooterId: e.playerId,
          goalScorerId: e.type == 'goal' ? e.playerId : null,
          assist1Id: e.details['assist1Id'] as String?,
          assist2Id: e.details['assist2Id'] as String?,
          eventId: e.id,
        );

        persistedById[e.id] = persistedMarker;
      }

      // Merge: prefer to preserve useful in-memory fields (player numbers, shooter/assists)
      // while still showing the authoritative persisted marker geometry and goal/shot status.

      // Preserve the exact in-memory marker ordering so newly-added markers stay
      // visually on top (Stack paints later children over earlier ones). Then
      // append any persisted-only markers that we don't have locally. This is a
      // minimal, low-risk z-order fix: it doesn't change marker coordinates or
      // persisted data — it only avoids reordering local markers based on the
      // persisted events list.
      final merged = <ShotMarker>[];

      // Start with the current in-memory markers in their existing order.
      // This preserves z-order (new markers are appended at the end and will
      // remain on top).
      merged.addAll(markers);

      // Build a quick lookup of local markers by eventId
      final Map<String, ShotMarker> localById = {};
      for (final m in markers) {
        if (m.eventId != null) localById[m.eventId!] = m;
      }

      // For each persisted marker, if we already have a local marker for that
      // eventId, update the local marker's dx/dy to match the computed
      // persisted geometry so the in-memory marker doesn't jump after a
      // rebuild. If no local marker exists, append the persisted marker so
      // it appears beneath local markers added later.
      for (final entry in persistedById.entries) {
        final persisted = entry.value;
        final local = localById[entry.key];
        if (local != null) {
          // Update the local marker's geometry fields to the authoritative
          // persisted pixels (computed from dxNorm when available). Preserve
          // other local fields like playerNumber/assists.
          final updatedLocal = ShotMarker(
            dx: persisted.dx,
            dy: persisted.dy,
            isGoal: local.isGoal || persisted.isGoal,
            teamColorValue: local.teamColorValue,
            playerNumber: local.playerNumber ?? persisted.playerNumber,
            shooterId: local.shooterId ?? persisted.shooterId,
            goalScorerId: local.goalScorerId ?? persisted.goalScorerId,
            assist1Id: local.assist1Id ?? persisted.assist1Id,
            assist2Id: local.assist2Id ?? persisted.assist2Id,
            eventId: local.eventId,
          );
          // Replace in merged where the local marker originally sat
          final existingIdx = merged.indexWhere(
            (m) => m.eventId == local.eventId,
          );
          if (existingIdx != -1) {
            merged[existingIdx] = updatedLocal;
          }
        } else {
          // Append persisted-only markers so they are rendered beneath newer
          // in-memory markers (preserve z-order of local items).
          merged.add(persisted);
        }
      }

      // merged computed; debug prints removed

      // Do an append-only update: never clear or replace existing local markers.
      // This prevents persisted-box updates from overwriting UI geometry that
      // the user just added locally. Only append persisted-only markers.
      final List<ShotMarker> toAppend = [];
      final localIds = markers
          .where((m) => m.eventId != null)
          .map((m) => m.eventId!)
          .toSet();
      for (final m in merged) {
        if (m.eventId == null) continue;
        if (!localIds.contains(m.eventId!)) toAppend.add(m);
      }
      if (toAppend.isNotEmpty) {
        setState(() {
          markers.addAll(toAppend);
        });
      }
    } catch (_) {
      // ignore and leave markers as-is
    }
  }

  void updatePeriod(String period) {
    // If period changed, only clear markers when moving forward to a later period.
    final oldInt = _parsePeriod(currentPeriod);
    final newInt = _parsePeriod(period);
    if (newInt > oldInt) {
      // advancing forward: clear current in-memory markers for the new period
      setState(() {
        currentPeriod = period;
        markers.clear();
      });
    } else if (newInt < oldInt) {
      // moving back to an earlier period: load persisted markers for that period
      setState(() {
        currentPeriod = period;
      });
      _rebuildMarkersFromEvents();
    }
  }

  @override
  void dispose() {
    try {
      _gameListenable.removeListener(_rebuildMarkersFromEvents);
    } catch (_) {}
    super.dispose();
  }

  void handleDropdownSelection(String position, String action) {
    final playerBox = Hive.box<Player>('players');

    // Filter for players available in this game
    final eligiblePlayers = playerBox.values
        .where((p) => widget.game.availablePlayerIds.contains(p.id))
        .toList();

    // Defensive check: no eligible players
    if (eligiblePlayers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available players for this game.')),
      );
      return;
    }

    // Try to find a player matching the tapped position
    final defaultPlayer = eligiblePlayers.firstWhere(
      (p) => p.position == position,
      orElse: () => eligiblePlayers.first,
    );

    switch (action) {
      case 'face_off':
        PremiumService.isPremium().then((isPremium) {
          if (!isPremium) {
            showDialog(
              context: context,
              builder: (_) => UpgradeToPremiumDialog(
                title: 'Face-Off Tracking',
                message: 'Track face-offs during the game. Upgrade to premium to unlock this feature.',
              ),
            );
            return;
          }
          showDialog(
            context: context,
            builder: (_) => FaceOffDialog(
              game: widget.game,
              defaultPlayer: defaultPlayer,
              currentPeriod: _parsePeriod(currentPeriod),
            ),
          );
        });
        break;

      case 'penalty':
        PremiumService.isPremium().then((isPremium) {
          if (!isPremium) {
            showDialog(
              context: context,
              builder: (_) => UpgradeToPremiumDialog(
                title: 'Penalty Tracking',
                message: 'Track penalties during the game. Upgrade to premium to unlock this feature.',
              ),
            );
            return;
          }
          showDialog(
            context: context,
            builder: (_) => PenaltyDialog(
              game: widget.game,
              defaultPlayer: defaultPlayer,
              currentPeriod: _parsePeriod(currentPeriod),
            ),
          );
        });
        break;
      case 'choose_player':
        showDialog(
          context: context,
          builder: (_) => ChoosePlayerDialog(
            position: position,
            availablePlayerIds: widget.game.availablePlayerIds,
            positionAssignments: positionAssignments,
          ),
        ).then((pickedPlayer) {
          if (pickedPlayer != null) {
            setState(() {
              positionAssignments[position] = pickedPlayer.id;
              Hive.box(
                'positionAssignments',
              ).put(widget.game.id, positionAssignments);
            });
          }
        });
        break;

      case 'clear_player':
        setState(() {
          positionAssignments[position] = '';
          Hive.box(
            'positionAssignments',
          ).put(widget.game.id, positionAssignments);
        });
        break;

      case 'change_line':
        PremiumService.isPremium().then((isPremium) {
          if (!isPremium) {
            showDialog(
              context: context,
              builder: (_) => UpgradeToPremiumDialog(
                title: 'Line Changes',
                message: 'Quickly change all players on the ice. Upgrade to premium to unlock this feature.',
              ),
            );
            return;
          }
          showDialog(
            context: context,
            builder: (_) => ChooseLineDialog(teamId: widget.game.teamId),
          ).then((selectedLine) {
            if (selectedLine != null && selectedLine is Line) {
              setState(() {
                positionAssignments['LW'] = selectedLine.lwId;
                positionAssignments['C'] = selectedLine.cId;
                positionAssignments['RW'] = selectedLine.rwId;
                positionAssignments['LD'] = selectedLine.ldId;
                positionAssignments['RD'] = selectedLine.rdId;
                Hive.box(
                  'positionAssignments',
                ).put(widget.game.id, positionAssignments);
              });
            }
          });
        });
        break;

      case 'clear_line':
        PremiumService.isPremium().then((isPremium) {
          if (!isPremium) {
            showDialog(
              context: context,
              builder: (_) => UpgradeToPremiumDialog(
                title: 'Clear Line',
                message: 'Quickly clear all players from the ice. Upgrade to premium to unlock this feature.',
              ),
            );
            return;
          }
          setState(() {
            positionAssignments['LW'] = '';
            positionAssignments['C'] = '';
            positionAssignments['RW'] = '';
            positionAssignments['LD'] = '';
            positionAssignments['RD'] = '';
            // Leave 'G' unchanged
            Hive.box(
              'positionAssignments',
            ).put(widget.game.id, positionAssignments);
          });
        });
        break;

      case 'change_goalie':
        final playerBox = Hive.box<Player>('players');
        final availablePlayerIds = playerBox.values
            .where((p) => p.teamId == widget.game.teamId)
            .map((p) => p.id)
            .toList();

        showDialog(
          context: context,
          builder: (_) => ChooseGoalieDialog(
            availablePlayerIds: availablePlayerIds,
            currentGoalieId: positionAssignments['G'],
          ),
        ).then((pickedGoalie) {
          if (pickedGoalie != null) {
            setState(() {
              positionAssignments['G'] = pickedGoalie.id;
              Hive.box(
                'positionAssignments',
              ).put(widget.game.id, positionAssignments);
            });
          }
        });
        break;

      case 'pull_goalie':
        PremiumService.isPremium().then((isPremium) {
          if (!isPremium) {
            showDialog(
              context: context,
              builder: (_) => UpgradeToPremiumDialog(
                title: 'Pull Goalie',
                message: 'Pull your goalie for an extra attacker. Upgrade to premium to unlock this feature.',
              ),
            );
            return;
          }
          setState(() {
            positionAssignments['G'] = ''; // Empty net
            Hive.box(
              'positionAssignments',
            ).put(widget.game.id, positionAssignments);
          });
        });
        break;

      // TODO: Add logic for choose_player, change_line
    }
  }

  int _parsePeriod(String label) {
    switch (label) {
      case 'OT':
        return 4;
      case 'SO':
        return 5;
      default:
        return int.tryParse(label) ?? 1;
    }
  }

  void updatePPO(String team, int delta) {
    setState(() {
      if (team == 'home') {
        homePPO = (homePPO + delta).clamp(0, 99);
      } else {
        visitorPPO = (visitorPPO + delta).clamp(0, 99);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final opponentName = opponentTeam?.name ?? 'Opponent';

    final accentColor = widget.team.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Game Tracker'),
        backgroundColor: accentColor,
      ),
      body: Column(
        children: [
          // Top Banner: Position Boxes
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['C', 'LW', 'RW', 'LD', 'RD', 'G'].map((pos) {
                final bgColor = accentColor.withAlpha((0.4 * 255).round());
                final fgColor = _contrastTextColor(bgColor);
                return Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final items = pos == 'G'
                          ? [
                              const PopupMenuItem(
                                value: 'change_goalie',
                                child: Text('Change Goalie'),
                              ),
                              const PopupMenuItem(
                                value: 'pull_goalie',
                                child: Text('Pull Goalie'),
                              ),
                              const PopupMenuItem(
                                value: 'penalty',
                                child: Text('Penalty'),
                              ),
                            ]
                          : [
                              const PopupMenuItem(
                                value: 'choose_player',
                                child: Text('Choose Player'),
                              ),
                              const PopupMenuItem(
                                value: 'clear_player',
                                child: Text('Clear Player'),
                              ),
                              const PopupMenuItem(
                                value: 'change_line',
                                child: Text('Change Line'),
                              ),
                              const PopupMenuItem(
                                value: 'clear_line',
                                child: Text('Clear Line'),
                              ),
                              const PopupMenuItem(
                                value: 'face_off',
                                child: Text('Face-Off'),
                              ),
                              const PopupMenuItem(
                                value: 'penalty',
                                child: Text('Penalty'),
                              ),
                            ];

                      showMenu(
                        context: context,
                        position: RelativeRect.fromLTRB(100, 100, 0, 0),
                        items: items,
                      ).then((value) {
                        if (value != null) handleDropdownSelection(pos, value);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bgColor,
                      foregroundColor: fgColor,
                      elevation: 2,
                      shadowColor: accentColor,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: accentColor, width: 1),
                      ),
                    ),
                    child: Text(
                      (() {
                        final playerId = positionAssignments[pos];
                        final playerBox = Hive.box<Player>('players');

                        if (pos == 'G') {
                          if (playerId == null) return 'G'; // Default
                          if (playerId.isEmpty) return 'EN'; // Goalie pulled
                          final goalie = playerBox.get(playerId);
                          return goalie != null
                              ? goalie.number.toString()
                              : 'G';
                        }

                        if (playerId != null && playerId.isNotEmpty) {
                          final player = playerBox.get(playerId);
                          return player != null
                              ? player.number.toString()
                              : pos;
                        }

                        return pos;
                      })(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Ice Rink
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                // Calculate tap position relative to the ice image itself so
                // normalization uses the image display rect (no stack offsets).
                final box =
                    iceKey.currentContext?.findRenderObject() as RenderBox?;
                if (box != null) {
                  tapPosition = box.globalToLocal(details.globalPosition);
                }
              },
              onTap: () {
                if (tapPosition != null) addMarker(tapPosition!, false);
              },
              onDoubleTap: () {
                if (tapPosition != null) addMarker(tapPosition!, true);
              },
              child: SingleChildScrollView(
                child: Stack(
                  key: stackKey,
                  children: [
                    SizedBox(
                      key: iceKey,
                      width: MediaQuery.of(context).size.width,
                      height: 800.0,
                      child: Image.asset(
                        'assets/ice_rink.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // Left-end team label (defensive zone)
                    Positioned(
                      top: 260,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          homeOnLeft ? widget.team.name : opponentName,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: homeOnLeft
                                ? widget.team.primaryColor
                                : opponentTeam?.color ?? Colors.grey,
                          ),
                        ),
                      ),
                    ),

                    // Right-end team label (defensive zone)
                    Positioned(
                      bottom: 260,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          homeOnLeft ? opponentName : widget.team.name,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: homeOnLeft
                                ? opponentTeam?.color ?? Colors.grey
                                : widget.team.primaryColor,
                          ),
                        ),
                      ),
                    ),

                    // Marker rendering: compute rendered position using normalized
                    // coords when available so the marker alignment matches the
                    // review view which also uses normalized coords.
                    ...markers.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final marker = entry.value;
                      double imgW = MediaQuery.of(context).size.width;
                      double imgH = 800.0;
                      try {
                        final rb =
                            iceKey.currentContext?.findRenderObject()
                                as RenderBox?;
                        if (rb != null && rb.hasSize) {
                          imgW = rb.size.width;
                          imgH = rb.size.height;
                        }
                      } catch (_) {}

                      // Try to prefer normalized coordinates from the persisted
                      // GameEvent (dxNorm/dyNorm). If not available, fall back
                      // to the marker's raw dx/dy.
                      double dxVal = marker.dx;
                      double dyVal = marker.dy;
                      if (marker.eventId != null) {
                        GameEvent? ev;
                        try {
                          ev = (widget.game.events ?? []).firstWhere(
                            (e) => e.id == marker.eventId,
                          );
                        } catch (_) {
                          ev = null;
                        }
                        if (ev != null) {
                          final dxNorm = (ev.details['dxNorm'] as num?)
                              ?.toDouble();
                          final dyNorm = (ev.details['dyNorm'] as num?)
                              ?.toDouble();
                          if (dxNorm != null) dxVal = dxNorm * imgW;
                          if (dyNorm != null) dyVal = dyNorm * imgH;
                        }
                      }
                      if (kDebugMode) {
                        debugPrint(
                          'renderMarker: idx=$idx eventId=${marker.eventId} dx=${dxVal.toStringAsFixed(2)} dy=${dyVal.toStringAsFixed(2)} isGoal=${marker.isGoal} playerNumber=${marker.playerNumber} shooter=${marker.shooterId} goalScorer=${marker.goalScorerId}',
                        );
                      }
                      return Positioned(
                        left: dxVal - 10,
                        top: dyVal - 10,
                        child: GestureDetector(
                          onLongPress: () => showMarkerOptions(marker),
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: marker.teamColor,
                              shape: marker.isGoal
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                            ),
                            child: marker.isGoal && marker.playerNumber != null
                                ? Text(
                                    marker.playerNumber!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),

                    // debug badge removed
                  ],
                ),
              ),
            ),
          ),

          // 'Switch Ends' removed — ends are fixed for this view

          // Bottom Ribbon
          Container(
            color: accentColor.withAlpha((0.1 * 255).round()),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Period Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['1', '2', '3', 'OT', 'SO'].map((period) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(
                          period,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: currentPeriod == period,
                        onSelected: (_) => updatePeriod(period),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),

                // Scoreboard
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text(
                          widget.team.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.game.homeScore}',
                          style: const TextStyle(
                            fontSize: 30,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shots: ${widget.game.homeShots}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          opponentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.game.visitorScore}',
                          style: const TextStyle(
                            fontSize: 30,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Shots: ${widget.game.visitorShots}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),
                const Text(
                  'PPO',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),

                // PPO Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          onPressed: () => updatePPO('home', -1),
                        ),
                        Text('$homePPO'),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () => updatePPO('home', 1),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 20),
                          onPressed: () => updatePPO('visitor', -1),
                        ),
                        Text('$visitorPPO'),
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () => updatePPO('visitor', 1),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Done Button
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
