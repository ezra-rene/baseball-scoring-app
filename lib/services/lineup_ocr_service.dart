import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';

// ---------------------------------------------------------------------------
// Data returned for each parsed lineup row
// ---------------------------------------------------------------------------

class ParsedLineupRow {
  int? battingOrder;   // 1-9, if detected
  String name;         // player name (may be empty if only position found)
  int? jerseyNumber;
  FieldPosition? position;

  ParsedLineupRow({
    this.battingOrder,
    required this.name,
    this.jerseyNumber,
    this.position,
  });

  @override
  String toString() =>
      '[$battingOrder] #${jerseyNumber ?? "?"} $name  ${position != null ? fieldPositionLabel(position!) : "?"}';
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class LineupOcrService {
  static final _picker = ImagePicker();

  // Position token → enum  (longest first so "SS" beats "S", "1B" beats "1")
  static const _posTokens = <String, FieldPosition>{
    'SS': FieldPosition.ss,
    '1B': FieldPosition.b1,
    '2B': FieldPosition.b2,
    '3B': FieldPosition.b3,
    'DH': FieldPosition.dh,
    'PH': FieldPosition.ph,
    'PR': FieldPosition.pr,
    'LF': FieldPosition.lf,
    'CF': FieldPosition.cf,
    'RF': FieldPosition.rf,
    'P':  FieldPosition.p,
    'C':  FieldPosition.c,
  };

  /// Pick image from [source] (camera or gallery), run OCR, return parsed rows.
  /// Returns null if user cancelled the picker.
  static Future<List<ParsedLineupRow>?> scan({
    ImageSource source = ImageSource.camera,
  }) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (photo == null) return null;

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(File(photo.path));
      final recognized = await recognizer.processImage(inputImage);
      return _parse(recognized.text);
    } finally {
      recognizer.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static List<ParsedLineupRow> _parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.length >= 2)
        .toList();

    final rows = <ParsedLineupRow>[];
    for (final line in lines) {
      final row = _parseLine(line);
      if (row != null) rows.add(row);
    }

    // Sort by detected batting order
    rows.sort((a, b) {
      if (a.battingOrder == null && b.battingOrder == null) return 0;
      if (a.battingOrder == null) return 1;
      if (b.battingOrder == null) return -1;
      return a.battingOrder!.compareTo(b.battingOrder!);
    });

    return rows;
  }

  static ParsedLineupRow? _parseLine(String raw) {
    // Normalise separators: commas → space, collapse whitespace
    String work = raw
        .replaceAll(RegExp(r'[|,;]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (work.isEmpty) return null;

    // --- Tokenise ---
    final tokens = work.split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return null;

    int? battingOrder;
    int? jerseyNumber;
    FieldPosition? position;
    final nameTokens = <String>[];

    // Track which token indices we've consumed
    final used = <int>{};

    // 1. Batting order: first token that is a single digit 1-9,
    //    optionally followed by '.' (e.g. "1." or "1")
    for (int i = 0; i < tokens.length && battingOrder == null; i++) {
      final t = tokens[i].replaceAll('.', '');
      if (RegExp(r'^\d$').hasMatch(t)) {
        final n = int.parse(t);
        if (n >= 1 && n <= 9) {
          battingOrder = n;
          used.add(i);
        }
      }
    }

    // 2. Position: scan all tokens, longest match first.
    // Also try OCR-corrected variants: '8' → 'B' (e.g. "18" → "1B", "38" → "3B")
    final posEntries = _posTokens.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    String _ocrFixPos(String t) {
      // Replace trailing '8' with 'B' to catch "18"→"1B", "38"→"3B", "28"→"2B"
      // and leading '0' with 'C' to catch "0" misread catcher label
      return t.replaceAll(RegExp(r'8$'), 'B').replaceAll(RegExp(r'^0$'), 'C');
    }

    for (int i = 0; i < tokens.length; i++) {
      if (used.contains(i)) continue;
      final upper = tokens[i].toUpperCase().replaceAll('.', '');
      final candidates = [upper, _ocrFixPos(upper)];
      for (final candidate in candidates) {
        for (final entry in posEntries) {
          if (candidate == entry.key) {
            position = entry.value;
            used.add(i);
            break;
          }
        }
        if (position != null) break;
      }
      if (position != null) break;
    }

    // 3. Jersey number: token starting with '#' or a 1-3 digit standalone number
    for (int i = 0; i < tokens.length; i++) {
      if (used.contains(i)) continue;
      final t = tokens[i];
      // #23 or #7
      if (t.startsWith('#')) {
        final num = int.tryParse(t.substring(1));
        if (num != null) {
          jerseyNumber = num;
          used.add(i);
          break;
        }
      }
      // Standalone 1-3 digit number that hasn't been claimed
      if (RegExp(r'^\d{1,3}$').hasMatch(t)) {
        final num = int.tryParse(t);
        if (num != null && num <= 999) {
          jerseyNumber = num;
          used.add(i);
          break;
        }
      }
    }

    // 4. Remaining tokens → player name
    for (int i = 0; i < tokens.length; i++) {
      if (!used.contains(i)) nameTokens.add(tokens[i]);
    }

    String name = nameTokens
        .join(' ')
        .replaceAll(RegExp(r'^[\.\-]+|[\.\-]+$'), '')
        .trim();

    // Strip a single leading lowercase letter that merged with the name
    // e.g. "cGIRARDI" → "GIRARDI" (OCR merged position 'C' with the name)
    name = name.replaceAll(RegExp(r'^[a-z](?=[A-Z])'), '');

    // Skip lines that look like headers or have no useful info
    if (name.isEmpty && position == null && jerseyNumber == null) return null;

    // Skip very short "names" that are likely OCR noise (single letter etc.)
    // unless a position was also found
    if (name.length <= 1 && position == null) return null;

    return ParsedLineupRow(
      battingOrder: battingOrder,
      name: name,
      jerseyNumber: jerseyNumber,
      position: position,
    );
  }
}
