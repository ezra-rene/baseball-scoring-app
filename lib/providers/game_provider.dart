import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../screens/base_running_event.dart';
import '../screens/edit_pa_sheet.dart';
import '../services/game_storage.dart';

class GameProvider extends ChangeNotifier {
  Game? _game;
  final List<BaseRunner> _runners = [];
  int _balls = 0;
  int _strikes = 0;

  Game? get game => _game;
  bool get hasGame => _game != null && _game!.status != GameStatus.setup;
  List<BaseRunner> get runners => List.unmodifiable(_runners);
  int get balls => _balls;
  int get strikes => _strikes;

  // Foul pitch count (tracked separately for pitch sequencing)
  int _fouls = 0;
  int get fouls => _fouls;

  void addBall() {
    if (_balls < 3) { _balls++; notifyListeners(); }
  }

  void addStrike() {
    if (_strikes < 2) { _strikes++; notifyListeners(); }
  }

  /// Foul ball — always counts as a pitch, only a strike if count < 2
  void addFoul() {
    _fouls++;
    if (_strikes < 2) _strikes++;
    notifyListeners();
  }

  void resetCount() {
    _balls = 0;
    _strikes = 0;
    _fouls = 0;
    notifyListeners();
  }

  Future<void> _autoSave() async {
    if (_game != null) {
      try {
        await GameStorage.saveGame(_game!,
            runners: _runners, balls: _balls, strikes: _strikes);
      } catch (e) {
        debugPrint('AutoSave error: $e');
      }
    }
  }

  /// Explicit save — call this before navigating away.
  Future<void> saveNow() => _autoSave();

  /// Load a previously saved game by ID.
  Future<bool> loadGame(String id) async {
    final data = await GameStorage.loadGameData(id);
    if (data == null) return false;
    _game = data['game'] as Game;
    _runners
      ..clear()
      ..addAll(data['runners'] as List<BaseRunner>);
    _balls = data['balls'] as int;
    _strikes = data['strikes'] as int;
    notifyListeners();
    return true;
  }

  Future<void> deleteSavedGame(String id) async {
    await GameStorage.deleteGame(id);
    if (_game?.id == id) {
      _game = null;
      _runners.clear();
      _balls = 0;
      _strikes = 0;
      notifyListeners();
    }
  }

  void startGame({
    required String homeTeamName,
    required String awayTeamName,
    required List<Player> homeLineup,
    required List<Player> awayLineup,
    GameInfo? gameInfo,
  }) {
    _game = Game(
        homeTeamName: homeTeamName,
        awayTeamName: awayTeamName,
        info: gameInfo ?? GameInfo())
      ..homeTeam = TeamGame(name: homeTeamName, players: homeLineup)
      ..awayTeam = TeamGame(name: awayTeamName, players: awayLineup)
      ..status = GameStatus.inProgress;
    _runners.clear();
    _autoSave();
    notifyListeners();
  }

  /// Record a plate appearance for the current batter.
  /// Returns the list of runners that were on base BEFORE this PA
  /// (so the UI can prompt for their advancement).
  List<BaseRunner> recordPlateAppearance(PlateAppearance pa) {
    if (_game == null) return [];
    final batting = _game!.battingTeam;
    final slotIndex = batting.currentBatterIndex;
    final slot = batting.currentBatter;

    // Stamp current ball/strike count onto the PA before resetting
    final stampedPA = pa.copyWith(
      pitchBalls: _balls,
      pitchStrikes: _strikes,
    );

    // Reset count for next batter
    _balls = 0;
    _strikes = 0;
    _fouls = 0;

    // Snapshot runners before this PA for the advancement dialog
    final runnersBeforePA = List<BaseRunner>.from(_runners);

    // Add PA to batter's slot (use stamped version)
    slot.plateAppearances.add(stampedPA);

    // Advance batter in lineup
    batting.advanceBatter();

    // Track outs
    _game!.outs += pa.outsRecorded;

    // Add this batter as a runner if they reached base and didn't already score (HR)
    if (pa.reachedFirst && !pa.scored) {
      final startBase = pa.reachedThird ? 3 : pa.reachedSecond ? 2 : 1;
      _runners.add(BaseRunner(
        lineupSlotIndex: slotIndex,
        paId: pa.id,
        startBase: startBase,
      ));
    }

    // If 3 outs, clear runners and advance inning
    if (_game!.outs >= 3) {
      _runners.clear();
      _endHalfInning();
    }

    _autoSave();
    notifyListeners();
    return runnersBeforePA;
  }

