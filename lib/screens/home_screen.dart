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
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1B5E20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sports_baseball,
                        size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Baseball Scorer',
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
                      color: Color(0xFF90CAF9),
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
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
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
                        color: Color(0xFF90CAF9),
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
                  color: Colors.white,
                  backgroundColor: const Color(0xFF0D2137),
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
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComplete ? Colors.white12 : Colors.green.withValues(alpha: 0.3),
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
                          : Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      summary.statusLabel,
                      style: TextStyle(
                        color: isComplete
                            ? Colors.white54
                            : Colors.greenAccent,
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
                          ? Colors.greenAccent
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
                          ? Colors.greenAccent
                          : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      summary.homeTeamName,
                      textAlign: TextAlign.right,
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
                          : Colors.greenAccent,
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
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }
}
