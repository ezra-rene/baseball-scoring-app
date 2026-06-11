import 'dart:math';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum FieldPosition { p, c, b1, b2, b3, ss, lf, cf, rf, dh, ph, pr }

String fieldPositionLabel(FieldPosition p) {
  switch (p) {
    case FieldPosition.p:
      return 'P';
    case FieldPosition.c:
      return 'C';
    case FieldPosition.b1:
      return '1B';
    case FieldPosition.b2:
      return '2B';
    case FieldPosition.b3:
      return '3B';
    case FieldPosition.ss:
      return 'SS';
    case FieldPosition.lf:
      return 'LF';
    case FieldPosition.cf:
      return 'CF';
    case FieldPosition.rf:
      return 'RF';
    case FieldPosition.dh:
      return 'DH';
    case FieldPosition.ph:
      return 'PH';
    case FieldPosition.pr:
      return 'PR';
  }
}

// Fielder number (1-9) as a string for notation
String fielderNum(FieldPosition p) {
  switch (p) {
    case FieldPosition.p:
      return '1';
    case FieldPosition.c:
      return '2';
    case FieldPosition.b1:
      return '3';
    case FieldPosition.b2:
      return '4';
    case FieldPosition.b3:
      return '5';
    case FieldPosition.ss:
      return '6';
    case FieldPosition.lf:
      return '7';
    case FieldPosition.cf:
      return '8';
    case FieldPosition.rf:
      return '9';
    default:
      return '';
  }
}

enum HitDirection {
  line3B,      // down the 3B line
  leftField,   // left field
  leftCenter,  // left-center
  center,      // center field
  rightCenter, // right-center
  rightField,  // right field
  line1B,      // down the 1B line
}

String hitDirectionLabel(HitDirection d) {
  switch (d) {
    case HitDirection.line3B:    return '3B Line';
    case HitDirection.leftField: return 'LF';
    case HitDirection.leftCenter:return 'LC';
    case HitDirection.center:    return 'CF';
    case HitDirection.rightCenter:return 'RC';
    case HitDirection.rightField: return 'RF';
    case HitDirection.line1B:    return '1B Line';
  }
}

enum PlayResult {
  single,
  double_,
  triple,
  homeRun,
  strikeoutSwinging,
  strikeoutLooking,
  walk,
  intentionalWalk,
  hitByPitch,
  error,
  fieldersChoice,
  sacrificeBunt,
  sacrificeFly,
  groundOut,
  flyOut,
  lineOut,
  doublePlay,
  triplePlay,
  droppedThirdStrike,
  catchersInterference,
  infieldHit,
  groundRuleDouble,
}

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------

class Player {
  final String id;
  String name;
  int jerseyNumber;
  FieldPosition position;

  Player({
    String? id,
    required this.name,
    this.jerseyNumber = 0,
    this.position = FieldPosition.dh,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'jerseyNumber': jerseyNumber,
    'position': position.index,
  };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    id: j['id'],
    name: j['name'],
    jerseyNumber: j['jerseyNumber'] ?? 0,
    position: FieldPosition.values[j['position'] ?? 0],
  );
}

// ---------------------------------------------------------------------------
// Plate Appearance
// ---------------------------------------------------------------------------

class PlateAppearance {
  final String id;
  final int inning;
  final bool topOfInning;
  final PlayResult result;
  final String fielderNotation; // e.g. "6-3", "8", "E6"
  final int rbis;
  final bool reachedFirst;
  final bool reachedSecond;
  final bool reachedThird;
  final bool scored;
  final bool earnedRun;
  final int? outAtBase; // 1/2/3 if runner was put out on the bases
  final List<String> baseEvents; // e.g. ["SB3", "WP"]
  final int pitchBalls;
  final int pitchStrikes;
  final HitDirection? hitDirection;

