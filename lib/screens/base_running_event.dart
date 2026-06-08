import 'package:flutter/material.dart';
import '../models/models.dart';

enum BaseRunningEventType {
  stolenBase,
  caughtStealing,
  wildPitch,
  passedBall,
  balk,
  pickoff,
  pickoffAttempt,   // throw over, runner safe
  pickoffError,     // throw over goes wild, runner advances
  defensiveIndifference,
  otherAdvance,
}

String eventLabel(BaseRunningEventType t) {
  switch (t) {
    case BaseRunningEventType.stolenBase:
      return 'SB';
    case BaseRunningEventType.caughtStealing:
      return 'CS';
    case BaseRunningEventType.wildPitch:
      return 'WP';
    case BaseRunningEventType.passedBall:
      return 'PB';
    case BaseRunningEventType.balk:
      return 'BK';
    case BaseRunningEventType.pickoff:
      return 'PO';
    case BaseRunningEventType.pickoffAttempt:
      return 'POA';
    case BaseRunningEventType.pickoffError:
      return 'E1';
    case BaseRunningEventType.defensiveIndifference:
      return 'DI';
    case BaseRunningEventType.otherAdvance:
      return 'ADV';
  }
}

String eventDescription(BaseRunningEventType t) {
  switch (t) {
    case BaseRunningEventType.stolenBase:
      return 'Stolen Base';
    case BaseRunningEventType.caughtStealing:
      return 'Caught Stealing';
    case BaseRunningEventType.wildPitch:
      return 'Wild Pitch';
    case BaseRunningEventType.passedBall:
      return 'Passed Ball';
    case BaseRunningEventType.balk:
      return 'Balk';
    case BaseRunningEventType.pickoff:
      return 'Pickoff (out)';
    case BaseRunningEventType.pickoffAttempt:
      return 'Pickoff Attempt';
    case BaseRunningEventType.pickoffError:
      return 'Pickoff Error';
    case BaseRunningEventType.defensiveIndifference:
      return 'Def. Indifference';
    case BaseRunningEventType.otherAdvance:
      return 'Other Advance';
  }
}

class BaseRunningResult {
  final String paId;
  final int lineupSlotIndex;
  final BaseRunningEventType eventType;
  final int newBase; // 1/2/3 = on base, 4 = scored, 0 = out
  final String notation; // e.g. "SB2", "CS3", "WP"

  const BaseRunningResult({
    required this.paId,
    required this.lineupSlotIndex,
    required this.eventType,
    required this.newBase,
    required this.notation,
  });
}

Future<BaseRunningResult?> showBaseRunningEvent(
  BuildContext context, {
  required List<BaseRunner> runners,
  required TeamGame battingTeam,
}) {
  if (runners.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No runners on base.'),
        backgroundColor: Color(0xFF0D2137),
        duration: Duration(seconds: 2),
      ),
    );
    return Future.value(null);
  }

  return showModalBottomSheet<BaseRunningResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BaseRunningEventSheet(
      runners: runners,
      battingTeam: battingTeam,
    ),
  );
}

class BaseRunningEventSheet extends StatefulWidget {
  final List<BaseRunner> runners;
  final TeamGame battingTeam;

  const BaseRunningEventSheet({
    super.key,
    required this.runners,
    required this.battingTeam,
  });

  @override
  State<BaseRunningEventSheet> createState() => _BaseRunningEventSheetState();
}

class _BaseRunningEventSheetState extends State<BaseRunningEventSheet> {
  BaseRunner? _selectedRunner;
  BaseRunningEventType? _selectedEvent;
  int? _newBase; // 0=out, 1/2/3=base, 4=scored

  String _playerName(BaseRunner r) {
    if (r.lineupSlotIndex < 0 ||
        r.lineupSlotIndex >= widget.battingTeam.lineup.length) {
      return 'Runner';
    }
    return widget.battingTeam.lineup[r.lineupSlotIndex].currentPlayer.name;
  }

  String _baseName(int base) {
    switch (base) {
      case 1: return '1st';
      case 2: return '2nd';
      case 3: return '3rd';
      default: return '?';
    }
  }

