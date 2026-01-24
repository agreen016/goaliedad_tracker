import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import '../models/team.dart';
import 'players_screen.dart';
import 'edit_team_screen.dart';
import '../widgets/stat_box.dart';
import '../widgets/stat_grid.dart';
import 'package:hive/hive.dart';
import '../models/player.dart';
import 'games_screen.dart';
import '../models/game.dart';
import '../models/goal.dart';
import '../widgets/shot_heatmap.dart';
import '../services/pdf_export_service.dart';
import '../services/premium_service.dart';
import '../widgets/upgrade_dialog.dart';
import 'goalie_analysis_screen.dart';

class TeamHubScreen extends StatefulWidget {
  final Team team;

  const TeamHubScreen({super.key, required this.team});

  @override
  State<TeamHubScreen> createState() => _TeamHubScreenState();
}

class _TeamHubScreenState extends State<TeamHubScreen> {
  late TextEditingController nameController;
  late TextEditingController leagueController;
  late TextEditingController divisionController;
  late int startYear;
  late int endYear;
  int _selectedIndex = 0;

  String _selectedGameType = 'ALL';
  String? _selectedSeasonHeatmapGoalie;
  // Heatmap UI settings
  HeatmapMode _seasonHeatmapMode = HeatmapMode.grid;
  int _seasonHeatmapCols = 40;
  final GlobalKey _seasonHeatmapKey = GlobalKey();
  // Caches to avoid expensive recomputation on every build (e.g., while typing)
  List<Map<String, dynamic>>? _cachedPlayerRows;
  List<Map<String, dynamic>>? _cachedGoalieRows;
  String? _cachedGameType;
  late StreamSubscription _gamesSub;
  late StreamSubscription _goalsSub;
  late StreamSubscription _playersSub;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.team.name);
    leagueController = TextEditingController(text: widget.team.league);
    divisionController = TextEditingController(text: widget.team.division);
    startYear = widget.team.seasonStartYear;
    endYear = widget.team.seasonEndYear;
    // Listen for changes in Hive boxes and invalidate cached aggregations
    try {
      _gamesSub = Hive.box<Game>(
        'games',
      ).watch().listen((_) => _invalidateCaches());
    } catch (_) {
      _gamesSub = const Stream.empty().listen((_) {});
    }
    try {
      _goalsSub = Hive.box<Goal>(
        'goals',
      ).watch().listen((_) => _invalidateCaches());
    } catch (_) {
      _goalsSub = const Stream.empty().listen((_) {});
    }
    try {
      _playersSub = Hive.box<Player>(
        'players',
      ).watch().listen((_) => _invalidateCaches());
    } catch (_) {
      _playersSub = const Stream.empty().listen((_) {});
    }
  }

  void _invalidateCaches() {
    _cachedPlayerRows = null;
    _cachedGoalieRows = null;
    _cachedGameType = null;
  }

  @override
  void dispose() {
    try {
      _gamesSub.cancel();
    } catch (_) {}
    try {
      _goalsSub.cancel();
    } catch (_) {}
    try {
      _playersSub.cancel();
    } catch (_) {}
    nameController.dispose();
    leagueController.dispose();
    divisionController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    setState(() {
      widget.team.name = nameController.text.trim();
      widget.team.league = leagueController.text.trim();
      widget.team.division = divisionController.text.trim();
      widget.team.seasonStartYear = startYear;
      widget.team.seasonEndYear = endYear;
      widget.team.save();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Team updated')));
  }

  Color _getTeamColor() {
    try {
      return Color(
        int.parse(widget.team.primaryColorHex.replaceFirst('#', '0xFF')),
      );
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  Color _getTextColor(Color bg) {
    return bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  List<Map<String, dynamic>> _getPlayerRows() {
    // Aggregate per-player stats across filtered games below.
    final playerBox = Hive.box<Player>('players');
    final teamPlayers = playerBox.values
        .where((p) => p.teamId == widget.team.id)
        .where((p) => p.position.trim().toLowerCase() != 'goalie')
        .toList();

    // Prepare accumulators
    final Map<String, Map<String, int>> stats = {};
    for (final p in teamPlayers) {
      stats[p.id] = {
        'GP': 0,
        'G': 0,
        'A': 0,
        'P': 0,
        'S': 0,
        'PPG': 0,
        'SHG': 0,
        'GWG': 0,
        '+/-': 0,
        'PIM': 0,
        'FW': 0,
        'FL': 0,
      };
    }

    // Iterate filtered games and aggregate
    final allGamesBox = Hive.box<Game>('games');
    final games = allGamesBox.values
        .where((g) => g.teamId == widget.team.id)
        .toList();
    final filteredGames = _selectedGameType == 'ALL'
        ? games
        : games.where((g) => g.gameType == _selectedGameType).toList();

    // Goals box
    final Box<Goal> goalBox = Hive.box<Goal>('goals');

    for (final g in filteredGames) {
      // track players seen in this game so we can increment GP
      final Set<String> playersSeen = {};

      // goals for this game
      final gameGoals = goalBox.values.where((gg) => gg.gameId == g.id);
      for (final goal in gameGoals) {
        // only count G/A for players on this team
        if (goal.teamId == widget.team.id) {
          final scorer = goal.scorerId;
          if (scorer.isNotEmpty && stats.containsKey(scorer)) {
            stats[scorer]!['G'] = (stats[scorer]!['G'] ?? 0) + 1;
            stats[scorer]!['P'] = (stats[scorer]!['P'] ?? 0) + 1;
            playersSeen.add(scorer);
            // power-play / shorthanded
            try {
              final gt = goal.goalType.toString().toUpperCase();
              if (gt == 'PP') {
                stats[scorer]!['PPG'] = (stats[scorer]!['PPG'] ?? 0) + 1;
              }
              if (gt == 'SH') {
                stats[scorer]!['SHG'] = (stats[scorer]!['SHG'] ?? 0) + 1;
              }
            } catch (_) {}
          }
          for (final a in goal.assistIds) {
            if (a.toString().isNotEmpty && stats.containsKey(a)) {
              stats[a]!['A'] = (stats[a]!['A'] ?? 0) + 1;
              stats[a]!['P'] = (stats[a]!['P'] ?? 0) + 1;
              playersSeen.add(a.toString());
            }
          }
        }
      }

      // events
      final events = g.events ?? [];
      for (final ev in events) {
        if (ev.type == 'shot' || ev.type == 'goal') {
          final pid = ev.playerId;
          // count shots for players on this team (shots by this team)
          if (pid != null &&
              stats.containsKey(pid) &&
              ev.teamId == widget.team.id) {
            stats[pid]!['S'] = (stats[pid]!['S'] ?? 0) + 1;
            playersSeen.add(pid);
          }

          // +/- attribution uses onIce snapshot on goal events
          if (ev.type == 'goal') {
            try {
              final details = ev.details;
              if (details['onIce'] != null && details['onIce'] is Map) {
                final onIce = Map<String, dynamic>.from(details['onIce']);
                for (final entry in onIce.entries) {
                  final playerId = (entry.value ?? '').toString();
                  if (playerId.isEmpty) continue;
                  if (!stats.containsKey(playerId)) continue;
                  if (ev.teamId == widget.team.id) {
                    stats[playerId]!['+/-'] =
                        (stats[playerId]!['+/-'] ?? 0) + 1;
                  } else {
                    stats[playerId]!['+/-'] =
                        (stats[playerId]!['+/-'] ?? 0) - 1;
                  }
                  playersSeen.add(playerId);
                }
              }
            } catch (_) {}
          }
        } else if (ev.type == 'faceoff') {
          try {
            final pid = ev.playerId;
            if (pid != null && stats.containsKey(pid)) {
              final res = (ev.details['result'] ?? '').toString().toLowerCase();
              if (res == 'won') {
                stats[pid]!['FW'] = (stats[pid]!['FW'] ?? 0) + 1;
              } else if (res == 'lost') {
                stats[pid]!['FL'] = (stats[pid]!['FL'] ?? 0) + 1;
              }
              playersSeen.add(pid);
            }
          } catch (_) {}
        } else if (ev.type == 'penalty') {
          try {
            final pid = ev.playerId;
            if (pid != null && stats.containsKey(pid)) {
              final mins = (ev.details['minutes'] ?? 0) as int? ?? 0;
              stats[pid]!['PIM'] = (stats[pid]!['PIM'] ?? 0) + mins;
              playersSeen.add(pid);
            }
          } catch (_) {}
        }
      }

      // also consider available players as having appeared in the game
      try {
        final avail = g.availablePlayerIds;
        for (final pid in avail) {
          playersSeen.add(pid.toString());
        }
      } catch (_) {}

      // increment GP for players seen in this game
      for (final pid in playersSeen) {
        if (stats.containsKey(pid)) {
          stats[pid]!['GP'] = (stats[pid]!['GP'] ?? 0) + 1;
        }
      }
    }

    // produce rows with aggregated FW% computed
    // Return cached rows when available for the current game type
    if (_cachedPlayerRows != null && _cachedGameType == _selectedGameType) {
      return _cachedPlayerRows!;
    }

    final computed = teamPlayers.map((p) {
      final s =
          stats[p.id] ??
          {
            for (var k in ['G', 'A', 'P', 'S', '+/-']) k: 0,
          };
      final fw = s['FW'] ?? 0;
      final fl = s['FL'] ?? 0;
      final fwPct = (fw + fl) > 0 ? ((fw * 100) / (fw + fl)).round() : 0;
      return {
        'Name': p.name,
        'GP': s['GP'] ?? 0,
        'G': s['G'] ?? 0,
        'A': s['A'] ?? 0,
        'P': s['P'] ?? 0,
        'S': s['S'] ?? 0,
        'PPG': s['PPG'] ?? 0,
        'SHG': s['SHG'] ?? 0,
        'GWG': s['GWG'] ?? 0,
        '+/-': s['+/-'] ?? 0,
        'PIM': s['PIM'] ?? 0,
        'FW': fw,
        'FL': fl,
        'FW%': fwPct,
      };
    }).toList();

    _cachedPlayerRows = computed;
    _cachedGameType = _selectedGameType;
    return computed;
  }

  List<Map<String, dynamic>> _getGoalieRows() {
    if (_cachedGoalieRows != null && _cachedGameType == _selectedGameType) {
      return _cachedGoalieRows!;
    }
    final box = Hive.box<Player>('players');
    final teamPlayers = box.values.where((p) => p.teamId == widget.team.id);

    final goalies = teamPlayers.where(
      (p) => p.position.trim().toLowerCase() == 'goalie',
    );
    final rows = <Map<String, dynamic>>[];
    final allGamesBox = Hive.box<Game>('games');
    final games = allGamesBox.values
        .where((g) => g.teamId == widget.team.id)
        .toList();
    final filteredGames = _selectedGameType == 'ALL'
        ? games
        : games.where((g) => g.gameType == _selectedGameType).toList();

    final Map<String, Map<String, num>> accum = {};
    for (final p in goalies) {
      accum[p.id] = {
        'GP': 0,
        'MIN': 0,
        'SOG': 0,
        'GA': 0,
        'SV': 0,
        'SO': 0,
        'PIM': 0,
        'G': 0,
        'A': 0,
        'P': 0,
      };
    }

    for (final g in filteredGames) {
      // track which goalies appeared in this game so we can increment GP
      final Set<String> goaliesSeen = {};

      // events - use events for both SOG and GA counting (same as game details screen)
      final events = g.events ?? [];
      for (final ev in events) {
        if (ev.type == 'shot' || ev.type == 'goal') {
          final details = ev.details;
          String goalieId = (details['goalieId'] ?? '').toString();
          if (goalieId.isEmpty && details['onIce'] != null) {
            try {
              final onIce = Map<String, dynamic>.from(details['onIce']);
              goalieId = (onIce['G'] ?? '').toString();
            } catch (_) {}
          }
          if (goalieId.isEmpty && (g.startingGoalie ?? '').isNotEmpty) {
            goalieId = g.startingGoalie!;
          }
          // record that this goalie appeared in this game
          if (goalieId.isNotEmpty) goaliesSeen.add(goalieId);
          if (goalieId.isNotEmpty && accum.containsKey(goalieId)) {
            // Count SOG when shot was taken by OPPOSING team
            if (ev.teamId != widget.team.id) {
              accum[goalieId]!['SOG'] = (accum[goalieId]!['SOG'] ?? 0) + 1;
            }
            // Count GA when goal was scored by OPPOSING team (same logic as game details)
            if (ev.type == 'goal' && ev.teamId != widget.team.id) {
              accum[goalieId]!['GA'] = (accum[goalieId]!['GA'] ?? 0) + 1;
            }
          }
        }
      }

      // also count starting goalie if not present in events
      if ((g.startingGoalie ?? '').isNotEmpty) {
        goaliesSeen.add(g.startingGoalie!);
      }

      // increment GP for each goalie who appeared in this game
      for (final gid in goaliesSeen) {
        if (accum.containsKey(gid)) {
          accum[gid]!['GP'] = (accum[gid]!['GP'] ?? 0) + 1;
        }
      }
    }

    for (final p in goalies) {
      final a = accum[p.id] ?? {};
      final sog = a['SOG'] ?? 0;
      final ga = a['GA'] ?? 0;
      // compute MIN based on distinct periods where this goalie appears in onIce snapshots
      final Set<int> periodsSeen = {};
      for (final g in filteredGames) {
        final events = g.events ?? [];
        for (final ev in events) {
          try {
            if (ev.details['onIce'] != null) {
              final onIce = Map<String, dynamic>.from(ev.details['onIce']);
              if ((onIce['G'] ?? '') == p.id) {
                periodsSeen.add(ev.period);
              }
            }
          } catch (_) {}
        }
      }
      final minutes = periodsSeen.isNotEmpty ? (periodsSeen.length * 20) : 0;
      // Per-user request: use raw GA as GAA for the game
      final gp = a['GP'] ?? 0;
      final gaa = gp > 0 ? (ga.toDouble() / gp.toDouble()) : 0.0; // GA per game
      rows.add({
        'Name': p.name,
        'GP': a['GP'] ?? 0,
        'MIN': minutes,
        'SOG': sog,
        'GA': ga,
        'GAA': gaa.toStringAsFixed(2),
        'SV': (sog - ga),
        'SV%': sog > 0
            ? '${(((sog - ga) / sog) * 100).toStringAsFixed(1)}%'
            : '0%',
        'SO': a['SO'] ?? 0,
        'PIM': a['PIM'] ?? 0,
        'G': a['G'] ?? 0,
        'A': a['A'] ?? 0,
        'P': a['P'] ?? 0,
      });
    }

    return rows;
  }

  Widget _buildGameTypeFilters() {
    final types = ['ALL', 'League', 'Friendly', 'Playoff', 'Tournament'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: types.map((type) {
            final isSelected = _selectedGameType == type;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(type),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedGameType = type;
                  });
                },
                selectedColor: _getTeamColor(),
                backgroundColor: Colors.grey.shade300,
                labelStyle: TextStyle(
                  color: isSelected
                      ? _getTextColor(_getTeamColor())
                      : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTeamStats(Color accentColor) {
    final Box<Game> gameBox = Hive.box<Game>('games');
    final allGames = gameBox.values
        .where((g) => g.teamId == widget.team.id)
        .toList();
    final filteredGames = _selectedGameType == 'ALL'
        ? allGames
        : allGames.where((g) => g.gameType == _selectedGameType).toList();

    final totalGames = filteredGames.length;
    final wins = filteredGames
        .where((g) => g.homeScore > g.visitorScore)
        .length;
    final losses = filteredGames
        .where((g) => g.homeScore < g.visitorScore)
        .length;
    final ties = filteredGames
        .where((g) => g.homeScore == g.visitorScore)
        .length;

    final goalsFor = filteredGames.fold<int>(0, (sum, g) => sum + g.homeScore);
    final goalsAgainst = filteredGames.fold<int>(
      0,
      (sum, g) => sum + g.visitorScore,
    );
    final totalShots = filteredGames.fold<int>(
      0,
      (sum, g) => sum + g.homeShots,
    );

    // Special teams and leaders: aggregate Goal records across filtered games
    int ppGoalsFor = 0;
    int shGoalsFor = 0;
    int ppGoalsAgainst = 0;
    int shGoalsAgainst = 0;
    int teamPPO = 0; // power play opportunities for this team
    int oppPPO =
        0; // power play opportunities for opponents (team's PK opportunities)
    int penaltyMinutes = 0;

    final Box<Goal> goalBox = Hive.box<Goal>('goals');
    for (final g in filteredGames) {
      // Count PPO: assume games stored are for this team and homePPO is team's PPO
      teamPPO += g.homePPO;
      oppPPO += g.visitorPPO;

      // collect goals for this game
      try {
        final gameGoals = goalBox.values.where((gg) => gg.gameId == g.id);
        for (final goal in gameGoals) {
          if (goal.teamId == widget.team.id) {
            if (goal.goalType.toUpperCase() == 'PP') ppGoalsFor++;
            if (goal.goalType.toUpperCase() == 'SH') shGoalsFor++;
          } else {
            if (goal.goalType.toUpperCase() == 'PP') ppGoalsAgainst++;
            if (goal.goalType.toUpperCase() == 'SH') shGoalsAgainst++;
          }
        }
      } catch (_) {}

      // penalties: sum minutes from game events where ev.type == 'penalty'
      try {
        final events = g.events ?? [];
        for (final ev in events) {
          if (ev.type == 'penalty') {
            final mins = (ev.details['minutes'] ?? 0) as int? ?? 0;
            if (ev.teamId == widget.team.id) penaltyMinutes += mins;
          }
        }
      } catch (_) {}
    }

    final ppPercent = teamPPO > 0 ? ((ppGoalsFor / teamPPO) * 100) : 0.0;
    final pkPercent = oppPPO > 0
        ? (((oppPPO - ppGoalsAgainst) / oppPPO) * 100)
        : 0.0;

    // Compute Shots Against by summing SA from player rows
    int shotsAgainst = 0;
    try {
      final rows = _getPlayerRows();
      shotsAgainst = rows.fold<int>(0, (s, r) => s + (r['SA'] as int? ?? 0));
    } catch (_) {}

    final avgGoals = totalGames > 0 ? (goalsFor / totalGames) : 0.0;
    final avgShots = totalGames > 0 ? (totalShots / totalGames) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Team Stats',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        _buildGameTypeFilters(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: StatBox(
                  title: 'Games',
                  value: '$totalGames',
                  accentColor: accentColor,
                ),
              ),
              Expanded(
                child: StatBox(
                  title: 'Wins',
                  value: '$wins',
                  accentColor: accentColor,
                ),
              ),
              Expanded(
                child: StatBox(
                  title: 'Losses',
                  value: '$losses',
                  accentColor: accentColor,
                ),
              ),
              Expanded(
                child: StatBox(
                  title: 'Ties',
                  value: '$ties',
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatBox(
                title: 'Goals',
                value: '$goalsFor',
                subtext: 'Avg: ${avgGoals.toStringAsFixed(1)}',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'Goals Against',
                value: '$goalsAgainst',
                subtext:
                    'Avg: ${totalGames > 0 ? (goalsAgainst / totalGames).toStringAsFixed(1) : '0.0'}',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'PP Goals',
                value: '$ppGoalsFor',
                subtext:
                    'Avg: ${totalGames > 0 ? (ppGoalsFor / totalGames).toStringAsFixed(2) : '0.0'}',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'SH Goals',
                value: '$shGoalsFor',
                subtext:
                    'Avg: ${totalGames > 0 ? (shGoalsFor / totalGames).toStringAsFixed(2) : '0.0'}',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'PP %',
                value: '${ppPercent.toStringAsFixed(1)}%',
                breakdown: '$ppGoalsFor / $teamPPO',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'PK %',
                value: '${pkPercent.toStringAsFixed(1)}%',
                breakdown: '${(oppPPO - ppGoalsAgainst)} / $oppPPO',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'SH GA',
                value: '$shGoalsAgainst',
                subtext:
                    'Avg: ${totalGames > 0 ? (shGoalsAgainst / totalGames).toStringAsFixed(2) : '0.0'}',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'PP GA',
                value: '$ppGoalsAgainst',
                subtext:
                    'Avg: ${totalGames > 0 ? (ppGoalsAgainst / totalGames).toStringAsFixed(2) : '0.0'}',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'Shots',
                value: '$totalShots',
                subtext: 'Avg: ${avgShots.toStringAsFixed(1)}',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'Missed/Blocked Shots',
                value: '0',
                subtext: 'Avg: 0.0',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'Shots Against',
                value: '$shotsAgainst',
                subtext: 'Avg: 0.0',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'Face-Off %',
                value: '0%',
                breakdown: '0 / 0',
                accentColor: accentColor,
              ),
              StatBox(
                title: 'Penalty Min',
                value: '$penaltyMinutes',
                subtext:
                    'Avg: ${totalGames > 0 ? (penaltyMinutes / totalGames).toStringAsFixed(1) : '0.0'}',
                accentColor: accentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamTab() {
    final accentColor = _getTeamColor();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundImage: widget.team.logoPath != null
                  ? FileImage(File(widget.team.logoPath!))
                  : const AssetImage('assets/default_team_logo.png')
                        as ImageProvider,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditTeamScreen(team: widget.team),
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Logo & Colors'),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Team Name'),
          ),
          TextField(
            controller: leagueController,
            decoration: const InputDecoration(labelText: 'League'),
          ),
          TextField(
            controller: divisionController,
            decoration: const InputDecoration(labelText: 'Division'),
          ),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: startYear,
                  decoration: const InputDecoration(labelText: 'Start Year'),
                  items: List.generate(10, (i) {
                    final year = DateTime.now().year - 5 + i;
                    return DropdownMenuItem(value: year, child: Text('$year'));
                  }),
                  onChanged: (val) =>
                      setState(() => startYear = val ?? startYear),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: endYear,
                  decoration: const InputDecoration(labelText: 'End Year'),
                  items: List.generate(10, (i) {
                    final year = DateTime.now().year - 5 + i;
                    return DropdownMenuItem(value: year, child: Text('$year'));
                  }),
                  onChanged: (val) => setState(() => endYear = val ?? endYear),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
          ),
          const SizedBox(height: 32),
          _buildTeamStats(accentColor),
          const SizedBox(height: 32),
          // compute leaders from player rows so placeholder can be pure UI
          Builder(
            builder: (_) {
              final rows = _getPlayerRows();
              // compute leaders
              String topScorer = '';
              String topAssist = '';
              String topPoints = '';
              try {
                if (rows.isNotEmpty) {
                  final sortedByG = List.from(rows)
                    ..sort((a, b) => (b['G'] ?? 0).compareTo(a['G'] ?? 0));
                  final sortedByA = List.from(rows)
                    ..sort((a, b) => (b['A'] ?? 0).compareTo(a['A'] ?? 0));
                  final sortedByP = List.from(rows)
                    ..sort((a, b) => (b['P'] ?? 0).compareTo(a['P'] ?? 0));
                  final gRow = sortedByG.first;
                  final aRow = sortedByA.first;
                  final pRow = sortedByP.first;
                  final gName = gRow['Name'] ?? '-';
                  final aName = aRow['Name'] ?? '-';
                  final pName = pRow['Name'] ?? '-';
                  final gCount = (gRow['G'] ?? 0).toString();
                  final aCount = (aRow['A'] ?? 0).toString();
                  final pCount = (pRow['P'] ?? 0).toString();
                  topScorer = '$gName ($gCount)';
                  topAssist = '$aName ($aCount)';
                  topPoints = '$pName ($pCount)';
                }
              } catch (_) {}

              // Build a map of leader stats (some may be empty)
              final leaders = <String, String>{};
              if (topScorer.isNotEmpty) leaders['Goals'] = topScorer;
              if (topAssist.isNotEmpty) leaders['Assists'] = topAssist;
              if (topPoints.isNotEmpty) leaders['Points'] = topPoints;

              // Additional player-based leaders from player rows
              try {
                // PPG, SHG, +/- , PIM, FW%
                final players = rows;
                // PPG leader
                final byPpg = List.from(players)
                  ..sort((a, b) => (b['PPG'] ?? 0).compareTo(a['PPG'] ?? 0));
                if (byPpg.isNotEmpty && (byPpg.first['PPG'] ?? 0) > 0) {
                  final p = byPpg.first; // display name and value
                  leaders['PPG'] = '${p['Name']} (${p['PPG']})';
                }
                // SHG leader
                final byShg = List.from(players)
                  ..sort((a, b) => (b['SHG'] ?? 0).compareTo(a['SHG'] ?? 0));
                if (byShg.isNotEmpty && (byShg.first['SHG'] ?? 0) > 0) {
                  final p = byShg.first;
                  leaders['SHG'] = '${p['Name']} (${p['SHG']})';
                }
                // +/- leader (largest absolute value)
                final byPlusMinus = List.from(players)
                  ..sort((a, b) => (b['+/-'] ?? 0).compareTo(a['+/-'] ?? 0));
                if (byPlusMinus.isNotEmpty &&
                    (byPlusMinus.first['+/-'] ?? 0) != 0) {
                  final p = byPlusMinus.first;
                  leaders['+/-'] = '${p['Name']} (${p['+/-']})';
                }
                // PIM leader
                final byPim = List.from(players)
                  ..sort((a, b) => (b['PIM'] ?? 0).compareTo(a['PIM'] ?? 0));
                if (byPim.isNotEmpty && (byPim.first['PIM'] ?? 0) > 0) {
                  final p = byPim.first;
                  leaders['PIM'] = '${p['Name']} (${p['PIM']})';
                }
                // FW% leader (use computed FW% if present)
                final byFwPct = List.from(players)
                  ..sort((a, b) => (b['FW%'] ?? 0).compareTo(a['FW%'] ?? 0));
                if (byFwPct.isNotEmpty && (byFwPct.first['FW%'] ?? 0) > 0) {
                  final p = byFwPct.first;
                  final pct = (p['FW%'] ?? 0).toString();
                  leaders['FW%'] = '${p['Name']} ($pct%)';
                }
              } catch (_) {}

              // Goalie-based leaders (SV, SV%, SO, GAA)
              try {
                final gRows = _getGoalieRows();
                if (gRows.isNotEmpty) {
                  // SV leader (saves)
                  final bySv = List.from(gRows)
                    ..sort((a, b) => (b['SV'] ?? 0).compareTo(a['SV'] ?? 0));
                  if (bySv.isNotEmpty && (bySv.first['SV'] ?? 0) > 0) {
                    final g = bySv.first;
                    leaders['SV'] = '${g['Name']} (${g['SV']})';
                  }
                  // SV% leader
                  final bySvPct = List.from(gRows)
                    ..sort(
                      (a, b) => (b['SV%'] ?? '0%').toString().compareTo(
                        (a['SV%'] ?? '0%').toString(),
                      ),
                    );
                  if (bySvPct.isNotEmpty &&
                      (bySvPct.first['SV%'] ?? '0%') != '0%') {
                    final g = bySvPct.first;
                    leaders['SV%'] = '${g['Name']} (${g['SV%']})';
                  }
                  // SO leader
                  final bySo = List.from(gRows)
                    ..sort((a, b) => (b['SO'] ?? 0).compareTo(a['SO'] ?? 0));
                  if (bySo.isNotEmpty && (bySo.first['SO'] ?? 0) > 0) {
                    final g = bySo.first;
                    leaders['SO'] = '${g['Name']} (${g['SO']})';
                  }
                  // GAA leader (lowest numeric GAA). Only consider goalies with GP>0
                  final candidates = gRows
                      .where((r) => (r['GP'] ?? 0) > 0)
                      .toList();
                  if (candidates.isNotEmpty) {
                    candidates.sort((a, b) {
                      final da =
                          double.tryParse((a['GAA'] ?? '0').toString()) ??
                          double.infinity;
                      final db =
                          double.tryParse((b['GAA'] ?? '0').toString()) ??
                          double.infinity;
                      return da.compareTo(db);
                    });
                    final best = candidates.first;
                    leaders['GAA'] = '${best['Name']} (${best['GAA']})';
                  }
                }
              } catch (_) {}

              return _buildTeamLeadersList(accentColor, leaders);
            },
          ),
          StatGrid(
            title: 'Player Stats',
            columns: [
              'Name',
              'GP',
              'G',
              'A',
              'P',
              'S',
              'PPG',
              'SHG',
              'GWG',
              '+/-',
              'PIM',
              'FW',
              'FL',
              'FW%',
            ],
            rows: _getPlayerRows(),
            totals: {
              'Name': 'Totals',
              'GP': 0,
              'G': 0,
              'A': 0,
              'P': 0,
              'S': 0,
              'PPG': 0,
              'SHG': 0,
              'GWG': 0,
              '+/-': 0,
              'PIM': 0,
              'FW': 0,
              'FL': 0,
              'FW%': '0%',
            },
            accentColor: accentColor,
          ),
          const SizedBox(height: 24),
          StatGrid(
            title: 'Goalie Stats',
            columns: [
              'Name',
              'GP',
              'MIN',
              'SOG',
              'GA',
              'GAA',
              'SV',
              'SV%',
              'SO',
              'PIM',
              'G',
              'A',
              'P',
            ],
            rows: _getGoalieRows(),
            totals: {
              'Name': 'Totals',
              'GP': 0,
              'MIN': 0,
              'SOG': 0,
              'GA': 0,
              'GAA': '0.00',
              'SV': 0,
              'SV%': '0%',
              'SO': 0,
              'PIM': 0,
              'G': 0,
              'A': 0,
              'P': 0,
            },
            accentColor: accentColor,
          ),
          const SizedBox(height: 16),
          // Goalie Analysis button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.analytics),
              label: const Text('Goalie Zone Analysis'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () async {
                // Check premium status
                if (!await PremiumService.canAccessGoalieAnalysis()) {
                  showUpgradeDialog(
                    context,
                    title: 'Premium Feature',
                    message: 'Goalie Zone Analysis is a premium feature. Upgrade to access advanced shot tracking and analysis!',
                    onUpgrade: () {
                      // TODO: Navigate to purchase screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Purchase screen coming soon!')),
                      );
                    },
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GoalieAnalysisScreen(team: widget.team),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Aggregates normalized shot coordinates across filteredGames for the goalie name provided
  List<Offset> _collectSeasonShotsForGoalie(String goalieName) {
    final pts = <Offset>[];
    try {
      // map goalie name to player id via goalie rows
      final gRows = _getGoalieRows();
      String? goalieId;
      for (final g in gRows) {
        if ((g['Name'] ?? '') == goalieName) {
          // We need the player id; rows don't carry id, so try resolving by name
          final box = Hive.box<Player>('players');
          for (final pv in box.values) {
            try {
              if (pv.name == goalieName) {
                goalieId = pv.id;
                break;
              }
            } catch (_) {}
          }
          break;
        }
      }
      if (goalieId == null) return pts;

      final allGamesBox = Hive.box<Game>('games');
      final games = allGamesBox.values
          .where((g) => g.teamId == widget.team.id)
          .toList();
      final filteredGames = _selectedGameType == 'ALL'
          ? games
          : games.where((g) => g.gameType == _selectedGameType).toList();
      for (final g in filteredGames) {
        final events = g.events ?? [];
        for (final ev in events) {
          if (ev.type == 'shot' || ev.type == 'goal') {
            // only opponent shots
            if (ev.teamId == widget.team.id) continue;
            String goalie = (ev.details['goalieId'] ?? '').toString();
            if (goalie.isEmpty && ev.details['onIce'] != null) {
              try {
                final onIce = Map<String, dynamic>.from(ev.details['onIce']);
                goalie = (onIce['G'] ?? '').toString();
              } catch (_) {}
            }
            if (goalie.isEmpty && (g.startingGoalie ?? '').isNotEmpty) {
              goalie = g.startingGoalie!;
            }
            if (goalie != goalieId) {
              continue;
            }
            final dxNorm = (ev.details['dxNorm'] as num?)?.toDouble();
            final dyNorm = (ev.details['dyNorm'] as num?)?.toDouble();
            if (dxNorm != null && dyNorm != null) {
              pts.add(Offset(dxNorm, dyNorm));
            }
          }
        }
      }
    } catch (_) {}
    return pts;
  }

  Widget _buildTabContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildTeamTab();
      case 1:
        return PlayersScreen(team: widget.team);
      case 2:
        return GamesScreen(team: widget.team);
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamColor = _getTeamColor();
    final textColor = _getTextColor(teamColor);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: teamColor,
        title: Text(widget.team.name, style: TextStyle(color: textColor)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _buildTabContent(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Team'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Players'),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_hockey),
            label: 'Games',
          ),
        ],
      ),
    );
  }
}

// Render a compact vertical leaders list; only non-empty fields are shown.
Widget _buildTeamLeadersList(Color accentColor, Map<String, String> leaders) {
  // Build rows for non-empty leader entries
  final entries = leaders.entries.where((e) => e.value.isNotEmpty);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leaders',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...entries.map((entry) {
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${entry.key}:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              const Divider(height: 12, thickness: 1),
            ],
          );
        }),
      ],
    ),
  );
}