  PlateAppearance({
    String? id,
    required this.inning,
    required this.topOfInning,
    required this.result,
    this.fielderNotation = '',
    this.rbis = 0,
    bool? reachedFirst,
    bool? reachedSecond,
    bool? reachedThird,
    bool? scored,
    this.earnedRun = true,
    this.outAtBase,
    List<String>? baseEvents,
    this.pitchBalls = 0,
    this.pitchStrikes = 0,
    this.hitDirection,
  })  : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}',
        reachedFirst = reachedFirst ?? defaultReachedFirst(result),
        reachedSecond = reachedSecond ?? defaultReachedSecond(result),
        reachedThird = reachedThird ?? defaultReachedThird(result),
        scored = scored ?? defaultScored(result),
        baseEvents = baseEvents ?? [];

  PlateAppearance copyWith({
    bool? reachedFirst,
    bool? reachedSecond,
    bool? reachedThird,
    bool? scored,
    int? rbis,
    int? outAtBase,
    bool clearOutAtBase = false,
    List<String>? baseEvents,
    int? pitchBalls,
    int? pitchStrikes,
    HitDirection? hitDirection,
    bool clearHitDirection = false,
  }) {
    return PlateAppearance(
      id: id,
      inning: inning,
      topOfInning: topOfInning,
      result: result,
      fielderNotation: fielderNotation,
      rbis: rbis ?? this.rbis,
      reachedFirst: reachedFirst ?? this.reachedFirst,
      reachedSecond: reachedSecond ?? this.reachedSecond,
      reachedThird: reachedThird ?? this.reachedThird,
      scored: scored ?? this.scored,
      earnedRun: earnedRun,
      outAtBase: clearOutAtBase ? null : (outAtBase ?? this.outAtBase),
      baseEvents: baseEvents ?? List.from(this.baseEvents),
      pitchBalls: pitchBalls ?? this.pitchBalls,
      pitchStrikes: pitchStrikes ?? this.pitchStrikes,
      hitDirection: clearHitDirection ? null : (hitDirection ?? this.hitDirection),
    );
  }

  static bool defaultReachedFirst(PlayResult r) => const {
        PlayResult.single,
        PlayResult.double_,
        PlayResult.triple,
        PlayResult.homeRun,
        PlayResult.walk,
        PlayResult.intentionalWalk,
        PlayResult.hitByPitch,
        PlayResult.error,
        PlayResult.fieldersChoice,
        PlayResult.droppedThirdStrike,
        PlayResult.catchersInterference,
        PlayResult.infieldHit,
        PlayResult.groundRuleDouble,
      }.contains(r);

  static bool defaultReachedSecond(PlayResult r) =>
      const {PlayResult.double_, PlayResult.triple, PlayResult.homeRun, PlayResult.groundRuleDouble}.contains(r);

  static bool defaultReachedThird(PlayResult r) =>
      const {PlayResult.triple, PlayResult.homeRun}.contains(r);

  static bool defaultScored(PlayResult r) => r == PlayResult.homeRun;

  bool get isHit => const {
        PlayResult.single,
        PlayResult.double_,
        PlayResult.triple,
        PlayResult.homeRun,
        PlayResult.infieldHit,
        PlayResult.groundRuleDouble,
      }.contains(result);

  bool get isOut => const {
        PlayResult.strikeoutSwinging,
        PlayResult.strikeoutLooking,
        PlayResult.groundOut,
        PlayResult.flyOut,
        PlayResult.lineOut,
        PlayResult.sacrificeBunt,
        PlayResult.sacrificeFly,
        PlayResult.doublePlay,
        PlayResult.triplePlay,
      }.contains(result);

  int get outsRecorded {
    if (result == PlayResult.doublePlay) return 2;
    if (result == PlayResult.triplePlay) return 3;
    if (isOut) return 1;
    return 0;
  }

  String get displayText {
    switch (result) {
      case PlayResult.single:
        return '1B';
      case PlayResult.double_:
        return '2B';
      case PlayResult.triple:
        return '3B';
      case PlayResult.homeRun:
        return 'HR';
      case PlayResult.strikeoutSwinging:
        return 'K';
      case PlayResult.strikeoutLooking:
        return 'Kc';
      case PlayResult.walk:
        return 'BB';
      case PlayResult.intentionalWalk:
        return 'IBB';
      case PlayResult.hitByPitch:
        return 'HBP';
      case PlayResult.error:
        return 'E${fielderNotation}';
      case PlayResult.fieldersChoice:
        return 'FC';
      case PlayResult.sacrificeBunt:
        return 'SBNT';
      case PlayResult.sacrificeFly:
        return 'SFLY';
      case PlayResult.groundOut:
        return fielderNotation.isEmpty ? 'GO' : fielderNotation;
      case PlayResult.flyOut:
        return fielderNotation.isEmpty ? 'FO' : 'F$fielderNotation';
      case PlayResult.lineOut:
        return fielderNotation.isEmpty ? 'LO' : 'L$fielderNotation';
      case PlayResult.doublePlay:
        return fielderNotation.isEmpty ? 'DP' : fielderNotation;
      case PlayResult.triplePlay:
        return fielderNotation.isEmpty ? 'TP' : fielderNotation;
      case PlayResult.droppedThirdStrike:
        return 'K+';
      case PlayResult.catchersInterference:
        return 'CI';
      case PlayResult.infieldHit:
        return fielderNotation.isEmpty ? 'IH' : 'IH${fielderNotation}';
      case PlayResult.groundRuleDouble:
        return 'GRD';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inning': inning,
    'topOfInning': topOfInning,
    'result': result.index,
    'fielderNotation': fielderNotation,
    'rbis': rbis,
    'reachedFirst': reachedFirst,
    'reachedSecond': reachedSecond,
    'reachedThird': reachedThird,
    'scored': scored,
    'earnedRun': earnedRun,
    'outAtBase': outAtBase,
    'baseEvents': baseEvents,
    'pitchBalls': pitchBalls,
    'pitchStrikes': pitchStrikes,
    'hitDirection': hitDirection?.index,
  };

  factory PlateAppearance.fromJson(Map<String, dynamic> j) => PlateAppearance(
    id: j['id'],
    inning: j['inning'],
    topOfInning: j['topOfInning'],
    result: PlayResult.values[j['result']],
    fielderNotation: j['fielderNotation'] ?? '',
    rbis: j['rbis'] ?? 0,
    reachedFirst: j['reachedFirst'] ?? false,
    reachedSecond: j['reachedSecond'] ?? false,
    reachedThird: j['reachedThird'] ?? false,
    scored: j['scored'] ?? false,
    earnedRun: j['earnedRun'] ?? true,
    outAtBase: j['outAtBase'] as int?,
    baseEvents: List<String>.from(j['baseEvents'] ?? []),
    pitchBalls: j['pitchBalls'] ?? 0,
    pitchStrikes: j['pitchStrikes'] ?? 0,
    hitDirection: j['hitDirection'] != null
        ? HitDirection.values[j['hitDirection']]
        : null,
  );
}

