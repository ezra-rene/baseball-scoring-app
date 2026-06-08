import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';
import 'game_info_sheet.dart';
import 'scorebook_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _homeNameCtrl = TextEditingController(text: 'Home');
  final _awayNameCtrl = TextEditingController(text: 'Away');
  GameInfo _gameInfo = GameInfo();

  // 9 players per team — name and jersey controllers
  final List<TextEditingController> _homeNames =
      List.generate(9, (i) => TextEditingController(text: 'Player ${i + 1}'));
  final List<TextEditingController> _homeNums =
      List.generate(9, (i) => TextEditingController(text: '${i + 1}'));
  final List<FieldPosition> _homePositions =
      List.filled(9, FieldPosition.dh, growable: false).toList();

  final List<TextEditingController> _awayNames =
      List.generate(9, (i) => TextEditingController(text: 'Player ${i + 1}'));
  final List<TextEditingController> _awayNums =
      List.generate(9, (i) => TextEditingController(text: '${i + 1}'));
  final List<FieldPosition> _awayPositions =
      List.filled(9, FieldPosition.dh, growable: false).toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    // Set default positions
    final defaults = [
      FieldPosition.cf, FieldPosition.ss, FieldPosition.b1,
      FieldPosition.rf, FieldPosition.b3, FieldPosition.lf,
      FieldPosition.b2, FieldPosition.c,  FieldPosition.p,
    ];
    for (int i = 0; i < 9; i++) {
      _homePositions[i] = defaults[i];
      _awayPositions[i] = defaults[i];
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [..._homeNames, ..._homeNums, ..._awayNames, ..._awayNums,
        _homeNameCtrl, _awayNameCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Player> _buildLineup(
    List<TextEditingController> names,
    List<TextEditingController> nums,
    List<FieldPosition> positions,
  ) {
    return List.generate(
      9,
      (i) => Player(
        name: names[i].text.trim().isEmpty ? 'Player ${i + 1}' : names[i].text.trim(),
        jerseyNumber: int.tryParse(nums[i].text) ?? 0,
        position: positions[i],
      ),
    );
  }

  void _startGame() {
    final provider = context.read<GameProvider>();
    provider.startGame(
      homeTeamName: _homeNameCtrl.text.trim().isEmpty ? 'Home' : _homeNameCtrl.text.trim(),
      awayTeamName: _awayNameCtrl.text.trim().isEmpty ? 'Away' : _awayNameCtrl.text.trim(),
      homeLineup: _buildLineup(_homeNames, _homeNums, _homePositions),
      awayLineup: _buildLineup(_awayNames, _awayNums, _awayPositions),
      gameInfo: _gameInfo,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ScorebookScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2137),
        foregroundColor: Colors.white,
        title: const Text('Game Setup'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.green.shade400,
          tabs: [
            Tab(text: _awayNameCtrl.text.isEmpty ? 'Away Team' : _awayNameCtrl.text),
            Tab(text: _homeNameCtrl.text.isEmpty ? 'Home Team' : _homeNameCtrl.text),
            const Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Details'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _startGame,
            icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
            label: const Text('Start Game',
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TeamSetupPage(
            teamNameCtrl: _awayNameCtrl,
            playerNames: _awayNames,
            playerNums: _awayNums,
            positions: _awayPositions,
            onPositionChanged: (i, pos) =>
                setState(() => _awayPositions[i] = pos),
            onTeamNameChanged: () => setState(() {}),
          ),
          _TeamSetupPage(
            teamNameCtrl: _homeNameCtrl,
            playerNames: _homeNames,
            playerNums: _homeNums,
            positions: _homePositions,
            onPositionChanged: (i, pos) =>
                setState(() => _homePositions[i] = pos),
            onTeamNameChanged: () => setState(() {}),
          ),
          _GameDetailsPage(
            info: _gameInfo,
            onChanged: (info) => setState(() => _gameInfo = info),
          ),
        ],
      ),
    );
  }
}

class _TeamSetupPage extends StatelessWidget {
  final TextEditingController teamNameCtrl;
  final List<TextEditingController> playerNames;
  final List<TextEditingController> playerNums;
  final List<FieldPosition> positions;
  final void Function(int, FieldPosition) onPositionChanged;
  final VoidCallback onTeamNameChanged;

  const _TeamSetupPage({
    required this.teamNameCtrl,
    required this.playerNames,
    required this.playerNums,
    required this.positions,
    required this.onPositionChanged,
    required this.onTeamNameChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Team name field
        _SectionLabel('Team Name'),
        const SizedBox(height: 8),
        TextField(
          controller: teamNameCtrl,
          onChanged: (_) => onTeamNameChanged(),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: _inputDeco('Team name'),
        ),
        const SizedBox(height: 24),
        _SectionLabel('Batting Order'),
        const SizedBox(height: 8),
        ...List.generate(9, (i) => _PlayerRow(
              order: i + 1,
              nameCtrl: playerNames[i],
              numCtrl: playerNums[i],
              position: positions[i],
              onPositionChanged: (pos) => onPositionChanged(i, pos),
            )),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final int order;
  final TextEditingController nameCtrl;
  final TextEditingController numCtrl;
  final FieldPosition position;
  final ValueChanged<FieldPosition> onPositionChanged;

  const _PlayerRow({
    required this.order,
    required this.nameCtrl,
    required this.numCtrl,
    required this.position,
    required this.onPositionChanged,
  });

  static const _positions = FieldPosition.values;
  static const _fieldPositions = [
    FieldPosition.p, FieldPosition.c, FieldPosition.b1, FieldPosition.b2,
    FieldPosition.b3, FieldPosition.ss, FieldPosition.lf, FieldPosition.cf,
    FieldPosition.rf, FieldPosition.dh,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$order.',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
          // Jersey number
          SizedBox(
            width: 44,
            child: TextField(
              controller: numCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: _inputDeco('#').copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: _inputDeco('Player name').copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Position dropdown
          DropdownButton<FieldPosition>(
            value: position,
            dropdownColor: const Color(0xFF0D2137),
            style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13),
            underline: const SizedBox(),
            items: _fieldPositions
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(fieldPositionLabel(p)),
                    ))
                .toList(),
            onChanged: (p) {
              if (p != null) onPositionChanged(p);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Game Details page (third tab in setup)
// ---------------------------------------------------------------------------

class _GameDetailsPage extends StatefulWidget {
  final GameInfo info;
  final ValueChanged<GameInfo> onChanged;

  const _GameDetailsPage({required this.info, required this.onChanged});

  @override
  State<_GameDetailsPage> createState() => _GameDetailsPageState();
}

class _GameDetailsPageState extends State<_GameDetailsPage> {
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
    final i = widget.info;
    _venueCtrl = TextEditingController(text: i.venue);
    _eventCtrl = TextEditingController(text: i.eventName);
    _umpireCtrl = TextEditingController(text: i.umpire);
    _scorerCtrl = TextEditingController(text: i.scorer);
    _notesCtrl = TextEditingController(text: i.notes);
    _gameDate = i.gameDate;
    _gameTimeHour = i.gameTimeHour;
    _gameTimeMinute = i.gameTimeMinute;
  }

  @override
  void dispose() {
    for (final c in [_venueCtrl, _eventCtrl, _umpireCtrl, _scorerCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged(GameInfo(
      venue: _venueCtrl.text.trim(),
      eventName: _eventCtrl.text.trim(),
      umpire: _umpireCtrl.text.trim(),
      scorer: _scorerCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      gameDate: _gameDate,
      gameTimeHour: _gameTimeHour,
      gameTimeMinute: _gameTimeMinute,
    ));
  }

  String get _dateLabel => _gameDate == null
      ? 'Pick date'
      : '${_gameDate!.month}/${_gameDate!.day}/${_gameDate!.year}';

  String get _timeLabel {
    if (_gameTimeHour == null || _gameTimeMinute == null) return 'Pick time';
    final h = _gameTimeHour! > 12
        ? _gameTimeHour! - 12
        : _gameTimeHour! == 0 ? 12 : _gameTimeHour!;
    final m = _gameTimeMinute!.toString().padLeft(2, '0');
    return '$h:$m ${_gameTimeHour! >= 12 ? "PM" : "AM"}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _gameDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
              primary: Colors.green.shade400,
              surface: const Color(0xFF0D2137)),
        ),
        child: child!,
      ),
    );
    if (picked != null) { setState(() => _gameDate = picked); _notify(); }
  }

  Future<void> _pickTime() async {
    final initial = (_gameTimeHour != null && _gameTimeMinute != null)
        ? TimeOfDay(hour: _gameTimeHour!, minute: _gameTimeMinute!)
        : TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
              primary: Colors.green.shade400,
              surface: const Color(0xFF0D2137)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _gameTimeHour = picked.hour;
        _gameTimeMinute = picked.minute;
      });
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionLabel('Date & Time'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _DateTimeButton(
              icon: Icons.calendar_today,
              label: _dateLabel,
              active: _gameDate != null,
              onTap: _pickDate,
            )),
            const SizedBox(width: 10),
            Expanded(child: _DateTimeButton(
              icon: Icons.access_time,
              label: _timeLabel,
              active: _gameTimeHour != null,
              onTap: _pickTime,
            )),
          ],
        ),
        const SizedBox(height: 16),
        _SectionLabel('Venue / Field'),
        const SizedBox(height: 6),
        _setupField(_venueCtrl, 'e.g. Yankee Stadium, Field 3'),
        const SizedBox(height: 14),
        _SectionLabel('Event / Tournament'),
        const SizedBox(height: 6),
        _setupField(_eventCtrl, 'e.g. Spring League, District 5'),
        const SizedBox(height: 14),
        _SectionLabel('Home Plate Umpire'),
        const SizedBox(height: 6),
        _setupField(_umpireCtrl, 'Umpire name'),
        const SizedBox(height: 14),
        _SectionLabel('Official Scorer'),
        const SizedBox(height: 6),
        _setupField(_scorerCtrl, 'Your name'),
        const SizedBox(height: 14),
        _SectionLabel('Notes'),
        const SizedBox(height: 6),
        _setupField(_notesCtrl, 'Weather, field conditions, etc.', maxLines: 3),
      ],
    );
  }

  Widget _setupField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: (_) => _notify(),
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: _inputDeco(hint),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon, required this.label,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1565C0).withValues(alpha: 0.25)
              : const Color(0xFF152030),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: active ? Colors.lightBlueAccent : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: active ? Colors.lightBlueAccent : Colors.white38,
                size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : Colors.white38,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
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

InputDecoration _inputDeco(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24),
    filled: true,
    fillColor: const Color(0xFF152030),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Colors.white12),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFF42A5F5)),
    ),
  );
}