  /// Update a runner's advancement after a PA.
  /// [paId] identifies the runner's original PA.
  /// [newBase] is 1/2/3 if still on base, 4 = scored, 0 = out on base paths.
  void advanceRunner(String paId, int newBase) {
    if (_game == null) return;
    final batting = _game!.battingTeam;

    // Find and update the PA in the lineup
    for (final slot in batting.lineup) {
      final idx = slot.plateAppearances.indexWhere((pa) => pa.id == paId);
      if (idx != -1) {
        final old = slot.plateAppearances[idx];
        slot.plateAppearances[idx] = old.copyWith(
          reachedFirst: newBase >= 1,
          reachedSecond: newBase >= 2,
          reachedThird: newBase >= 3,
          scored: newBase >= 4,
        );
        break;
      }
    }

    // Update or remove from runners list
    if (newBase >= 4 || newBase == 0) {
      // Only count an out if this runner was still active (i.e. the inning
      // wasn't already ended by the PA itself, which clears _runners first).
      final wasStillOnBase = _runners.any((r) => r.paId == paId);
      _runners.removeWhere((r) => r.paId == paId);
      if (newBase == 0 && wasStillOnBase) {
        _game!.outs++;
        if (_game!.outs >= 3) {
          _runners.clear();
          _endHalfInning();
        }
      }
    } else {
      final runner = _runners.firstWhere((r) => r.paId == paId,
          orElse: () => BaseRunner(lineupSlotIndex: -1, paId: paId, startBase: 1));
      runner.currentBase = newBase;
    }

    _autoSave();
    notifyListeners();
  }

  void _endHalfInning() {
    _game!.outs = 0;
    if (_game!.isTopOfInning) {
      _game!.isTopOfInning = false;
    } else {
      _game!.currentInning++;
      _game!.isTopOfInning = true;
    }
  }

  void endHalfInning() {
    if (_game == null) return;
    _runners.clear();
    _endHalfInning();
    _autoSave();
    notifyListeners();
  }

  void endGame() {
    if (_game == null) return;
    _game!.status = GameStatus.complete;
    _autoSave();
    notifyListeners();
  }

  /// Record a base running event (SB, WP, PB, BK, CS, PO, etc.)
  void recordBaseRunningEvent(BaseRunningResult event) {
    if (_game == null) return;
    final batting = _game!.battingTeam;

    // Update the runner's PA with their new base position + notation
    for (final slot in batting.lineup) {
      final idx =
          slot.plateAppearances.indexWhere((pa) => pa.id == event.paId);
      if (idx != -1) {
        final old = slot.plateAppearances[idx];
        // If the same base notation already exists, increment its count
        // e.g. POA + POA → POA2, SB + SB → SB2
        final updatedEvents = List<String>.from(old.baseEvents);
        final base = event.notation.replaceAll(RegExp(r'\d+$'), '');
        final existingIdx = updatedEvents.indexWhere(
            (e) => e.replaceAll(RegExp(r'\d+$'), '') == base);
        if (existingIdx != -1) {
          final existing = updatedEvents[existingIdx];
          final currentCount =
              int.tryParse(existing.replaceAll(RegExp(r'^[A-Za-z]+'), '')) ?? 1;
          updatedEvents[existingIdx] = '$base${currentCount + 1}';
        } else {
          updatedEvents.add(event.notation);
        }
        slot.plateAppearances[idx] = old.copyWith(
          reachedFirst: event.newBase >= 1,
          reachedSecond: event.newBase >= 2,
          reachedThird: event.newBase >= 3,
          scored: event.newBase >= 4,
          baseEvents: updatedEvents,
        );
        break;
      }
    }

    // Handle outs (CS, PO)
    final isOut = event.newBase == 0;
    if (isOut) {
      _runners.removeWhere((r) => r.paId == event.paId);
      _game!.outs++;
      if (_game!.outs >= 3) {
        _runners.clear();
        _endHalfInning();
      }
    } else if (event.newBase >= 4) {
      // Scored — remove from runners
      _runners.removeWhere((r) => r.paId == event.paId);
    } else {
      // Advanced to a new base — update runner position
      final runner = _runners.firstWhere(
        (r) => r.paId == event.paId,
        orElse: () => BaseRunner(
            lineupSlotIndex: event.lineupSlotIndex,
            paId: event.paId,
            startBase: event.newBase),
      );
      runner.currentBase = event.newBase;
    }

    _autoSave();
    notifyListeners();
  }

  /// Auto-update RBIs on a PA after runner advancement is confirmed.
  void updatePARbis(String paId, int rbis, {required bool wasAwayBatting}) {
    if (_game == null) return;
    final team = wasAwayBatting ? _game!.awayTeam! : _game!.homeTeam!;
    for (final slot in team.lineup) {
      final idx = slot.plateAppearances.indexWhere((pa) => pa.id == paId);
      if (idx != -1) {
        slot.plateAppearances[idx] =
            slot.plateAppearances[idx].copyWith(rbis: rbis);
        break;
      }
    }
    _autoSave();
    notifyListeners();
  }

