import 'package:flutter/material.dart';
import '../models/models.dart';

Future<GameInfo?> showGameInfoSheet(
  BuildContext context, {
  required GameInfo current,
}) {
  return showModalBottomSheet<GameInfo>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GameInfoSheet(current: current),
  );
}

class GameInfoSheet extends StatefulWidget {
  final GameInfo current;
  const GameInfoSheet({super.key, required this.current});

  @override
  State<GameInfoSheet> createState() => _GameInfoSheetState();
}

class _GameInfoSheetState extends State<GameInfoSheet> {
  late TextEditingController _venueCtrl;
  late TextEditingController _eventCtrl;
  late TextEditingController _umpireCtrl;
  late TextEditingController _scorerCtrl;
  late TextEditingController _notesCtrl;
  DateTime? _gameDate;
  int? _gameTimeHour;
  int? _gameTimeMinute;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _venueCtrl = TextEditingController(text: c.venue);
    _eventCtrl = TextEditingController(text: c.eventName);
    _umpireCtrl = TextEditingController(text: c.umpire);
    _scorerCtrl = TextEditingController(text: c.scorer);
    _notesCtrl = TextEditingController(text: c.notes);
    _gameDate = c.gameDate;
    _gameTimeHour = c.gameTimeHour;
    _gameTimeMinute = c.gameTimeMinute;
  }

  @override
  void dispose() {
    for (final c in [_venueCtrl, _eventCtrl, _umpireCtrl, _scorerCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _gameDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Colors.green.shade400,
            surface: const Color(0xFF0D2137),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _gameDate = picked);
  }

  Future<void> _pickTime() async {
    final now = TimeOfDay.now();
    final initial = (_gameTimeHour != null && _gameTimeMinute != null)
        ? TimeOfDay(hour: _gameTimeHour!, minute: _gameTimeMinute!)
        : now;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: Colors.green.shade400,
            surface: const Color(0xFF0D2137),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _gameTimeHour = picked.hour;
        _gameTimeMinute = picked.minute;
      });
    }
  }

  void _confirm() {
    Navigator.pop(
      context,
      GameInfo(
        venue: _venueCtrl.text.trim(),
        eventName: _eventCtrl.text.trim(),
        umpire: _umpireCtrl.text.trim(),
        scorer: _scorerCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        gameDate: _gameDate,
        gameTimeHour: _gameTimeHour,
        gameTimeMinute: _gameTimeMinute,
      ),
    );
  }

  String get _dateLabel {
    if (_gameDate == null) return 'Pick date';
    return '${_gameDate!.month}/${_gameDate!.day}/${_gameDate!.year}';
  }

  String get _timeLabel {
    if (_gameTimeHour == null || _gameTimeMinute == null) return 'Pick time';
    final h = _gameTimeHour! > 12
        ? _gameTimeHour! - 12
        : _gameTimeHour! == 0 ? 12 : _gameTimeHour!;
    final m = _gameTimeMinute!.toString().padLeft(2, '0');
    final ampm = _gameTimeHour! >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        expand: false,
        builder: (_, scrollCtrl) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D2137),
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
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
                  'Game Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Date & Time row
                _Label('Date & Time'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.calendar_today,
                        label: _dateLabel,
                        active: _gameDate != null,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerButton(
                        icon: Icons.access_time,
                        label: _timeLabel,
                        active: _gameTimeHour != null,
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Venue
                _Label('Venue / Field'),
                const SizedBox(height: 6),
                _Field(controller: _venueCtrl, hint: 'e.g. Yankee Stadium, Field 3'),
                const SizedBox(height: 14),

                // Event / Tournament
                _Label('Event / Tournament'),
                const SizedBox(height: 6),
                _Field(controller: _eventCtrl, hint: 'e.g. Spring League, District 5 Championship'),
                const SizedBox(height: 14),

                // Umpire
                _Label('Home Plate Umpire'),
                const SizedBox(height: 6),
                _Field(controller: _umpireCtrl, hint: 'Umpire name'),
                const SizedBox(height: 14),

                // Official Scorer
                _Label('Official Scorer'),
                const SizedBox(height: 6),
                _Field(controller: _scorerCtrl, hint: 'Your name'),
                const SizedBox(height: 14),

                // Notes
                _Label('Notes'),
                const SizedBox(height: 6),
                _Field(
                  controller: _notesCtrl,
                  hint: 'Weather, field conditions, etc.',
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Details',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF152030),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFF42A5F5)),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1565C0).withValues(alpha: 0.3)
              : const Color(0xFF152030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? Colors.lightBlueAccent
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    active ? Colors.lightBlueAccent : Colors.white38,
                size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
