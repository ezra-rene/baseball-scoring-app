import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/hit_direction_selector.dart';

/// Bottom sheet for recording a plate appearance.
/// Returns a [PlateAppearance] or null if cancelled.
Future<PlateAppearance?> showAtBatEntry(
  BuildContext context, {
  required int inning,
  required bool topOfInning,
  required String batterName,
  required int battingOrder,
  int initialBalls = 0,
  int initialStrikes = 0,
}) {
  return showModalBottomSheet<PlateAppearance>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AtBatEntrySheet(
      inning: inning,
      topOfInning: topOfInning,
      batterName: batterName,
      battingOrder: battingOrder,
      initialBalls: initialBalls,
      initialStrikes: initialStrikes,
    ),
  );
}

class AtBatEntrySheet extends StatefulWidget {
  final int inning;
  final bool topOfInning;
  final String batterName;
  final int battingOrder;
  final int initialBalls;
  final int initialStrikes;

  const AtBatEntrySheet({
    super.key,
    required this.inning,
    required this.topOfInning,
    required this.batterName,
    required this.battingOrder,
    this.initialBalls = 0,
    this.initialStrikes = 0,
  });

  @override
  State<AtBatEntrySheet> createState() => _AtBatEntrySheetState();
}

class _AtBatEntrySheetState extends State<AtBatEntrySheet> {
  PlayResult? _result;
  HitDirection? _hitDirection;
  int _rbis = 0;
  bool _reachedFirst = false;
  bool _reachedSecond = false;
  bool _reachedThird = false;
  bool _scored = false;
  late int _balls;
  late int _strikes;