// ---------------------------------------------------------------------------
// Pitching Appearance — one pitcher's stint in a game
// ---------------------------------------------------------------------------

class PitchingAppearance {
  final String id;
  String pitcherName;
  int jerseyNumber;
  final int startInning;

  PitchingAppearance({
    String? id,
    required this.pitcherName,
    required this.jerseyNumber,
    required this.startInning,
  }) : id = id ?? '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'pitcherName': pitcherName,
    'jerseyNumber': jerseyNumber,
    'startInning': startInning,
  };

  factory PitchingAppearance.fromJson(Map<String, dynamic> j) => PitchingAppearance(
    id: j['id'],
    pitcherName: j['pitcherName'] ?? '',
    jerseyNumber: j['jerseyNumber'] ?? 0,
    startInning: j['startInning'] ?? 1,
  );
}

// ---------------------------------------------------------------------------
// Base Runner — tracks a runner currently on base
// ---------------------------------------------------------------------------

class BaseRunner {
  final int lineupSlotIndex;
  final String paId;
  final int startBase;
  int currentBase;

  BaseRunner({
    required this.lineupSlotIndex,
    required this.paId,
    required this.startBase,
  }) : currentBase = startBase;

  Map<String, dynamic> toJson() => {
    'lineupSlotIndex': lineupSlotIndex,
    'paId': paId,
    'startBase': startBase,
    'currentBase': currentBase,
  };

  factory BaseRunner.fromJson(Map<String, dynamic> j) {
    final r = BaseRunner(
      lineupSlotIndex: j['lineupSlotIndex'],
      paId: j['paId'],
      startBase: j['startBase'],
    );
    r.currentBase = j['currentBase'];
    return r;
  }
}

// ---------------------------------------------------------------------------
// Lineup Slot (one batting order position, may have substitutes)
// ---------------------------------------------------------------------------