  /// Re-record a PA for a specific lineup slot (after a delete).
  /// Counts outs and ends the half-inning if 3 outs are reached.
  /// Returns runners that were on base before this PA (for advancement dialog).
  List<BaseRunner> addPlateAppearanceToSlot(
    PlateAppearance pa, {
    required bool isHomeTeam,
    required int slotIndex,
  }) {
    if (_game == null) return [];
    final team = isHomeTeam ? _game!.homeTeam! : _game!.awayTeam!;
    if (slotIndex < 0 || slotIndex >= team.lineup.length) return [];

    final runnersBeforePA = List<BaseRunner>.from(_runners);

    team.lineup[slotIndex].plateAppearances.add(pa);

    // Count outs from this PA
    _game!.outs += pa.outsRecorded;

    // Add batter as runner if they reached base
    if (pa.reachedFirst && !pa.scored) {
      final startBase = pa.reachedThird ? 3 : pa.reachedSecond ? 2 : 1;
      _runners.add(BaseRunner(
        lineupSlotIndex: slotIndex,
        paId: pa.id,
        startBase: startBase,
      ));
    }

    if (_game!.outs >= 3) {
      _runners.clear();
      _endHalfInning();
    }

    _autoSave();
    notifyListeners();
    return runnersBeforePA;
  }

  /// Delete a plate appearance entirely.
  void deletePlateAppearance(String paId, {required bool isHomeTeam}) {
    if (_game == null) return;
    final team = isHomeTeam ? _game!.homeTeam! : _game!.awayTeam!;
    for (final slot in team.lineup) {
      final idx = slot.plateAppearances.indexWhere((pa) => pa.id == paId);
      if (idx != -1) {
        final pa = slot.plateAppearances[idx];
        // Walk back outs this PA contributed
        if (pa.outsRecorded > 0) {
          _game!.outs = (_game!.outs - pa.outsRecorded).clamp(0, 2);
        }
        slot.plateAppearances.removeAt(idx);
        // Remove from active runners if still on base
        _runners.removeWhere((r) => r.paId == paId);
        break;
      }
    }
    _autoSave();
    notifyListeners();
  }

  /// Edit an existing plate appearance (correct base paths, RBIs, etc.)
  void editPlateAppearance(EditPAResult edit, {required bool isHomeTeam}) {
    if (_game == null) return;
    final team = isHomeTeam ? _game!.homeTeam! : _game!.awayTeam!;

    for (final slot in team.lineup) {
      final idx = slot.plateAppearances.indexWhere((pa) => pa.id == edit.paId);
      if (idx != -1) {
        final old = slot.plateAppearances[idx];
        slot.plateAppearances[idx] = PlateAppearance(
          id: old.id,
          inning: old.inning,
          topOfInning: old.topOfInning,
          result: edit.result,
          fielderNotation: edit.fielderNotation,
          rbis: edit.rbis,
          reachedFirst: edit.reachedFirst,
          reachedSecond: edit.reachedSecond,
          reachedThird: edit.reachedThird,
          scored: edit.scored,
          earnedRun: old.earnedRun,
          baseEvents: old.baseEvents,
          pitchBalls: old.pitchBalls,
          pitchStrikes: old.pitchStrikes,
          hitDirection: edit.hitDirection,
        );
        final runner = _runners.firstWhere(
          (r) => r.paId == edit.paId,
          orElse: () => BaseRunner(lineupSlotIndex: -1, paId: '', startBase: 1),
        );
        if (runner.paId == edit.paId) {
          if (edit.scored || (!edit.reachedFirst)) {
            _runners.removeWhere((r) => r.paId == edit.paId);
          } else {
            runner.currentBase = edit.reachedThird ? 3 : edit.reachedSecond ? 2 : 1;
          }
        }
        break;
      }
    }
    _autoSave();
    notifyListeners();
  }

  /// Rename a team mid-game.
  void renameTeam({required bool isHomeTeam, required String name}) {
    if (_game == null || name.trim().isEmpty) return;
    final trimmed = name.trim();
    if (isHomeTeam) {
      _game!.homeTeamName = trimmed;
      _game!.homeTeam?.name = trimmed;
    } else {
      _game!.awayTeamName = trimmed;
      _game!.awayTeam?.name = trimmed;
    }
    _autoSave();
    notifyListeners();
  }

  /// Edit a player's name, number, and position in-game.
  void editPlayer({
    required bool isHomeTeam,
    required int lineupIndex,
    required String name,
    required int jerseyNumber,
    required FieldPosition position,
  }) {
    if (_game == null) return;
    final team = isHomeTeam ? _game!.homeTeam! : _game!.awayTeam!;
    final player = team.lineup[lineupIndex].currentPlayer;
    player.name = name;
    player.jerseyNumber = jerseyNumber;
    player.position = position;
    _autoSave();
    notifyListeners();
  }

  void updateGameInfo(GameInfo info) {
    if (_game == null) return;
    _game!.info = info;
    _autoSave();
    notifyListeners();
  }

  void newGame() {
    _game = null;
    _runners.clear();
    notifyListeners();
  }
}
