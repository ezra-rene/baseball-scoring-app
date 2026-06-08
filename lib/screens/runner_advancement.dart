import 'package:flutter/material.dart';
import '../models/models.dart';

/// Calculate smart default base for a runner given the batter's result.
int smartDefaultBase(int currentBase, PlayResult batterResult) {
  switch (batterResult) {
    case PlayResult.single:
      // Runners advance 1 base; runner on 3rd scores
      return currentBase >= 3 ? 4 : currentBase + 1;
    case PlayResult.double_:
      // Runner on 1st goes to 3rd; runners on 2nd/3rd score
      return currentBase == 1 ? 3 : 4;
    case PlayResult.triple:
    case PlayResult.homeRun:
      // Everyone scores
      return 4;
    case PlayResult.walk:
    case PlayResult.intentionalWalk:
    case PlayResult.hitByPitch:
      // Only forced runners advance
      return currentBase + 1 <= 3 ? currentBase + 1 : 4;
    case PlayResult.sacrificeBunt:
      // All runners advance exactly one base on a sac bunt
      return currentBase >= 3 ? 4 : currentBase + 1;
    case PlayResult.sacrificeFly:
      // Runner on 3rd scores; others hold (may tag up — let scorer decide)
      return currentBase == 3 ? 4 : currentBase;
    default:
      // No automatic advancement on outs, strikeouts, etc.
      return currentBase;
  }
}

/// Shows a bottom sheet to advance base runners after a plate appearance.
/// Returns a map of paId → newBase (1/2/3 = on base, 4 = scored, 0 = out).
Future<Map<String, int>?> showRunnerAdvancement(
  BuildContext context, {
  required List<BaseRunner> runners,
  required TeamGame battingTeam,
  required String batterResult,
  required PlayResult batterPlayResult,
}) {
  if (runners.isEmpty) return Future.value({});
  return showModalBottomSheet<Map<String, int>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => RunnerAdvancementSheet(
      runners: runners,
      battingTeam: battingTeam,
      batterResult: batterResult,
      batterPlayResult: batterPlayResult,
    ),
  );
}

class RunnerAdvancementSheet extends StatefulWidget {
  final List<BaseRunner> runners;
  final TeamGame battingTeam;
  final String batterResult;
  final PlayResult batterPlayResult;

  const RunnerAdvancementSheet({
    super.key,
    required this.runners,
    required this.battingTeam,
    required this.batterResult,
    required this.batterPlayResult,
  });

  @override
  State<RunnerAdvancementSheet> createState() =>
      _RunnerAdvancementSheetState();
}

class _RunnerAdvancementSheetState extends State<RunnerAdvancementSheet> {
  // paId -> newBase (1/2/3 = on base, 4 = scored, 0 = out on bases)
  late Map<String, int> _advancement;

  @override
  void initState() {
    super.initState();
    // Smart defaults based on batter result
    _advancement = {
      for (final r in widget.runners)
        r.paId: smartDefaultBase(r.currentBase, widget.batterPlayResult),
    };
  }

  String _baseName(int base) {
    switch (base) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '?';
    }
  }

  String _playerName(BaseRunner r) {
    if (r.lineupSlotIndex < 0 ||
        r.lineupSlotIndex >= widget.battingTeam.lineup.length) {
      return 'Runner';
    }
    return widget.battingTeam.lineup[r.lineupSlotIndex].currentPlayer.name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D2137),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            'Advance Runners',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Batter: ${widget.batterResult} — where did each runner end up?',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Runner rows
          ...widget.runners.map((r) {
            final name = _playerName(r);
            final fromBase = _baseName(r.currentBase);
            final current = _advancement[r.paId] ?? r.currentBase;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF152030),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white54, size: 16),
                      const SizedBox(width: 6),
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const SizedBox(width: 8),
                      Text('(on $fromBase)',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Advancement buttons
                  Row(
                    children: [
                      // Only show bases ahead of where they started
                      if (r.currentBase < 2)
                        _AdvButton(
                          label: '2nd',
                          icon: Icons.looks_two,
                          color: Colors.blueGrey,
                          selected: current == 2,
                          onTap: () =>
                              setState(() => _advancement[r.paId] = 2),
                        ),
                      if (r.currentBase < 3)
                        _AdvButton(
                          label: '3rd',
                          icon: Icons.looks_3,
                          color: Colors.indigo,
                          selected: current == 3,
                          onTap: () =>
                              setState(() => _advancement[r.paId] = 3),
                        ),
                      _AdvButton(
                        label: 'Scored',
                        icon: Icons.home,
                        color: Colors.green.shade700,
                        selected: current == 4,
                        onTap: () =>
                            setState(() => _advancement[r.paId] = 4),
                      ),
                      _AdvButton(
                        label: 'Out',
                        icon: Icons.cancel_outlined,
                        color: Colors.red.shade800,
                        selected: current == 0,
                        onTap: () =>
                            setState(() => _advancement[r.paId] = 0),
                      ),
                      // "Stayed" button — keep on same base
                      _AdvButton(
                        label: 'Stayed',
                        icon: Icons.pause_circle_outline,
                        color: Colors.grey.shade700,
                        selected: current == r.currentBase,
                        onTap: () =>
                            setState(() => _advancement[r.paId] = r.currentBase),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _advancement),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm Advancement',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AdvButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? color : Colors.white12),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : Colors.white38,
                  size: 18),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
