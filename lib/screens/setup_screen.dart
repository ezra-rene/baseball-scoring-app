import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/game_provider.dart';
import '../services/lineup_ocr_service.dart';
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
  final _homePitcherNameCtrl = TextEditingController();
  final _homePitcherNumCtrl = TextEditingController();
  final _awayPitcherNameCtrl = TextEditingController();
  final _awayPitcherNumCtrl = TextEditingController();

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
        _homeNameCtrl, _awayNameCtrl,
        _homePitcherNameCtrl, _homePitcherNumCtrl,
        _awayPitcherNameCtrl, _awayPitcherNumCtrl]) {
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

  /// Scan a lineup card photo and, after user review, apply to the given team.
  Future<void> _scanLineup({required bool isHome}) async {
    // Ask camera vs gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF0D2137),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Scan Lineup Card',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Take a photo or choose from gallery',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.lightBlueAccent),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.lightBlueAccent),
              title: const Text('Photo Library', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    // Show loading
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            color: Color(0xFF0D2137),
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.lightBlueAccent),
                  SizedBox(height: 16),
                  Text('Reading lineup card…',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    List<ParsedLineupRow>? rows;
    try {
      rows = await LineupOcrService.scan(source: source);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // dismiss loading

    if (rows == null) return; // user cancelled picker

    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No lineup data found. Try a clearer photo with good lighting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show review sheet
    final confirmed = await _showReviewSheet(rows);
    if (confirmed != true || !mounted) return;

    // Apply parsed rows to lineup (up to 9)
    setState(() {
      final names = isHome ? _homeNames : _awayNames;
      final nums = isHome ? _homeNums : _awayNums;
      final positions = isHome ? _homePositions : _awayPositions;

      for (int i = 0; i < rows!.length && i < 9; i++) {
        final row = rows[i];
        if (row.name.isNotEmpty) names[i].text = row.name;
        if (row.jerseyNumber != null) nums[i].text = '${row.jerseyNumber}';
        if (row.position != null) positions[i] = row.position!;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lineup populated from scan (${rows.length} players)'),
        backgroundColor: Colors.green.shade700,
      ),
    );
  }

  Future<bool?> _showReviewSheet(List<ParsedLineupRow> rows) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _LineupReviewSheet(rows: rows),
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
      homeStartingPitcher: _homePitcherNameCtrl.text.trim(),
      homeStartingPitcherJersey: int.tryParse(_homePitcherNumCtrl.text.trim()) ?? 0,
      awayStartingPitcher: _awayPitcherNameCtrl.text.trim(),
      awayStartingPitcherJersey: int.tryParse(_awayPitcherNumCtrl.text.trim()) ?? 0,
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
            onScanLineup: () => _scanLineup(isHome: false),
            pitcherNameCtrl: _awayPitcherNameCtrl,
            pitcherNumCtrl: _awayPitcherNumCtrl,
          ),
          _TeamSetupPage(
            teamNameCtrl: _homeNameCtrl,
            playerNames: _homeNames,
            playerNums: _homeNums,
            positions: _homePositions,
            onPositionChanged: (i, pos) =>
                setState(() => _homePositions[i] = pos),
            onTeamNameChanged: () => setState(() {}),
            onScanLineup: () => _scanLineup(isHome: true),
            pitcherNameCtrl: _homePitcherNameCtrl,
            pitcherNumCtrl: _homePitcherNumCtrl,
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
  final VoidCallback onScanLineup;
  final TextEditingController pitcherNameCtrl;
  final TextEditingController pitcherNumCtrl;

  const _TeamSetupPage({
    required this.teamNameCtrl,
    required this.playerNames,
    required this.playerNums,
    required this.positions,
    required this.onPositionChanged,
    required this.onTeamNameChanged,
    required this.onScanLineup,
    required this.pitcherNameCtrl,
    required this.pitcherNumCtrl,
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
        // Scan lineup card button
        OutlinedButton.icon(
          onPressed: onScanLineup,
          icon: const Icon(Icons.document_scanner, size: 18),
          label: const Text('Scan Lineup Card'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.lightBlueAccent,
            side: const BorderSide(color: Colors.lightBlueAccent),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel('Batting Order'),
        const SizedBox(height: 8),
        ...List.generate(9, (i) => _PlayerRow(
              order: i + 1,
              nameCtrl: playerNames[i],
              numCtrl: playerNums[i],
              position: positions[i],
              onPositionChanged: (pos) => onPositionChanged(i, pos),
            )),
        const SizedBox(height: 24),
        _SectionLabel('Starting Pitcher (optional)'),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 70,
              child: TextField(
                controller: pitcherNumCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('#'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: pitcherNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Pitcher name'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
      firstDate: DateTime(1900),
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

// ---------------------------------------------------------------------------
// Lineup scan review sheet
// ---------------------------------------------------------------------------

class _LineupReviewSheet extends StatelessWidget {
  final List<ParsedLineupRow> rows;
  const _LineupReviewSheet({required this.rows});

  @override
  Widget build(BuildContext context) {
    final usable = rows.take(9).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) {
        return Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${usable.length} player${usable.length == 1 ? '' : 's'} detected',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Review the parsed lineup, then tap Apply.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            // List
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: usable.length,
                itemBuilder: (_, i) {
                  final row = usable[i];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF1565C0),
                      child: Text(
                        '${row.battingOrder ?? i + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      row.name.isNotEmpty ? row.name : '—',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Row(
                      children: [
                        if (row.jerseyNumber != null)
                          _chip('#${row.jerseyNumber}',
                              Colors.white54),
                        if (row.position != null)
                          _chip(
                            fieldPositionLabel(row.position!),
                            Colors.lightBlueAccent,
                          ),
                        if (row.position == null)
                          _chip('pos unknown', Colors.orange.shade300),
                      ],
                    ),
                  );
                },
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            // Buttons
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Apply to Lineup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6, top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ---------------------------------------------------------------------------

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
