import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/hit_direction_selector.dart';

class EditPAResult {
  final String paId;
  final PlayResult result;
  final String fielderNotation;
  final bool reachedFirst;
  final bool reachedSecond;
  final bool reachedThird;
  final bool scored;
  final int rbis;
  final HitDirection? hitDirection;

  const EditPAResult({
    required this.paId,
    required this.result,
    required this.fielderNotation,
    required this.reachedFirst,
    required this.reachedSecond,
    required this.reachedThird,
    required this.scored,
    required this.rbis,
    this.hitDirection,
  });
}

Future<EditPAResult?> showEditPA(
  BuildContext context, {
  required PlateAppearance pa,
  required String playerName,
  required int inning,
}) {
  return showModalBottomSheet<EditPAResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditPASheet(pa: pa, playerName: playerName, inning: inning),
  );
}

class EditPASheet extends StatefulWidget {
  final PlateAppearance pa;
  final String playerName;
  final int inning;

  const EditPASheet({
    super.key,
    required this.pa,
    required this.playerName,
    required this.inning,
  });

  @override
  State<EditPASheet> createState() => _EditPASheetState();
}

class _EditPASheetState extends State<EditPASheet> {
  late PlayResult _result;
  late List<int> _selectedFielders;
  HitDirection? _hitDirection;
  late bool _isError;
  late bool _reachedFirst;
  late bool _reachedSecond;
  late bool _reachedThird;
  late bool _scored;
  late int _rbis;

  @override
  void initState() {
    super.initState();
    _result = widget.pa.result;
    _selectedFielders = _parseFielders(widget.pa.fielderNotation, widget.pa.result);
    _isError = widget.pa.result == PlayResult.error;
    _hitDirection = widget.pa.hitDirection;
    _reachedFirst = widget.pa.reachedFirst;
    _reachedSecond = widget.pa.reachedSecond;
    _reachedThird = widget.pa.reachedThird;
    _scored = widget.pa.scored;
    _rbis = widget.pa.rbis;
  }

  /// Parse existing notation back into fielder numbers e.g. "6-3" → [6, 3]
  List<int> _parseFielders(String notation, PlayResult result) {
    if (notation.isEmpty) return [];
    // Strip leading letters (E, F, L)
    final cleaned = notation.replaceAll(RegExp(r'^[A-Za-z]+'), '');
    return cleaned
        .split('-')
        .map((s) => int.tryParse(s.trim()))
        .where((n) => n != null && n >= 1 && n <= 9)
        .cast<int>()
        .toList();
  }

  bool get _showFielders => const {
        PlayResult.groundOut,
        PlayResult.flyOut,
        PlayResult.lineOut,
        PlayResult.doublePlay,
        PlayResult.triplePlay,
        PlayResult.error,
        PlayResult.fieldersChoice,
        PlayResult.sacrificeBunt,
        PlayResult.sacrificeFly,
      }.contains(_result);

  bool get _isFlyOrLine =>
      _result == PlayResult.flyOut || _result == PlayResult.lineOut;

  String get _fielderNotation {
    if (_selectedFielders.isEmpty) return '';
    if (_isError) return _selectedFielders.first.toString();
    if (_isFlyOrLine) return _selectedFielders.first.toString();
    return _selectedFielders.join('-');
  }

  void _onResultSelected(PlayResult r) {
    setState(() {
      _result = r;
      _isError = r == PlayResult.error;
      _selectedFielders.clear();
    });
  }

