import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Summary shown on the home screen without loading the full game.
class GameSummary {
  final String id;
  final String homeTeamName;
  final String awayTeamName;
  final int homeScore;
  final int awayScore;
  final int currentInning;
  final bool isTopOfInning;
  final GameStatus status;
  final DateTime startTime;

  const GameSummary({
    required this.id,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeScore,
    required this.awayScore,
    required this.currentInning,
    required this.isTopOfInning,
    required this.status,
    required this.startTime,
  });

  String get statusLabel {
    switch (status) {
      case GameStatus.complete:
        return 'Final';
      case GameStatus.inProgress:
        return '${isTopOfInning ? "Top" : "Bot"} $currentInning';
      default:
        return 'Setup';
    }
  }

  factory GameSummary.fromGame(Game game) => GameSummary(
        id: game.id,
        homeTeamName: game.homeTeamName,
        awayTeamName: game.awayTeamName,
        homeScore: game.homeScore,
        awayScore: game.awayScore,
        currentInning: game.currentInning,
        isTopOfInning: game.isTopOfInning,
        status: game.status,
        startTime: game.startTime,
      );
}

class GameStorage {
  static const _idsKey = 'saved_game_ids';
  static const _gamePrefix = 'game_';
  static const _runnersPrefix = 'runners_';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  static Future<void> saveGame(
    Game game, {
    List<BaseRunner> runners = const [],
    int balls = 0,
    int strikes = 0,
  }) async {
    final prefs = await _prefs;

    // Encode game
    final gameJson = jsonEncode(game.toJson());
    await prefs.setString('$_gamePrefix${game.id}', gameJson);

    // Encode runners + count alongside the game
    final meta = jsonEncode({
      'runners': runners.map((r) => r.toJson()).toList(),
      'balls': balls,
      'strikes': strikes,
    });
    await prefs.setString('$_runnersPrefix${game.id}', meta);

    // Update the list of saved IDs
    final ids = prefs.getStringList(_idsKey) ?? [];
    if (!ids.contains(game.id)) {
      ids.insert(0, game.id); // newest first
      await prefs.setStringList(_idsKey, ids);
    }
  }

  // ---------------------------------------------------------------------------
  // Load all summaries (fast — no full deserialization)
  // ---------------------------------------------------------------------------

  static Future<List<GameSummary>> loadAllSummaries() async {
    final prefs = await _prefs;
    final ids = prefs.getStringList(_idsKey) ?? [];
    final summaries = <GameSummary>[];

    for (final id in ids) {
      final raw = prefs.getString('$_gamePrefix$id');
      if (raw == null) continue;
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final game = Game.fromJson(j);
        summaries.add(GameSummary.fromGame(game));
      } catch (_) {
        // Skip corrupted entries
      }
    }
    return summaries;
  }

  // ---------------------------------------------------------------------------
  // Load a full game by ID
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> loadGameData(String id) async {
    final prefs = await _prefs;
    final raw = prefs.getString('$_gamePrefix$id');
    if (raw == null) return null;

    try {
      final game = Game.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      List<BaseRunner> runners = [];
      int balls = 0;
      int strikes = 0;
      final metaRaw = prefs.getString('$_runnersPrefix$id');
      if (metaRaw != null) {
        final meta = jsonDecode(metaRaw) as Map<String, dynamic>;
        runners = (meta['runners'] as List)
            .map((r) => BaseRunner.fromJson(r as Map<String, dynamic>))
            .toList();
        balls = meta['balls'] ?? 0;
        strikes = meta['strikes'] ?? 0;
      }

      return {'game': game, 'runners': runners, 'balls': balls, 'strikes': strikes};
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  static Future<void> deleteGame(String id) async {
    final prefs = await _prefs;
    await prefs.remove('$_gamePrefix$id');
    await prefs.remove('$_runnersPrefix$id');
    final ids = prefs.getStringList(_idsKey) ?? [];
    ids.remove(id);
    await prefs.setStringList(_idsKey, ids);
  }
}