  void _autoSetEvent() {
    if (_selectedEvent == null || _selectedRunner == null) return;
    final currentBase = _selectedRunner!.currentBase;

    // Auto-set sensible defaults for new base
    switch (_selectedEvent!) {
      case BaseRunningEventType.stolenBase:
      case BaseRunningEventType.wildPitch:
      case BaseRunningEventType.passedBall:
      case BaseRunningEventType.balk:
      case BaseRunningEventType.defensiveIndifference:
      case BaseRunningEventType.otherAdvance:
      case BaseRunningEventType.pickoffError:
        // Advance one base by default
        _newBase = currentBase < 3 ? currentBase + 1 : 4;
        break;
      case BaseRunningEventType.caughtStealing:
      case BaseRunningEventType.pickoff:
        _newBase = 0; // out
        break;
      case BaseRunningEventType.pickoffAttempt:
        // Runner stays — no base change
        _newBase = currentBase;
        break;
    }
  }

  String get _notation {
    if (_selectedEvent == null || _newBase == null) return '';
    final abbr = eventLabel(_selectedEvent!);
    if (_newBase == 0) return abbr;
    if (_newBase == 4) return '${abbr}H';
    return '$abbr${_newBase}';
  }

  void _confirm() {
    if (_selectedRunner == null || _selectedEvent == null || _newBase == null) return;
    Navigator.pop(
      context,
      BaseRunningResult(
        paId: _selectedRunner!.paId,
        lineupSlotIndex: _selectedRunner!.lineupSlotIndex,
        eventType: _selectedEvent!,
        newBase: _newBase!,
        notation: _notation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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

              const Text(
                'Base Running Event',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Select the runner, then the event type.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // --- Step 1: Select runner ---
              _StepLabel('1  Select Runner'),
              const SizedBox(height: 8),
              ...widget.runners.map((r) {
                final name = _playerName(r);
                final base = _baseName(r.currentBase);
                final isSelected = _selectedRunner?.paId == r.paId;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRunner = r;
                      _newBase = null;
                      _autoSetEvent();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1565C0)
                          : const Color(0xFF152030),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.lightBlueAccent
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person,
                            color: isSelected
                                ? Colors.white
                                : Colors.white38,
                            size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white24
                                : Colors.white12,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'on $base',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // --- Step 2: Select event ---
              _StepLabel('2  Event Type'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BaseRunningEventType.values.map((e) {
                  final isSelected = _selectedEvent == e;
                  final isOut = e == BaseRunningEventType.caughtStealing ||
                      e == BaseRunningEventType.pickoff;
                  final color = isOut
                      ? Colors.red.shade800
                      : Colors.teal.shade700;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEvent = e;
                        _autoSetEvent();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? color
                              : Colors.white12,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            eventLabel(e),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            eventDescription(e),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // --- Step 3: Result base (if runner not out) ---
              if (_selectedRunner != null &&
                  _selectedEvent != null &&
                  _selectedEvent != BaseRunningEventType.caughtStealing &&
                  _selectedEvent != BaseRunningEventType.pickoff &&
                  _selectedEvent != BaseRunningEventType.pickoffAttempt) ...[
                const SizedBox(height: 16),
                _StepLabel('3  Result'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (_selectedRunner!.currentBase < 2)
                      _ResultBtn(
                        label: '2nd',
                        selected: _newBase == 2,
                        color: Colors.blueGrey.shade600,
                        onTap: () => setState(() => _newBase = 2),
                      ),
                    if (_selectedRunner!.currentBase < 3)
                      _ResultBtn(
                        label: '3rd',
                        selected: _newBase == 3,
                        color: Colors.indigo.shade600,
                        onTap: () => setState(() => _newBase = 3),
                      ),
                    _ResultBtn(
                      label: 'Scored',
                      selected: _newBase == 4,
                      color: Colors.green.shade700,
                      onTap: () => setState(() => _newBase = 4),
                    ),
                  ],
                ),
              ],

              // Notation preview
              if (_notation.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF152030),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'Notation: $_notation',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_selectedRunner != null &&
                          _selectedEvent != null &&
                          _newBase != null)
                      ? _confirm
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    'Record Event',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepLabel extends StatelessWidget {
  final String text;
  const _StepLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF90CAF9),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }
}

class _ResultBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ResultBtn({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? color : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
