import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';

class BoxScoreScreen extends StatelessWidget {
  const BoxScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>().game;
    if (game == null) return const SizedBox();

    final innings = game.totalInnings;
    final awayRuns = game.awayTeam!.runsByInning;
    final homeRuns = game.homeTeam!.runsByInning;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2137),
        foregroundColor: Colors.white,
        title: const Text('Box Score'),
        actions: [
          if (game.status == GameStatus.complete)
            TextButton(
              onPressed: () {
                context.read<GameProvider>().newGame();
                Navigator.popUntil(context, (r) => r.isFirst);
              },
              child: const Text('New Game',
                  style: TextStyle(color: Colors.greenAccent)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Game info header
            if (game.info.eventName.isNotEmpty ||
                game.info.venue.isNotEmpty ||
                game.info.gameDate != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2137),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (game.info.eventName.isNotEmpty)
                      Text(game.info.eventName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                    if (game.info.gameDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatGameDateTime(game.info),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                    if (game.info.venue.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(game.info.venue,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                    if (game.info.umpire.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('HP Umpire: ${game.info.umpire}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                    ],
                    if (game.info.scorer.isNotEmpty)
                      Text('Scorer: ${game.info.scorer}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),

            // Game status
            if (game.status == GameStatus.complete)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B5E20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  game.awayScore > game.homeScore
                      ? '${game.awayTeam!.name} wins  ${game.awayScore}–${game.homeScore}'
                      : game.homeScore > game.awayScore
                          ? '${game.homeTeam!.name} wins  ${game.homeScore}–${game.awayScore}'
                          : 'Tie game  ${game.awayScore}–${game.homeScore}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            // Line score
            _SectionTitle('Line Score'),
            const SizedBox(height: 8),
            _LineScore(game: game, innings: innings),
            const SizedBox(height: 24),

            // Away batting stats
            _SectionTitle(game.awayTeam!.name),
            const SizedBox(height: 8),
            _BattingStats(team: game.awayTeam!),
            const SizedBox(height: 24),

            // Home batting stats
            _SectionTitle(game.homeTeam!.name),
            const SizedBox(height: 8),
            _BattingStats(team: game.homeTeam!),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
          color: Color(0xFF90CAF9),
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.5),
    );
  }
}

class _LineScore extends StatelessWidget {
  final Game game;
  final int innings;

  const _LineScore({required this.game, required this.innings});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D2137),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            // Header
            _LineScoreRow(
              label: '',
              values: List.generate(innings, (i) => '${i + 1}'),
              r: 'R',
              h: 'H',
              isHeader: true,
            ),
            const Divider(color: Colors.white12, height: 1),
            // Away
            _LineScoreRow(
              label: game.awayTeam!.name,
              values: List.generate(innings,
                  (i) => '${game.awayTeam!.runsByInning[i + 1] ?? '-'}'),
              r: '${game.awayScore}',
              h: '${game.awayTeam!.totalHits}',
            ),
            const Divider(color: Colors.white12, height: 1),
            // Home
            _LineScoreRow(
              label: game.homeTeam!.name,
              values: List.generate(innings,
                  (i) => '${game.homeTeam!.runsByInning[i + 1] ?? '-'}'),
              r: '${game.homeScore}',
              h: '${game.homeTeam!.totalHits}',
            ),
          ],
        ),
      ),
    );
  }
}

class _LineScoreRow extends StatelessWidget {
  final String label;
  final List<String> values;
  final String r;
  final String h;
  final bool isHeader;

  const _LineScoreRow({
    required this.label,
    required this.values,
    required this.r,
    required this.h,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: isHeader ? const Color(0xFF90CAF9) : Colors.white,
      fontSize: isHeader ? 11 : 14,
      fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(label.length > 12 ? label.substring(0, 12) : label,
                  style: style.copyWith(
                      color: isHeader ? const Color(0xFF90CAF9) : Colors.white70))),
          ...values.map((v) => SizedBox(
                width: 28,
                child: Text(v, textAlign: TextAlign.center, style: style),
              )),
          const SizedBox(width: 8),
          SizedBox(
              width: 28,
              child: Text(r,
                  textAlign: TextAlign.center,
                  style: style.copyWith(
                      color: isHeader
                          ? const Color(0xFF90CAF9)
                          : Colors.greenAccent,
                      fontWeight: FontWeight.bold))),
          SizedBox(
              width: 28,
              child: Text(h,
                  textAlign: TextAlign.center,
                  style: style.copyWith(
                      color: isHeader
                          ? const Color(0xFF90CAF9)
                          : Colors.white))),
        ],
      ),
    );
  }
}