class LineupSlot {
  List<Player> players;
  List<PlateAppearance> plateAppearances;

  LineupSlot({required Player initialPlayer})
      : players = [initialPlayer],
        plateAppearances = [];

  Player get currentPlayer => players.last;

  int get hits => plateAppearances.where((pa) => pa.isHit).length;
  int get rbis => plateAppearances.fold(0, (s, pa) => s + pa.rbis);
  int get runs => plateAppearances.where((pa) => pa.scored).length;

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'plateAppearances': plateAppearances.map((pa) => pa.toJson()).toList(),
  };

  factory LineupSlot.fromJson(Map<String, dynamic> j) {
    final players = (j['players'] as List)
        .map((p) => Player.fromJson(p as Map<String, dynamic>))
        .toList();
    final slot = LineupSlot(initialPlayer: players.first);
    slot.players = players;
    slot.plateAppearances = (j['plateAppearances'] as List)
        .map((pa) => PlateAppearance.fromJson(pa as Map<String, dynamic>))
        .toList();
    return slot;
  }
}

// ---------------------------------------------------------------------------
// Team Game state
// ---------------------------------------------------------------------------

class TeamGame {
  String name;
  final List<LineupSlot> lineup;
  int currentBatterIndex;
  List<PitchingAppearance> pitchingLog;

  TeamGame({required this.name, required List<Player> players})
      : lineup = players.map((p) => LineupSlot(initialPlayer: p)).toList(),
        currentBatterIndex = 0,
        pitchingLog = [];

  LineupSlot get currentBatter => lineup[currentBatterIndex];

  void advanceBatter() {
    currentBatterIndex = (currentBatterIndex + 1) % lineup.length;
  }

  int get totalRuns => lineup.fold(0, (s, slot) => s + slot.runs);
  int get totalHits => lineup.fold(0, (s, slot) => s + slot.hits);
  int get totalRbis => lineup.fold(0, (s, slot) => s + slot.rbis);

  // Runs per inning (1-based key)
  Map<int, int> get runsByInning {
    final map = <int, int>{};
    for (final slot in lineup) {
      for (final pa in slot.plateAppearances) {
        if (pa.scored) {
          map[pa.inning] = (map[pa.inning] ?? 0) + 1;
        }
      }
    }
    return map;
  }

  // All PAs ordered by inning then insertion order
  List<PlateAppearance> get allPAs =>
      lineup.expand((s) => s.plateAppearances).toList()
        ..sort((a, b) => a.inning.compareTo(b.inning));

  Map<String, dynamic> toJson() => {
    'name': name,
    'lineup': lineup.map((s) => s.toJson()).toList(),
    'currentBatterIndex': currentBatterIndex,
    'pitchingLog': pitchingLog.map((p) => p.toJson()).toList(),
  };

  factory TeamGame.fromJson(Map<String, dynamic> j) {
    final slots = (j['lineup'] as List)
        .map((s) => LineupSlot.fromJson(s as Map<String, dynamic>))
        .toList();
    final team = TeamGame(
      name: j['name'],
      players: slots.map((s) => s.currentPlayer).toList(),
    );
    for (int i = 0; i < slots.length; i++) {
      team.lineup[i].players = slots[i].players;
      team.lineup[i].plateAppearances = slots[i].plateAppearances;
    }
    team.currentBatterIndex = j['currentBatterIndex'] ?? 0;
    team.pitchingLog = ((j['pitchingLog'] as List?) ?? [])
        .map((p) => PitchingAppearance.fromJson(p as Map<String, dynamic>))
        .toList();
    return team;
  }
}

// ---------------------------------------------------------------------------
// Game
// ---------------------------------------------------------------------------

enum GameStatus { setup, inProgress, complete }

class GameInfo {
  String venue;
  String eventName;
  String umpire;
  String scorer;
  String notes;
  DateTime? gameDate;
  int? gameTimeHour;   // 0-23
  int? gameTimeMinute; // 0-59

  GameInfo({
    this.venue = '',
    this.eventName = '',
    this.umpire = '',
    this.scorer = '',
    this.notes = '',
    this.gameDate,
    this.gameTimeHour,
    this.gameTimeMinute,
  });

