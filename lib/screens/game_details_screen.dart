import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import '../widgets/game_player_stats_grid.dart';
import '../widgets/game_goalie_stats_grid.dart';
import '../widgets/game_scoring_summary_grid.dart';
import '../widgets/game_shot_summary_grid.dart';
import '../widgets/game_special_teams_grid.dart';
import '../widgets/game_rink_view.dart';
import '../widgets/shot_heatmap.dart';
import '../services/pdf_export_service.dart';
import '../services/premium_service.dart';
import '../widgets/upgrade_dialog.dart';
import '../models/team.dart';
import '../models/game.dart';
import '../models/opponent.dart';
import '../models/player.dart';
import '../models/goal.dart';
import 'opponent_selection_screen.dart';
import 'live_game_tracker_screen.dart';

class GameDetailsScreen extends StatefulWidget {
  final Team team;
  final Game? existingGame;

  const GameDetailsScreen({required this.team, this.existingGame, super.key});

  @override
  State<GameDetailsScreen> createState() => _GameDetailsScreenState();
}

class _GameDetailsScreenState extends State<GameDetailsScreen> {
  final GlobalKey _heatmapKey = GlobalKey();
  final GlobalKey _rinkKey = GlobalKey();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDateTime = DateTime.now();
  String _selectedGameType = 'League';
  int _homeScore = 0;
  int _visitorScore = 0;
  int _homeShots = 0;
  int _visitorShots = 0;
  bool _isFinal = false;
  String? _startingGoalie; // stores player id
  String? _startingGoalieName; // human-readable name shown in UI
  String? _visitorTeamName;
  String? _selectedHeatmapGoalie;
  late Game _game;
  late Box<Game> _gameBox;
  late ValueListenable<Box<Game>> _gameListenable;
  late Box<Goal> _goalBox;
  late ValueListenable<Box<Goal>> _goalListenable;

  @override
  void initState() {
    super.initState();
    _gameBox = Hive.box<Game>('games');

    if (widget.existingGame != null) {
      _game = widget.existingGame!;
      _startingGoalie = _game.startingGoalie;
      // if startingGoalie is stored as id, try to resolve name
      if (_startingGoalie != null && _startingGoalie!.isNotEmpty) {
        final p = Hive.box<Player>('players').get(_startingGoalie);
        if (p != null) _startingGoalieName = '${p.name} (#${p.number})';
      }
    } else {
      _game = Game(
        id: UniqueKey().toString(),
        teamId: widget.team.id,
        dateTime: DateTime.now(),
        opponent: '',
        gameType: 'League',
        result: '',
        name: '',
        location: '',
        homeScore: 0,
        visitorScore: 0,
        homeShots: 0,
        visitorShots: 0,
        isFinal: false,
        startingGoalie: null,
        opponentTeamId: null,
        isUserTeamVisitor: false,
      );
      _gameBox.put(_game.id, _game);
    }

    if (_game.availablePlayerIds.isEmpty) {
      final playerBox = Hive.box<Player>('players');
      final rosteredPlayers = playerBox.values
          .where((p) => p.teamId == widget.team.id)
          .map((p) => p.id)
          .toList();
      _game.availablePlayerIds = rosteredPlayers;
    }

    _nameController.text = _game.name ?? '';
    _locationController.text = _game.location ?? '';
    _selectedDateTime = _game.dateTime;
    _selectedGameType = _game.gameType;
    _homeScore = _game.homeScore;
    _visitorScore = _game.visitorScore;
    _homeShots = _game.homeShots;
    _visitorShots = _game.visitorShots;
    _isFinal = _game.isFinal;
    _startingGoalie = _game.startingGoalie;
    if (_startingGoalie != null && _startingGoalie!.isNotEmpty) {
      final p = Hive.box<Player>('players').get(_startingGoalie);
      if (p != null) _startingGoalieName = '${p.name} (#${p.number})';
    }
    _visitorTeamName = _game.opponent;

    _nameController.addListener(_saveGame);
    _locationController.addListener(_saveGame);

    // Listen for changes to this game in Hive and refresh local state so UI stays accurate
    _gameListenable = _gameBox.listenable(keys: [_game.id]);
    _gameListenable.addListener(_onGameChanged);

    // Listen for goal box changes so scoring/grids refresh when Goals are added
    try {
      _goalBox = Hive.box<Goal>('goals');
      _goalListenable = _goalBox.listenable();
      _goalListenable.addListener(() {
        // simply reload the game from box to pick up any derived stats
        final updated = _gameBox.get(_game.id);
        if (updated == null) return;
        setState(() {
          _game = updated;
          _homeScore = _game.homeScore;
          _visitorScore = _game.visitorScore;
          _homeShots = _game.homeShots;
          _visitorShots = _game.visitorShots;
          _isFinal = _game.isFinal;
          _startingGoalie = _game.startingGoalie;
          _visitorTeamName = _game.opponent;
          _selectedDateTime = _game.dateTime;
          _selectedGameType = _game.gameType;
        });
      });
    } catch (_) {}
  }

