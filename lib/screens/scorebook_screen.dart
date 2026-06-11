import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';
import '../widgets/diamond_painter.dart';
import 'at_bat_entry.dart';
import 'box_score_screen.dart';
import 'runner_advancement.dart';
import 'base_running_event.dart';
import 'edit_pa_sheet.dart';
import 'edit_player_sheet.dart';
import 'game_info_sheet.dart';

class ScorebookScreen extends StatefulWidget {
  const ScorebookScreen({super.key});

  @override
  State<ScorebookScreen> createState() => _ScorebookScreenState();
}

class _ScorebookScreenState extends State<ScorebookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    // Sync tab to batting team on load
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTab());
  }

  /// Switches the tab to whichever team is currently batting.
  void _syncTab() {
    final game = context.read<GameProvider>().game;
    if (game == null) return;
    // Away bats top (isTop=true) → tab 0; Home bats bottom → tab 1
    final targetIndex = game.isTopOfInning ? 0 : 1;
    if (_tabs.index != targetIndex) {
      _tabs.animateTo(targetIndex);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _recordAtBat(BuildContext context) async {
    final provider = context.read<GameProvider>();
    final game = provider.game!;
    final batting = game.battingTeam;
    final slot = batting.currentBatter;
    final batter = slot.currentPlayer;
    final order = batting.currentBatterIndex + 1;

    final pa = await showAtBatEntry(
      context,
      inning: game.currentInning,
      topOfInning: game.isTopOfInning,
      batterName: batter.name,
      battingOrder: order,
      initialBalls: provider.balls,
      initialStrikes: provider.strikes,
    );

    if (pa == null || !context.mounted) return;

    // Capture inning state and batting team BEFORE recording (game object mutates)
    final wasAwayBatting = game.isTopOfInning;
    final inningBefore = game.currentInning;
    final battingTeamBefore = game.battingTeam;

    // Record the PA — get runners that were on base before this PA
    final runnersBeforePA = provider.recordPlateAppearance(pa);

    // Calculate auto RBIs: runners who score + batter if HR
    int autoRbis = pa.scored ? 1 : 0; // batter scores = HR = 1 RBI

    // Only ask about runner advancement if the inning is still going
    final inningEnded = provider.game == null ||
        provider.game!.isTopOfInning != wasAwayBatting ||
        provider.game!.currentInning != inningBefore;

    if (runnersBeforePA.isNotEmpty && !inningEnded && context.mounted) {
      final advancement = await showRunnerAdvancement(
        context,
        runners: runnersBeforePA,
        battingTeam: battingTeamBefore,
        batterResult: pa.displayText,
        batterPlayResult: pa.result,
      );

      if (advancement != null && context.mounted) {
        for (final entry in advancement.entries) {
          provider.advanceRunner(entry.key, entry.value);
          // Count each runner who scored
          if (entry.value >= 4) autoRbis++;
        }
      }
    }

    // Auto-apply RBIs based on who scored (SAC fly, errors don't always get RBI —
    // for now we set it and let the scorekeeper override via edit if needed)
    if (autoRbis > 0 && context.mounted) {
      provider.updatePARbis(pa.id, autoRbis, wasAwayBatting: wasAwayBatting);
    }

    // If the inning flipped (3 outs recorded), auto-switch to batting team's tab
    if (context.mounted) _syncTab();
  }

  Future<bool> _onWillPop() async {
    // Ensure game is saved before navigating away
    await context.read<GameProvider>().saveNow();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final game = provider.game;
    if (game == null) return const SizedBox();

    final isTop = game.isTopOfInning;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await context.read<GameProvider>().saveNow();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2137),
        foregroundColor: Colors.white,
        title: _ScoreHeader(game: game),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Game Details',
            onPressed: () async {
              final provider = context.read<GameProvider>();
              final result = await showGameInfoSheet(
                context,
                current: provider.game!.info,
              );
              if (result != null && context.mounted) {
                provider.updateGameInfo(result);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Box Score',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BoxScoreScreen()),
            ),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF0D2137),
            onSelected: (v) {
              if (v == 'end_half') {
                provider.endHalfInning();
                _syncTab();
              } else if (v == 'end_game') {
                _confirmEndGame(context, provider);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'end_half',
                child: Text('End Half-Inning',
                    style: TextStyle(color: Colors.white)),
              ),
              const PopupMenuItem(
                value: 'end_game',
                child: Text('End Game',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          indicatorColor:
              isTop ? Colors.lightBlueAccent : Colors.greenAccent,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isTop)
                    const Icon(Icons.arrow_right,
                        color: Colors.lightBlueAccent, size: 18),
                  Text(game.awayTeam!.name),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isTop)
                    const Icon(Icons.arrow_right,
                        color: Colors.greenAccent, size: 18),
                  Text(game.homeTeam!.name),
                ],
              ),
            ),
          ],
        ),
      ),

      // Status bar
      body: Column(
        children: [
          _GameStatusBar(game: game),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ScorebookGrid(
                          team: game.awayTeam!,
                          game: game,
                          isBatting: isTop,
                          onEditPA: (pa, name, inning, isHome) =>
                              _editPA(context, pa: pa, playerName: name, inning: inning, isHomeTeam: isHome),
                          onAddPA: (name, slot, inning, isHome) =>
                              _addPA(context, playerName: name, slotIndex: slot, inning: inning, isHomeTeam: isHome, isTopOfInning: true),
                          onEditPlayer: (player, idx, isHome, order) =>
                              _editPlayer(context, player: player, lineupIndex: idx, isHomeTeam: isHome, battingOrder: order)),
                      _ScorebookGrid(
                          team: game.homeTeam!,
                          game: game,
                          isBatting: !isTop,
                          onEditPA: (pa, name, inning, isHome) =>
                              _editPA(context, pa: pa, playerName: name, inning: inning, isHomeTeam: isHome),
                          onAddPA: (name, slot, inning, isHome) =>
                              _addPA(context, playerName: name, slotIndex: slot, inning: inning, isHomeTeam: isHome, isTopOfInning: false),
                          onEditPlayer: (player, idx, isHome, order) =>
                              _editPlayer(context, player: player, lineupIndex: idx, isHomeTeam: isHome, battingOrder: order)),
                    ],
                  ),
                ),
                _PitchingSection(game: game),
              ],
            ),
          ),
        ],
      ),

      floatingActionButton: game.status == GameStatus.inProgress
          ? Padding(
              padding: const EdgeInsets.only(bottom: 130),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Base running event button
                  FloatingActionButton.extended(
                    heroTag: 'base_running',
                    onPressed: () => _recordBaseRunningEvent(context),
                    backgroundColor: const Color(0xFF5D4037),
                    icon: const Icon(Icons.directions_run, color: Colors.white),
                    label: const Text('Base Running',
                        style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  // Record PA button
                  FloatingActionButton.extended(
                    heroTag: 'record_pa',
                    onPressed: () => _recordAtBat(context),
                    backgroundColor: const Color(0xFF2E7D32),
                    icon: const Icon(Icons.sports_baseball, color: Colors.white),
                    label: Text(
                      'Record PA — ${game.battingTeam.currentBatter.currentPlayer.name}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : null,
      ),
    );
  }

  Future<void> _editPlayer(
    BuildContext context, {
    required Player player,
    required int lineupIndex,
    required bool isHomeTeam,
    required int battingOrder,
  }) async {
    final provider = context.read<GameProvider>();
    final result = await showEditPlayer(
      context,
      player: player,
      lineupIndex: lineupIndex,
      isHomeTeam: isHomeTeam,
      battingOrder: battingOrder,
    );
    if (result != null && context.mounted) {
      provider.editPlayer(
        isHomeTeam: result.isHomeTeam,
        lineupIndex: result.lineupIndex,
        name: result.name,
        jerseyNumber: result.jerseyNumber,
        position: result.position,
      );
    }
  }

  /// Re-record a PA for a cell that was deleted (slot/inning already known).
  Future<void> _addPA(
    BuildContext context, {
    required String playerName,
    required int slotIndex,
    required int inning,
    required bool isHomeTeam,
    required bool isTopOfInning,
  }) async {
    final provider = context.read<GameProvider>();
    final game = provider.game!;

    final pa = await showAtBatEntry(
      context,
      inning: inning,
      topOfInning: isTopOfInning,
      batterName: playerName,
      battingOrder: slotIndex + 1,
    );
    if (pa == null || !context.mounted) return;

    final wasAwayBatting = game.isTopOfInning;
    final inningBefore = game.currentInning;
    final battingTeamBefore = game.battingTeam;
    final runnersBeforePA = provider.addPlateAppearanceToSlot(
      pa,
      isHomeTeam: isHomeTeam,
      slotIndex: slotIndex,
    );

    // Handle runner advancement (same as normal PA flow)
    int autoRbis = pa.scored ? 1 : 0;
    final inningEnded = provider.game == null ||
        provider.game!.isTopOfInning != wasAwayBatting ||
        provider.game!.currentInning != inningBefore;

    if (runnersBeforePA.isNotEmpty && !inningEnded && context.mounted) {
      final advancement = await showRunnerAdvancement(
        context,
        runners: runnersBeforePA,
        battingTeam: battingTeamBefore,
        batterResult: pa.displayText,
        batterPlayResult: pa.result,
      );
      if (advancement != null && context.mounted) {
        for (final entry in advancement.entries) {
          provider.advanceRunner(entry.key, entry.value);
          if (entry.value >= 4) autoRbis++;
        }
      }
    }

    if (autoRbis > 0 && context.mounted) {
      provider.updatePARbis(pa.id, autoRbis, wasAwayBatting: wasAwayBatting);
    }

    // If batter reached safely but we're still at 2 outs (e.g. FC, error, K+),
    // the 3rd out must have come from a runner — ask and end the inning if so.
    final stillTwoOuts = provider.game?.outs == 2 &&
        provider.game?.isTopOfInning == game.isTopOfInning;
    final couldHaveRunnerOut = pa.reachedFirst && const {
      PlayResult.fieldersChoice,
      PlayResult.error,
      PlayResult.droppedThirdStrike,
    }.contains(pa.result);

    if (stillTwoOuts && couldHaveRunnerOut && context.mounted) {
      final endInning = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF0D2137),
          title: const Text('3rd Out?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Was a runner put out on this play to end the inning?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes — End Inning',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if ((endInning ?? false) && context.mounted) {
        provider.endHalfInning();
      }
    }

    // Auto-flip tab if inning changed
    if (context.mounted) _syncTab();
  }

  Future<void> _editPA(
    BuildContext context, {
    required PlateAppearance pa,
    required String playerName,
    required int inning,
    required bool isHomeTeam,
  }) async {
    final provider = context.read<GameProvider>();
    final result = await showEditPA(
      context,
      pa: pa,
      playerName: playerName,
      inning: inning,
    );
    if (result != null && context.mounted) {
      if (result.deleted) {
        provider.deletePlateAppearance(result.paId, isHomeTeam: isHomeTeam);
      } else {
        provider.editPlateAppearance(result, isHomeTeam: isHomeTeam);
      }
    }
  }

  Future<void> _recordBaseRunningEvent(BuildContext context) async {
    final provider = context.read<GameProvider>();
    final game = provider.game!;

    final result = await showBaseRunningEvent(
      context,
      runners: provider.runners,
      battingTeam: game.battingTeam,
    );

    if (result != null && context.mounted) {
      provider.recordBaseRunningEvent(result);
    }
  }

  void _confirmEndGame(BuildContext context, GameProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2137),
        title: const Text('End Game?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Mark this game as complete.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.pop(context);
              provider.endGame();
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BoxScoreScreen()),
              );
            },
            child: const Text('End Game',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score header in AppBar
// ---------------------------------------------------------------------------

class _ScoreHeader extends StatelessWidget {
  final Game game;
  const _ScoreHeader({required this.game});

  void _editTeamName(BuildContext context, bool isHomeTeam) {
    final current = isHomeTeam ? game.homeTeamName : game.awayTeamName;
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2137),
        title: Text('Rename ${isHomeTeam ? "Home" : "Away"} Team',
            style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Team name',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF152030),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.lightBlueAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0)),
            onPressed: () {
              context.read<GameProvider>().renameTeam(
                    isHomeTeam: isHomeTeam,
                    name: ctrl.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _editTeamName(context, false),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: Text(
              game.awayTeam!.name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF152030),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${game.awayScore} — ${game.homeScore}',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => _editTeamName(context, true),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: Text(
              game.homeTeam!.name,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Game status bar (inning, outs)
// ---------------------------------------------------------------------------

class _GameStatusBar extends StatelessWidget {
  final Game game;
  const _GameStatusBar({required this.game});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();

    return Container(
      color: const Color(0xFF0D2137),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Inning
          Text(
            '${game.currentHalfLabel} ${game.currentInning}',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(width: 10),
          // Batter info
          Expanded(
            child: Text(
              'Up: ${game.battingTeam.currentBatter.currentPlayer.name}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Base runners diamond
          _BaseDiamond(runners: provider.runners),
          const SizedBox(width: 10),
          // Outs
          Row(
            children: [
              const Text('O:',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 4),
              ...List.generate(3, (i) => _CountDot(
                filled: i < game.outs,
                fillColor: Colors.red.shade400,
                borderColor: Colors.red.shade700,
              )),
            ],
          ),
          const SizedBox(width: 10),
          // Balls, Strikes, Foul — tappable
          Row(
            children: [
              // Balls
              const Text('B:',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 3),
              ...List.generate(3, (i) => GestureDetector(
                onTap: () => provider.addBall(),
                child: _CountBox(
                  filled: i < provider.balls,
                  fillColor: Colors.green.shade500,
                  borderColor: Colors.green.shade800,
                ),
              )),
              const SizedBox(width: 6),
              // Strikes
              const Text('S:',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(width: 3),
              ...List.generate(2, (i) => GestureDetector(
                onTap: () => provider.addStrike(),
                child: _CountBox(
                  filled: i < provider.strikes,
                  fillColor: Colors.red.shade400,
                  borderColor: Colors.red.shade800,
                ),
              )),
              const SizedBox(width: 6),
              // Foul button
              GestureDetector(
                onTap: () => provider.addFoul(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: provider.fouls > 0
                        ? Colors.orange.shade700
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: provider.fouls > 0
                          ? Colors.orange.shade500
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    provider.fouls > 0 ? 'F${provider.fouls}' : 'F',
                    style: TextStyle(
                      color: provider.fouls > 0
                          ? Colors.white
                          : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Reset count
              GestureDetector(
                onTap: () => provider.resetCount(),
                child: const Icon(Icons.refresh,
                    color: Colors.white24, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBox extends StatelessWidget {
  final bool filled;
  final Color fillColor;
  final Color borderColor;

  const _CountBox({
    required this.filled,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        color: filled ? fillColor : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: filled ? fillColor : Colors.white24,
          width: 1.5,
        ),
      ),
    );
  }
}

class _CountDot extends StatelessWidget {
  final bool filled;
  final Color fillColor;
  final Color borderColor;

  const _CountDot({
    required this.filled,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? fillColor : Colors.white12,
        border: Border.all(
          color: filled ? borderColor : Colors.white24,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The scorebook grid
// ---------------------------------------------------------------------------

class _ScorebookGrid extends StatelessWidget {
  final TeamGame team;
  final Game game;
  final bool isBatting;
  final void Function(PlateAppearance pa, String playerName, int inning, bool isHomeTeam) onEditPA;
  final void Function(String playerName, int slotIndex, int inning, bool isHomeTeam) onAddPA;
  final void Function(Player player, int lineupIndex, bool isHomeTeam, int battingOrder) onEditPlayer;

  const _ScorebookGrid({
    required this.team,
    required this.game,
    required this.isBatting,
    required this.onEditPA,
    required this.onAddPA,
    required this.onEditPlayer,
  });

  static const double _cellSize = 64;
  static const double _nameColWidth = 105;
  static const double _statColWidth = 36;
  static const double _totalsHeight = 32;

  @override
  Widget build(BuildContext context) {
    final innings = game.totalInnings;
    final runsByInning = team.runsByInning;

    // Build frozen left column rows and scrollable right column rows in sync.
    final leftHeaderRow = Row(children: [
      _HeaderCell('#', width: 28),
      _HeaderCell('Player', width: _nameColWidth, align: TextAlign.left),
      _HeaderCell('Pos', width: 36),
    ]);

    final rightHeaderRow = Row(children: [
      ...List.generate(innings, (i) => _HeaderCell('${i + 1}', width: _cellSize)),
      _HeaderCell('R', width: _statColWidth),
      _HeaderCell('H', width: _statColWidth),
      _HeaderCell('RBI', width: _statColWidth),
    ]);

    final leftRows = <Widget>[];
    final rightRows = <Widget>[];

    for (int idx = 0; idx < team.lineup.length; idx++) {
      final slot = team.lineup[idx];
      final player = slot.currentPlayer;
      final isCurrentBatter = isBatting && team.currentBatterIndex == idx;
      final rowColor = isCurrentBatter
          ? Colors.amber.withValues(alpha: 0.07)
          : idx.isEven
              ? Colors.white.withValues(alpha: 0.02)
              : Colors.transparent;

      // Left: order + name + position
      leftRows.add(Container(
        color: rowColor,
        child: Row(children: [
          SizedBox(
            width: 28,
            height: _cellSize,
            child: Center(
              child: Text('${idx + 1}',
                  style: TextStyle(
                      color: isCurrentBatter ? Colors.amber.shade300 : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          GestureDetector(
            onTap: () => onEditPlayer(player, idx, team == game.homeTeam, idx + 1),
            child: SizedBox(
              width: _nameColWidth,
              height: _cellSize,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: TextStyle(
                        color: isCurrentBatter ? Colors.amber.shade200 : Colors.white,
                        fontSize: 13,
                        fontWeight: isCurrentBatter ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (player.jerseyNumber > 0)
                      Text('#${player.jerseyNumber}',
                          style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 36,
            height: _cellSize,
            child: Center(
              child: Text(
                fieldPositionLabel(player.position),
                style: const TextStyle(
                    color: Colors.lightBlueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ]),
      ));

      // Right: inning cells + stats
      rightRows.add(Container(
        color: rowColor,
        child: Row(children: [
          ...List.generate(innings, (inn) {
            final pa = slot.plateAppearances
                .where((pa) => pa.inning == inn + 1)
                .firstOrNull;
            final isCurrent = isCurrentBatter &&
                pa == null &&
                inn + 1 == game.currentInning;
            return DiamondCell(
              size: _cellSize,
              pa: pa,
              isCurrent: isCurrent,
              onTap: pa != null
                  ? () => onEditPA(pa, slot.currentPlayer.name, inn + 1, team == game.homeTeam)
                  : !isCurrent
                      ? () => onAddPA(slot.currentPlayer.name, idx, inn + 1, team == game.homeTeam)
                      : null,
            );
          }),
          _StatCell(slot.runs, _statColWidth, Colors.greenAccent),
          _StatCell(slot.hits, _statColWidth, Colors.white),
          _StatCell(slot.rbis, _statColWidth, Colors.yellowAccent),
        ]),
      ));
    }

    // Totals row
    final leftTotals = Container(
      color: const Color(0xFF0D2137),
      child: SizedBox(
        width: 28 + _nameColWidth + 36,
        height: 32,
        child: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Runs', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );

    final rightTotals = Container(
      color: const Color(0xFF0D2137),
      child: Row(children: [
        ...List.generate(innings, (i) {
          final r = runsByInning[i + 1] ?? 0;
          return SizedBox(
            width: _cellSize,
            height: 32,
            child: Center(
              child: Text(
                r > 0 ? '$r' : '-',
                style: TextStyle(
                  color: r > 0 ? Colors.greenAccent : Colors.white24,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
        _StatCell(team.totalRuns, _statColWidth, Colors.greenAccent, height: _totalsHeight),
        _StatCell(team.totalHits, _statColWidth, Colors.white, height: _totalsHeight),
        _StatCell(team.totalRbis, _statColWidth, Colors.yellowAccent, height: _totalsHeight),
      ]),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Frozen left column ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white24, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftHeaderRow,
                const Divider(color: Colors.white12, height: 1),
                ...leftRows,
                const Divider(color: Colors.white24, height: 1),
                leftTotals,
                const SizedBox(height: 200),
              ],
            ),
          ),
          // ── Scrollable right section ─────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  rightHeaderRow,
                  const Divider(color: Colors.white12, height: 1),
                  ...rightRows,
                  const Divider(color: Colors.white24, height: 1),
                  rightTotals,
                  const SizedBox(height: 200),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  final TextAlign align;

  const _HeaderCell(this.text,
      {required this.width, this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          alignment: align == TextAlign.left
              ? Alignment.centerLeft
              : Alignment.center,
          child: Text(
            text,
            textAlign: align,
            style: const TextStyle(
                color: Color(0xFF90CAF9),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final int value;
  final double width;
  final Color color;
  final double height;

  const _StatCell(this.value, this.width, this.color, {this.height = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
              color: value > 0 ? color : Colors.white24,
              fontSize: 14,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live base runner diamond
// ---------------------------------------------------------------------------

class _BaseDiamond extends StatelessWidget {
  final List<BaseRunner> runners;
  const _BaseDiamond({required this.runners});

  @override
  Widget build(BuildContext context) {
    final occupied = runners.map((r) => r.currentBase).toSet();
    return SizedBox(
      width: 34,
      height: 34,
      child: CustomPaint(painter: _BaseDiamondPainter(occupied: occupied)),
    );
  }
}

class _BaseDiamondPainter extends CustomPainter {
  final Set<int> occupied;
  const _BaseDiamondPainter({required this.occupied});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.38;

    final home   = Offset(cx,      cy + r);
    final first  = Offset(cx + r,  cy);
    final second = Offset(cx,      cy - r);
    final third  = Offset(cx - r,  cy);

    // Outline
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(home, first, outlinePaint);
    canvas.drawLine(first, second, outlinePaint);
    canvas.drawLine(second, third, outlinePaint);
    canvas.drawLine(third, home, outlinePaint);

    // Draw each base square — yellow if occupied, dim if empty
    _drawBase(canvas, first,  occupied.contains(1));
    _drawBase(canvas, second, occupied.contains(2));
    _drawBase(canvas, third,  occupied.contains(3));

    // Home plate (always dim — batter not a runner yet)
    _drawBase(canvas, home, false, isHome: true);
  }

  void _drawBase(Canvas canvas, Offset pos, bool on, {bool isHome = false}) {
    const s = 4.5;
    final path = Path()
      ..moveTo(pos.dx,     pos.dy - s)
      ..lineTo(pos.dx + s, pos.dy)
      ..lineTo(pos.dx,     pos.dy + s)
      ..lineTo(pos.dx - s, pos.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = on
            ? Colors.yellow.shade400
            : Colors.white.withValues(alpha: isHome ? 0.15 : 0.12)
        ..style = PaintingStyle.fill,
    );
    if (on) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.yellow.shade200
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  @override
  bool shouldRepaint(_BaseDiamondPainter old) => old.occupied != occupied;
}

// ---------------------------------------------------------------------------
// Pitching Section
// ---------------------------------------------------------------------------

class _PitchingSection extends StatelessWidget {
  final Game game;
  const _PitchingSection({required this.game});

  // Compute stats for one pitching appearance given the opposing batting team
  // and whether this pitcher pitches in the top half (isTopHalf = true for home pitchers).
  Map<String, int> _stats(PitchingAppearance pa, int endInning,
      TeamGame battingTeam, bool isTopHalf) {
    int h = 0, r = 0, er = 0, bb = 0, k = 0, balls = 0, strikes = 0, outs = 0;
    for (final slot in battingTeam.lineup) {
      for (final bpa in slot.plateAppearances) {
        if (bpa.topOfInning != isTopHalf) continue;
        if (bpa.inning < pa.startInning || bpa.inning >= endInning) continue;
        if (bpa.isHit) h++;
        if (bpa.scored) r++;
        if (bpa.scored && bpa.earnedRun) er++;
        if ({PlayResult.walk, PlayResult.intentionalWalk, PlayResult.hitByPitch}
            .contains(bpa.result)) bb++;
        if ({PlayResult.strikeoutSwinging, PlayResult.strikeoutLooking}
            .contains(bpa.result)) k++;
        balls += bpa.pitchBalls;
        strikes += bpa.pitchStrikes;
        outs += bpa.outsRecorded;
      }
    }
    return {
      'h': h, 'r': r, 'er': er, 'bb': bb, 'k': k,
      'balls': balls, 'strikes': strikes, 'outs': outs,
    };
  }

  String _ip(int outs) => '${outs ~/ 3}.${outs % 3}';

  @override
  Widget build(BuildContext context) {
    final home = game.homeTeam!;
    final away = game.awayTeam!;
    // Home pitchers face away batters in TOP halves; away pitchers face home batters in BOTTOM halves
    final homePitchers = home.pitchingLog;
    final awayPitchers = away.pitchingLog;

    if (homePitchers.isEmpty && awayPitchers.isEmpty) {
      return _emptyState(context);
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
            child: Row(
              children: [
                const Text('PITCHING',
                    style: TextStyle(
                        color: Color(0xFF90CAF9),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showChangePitcherSheet(context),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Change Pitcher', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE8A87C),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const SizedBox(width: 24), // jersey
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()), // name
                for (final col in ['IP', 'H', 'R', 'ER', 'BB', 'K', 'B-S'])
                  SizedBox(
                    width: col == 'B-S' ? 46 : 28,
                    child: Text(col,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // Rows
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (awayPitchers.isNotEmpty) ...[
                  _teamLabel(away.name),
                  ...List.generate(awayPitchers.length, (i) {
                    final pa = awayPitchers[i];
                    final endInning = i + 1 < awayPitchers.length
                        ? awayPitchers[i + 1].startInning
                        : 999;
                    final s = _stats(pa, endInning, home, false);
                    return _PitcherRow(pa: pa, stats: s, ipStr: _ip(s['outs']!));
                  }),
                ],
                if (homePitchers.isNotEmpty) ...[
                  _teamLabel(home.name),
                  ...List.generate(homePitchers.length, (i) {
                    final pa = homePitchers[i];
                    final endInning = i + 1 < homePitchers.length
                        ? homePitchers[i + 1].startInning
                        : 999;
                    final s = _stats(pa, endInning, away, true);
                    return _PitcherRow(pa: pa, stats: s, ipStr: _ip(s['outs']!));
                  }),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('PITCHING',
              style: TextStyle(
                  color: Color(0xFF90CAF9),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(width: 12),
          const Text('No pitchers recorded',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _showChangePitcherSheet(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Pitcher', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE8A87C),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamLabel(String name) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 0, 2),
        child: Text(name,
            style: const TextStyle(
                color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
      );

  void _showChangePitcherSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePitcherSheet(game: game),
    );
  }
}

class _PitcherRow extends StatelessWidget {
  final PitchingAppearance pa;
  final Map<String, int> stats;
  final String ipStr;
  const _PitcherRow({required this.pa, required this.stats, required this.ipStr});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              pa.jerseyNumber > 0 ? '#${pa.jerseyNumber}' : '',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(pa.pitcherName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          for (final entry in [
            ('IP', ipStr),
            ('H', '${stats['h']}'),
            ('R', '${stats['r']}'),
            ('ER', '${stats['er']}'),
            ('BB', '${stats['bb']}'),
            ('K', '${stats['k']}'),
            ('B-S', '${stats['balls']}-${stats['strikes']}'),
          ])
            SizedBox(
              width: entry.$1 == 'B-S' ? 46 : 28,
              child: Text(entry.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: entry.$1 == 'IP'
                          ? Colors.white70
                          : entry.$1 == 'K'
                              ? Colors.greenAccent.shade400
                              : entry.$1 == 'R' || entry.$1 == 'ER'
                                  ? Colors.red.shade300
                                  : Colors.white54,
                      fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _ChangePitcherSheet extends StatefulWidget {
  final Game game;
  const _ChangePitcherSheet({required this.game});

  @override
  State<_ChangePitcherSheet> createState() => _ChangePitcherSheetState();
}

class _ChangePitcherSheetState extends State<_ChangePitcherSheet> {
  bool _isHomeTeam = true;
  final _nameCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  late int _inning;

  @override
  void initState() {
    super.initState();
    _inning = widget.game.currentInning;
    _isHomeTeam = !widget.game.isTopOfInning; // home pitches in top, away in bottom
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D2137),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Pitching Change',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            // Team toggle
            Row(
              children: [
                Expanded(
                  child: _TeamToggle(
                    label: widget.game.awayTeam!.name,
                    selected: !_isHomeTeam,
                    onTap: () => setState(() => _isHomeTeam = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TeamToggle(
                    label: widget.game.homeTeam!.name,
                    selected: _isHomeTeam,
                    onTap: () => setState(() => _isHomeTeam = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Name + number
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _numCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '#',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF152030),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Pitcher name',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF152030),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Inning
            Row(
              children: [
                const Text('Entering inning:',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const Spacer(),
                IconButton(
                  onPressed: _inning > 1 ? () => setState(() => _inning--) : null,
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.white54),
                ),
                Text('$_inning',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => setState(() => _inning++),
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nameCtrl.text.trim().isEmpty ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm Pitching Change',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    context.read<GameProvider>().addPitcherChange(
      name: name,
      jersey: int.tryParse(_numCtrl.text.trim()) ?? 0,
      isHomeTeam: _isHomeTeam,
      startInning: _inning,
    );
    Navigator.pop(context);
  }
}

class _TeamToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TeamToggle({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1565C0) : const Color(0xFF152030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? Colors.lightBlueAccent : Colors.white24),
        ),
        alignment: Alignment.center,
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: selected ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