  bool get hasTime => gameTimeHour != null && gameTimeMinute != null;

  String get formattedTime {
    if (!hasTime) return '';
    final h = gameTimeHour! > 12
        ? gameTimeHour! - 12
        : gameTimeHour! == 0 ? 12 : gameTimeHour!;
    final m = gameTimeMinute!.toString().padLeft(2, '0');
    final ampm = gameTimeHour! >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  Map<String, dynamic> toJson() => {
    'venue': venue,
    'eventName': eventName,
    'umpire': umpire,
    'scorer': scorer,
    'notes': notes,
    'gameDate': gameDate?.millisecondsSinceEpoch,
    'gameTimeHour': gameTimeHour,
    'gameTimeMinute': gameTimeMinute,
  };

  factory GameInfo.fromJson(Map<String, dynamic> j) => GameInfo(
    venue: j['venue'] ?? '',
    eventName: j['eventName'] ?? '',
    umpire: j['umpire'] ?? '',
    scorer: j['scorer'] ?? '',
    notes: j['notes'] ?? '',
    gameDate: j['gameDate'] != null
        ? DateTime.fromMillisecondsSinceEpoch(j['gameDate'])
        : null,
    gameTimeHour: j['gameTimeHour'],
    gameTimeMinute: j['gameTimeMinute'],
  );
}

class Game {
  final String id;
  String homeTeamName;
  String awayTeamName;
  TeamGame? homeTeam;
  TeamGame? awayTeam;
  int currentInning;
  bool isTopOfInning;
  int outs;
  GameStatus status;
  DateTime startTime;
  GameInfo info;

  Game({
    String? id,
    required this.homeTeamName,
    required this.awayTeamName,
    GameInfo? info,
  })  : id = id ?? '${DateTime.now().millisecondsSinceEpoch}',
        currentInning = 1,
        isTopOfInning = true,
        outs = 0,
        status = GameStatus.setup,
        startTime = DateTime.now(),
        info = info ?? GameInfo();

  TeamGame get battingTeam => isTopOfInning ? awayTeam! : homeTeam!;
  TeamGame get fieldingTeam => isTopOfInning ? homeTeam! : awayTeam!;

  String get currentHalfLabel => isTopOfInning ? 'Top' : 'Bot';
  int get homeScore => homeTeam?.totalRuns ?? 0;
  int get awayScore => awayTeam?.totalRuns ?? 0;

  int get totalInnings {
    final lastAway = awayTeam?.allPAs.isEmpty == false
        ? awayTeam!.allPAs.map((p) => p.inning).reduce(max)
        : 0;
    final lastHome = homeTeam?.allPAs.isEmpty == false
        ? homeTeam!.allPAs.map((p) => p.inning).reduce(max)
        : 0;
    return max(max(lastAway, lastHome), 9);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeTeamName': homeTeamName,
    'awayTeamName': awayTeamName,
    'homeTeam': homeTeam?.toJson(),
    'awayTeam': awayTeam?.toJson(),
    'currentInning': currentInning,
    'isTopOfInning': isTopOfInning,
    'outs': outs,
    'status': status.index,
    'startTime': startTime.millisecondsSinceEpoch,
    'info': info.toJson(),
  };

  factory Game.fromJson(Map<String, dynamic> j) {
    final game = Game(
      id: j['id'],
      homeTeamName: j['homeTeamName'],
      awayTeamName: j['awayTeamName'],
      info: j['info'] != null
          ? GameInfo.fromJson(j['info'] as Map<String, dynamic>)
          : GameInfo(),
    );
    if (j['homeTeam'] != null) {
      game.homeTeam = TeamGame.fromJson(j['homeTeam'] as Map<String, dynamic>);
    }
    if (j['awayTeam'] != null) {
      game.awayTeam = TeamGame.fromJson(j['awayTeam'] as Map<String, dynamic>);
    }
    game.currentInning = j['currentInning'] ?? 1;
    game.isTopOfInning = j['isTopOfInning'] ?? true;
    game.outs = j['outs'] ?? 0;
    game.status = GameStatus.values[j['status'] ?? 0];
    game.startTime = DateTime.fromMillisecondsSinceEpoch(
        j['startTime'] ?? DateTime.now().millisecondsSinceEpoch);
    return game;
  }
}