  void _onGameChanged() {
    final updated = _gameBox.get(_game.id);
    if (updated == null) return;
    setState(() {
      _game = updated;
      _homeScore = _game.homeScore;
      _visitorScore = _game.visitorScore;
      _homeShots = _game.homeShots;
      _visitorShots = _game.visitorShots;
      _isFinal = _game.isFinal;
      _startingGoalie = _game.startingGoalie;
      _visitorTeamName = _game.opponent;
      _selectedDateTime = _game.dateTime;
      _selectedGameType = _game.gameType;
    });
  }

  void _saveGame() {
    _game.name = _nameController.text;
    _game.location = _locationController.text;
    _game.dateTime = _selectedDateTime;
    _game.gameType = _selectedGameType;
    _game.homeScore = _homeScore;
    _game.visitorScore = _visitorScore;
    _game.homeShots = _homeShots;
    _game.visitorShots = _visitorShots;
    _game.isFinal = _isFinal;
    _game.startingGoalie = _startingGoalie;
    _game.opponent = _visitorTeamName ?? '';
    _game.availablePlayerIds = _game.availablePlayerIds;
    _game.unavailablePlayerReasons = _game.unavailablePlayerReasons;
    _game.save();
  }

  @override
  void dispose() {
    try {
      _gameListenable.removeListener(_onGameChanged);
    } catch (_) {}
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  List<Player> _getGoalies() {
    final playerBox = Hive.box<Player>('players');
    return playerBox.values
        .where((p) => p.teamId == widget.team.id && p.position == 'Goalie')
        .toList();
  }

  void _showGoaliePicker() {
    final goalies = _getGoalies();

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return ListView.builder(
          itemCount: goalies.length,
          itemBuilder: (_, index) {
            final goalie = goalies[index];
            return ListTile(
              title: Text('${goalie.name} (#${goalie.number})'),
              // ignore: use_build_context_synchronously
              onTap: () {
                setState(() {
                  // store the player id as startingGoalie, but keep a readable name for UI
                  _startingGoalie = goalie.id;
                  _startingGoalieName = '${goalie.name} (#${goalie.number})';
                  _game.startingGoalie = _startingGoalie;
                });
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  void _showEditLineupModal() {
    final playerBox = Hive.box<Player>('players');
    final rosteredPlayers = playerBox.values
        .where((p) => p.teamId == widget.team.id)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: rosteredPlayers.map((player) {
              final isAvailable = _game.availablePlayerIds.contains(player.id);
              final reason = _game.unavailablePlayerReasons[player.id];

              return ListTile(
                title: Text('${player.name} (#${player.number})'),
                subtitle: reason != null ? Text('Unavailable: $reason') : null,
                trailing: isAvailable
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.cancel, color: Colors.red),
                onTap: () => _showAvailabilityOptions(player),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _exportGamePdf() async {
    // Check premium status
    if (!await PremiumService.canExportPDF()) {
      showUpgradeDialog(
        context,
        title: 'Premium Feature',
        message: 'PDF export is a premium feature. Upgrade to generate detailed game reports!',
        onUpgrade: () {
          // TODO: Navigate to purchase screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase screen coming soon!')),
          );
        },
      );
      return;
    }

    // collect a minimal stats table (player name -> stat string) as sample
    final stats = <Map<String, String>>[];
    try {
      final playerBox = Hive.box<Player>('players');
      for (final pid in _game.availablePlayerIds) {
        final p = playerBox.get(pid);
        if (p == null) continue;
        stats.add({'Player': p.name, 'Notes': ''});
      }
    } catch (_) {}

    Uint8List? heatmapBytes;
    try {
      if (_heatmapKey.currentContext != null) {
        final boundary =
            _heatmapKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        heatmapBytes = byteData?.buffer.asUint8List();
      }
    } catch (_) {}

    Uint8List? rinkBytes;
    try {
      if (_rinkKey.currentContext != null) {
        final boundary =
            _rinkKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final img = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        rinkBytes = byteData?.buffer.asUint8List();
      }
    } catch (_) {}

    final pdfBytes = await PdfExportService.buildGamePdf(
      game: _game,
      team: widget.team,
      rinkPng: rinkBytes,
      heatmapPng: heatmapBytes,
    );

    await PdfExportService.shareGamePdf(
      pdfBytes,
      filename: 'game_${_game.id}.pdf',
    );
  }

  void _showAvailabilityOptions(Player player) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Available'),
              onTap: () async {
                setState(() {
                  _game.availablePlayerIds.add(player.id);
                  _game.unavailablePlayerReasons.remove(player.id);
                });
                await _game.save();
                Navigator.pop(context);
              },
            ),
            ...['Unavailable', 'Injury', 'Suspension', 'Other'].map((reason) {
              return ListTile(
                title: Text(reason),
                onTap: () async {
                  setState(() {
                    _game.availablePlayerIds.remove(player.id);
                    _game.unavailablePlayerReasons[player.id] = reason;
                  });
                  await _game.save();
                  Navigator.pop(context);
                },
              );
            }),
          ],
        );
      },
    );
  }

  // Helper: gather normalized points for opponent shots faced by given goalie in this game
  List<Offset> _collectOpponentShotsForGoalie(String goalieId) {
    final shots = <Offset>[];
    try {
      for (final ev in _game.events ?? []) {
        if (ev.type == 'shot' || ev.type == 'goal') {
          // only opponent shots
          if (ev.teamId == _game.teamId) continue;
          // resolve goalie for this event
          String goalie = (ev.details['goalieId'] ?? '').toString();
          if (goalie.isEmpty && ev.details['onIce'] != null) {
            try {
              final onIce = Map<String, dynamic>.from(ev.details['onIce']);
              goalie = (onIce['G'] ?? '').toString();
            } catch (_) {}
          }
          if (goalie.isEmpty && (_game.startingGoalie ?? '').isNotEmpty) {
            goalie = _game.startingGoalie!;
          }
          if (goalie != goalieId) continue;
          final dxNorm = (ev.details['dxNorm'] as num?)?.toDouble();
          final dyNorm = (ev.details['dyNorm'] as num?)?.toDouble();
          if (dxNorm != null && dyNorm != null) {
            shots.add(Offset(dxNorm, dyNorm));
          }
        }
      }
    } catch (_) {}
    return shots;
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (!mounted || pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (!mounted || pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _saveGame();
    });
  }

  Color _getOpponentColor() {
    final opponentBox = Hive.box<Opponent>('opponents');
    final opponent = opponentBox.values.firstWhereOrNull(
      (o) => o.name == _visitorTeamName,
    );
    return opponent?.color ?? Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final isVisitor = _game.isUserTeamVisitor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _exportGamePdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Game Name (optional)',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ['League', 'Friendly', 'Tournament'].map((type) {
                return ChoiceChip(
                  label: Text(type),
                  selected: _selectedGameType == type,
                  onSelected: (_) {
                    setState(() => _selectedGameType = type);
                    _saveGame();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Date & Time'),
              subtitle: Text('${_selectedDateTime.toLocal()}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDateTime,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Make My Team the Visitor'),
              value: isVisitor,
              onChanged: (val) {
                setState(() {
                  _game.isUserTeamVisitor = val;
                  _saveGame();
                });
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        isVisitor ? 'VISITOR' : 'HOME',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: widget.team.primaryColor.withAlpha(
                            (0.1 * 255).round(),
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.team.primaryColor,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          widget.team.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: widget.team.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        isVisitor ? 'HOME' : 'VISITOR',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OpponentSelectionScreen(
                                onSelect: (selectedOpponent) {
                                  setState(() {
                                    _visitorTeamName = selectedOpponent.name;
                                    _game.opponent = selectedOpponent.name;
                                    _game.opponentTeamId =
                                        selectedOpponent.key; // ✅ correct
                                    _saveGame();
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _getOpponentColor().withAlpha(
                              (0.1 * 255).round(),
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getOpponentColor(),
                              width: 2,
                            ),
                          ),
                          child: Text(
                            _visitorTeamName ?? '➕ Select Opponent',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _getOpponentColor(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '$_homeScore',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Shots: $_homeShots'),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '$_visitorScore',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Shots: $_visitorShots'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Final Score'),
              value: _isFinal,
              onChanged: (val) {
                setState(() => _isFinal = val);
                _saveGame();
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Starting Goalie'),
              subtitle: Text(
                _startingGoalieName ?? _startingGoalie ?? 'Select Goalie',
              ),
              trailing: const Icon(Icons.person),
              onTap: _showGoaliePicker,
            ),
            const SizedBox(height: 8),
            // Heatmap controls: select goalie to view shots faced
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  const Text('View shots vs:'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedHeatmapGoalie,
                      hint: const Text('Select goalie'),
                      isExpanded: true,
                      items: _getGoalies().map((g) {
                        return DropdownMenuItem(
                          value: g.id,
                          child: Text('${g.name} (#${g.number})'),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedHeatmapGoalie = val),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedHeatmapGoalie != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shot heatmap for selected goalie (this game)'),
                    const SizedBox(height: 8),
                    // The rink asset is 800px high in GameRinkView; match that here
                    RepaintBoundary(
                      key: _heatmapKey,
                      child: ShotHeatmap(
                        width: MediaQuery.of(context).size.width - 16,
                        height: 800.0,
                        points: _collectOpponentShotsForGoalie(
                          _selectedHeatmapGoalie!,
                        ),
                        color: widget.team.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (widget.existingGame == null)
              Text(
                'No Game Stats Yet',
                style: Theme.of(context).textTheme.bodyLarge,
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScoringSummaryGrid(
                    game: _game, // ✅ must be the updated game object
                    team: widget.team,
                    accentColor: widget.team.primaryColor,
                  ),

                  ShotSummaryGrid(
                    game: _game,
                    team: widget.team,
                    accentColor: widget.team.primaryColor,
                  ),
                  SpecialTeamsGrid(
                    game: _game,
                    team: widget.team,
                    accentColor: widget.team.primaryColor,
                  ),
                  GamePlayerStatsGrid(
                    game: _game,
                    team: widget.team,
                    accentColor: widget.team.primaryColor,
                  ),
                  GameGoalieStatsGrid(
                    game: _game,
                    team: widget.team,
                    accentColor: widget.team.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  // Rink view showing persisted shots/goals for the game
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: RepaintBoundary(
                      key: _rinkKey,
                      child: SizedBox(
                        height: 900, // Provide bounded height for GameRinkView
                        child: GameRinkView(
                          game: _game,
                          width: MediaQuery.of(context).size.width - 32,
                          homeOnLeft: true,
                          teamColor: widget.team.primaryColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _showEditLineupModal,
                child: const Text('Edit Lineup'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveGameTrackerScreen(
                        game: _game,
                        team: widget.team,
                        startingGoalieId: _startingGoalie,
                      ),
                    ),
                  );
                },
                child: const Text('Live Game Tracker'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