  void _confirm() {
    Navigator.pop(
      context,
      EditPAResult(
        paId: widget.pa.id,
        result: _result,
        fielderNotation: _fielderNotation,
        reachedFirst: _reachedFirst,
        reachedSecond: _reachedSecond,
        reachedThird: _reachedThird,
        scored: _scored,
        rbis: _rbis,
        hitDirection: _hitDirection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final halfLabel = widget.pa.topOfInning ? 'Top' : 'Bot';

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
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
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('EDIT',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.playerName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Text(
                          '$halfLabel ${widget.inning}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // --- Result ---
              _SectionLabel('Result'),
              const SizedBox(height: 8),

              _ResultRow(
                label: 'Hits',
                color: const Color(0xFF2E7D32),
                results: const [
                  (PlayResult.single, '1B'),
                  (PlayResult.double_, '2B'),
                  (PlayResult.triple, '3B'),
                  (PlayResult.homeRun, 'HR'),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),
              const SizedBox(height: 8),
              _ResultRow(
                label: 'On Base',
                color: const Color(0xFF1565C0),
                results: const [
                  (PlayResult.walk, 'BB'),
                  (PlayResult.intentionalWalk, 'IBB'),
                  (PlayResult.hitByPitch, 'HBP'),
                  (PlayResult.droppedThirdStrike, 'K+'),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),
              const SizedBox(height: 8),
              _ResultRow(
                label: 'Outs',
                color: const Color(0xFFC62828),
                results: const [
                  (PlayResult.strikeoutSwinging, 'K'),
                  (PlayResult.strikeoutLooking, 'Kc'),
                  (PlayResult.groundOut, 'GO'),
                  (PlayResult.flyOut, 'FO'),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),
              const SizedBox(height: 8),
              _ResultRow(
                label: '',
                color: const Color(0xFFC62828),
                results: const [
                  (PlayResult.lineOut, 'LO'),
                  (PlayResult.doublePlay, 'DP'),
                  (PlayResult.triplePlay, 'TP'),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),
              const SizedBox(height: 8),
              _ResultRow(
                label: 'Special',
                color: const Color(0xFFE65100),
                results: const [
                  (PlayResult.error, 'E'),
                  (PlayResult.fieldersChoice, 'FC'),
                  (PlayResult.sacrificeBunt, 'SAC'),
                  (PlayResult.sacrificeFly, 'SF'),
                ],
                selected: _result,
                onTap: _onResultSelected,
              ),

              // --- Ball direction (all batted balls) ---
              if (const {
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

              // --- Fielder selector ---
              if (_showFielders) ...[
                const SizedBox(height: 16),
                _SectionLabel(_isError
                    ? 'Fielder (Error on)'
                    : _isFlyOrLine
                        ? 'Fielder (who caught it)'
                        : 'Fielder(s) — tap each in order  e.g. SS→1B = 6, 3'),
                const SizedBox(height: 8),
                _FielderGrid(
                  selected: _selectedFielders,
                  onTap: (n) {
                    setState(() {
                      if (_isFlyOrLine || _isError) {
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
                if (_selectedFielders.isNotEmpty)
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
              if (_result != PlayResult.homeRun) ...[
                const SizedBox(height: 16),
                _SectionLabel('Base Advancement'),
                const SizedBox(height: 8),
                _BaseToggleRow(
                  reachedFirst: _reachedFirst,
                  reachedSecond: _reachedSecond,
                  reachedThird: _reachedThird,
                  scored: _scored,
                  onChanged: (f, s2, t, sc) => setState(() {
                    _reachedFirst = f;
                    _reachedSecond = s2;
                    _reachedThird = t;
                    _scored = sc;
                  }),
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
                    onPressed:
                        _rbis > 0 ? () => setState(() => _rbis--) : null,
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
                    child: Text('$_rbis',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed:
                        _rbis < 4 ? () => setState(() => _rbis++) : null,
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white70),
                    iconSize: 32,
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper widgets (duplicated here to keep file self-contained)
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
  final List<(PlayResult, String)> results;
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
        SizedBox(
          width: 52,
          child: text.isNotEmpty
              ? Text(label,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.bold))
              : null,
        ),
        ...results.map((r) {
          final isSelected = selected == r.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(r.$1),
              child: Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : color.withValues(alpha: 0.35),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  r.$2,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String get text => label;
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
                color:
                    isSel ? Colors.lightBlueAccent : Colors.white24,
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
          onTap: () => onChanged(
              !reachedFirst, reachedSecond, reachedThird, scored),
        ),
        _BaseChip(
          label: '2B',
          active: reachedSecond,
          onTap: () => onChanged(
              reachedFirst, !reachedSecond, reachedThird, scored),
        ),
        _BaseChip(
          label: '3B',
          active: reachedThird,
          onTap: () => onChanged(
              reachedFirst, reachedSecond, !reachedThird, scored),
        ),
        _BaseChip(
          label: 'Scored',
          active: scored,
          color: Colors.green.shade600,
          onTap: () => onChanged(
              reachedFirst, reachedSecond, reachedThird, !scored),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
