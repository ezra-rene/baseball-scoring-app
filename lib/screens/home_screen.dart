import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';
import '../services/game_storage.dart';
import 'setup_screen.dart';
import 'scorebook_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<GameSummary> _savedGames = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSummaries();
  }

  Future<void> _loadSummaries() async {
    final games = await GameStorage.loadAllSummaries();
    if (mounted) {
      setState(() {
        _savedGames = games;
        _loading = false;
      });
    }
  }

  Future<void> _resumeGame(BuildContext context, String id) async {
    final provider = context.read<GameProvider>();
    final ok = await provider.loadGame(id);
    if (ok && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScorebookScreen()),
      ).then((_) async {
        await Future.delayed(const Duration(milliseconds: 200));
        _loadSummaries();
      });
    }
  }

  Future<void> _deleteGame(String id) async {
    await context.read<GameProvider>().deleteSavedGame(id);
    await _loadSummaries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1120),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF12203A),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B4513).withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(painter: _DiamondLogoPainter()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Diamond Dugout',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Text(
                    'Official Scorebook',
                    style: TextStyle(
                      color: Color(0xFFBC8A5F),
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            // New Game button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SetupScreen()),
                    ).then((_) async {
                      await Future.delayed(const Duration(milliseconds: 200));
                      _loadSummaries();
                    });
                  },
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text('New Game',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    shadowColor: const Color(0xFF8B4513).withValues(alpha: 0.4),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Saved games list
            if (_loading)
              const Expanded(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: Colors.white38)))
            else if (_savedGames.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No saved games yet.\nStart a new game!',
                    style: TextStyle(color: Colors.white38, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  children: [
                    const Text(
                      'SAVED GAMES',
                      style: TextStyle(
                        color: Color(0xFFBC8A5F),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_savedGames.length} game${_savedGames.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadSummaries,
                  color: const Color(0xFFBC8A5F),
                  backgroundColor: const Color(0xFF0F1E32),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _savedGames.length,
                    itemBuilder: (_, i) =>
                        _GameCard(
                          summary: _savedGames[i],
                          onResume: () =>
                              _resumeGame(context, _savedGames[i].id),
                          onDelete: () => _confirmDelete(_savedGames[i]),
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(GameSummary summary) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D2137),
        title: const Text('Delete Game?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          '${summary.awayTeamName} vs ${summary.homeTeamName}',
          style: const TextStyle(color: Colors.white70),
        ),
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
              _deleteGame(summary.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameSummary summary;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  const _GameCard({
    required this.summary,
    required this.onResume,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = summary.status == GameStatus.complete;
    // Use GameInfo date/time if set, otherwise fall back to save timestamp
    final hasGameDate = summary.gameDate != null;
    final displayDate = summary.gameDate ?? summary.startTime;
    final dateStr = '${displayDate.month}/${displayDate.day}/${displayDate.year}';
    final timeStr = (summary.gameTimeHour != null && summary.gameTimeMinute != null)
        ? _formatHM(summary.gameTimeHour!, summary.gameTimeMinute!)
        : hasGameDate ? '' : _formatTime(summary.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete
              ? Colors.white12
              : const Color(0xFF8B4513).withValues(alpha: 0.5),
          width: isComplete ? 1 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: onResume,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isComplete
                          ? Colors.white12
                          : const Color(0xFF8B4513).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      summary.statusLabel,
                      style: TextStyle(
                        color: isComplete
                            ? Colors.white54
                            : const Color(0xFFE8A87C),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white24, size: 18),
                  ),
                ],
              ),
              // Date / time / event / venue info row
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  // Date
                  _InfoChip(Icons.calendar_today_outlined, dateStr),
                  // Time (if available)
                  if (timeStr.isNotEmpty)
                    _InfoChip(Icons.access_time, timeStr),
                  // Event
                  if (summary.eventName.isNotEmpty)
                    _InfoChip(Icons.emoji_events_outlined, summary.eventName),
                  // Venue
                  if (summary.venue.isNotEmpty)
                    _InfoChip(Icons.location_on_outlined, summary.venue),
                ],
              ),
              const SizedBox(height: 10),
              // Score line
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.awayTeamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: summary.awayScore > summary.homeScore
                            ? Colors.white
                            : Colors.white60,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${summary.awayScore}',
                    style: TextStyle(
                      color: summary.awayScore > summary.homeScore
                          ? const Color(0xFFE8A87C)
                          : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('—',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 18)),
                  ),
                  Text(
                    '${summary.homeScore}',
                    style: TextStyle(
                      color: summary.homeScore > summary.awayScore
                          ? const Color(0xFFE8A87C)
                          : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      summary.homeTeamName,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: summary.homeScore > summary.awayScore
                            ? Colors.white
                            : Colors.white60,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    isComplete ? 'View / Continue' : 'Resume →',
                    style: TextStyle(
                      color: isComplete
                          ? Colors.white38
                          : const Color(0xFFE8A87C),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String _formatHM(int hour, int minute) {
    final h = hour > 12 ? hour - 12 : hour == 0 ? 12 : hour;
    final m = minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _DiamondLogoPainter extends CustomPainter {
  const _DiamondLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.36; // half-diagonal of infield diamond

    // Base positions (diamond: home bottom, 1B right, 2B top, 3B left)
    final home  = Offset(cx,      cy + r);
    final first = Offset(cx + r,  cy);
    final second= Offset(cx,      cy - r);
    final third = Offset(cx - r,  cy);

    // ── Outfield grass arc (green fan) ──────────────────────────────────
    final grassPaint = Paint()
      ..color = const Color(0xFF1B5E20).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final grassPath = Path()
      ..moveTo(home.dx, home.dy)
      ..lineTo(cx - size.width * 0.48, cy - size.height * 0.05)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy + r * 0.15), radius: size.width * 0.50),
        pi + 0.38, pi - 0.76, false,
      )
      ..lineTo(home.dx, home.dy)
      ..close();
    canvas.drawPath(grassPath, grassPaint);

    // ── Infield dirt (brown diamond) ─────────────────────────────────────
    final dirtPaint = Paint()
      ..color = const Color(0xFF6B3A1F).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    final dirtPath = Path()
      ..moveTo(home.dx, home.dy)
      ..lineTo(first.dx, first.dy)
      ..lineTo(second.dx, second.dy)
      ..lineTo(third.dx, third.dy)
      ..close();
    canvas.drawPath(dirtPath, dirtPaint);

    // Infield grass (inner green square, slightly smaller)
    final igr = r * 0.54;
    final infieldGrassPaint = Paint()
      ..color = const Color(0xFF2E7D32).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    final igPath = Path()
      ..moveTo(cx,        cy + igr)
      ..lineTo(cx + igr,  cy)
      ..lineTo(cx,        cy - igr)
      ..lineTo(cx - igr,  cy)
      ..close();
    canvas.drawPath(igPath, infieldGrassPaint);

    // ── Basepaths (white lines) ────────────────────────────────────────
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(home, first, linePaint);
    canvas.drawLine(home, third, linePaint);
    canvas.drawLine(first, second, linePaint);
    canvas.drawLine(third, second, linePaint);

    // ── Bases (white squares, rotated 45°) ────────────────────────────
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    const bs = 5.0; // base size half-width
    for (final pos in [first, second, third]) {
      final bp = Path()
        ..moveTo(pos.dx,      pos.dy - bs)
        ..lineTo(pos.dx + bs, pos.dy)
        ..lineTo(pos.dx,      pos.dy + bs)
        ..lineTo(pos.dx - bs, pos.dy)
        ..close();
      canvas.drawPath(bp, basePaint);
    }
    // Home plate (pentagon shape)
    final hp = Path()
      ..moveTo(home.dx,        home.dy - bs)
      ..lineTo(home.dx + bs,   home.dy - bs * 0.3)
      ..lineTo(home.dx + bs * 0.6, home.dy + bs)
      ..lineTo(home.dx - bs * 0.6, home.dy + bs)
      ..lineTo(home.dx - bs,   home.dy - bs * 0.3)
      ..close();
    canvas.drawPath(hp, basePaint);

    // ── Pitcher's mound (small brown circle) ─────────────────────────
    canvas.drawCircle(
      Offset(cx, cy),
      4.5,
      Paint()..color = const Color(0xFF8B4513).withValues(alpha: 0.85),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      4.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_DiamondLogoPainter old) => false;
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white38),
        const SizedBox(width: 3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
      ],
    );
  }
}