class _BattingStats extends StatelessWidget {
  final TeamGame team;

  const _BattingStats({required this.team});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: const [
                SizedBox(
                    width: 28,
                    child: Text('#',
                        style: TextStyle(
                            color: Color(0xFF90CAF9),
                            fontSize: 11,
                            fontWeight: FontWeight.bold))),
                Expanded(
                    child: Text('Player',
                        style: TextStyle(
                            color: Color(0xFF90CAF9),
                            fontSize: 11,
                            fontWeight: FontWeight.bold))),
                _StatHeader('AB'),
                _StatHeader('H'),
                _StatHeader('R'),
                _StatHeader('RBI'),
                _StatHeader('BB'),
                _StatHeader('K'),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          ...team.lineup.asMap().entries.map((entry) {
            final i = entry.key;
            final slot = entry.value;
            final pas = slot.plateAppearances;
            final ab = pas
                .where((pa) => !const {
                      PlayResult.walk,
                      PlayResult.intentionalWalk,
                      PlayResult.hitByPitch,
                      PlayResult.sacrificeBunt,
                      PlayResult.sacrificeFly,
                    }.contains(pa.result))
                .length;
            final h = slot.hits;
            final r = slot.runs;
            final rbi = slot.rbis;
            final bb = pas
                .where((pa) =>
                    pa.result == PlayResult.walk ||
                    pa.result == PlayResult.intentionalWalk)
                .length;
            final k = pas
                .where((pa) =>
                    pa.result == PlayResult.strikeoutSwinging ||
                    pa.result == PlayResult.strikeoutLooking)
                .length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 28,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12))),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(slot.currentPlayer.name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                            Text(
                              fieldPositionLabel(
                                  slot.currentPlayer.position),
                              style: const TextStyle(
                                  color: Colors.lightBlueAccent,
                                  fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      _StatVal(ab),
                      _StatVal(h, highlight: h > 0),
                      _StatVal(r,
                          highlight: r > 0,
                          color: Colors.greenAccent),
                      _StatVal(rbi,
                          highlight: rbi > 0,
                          color: Colors.yellowAccent),
                      _StatVal(bb),
                      _StatVal(k),
                    ],
                  ),
                ),
                if (i < team.lineup.length - 1)
                  const Divider(color: Colors.white12, height: 1),
              ],
            );
          }),
          const Divider(color: Colors.white24, height: 1),
          // Totals
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 28),
                const Expanded(
                    child: Text('TOTALS',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            fontWeight: FontWeight.bold))),
                _StatVal(
                    team.lineup
                        .expand((s) => s.plateAppearances)
                        .where((pa) => !const {
                              PlayResult.walk,
                              PlayResult.intentionalWalk,
                              PlayResult.hitByPitch,
                              PlayResult.sacrificeBunt,
                              PlayResult.sacrificeFly,
                            }.contains(pa.result))
                        .length,
                    bold: true),
                _StatVal(team.totalHits, bold: true),
                _StatVal(team.totalRuns,
                    bold: true,
                    highlight: true,
                    color: Colors.greenAccent),
                _StatVal(team.totalRbis,
                    bold: true,
                    highlight: true,
                    color: Colors.yellowAccent),
                const _StatVal(0),
                const _StatVal(0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatHeader extends StatelessWidget {
  final String text;
  const _StatHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF90CAF9),
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _StatVal extends StatelessWidget {
  final int value;
  final bool highlight;
  final Color? color;
  final bool bold;

  const _StatVal(this.value,
      {this.highlight = false, this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Text(
        '$value',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: highlight ? (color ?? Colors.white) : Colors.white54,
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

String _formatGameDateTime(GameInfo info) {
  if (info.gameDate == null) return '';
  final d = info.gameDate!;
  final dateStr = '${d.month}/${d.day}/${d.year}';
  if (!info.hasTime) return dateStr;
  return '$dateStr  ${info.formattedTime}';
}
