import 'package:flutter/material.dart';
import '../models/models.dart';

class EditPlayerResult {
  final int lineupIndex;
  final bool isHomeTeam;
  final String name;
  final int jerseyNumber;
  final FieldPosition position;

  const EditPlayerResult({
    required this.lineupIndex,
    required this.isHomeTeam,
    required this.name,
    required this.jerseyNumber,
    required this.position,
  });
}

Future<EditPlayerResult?> showEditPlayer(
  BuildContext context, {
  required Player player,
  required int lineupIndex,
  required bool isHomeTeam,
  required int battingOrder,
}) {
  return showModalBottomSheet<EditPlayerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditPlayerSheet(
      player: player,
      lineupIndex: lineupIndex,
      isHomeTeam: isHomeTeam,
      battingOrder: battingOrder,
    ),
  );
}

class EditPlayerSheet extends StatefulWidget {
  final Player player;
  final int lineupIndex;
  final bool isHomeTeam;
  final int battingOrder;

  const EditPlayerSheet({
    super.key,
    required this.player,
    required this.lineupIndex,
    required this.isHomeTeam,
    required this.battingOrder,
  });

  @override
  State<EditPlayerSheet> createState() => _EditPlayerSheetState();
}

class _EditPlayerSheetState extends State<EditPlayerSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _numCtrl;
  late FieldPosition _position;

  static const _fieldPositions = [
    FieldPosition.p, FieldPosition.c, FieldPosition.b1, FieldPosition.b2,
    FieldPosition.b3, FieldPosition.ss, FieldPosition.lf, FieldPosition.cf,
    FieldPosition.rf, FieldPosition.dh,
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.player.name);
    _numCtrl = TextEditingController(
        text: widget.player.jerseyNumber > 0
            ? '${widget.player.jerseyNumber}'
            : '');
    _position = widget.player.position;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      EditPlayerResult(
        lineupIndex: widget.lineupIndex,
        isHomeTeam: widget.isHomeTeam,
        name: name,
        jerseyNumber: int.tryParse(_numCtrl.text.trim()) ?? 0,
        position: _position,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Push up when keyboard appears
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${widget.battingOrder}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Edit Player',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Name field
            _Label('Player Name'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: _inputDeco('Player name'),
            ),
            const SizedBox(height: 14),

            // Jersey number + position row
            Row(
              children: [
                // Jersey number
                SizedBox(
                  width: 100,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Jersey #'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _numCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                        decoration: _inputDeco('#'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Position
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Label('Position'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF152030),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: Colors.white12),
                        ),
                        child: DropdownButton<FieldPosition>(
                          value: _position,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF0D2137),
                          underline: const SizedBox(),
                          style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 15),
                          items: _fieldPositions
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(
                                        fieldPositionLabel(p)),
                                  ))
                              .toList(),
                          onChanged: (p) {
                            if (p != null) {
                              setState(() => _position = p);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
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
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
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