  // For fielder notation
  final List<int> _selectedFielders = []; // positions 1-9 selected in order
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _balls = widget.initialBalls;
    _strikes = widget.initialStrikes;
  }

  void _onResultSelected(PlayResult r) {
    setState(() {
      _result = r;
      _selectedFielders.clear();
      _isError = r == PlayResult.error;

      // Auto-set base advancement
      _reachedFirst = PlateAppearance.defaultReachedFirst(r);
      _reachedSecond = PlateAppearance.defaultReachedSecond(r);
      _reachedThird = PlateAppearance.defaultReachedThird(r);
      _scored = PlateAppearance.defaultScored(r);
    });
  }

  String get _fielderNotation {
    if (_selectedFielders.isEmpty) return '';
    if (_result == PlayResult.error) return _selectedFielders.first.toString();
    if (_result == PlayResult.flyOut || _result == PlayResult.lineOut) {
      return _selectedFielders.first.toString();
    }
    return _selectedFielders.join('-');
  }

  void _confirm() {
    if (_result == null) return;
    final pa = PlateAppearance(
      inning: widget.inning,
      topOfInning: widget.topOfInning,
      result: _result!,
      fielderNotation: _fielderNotation,
      rbis: _rbis,
      reachedFirst: _reachedFirst,
      reachedSecond: _reachedSecond,
      reachedThird: _reachedThird,
      scored: _scored,
      hitDirection: _hitDirection,
      pitchBalls: _balls,
      pitchStrikes: _strikes,
    );
    Navigator.pop(context, pa);
  }

  @override
  Widget build(BuildContext context) {
    final halfLabel = widget.topOfInning ? 'Top' : 'Bot';
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.98,
      builder: (_, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D2137),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      '$halfLabel ${widget.inning} — Batting Order #${widget.battingOrder}',
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.batterName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // --- Pitch Count ---
              _SectionLabel('Pitch Count'),
              const SizedBox(height: 8),
              _PitchCountRow(
                balls: _balls,
                strikes: _strikes,
                onBall: () => setState(() { if (_balls < 4) _balls++; }),
                onStrike: () => setState(() { if (_strikes < 3) _strikes++; }),
                onReset: () => setState(() { _balls = 0; _strikes = 0; }),
              ),
              const SizedBox(height: 16),

              _SectionLabel('Result'),
              const SizedBox(height: 8),

              // --- HITS ---
              _ResultRow(
                label: 'Hits',
                color: const Color(0xFF2E7D32),
                results: const [
                  (PlayResult.single, '1B', false),
                  (PlayResult.double_, '2B', false),
                  (PlayResult.triple, '3B', false),
                  (PlayResult.homeRun, 'HR', false),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),
              const SizedBox(height: 8),

              // --- ON BASE (no hit) ---
              _ResultRow(
                label: 'On Base',
                color: const Color(0xFF1565C0),
                results: const [
                  (PlayResult.walk, 'BB', false),
                  (PlayResult.intentionalWalk, 'IBB', false),
                  (PlayResult.hitByPitch, 'HBP', false),
                  (PlayResult.droppedThirdStrike, 'K+', false),
                  (PlayResult.catchersInterference, 'CI', false),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),
              const SizedBox(height: 8),

              // --- OUTS ---
              _ResultRow(
                label: 'Outs',
                color: const Color(0xFFC62828),
                results: const [
                  (PlayResult.strikeoutSwinging, 'K', false),
                  (PlayResult.strikeoutLooking, 'K', true),
                  (PlayResult.groundOut, 'GO', false),
                  (PlayResult.flyOut, 'FO', false),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),
              const SizedBox(height: 8),

              _ResultRow(
                label: '',
                color: const Color(0xFFC62828),
                results: const [
                  (PlayResult.lineOut, 'LO', false),
                  (PlayResult.doublePlay, 'DP', false),
                  (PlayResult.triplePlay, 'TP', false),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),
              const SizedBox(height: 8),

              // --- SPECIAL ---
              _ResultRow(
                label: 'Special',
                color: const Color(0xFFE65100),
                results: const [
                  (PlayResult.error, 'E', false),
                  (PlayResult.fieldersChoice, 'FC', false),
                  (PlayResult.sacrificeBunt, 'SAC Bunt', false),
                  (PlayResult.sacrificeFly, 'SAC Fly', false),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),

              // --- Ball direction (all batted balls) ---
              if (_result != null && const {
                PlayResult.single, PlayResult.double_,
                PlayResult.triple, PlayResult.homeRun,
                PlayResult.groundOut, PlayResult.flyOut, PlayResult.lineOut,
                PlayResult.doublePlay, PlayResult.triplePlay,
                PlayResult.fieldersChoice, PlayResult.error,
                PlayResult.sacrificeBunt, PlayResult.sacrificeFly,
              }.contains(_result)) ...[
                const SizedBox(height: 16),
                _SectionLabel('Ball Direction'),
                const SizedBox(height: 6),
                HitDirectionSelector(
                  selected: _hitDirection,
                  onChanged: (d) => setState(() => _hitDirection = d),
                ),
              ],

              // --- Fielder selector (shown for relevant results) ---
              if (_result != null &&
                  const {
                    PlayResult.groundOut,
                    PlayResult.flyOut,
                    PlayResult.lineOut,
                    PlayResult.doublePlay,
                    PlayResult.triplePlay,
                    PlayResult.error,
                    PlayResult.fieldersChoice,
                    PlayResult.sacrificeBunt,
                    PlayResult.sacrificeFly,
                  }.contains(_result)) ...[
                const SizedBox(height: 16),
                _SectionLabel(_isError
                    ? 'Fielder (Error on)'
                    : _result == PlayResult.flyOut || _result == PlayResult.lineOut
                        ? 'Fielder (who caught it)'
                        : 'Fielder(s) — tap each in order  e.g. SS→1B = 6, 3'),
                const SizedBox(height: 8),
                _FielderGrid(
                  selected: _selectedFielders,
                  onTap: (n) {
                    setState(() {
                      if (_result == PlayResult.flyOut ||
                          _result == PlayResult.lineOut ||
                          _isError) {
                        _selectedFielders
                          ..clear()
                          ..add(n);
                      } else {
                        if (_selectedFielders.contains(n)) {
                          _selectedFielders.remove(n);
                        } else {
                          _selectedFielders.add(n);
                        }
                      }
                    });
                  },
                ),
                if (_selectedFielders.isNotEmpty &&
                    _result != PlayResult.flyOut &&
                    _result != PlayResult.lineOut)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Notation: ${_isError ? "E" : ""}$_fielderNotation',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],

              // --- Base advancement ---
              if (_result != null && _result != PlayResult.homeRun) ...[
                const SizedBox(height: 16),
                _SectionLabel('Base Advancement'),
                const SizedBox(height: 4),
                _BaseToggleRow(
                  reachedFirst: _reachedFirst,
                  reachedSecond: _reachedSecond,
                  reachedThird: _reachedThird,
                  scored: _scored,
                  onChanged: (f, s2, t, sc) {
                    setState(() {
                      _reachedFirst = f;
                      _reachedSecond = s2;
                      _reachedThird = t;
                      _scored = sc;
                    });
                  },
                ),
              ],

              // --- RBIs ---
              const SizedBox(height: 16),
              _SectionLabel('RBIs'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _rbis > 0 ? () => setState(() => _rbis--) : null,
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.white70),
                    iconSize: 32,
                  ),
                  Container(
                    width: 64,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF152030),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '$_rbis',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _rbis < 4 ? () => setState(() => _rbis++) : null,
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white70),
                    iconSize: 32,
                  ),
                ],
              ),

              // --- Confirm ---
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _result != null ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Record At-Bat',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
          color: Color(0xFF90CAF9),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final Color color;
  final List<(PlayResult, String, bool)> results;
  final PlayResult? selected;
  final ValueChanged<PlayResult> onTap;

  const _ResultRow({
    required this.label,
    required this.color,
    required this.results,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label.isNotEmpty) ...[
          SizedBox(
            width: 52,
            child: Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ] else
          const SizedBox(width: 52),
        ...results.map((r) {
          final isSelected = selected == r.$1;
          final labelWidget = r.$3
              ? Transform.scale(scaleX: -1, child: Text(r.$2,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )))
              : Text(r.$2,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ));
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(r.$1),
              child: Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color : color.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: labelWidget,
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _FielderGrid extends StatelessWidget {
  final List<int> selected;
  final ValueChanged<int> onTap;

  const _FielderGrid({required this.selected, required this.onTap});

  static const _labels = {
    1: 'P', 2: 'C', 3: '1B', 4: '2B', 5: '3B',
    6: 'SS', 7: 'LF', 8: 'CF', 9: 'RF',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: List.generate(9, (i) {
        final n = i + 1;
        final isSel = selected.contains(n);
        final order = isSel ? selected.indexOf(n) + 1 : null;
        return GestureDetector(
          onTap: () => onTap(n),
          child: Container(
            width: 60,
            height: 48,
            decoration: BoxDecoration(
              color: isSel
                  ? const Color(0xFF1565C0)
                  : const Color(0xFF152030),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSel
                    ? Colors.lightBlueAccent
                    : Colors.white24,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$n',
                    style: TextStyle(
                        color: isSel ? Colors.white : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(_labels[n]!,
                    style: TextStyle(
                        color: isSel
                            ? Colors.lightBlueAccent
                            : Colors.white38,
                        fontSize: 11)),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _BaseToggleRow extends StatelessWidget {
  final bool reachedFirst;
  final bool reachedSecond;
  final bool reachedThird;
  final bool scored;
  final void Function(bool, bool, bool, bool) onChanged;

  const _BaseToggleRow({
    required this.reachedFirst,
    required this.reachedSecond,
    required this.reachedThird,
    required this.scored,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _BaseChip(
          label: '1B',
          active: reachedFirst,
          onTap: () => onChanged(!reachedFirst, reachedSecond, reachedThird, scored),
        ),
        _BaseChip(
          label: '2B',
          active: reachedSecond,
          onTap: () => onChanged(reachedFirst, !reachedSecond, reachedThird, scored),
        ),
        _BaseChip(
          label: '3B',
          active: reachedThird,
          onTap: () => onChanged(reachedFirst, reachedSecond, !reachedThird, scored),
        ),
        _BaseChip(
          label: 'Scored',
          active: scored,
          color: Colors.green.shade600,
          onTap: () => onChanged(reachedFirst, reachedSecond, reachedThird, !scored),
        ),
      ],
    );
  }
}

class _PitchCountRow extends StatelessWidget {
  final int balls;
  final int strikes;
  final VoidCallback onBall;
  final VoidCallback onStrike;
  final VoidCallback onReset;

  const _PitchCountRow({
    required this.balls,
    required this.strikes,
    required this.onBall,
    required this.onStrike,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Balls
        Expanded(
          child: GestureDetector(
            onTap: onBall,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade700),
              ),
              child: Column(
                children: [
                  Text('$balls',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const Text('Balls',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Strikes
        Expanded(
          child: GestureDetector(
            onTap: onStrike,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade700),
              ),
              child: Column(
                children: [
                  Text('$strikes',
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const Text('Strikes',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Reset
        GestureDetector(
          onTap: onReset,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.refresh, color: Colors.white38, size: 20),
          ),
        ),
      ],
    );
  }
}

class _BaseChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _BaseChip({
    required this.label,
    required this.active,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.blueGrey.shade600;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? c : c.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}
