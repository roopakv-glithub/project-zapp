// Standalone VTOP pasted-text -> slot decoder.
// Pure Dart, zero dependencies.

// ---------------------------------------------------------------------------
// Course-name cleaner
// ---------------------------------------------------------------------------

/// Strips VTOP metadata suffixes from a raw course-name string.
///
/// Handles single-line pastes where the course name is followed by
/// "(Theory Only)", credit numbers, category, class-group ID, slot+venue, etc.
String _cleanCourseName(String raw) {
  var name = raw;

  // 1. Cut at "( Theory …", "( Lab …", "( Embedded …", "( Project …", "( Soft …"
  name = name.replaceFirst(
    RegExp(
      r'\s*\(?\s*(?:Theory|Lab|Embedded|Project|Soft(?:ware)?)\s+(?:Only|and)\b.*',
      caseSensitive: false,
    ),
    '',
  );

  // 2. Cut at a VTOP credit structure: "3 1 0 0 4.0 …" (four ints + a float)
  name = name.replaceFirst(
    RegExp(r'\s+\d+\s+\d+\s+\d+\s+\d+\s+[\d.]+.*'),
    '',
  );

  // 3. Cut at a VTOP class-group ID like "CH2026…"
  name = name.replaceFirst(
    RegExp(r'\s+CH\d{4,}.*', caseSensitive: false),
    '',
  );

  // 4. Cut at a leaked slot token (e.g. "A1+TA1…", "L31+L32")
  name = name.replaceFirst(
    RegExp(
      r'\s+(?:[A-G][12]|T[A-Z]{1,3}[12]|L\d{1,3}|V\d)(?:\s*\+|\s*-|$).*',
      caseSensitive: false,
    ),
    '',
  );

  // 5. Cut at common VTOP category keywords
  name = name.replaceFirst(
    RegExp(
      r'\s+(?:Professional|University|Regular|Core|Elective|Programme)\b.*',
      caseSensitive: false,
    ),
    '',
  );

  // 6. Trim trailing dashes, numbers, whitespace
  name = name.replaceFirst(RegExp(r'[\s\-]+$'), '');

  return name.trim();
}

// ---------------------------------------------------------------------------
// Output models
// ---------------------------------------------------------------------------

/// One weekly class period decoded from pasted text.
class DecodedSlot {
  final String courseCode;
  final String courseName;
  final String slotCode;
  final int day; // 1=Mon .. 5=Fri
  final String start;
  final String end;
  final String venue;
  final String faculty;

  const DecodedSlot({
    required this.courseCode,
    required this.courseName,
    required this.slotCode,
    required this.day,
    required this.start,
    required this.end,
    required this.venue,
    required this.faculty,
  });

  @override
  String toString() =>
      '$courseCode · $slotCode · day $day $start-$end · $venue · $faculty';
}

/// Full decode output: usable slots + non-blocking warnings.
class DecodeResult {
  final List<DecodedSlot> slots;
  final List<String> warnings;
  const DecodeResult(this.slots, this.warnings);

  bool get hasSlots => slots.isNotEmpty;
}

// ---------------------------------------------------------------------------
// Vellore weekday FFCS pattern (Mon-Fri only). Do not use for another campus.
// ---------------------------------------------------------------------------

const _theoryRows = [
  ['A1', 'F1', 'D1', 'TB1', 'TG1', 'S11', 'A2', 'F2', 'D2', 'TB2', 'TG2', 'S3'],
  ['B1', 'G1', 'E1', 'TC1', 'TAA1', 'L12', 'B2', 'G2', 'E2', 'TC2', 'TAA2', 'S1'],
  ['C1', 'A1', 'F1', 'TD1', 'TBB1', 'L18', 'C2', 'A2', 'F2', 'TD2', 'TBB2', 'S4'],
  ['D1', 'B1', 'G1', 'TE1', 'TCC1', 'L24', 'D2', 'B2', 'G2', 'TE2', 'TCC2', 'S2'],
  ['E1', 'C1', 'TA1', 'TF1', 'TDD1', 'S15', 'E2', 'C2', 'TA2', 'TF2', 'TDD2', 'L60'],
];
const _theoryStarts = [
  '08:00', '08:55', '09:50', '10:45', '11:40', '12:35',
  '14:00', '14:55', '15:50', '16:45', '17:40', '18:35',
];
const _theoryEnds = [
  '08:50', '09:45', '10:40', '11:35', '12:30', '13:25',
  '14:50', '15:45', '16:40', '17:35', '18:30', '19:25',
];
const _labStarts = [
  '08:00', '08:50', '09:50', '10:40', '11:40', '12:30',
  '14:00', '14:50', '15:50', '16:40', '17:40', '18:30',
];
const _labEnds = [
  '08:50', '09:40', '10:40', '11:30', '12:30', '13:20',
  '14:50', '15:40', '16:40', '17:30', '18:30', '19:20',
];

String _labCode(int day, int column) {
  if (column < 6) {
    return 'L${(day - 1) * 6 + column + 1}';
  } else {
    return 'L${30 + (day - 1) * 6 + (column - 6) + 1}';
  }
}

/// slot -> list of (day, start, end)
Map<String, List<(int, String, String)>> _buildPattern() {
  final result = <String, List<(int, String, String)>>{};
  for (var day = 1; day <= 5; day++) {
    for (var col = 0; col < 12; col++) {
      final theory = _theoryRows[day - 1][col];
      if (theory.isNotEmpty) {
        (result[theory] ??= []).add((day, _theoryStarts[col], _theoryEnds[col]));
      }
      final lab = _labCode(day, col);
      (result[lab] ??= []).add((day, _labStarts[col], _labEnds[col]));
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Decoder
// ---------------------------------------------------------------------------

final _slotToken =
    RegExp(r'[A-G][12]|T[A-Z]{1,3}[12]|L\d{1,3}|V\d{1,2}|S\d{1,2}', caseSensitive: false);
final _courseCode =
    RegExp(r'[A-Z]{2,5}\d{3,5}[A-Z]?', caseSensitive: false);

List<String> _expandSlots(String text) {
  final match = _slotToken
      .allMatches(text.replaceAll(RegExp(r'[^A-Za-z0-9+]'), ' '))
      .map((m) => m.group(0)!.toUpperCase())
      .toList();
  // Keep order, drop duplicates.
  final seen = <String>{};
  return [for (final s in match) if (seen.add(s)) s];
}

List<String> _splitCells(String line) => line
    .split(RegExp(r'\t|\||;|,|\s{2,}'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

bool _isHeaderRow(String line) {
  final l = line.toLowerCase();
  return l.contains('course code') ||
      l.contains('course title') ||
      (l.contains('slot') && l.contains('venue')) ||
      l.contains('faculty');
}

bool _isSummaryLine(String line) {
  final l = line.toLowerCase();
  return l.contains('registered and approved') ||
      l.contains('total number of credits') ||
      l.contains('class group') ||
      RegExp(r'^\d{1,2}\s*-\s*[a-z]{3}\s*-\s*\d{4}$').hasMatch(l);
}

/// Group multi-line VTOP cell paste into one record per course.
/// Single-line tab rows pass through untouched.
List<String> _toRecords(String rawText) {
  final lines =
      rawText.replaceAll('\r', '\n').split('\n').map((l) => l.trim()).toList();
  final records = <String>[];
  var current = <String>[];
  var inMultiLine = false;

  void flush() {
    if (current.isNotEmpty) {
      records.add(current.join('\n'));
      current = [];
    }
    inMultiLine = false;
  }

  for (final line in lines) {
    if (line.isEmpty || _isHeaderRow(line) || _isSummaryLine(line)) continue;
    if (RegExp(r'^\d{1,2}$').hasMatch(line)) {
      // Serial-number line starts a new multi-line record.
      flush();
      inMultiLine = true;
      continue;
    }
    if (!inMultiLine) {
      // Single-line row: each line is its own record.
      if (line.isNotEmpty) records.add(line);
      continue;
    }
    current.add(line);
  }
  flush();
  return records;
}

/// Convert pasted VTOP text into weekly slots.
/// Never throws: unparseable rows become warnings.
DecodeResult decodePastedTimetable(String pastedText) {
  final pattern = _buildPattern();
  final slots = <DecodedSlot>[];
  final warnings = <String>[];
  final seen = <String>{};

  final records = _toRecords(pastedText);
  if (records.isEmpty) {
    return const DecodeResult([], ['No rows found. Paste your VTOP table.']);
  }

  for (var i = 0; i < records.length; i++) {
    final record = records[i];
    final flat = record.replaceAll('\n', ' ');
    final codeMatch = _courseCode.firstMatch(flat);
    if (codeMatch == null) continue; // header/blank fragment
    final courseCode = codeMatch.group(0)!.toUpperCase();
    if (courseCode.startsWith('CH')) continue; // class-id, not a course

    // Course name: "CODE - Name" preferred, else cell after the code.
    String courseName = '';
    final dashMatch = RegExp(
      '\\b${RegExp.escape(courseCode)}\\b\\s*-\\s*(.+)',
      caseSensitive: false,
    ).firstMatch(record.replaceAll('\n', ' '));
    if (dashMatch != null) {
      courseName = dashMatch.group(1)!.split(RegExp(r'\s{2,}|\t')).first.trim();
    }
    if (courseName.isEmpty) {
      final cells = _splitCells(record);
      final idx = cells.indexWhere(
        (c) => c.toUpperCase() == courseCode,
      );
      if (idx >= 0 && idx + 1 < cells.length) courseName = cells[idx + 1];
    }
    // Strip VTOP metadata suffixes (Theory/Lab annotation, credits, etc.)
    courseName = _cleanCourseName(courseName);
    if (courseName.isEmpty) {
      warnings.add('Row ${i + 1}: course name not found for $courseCode, skipped.');
      continue;
    }

    // Slot + venue: "A1+TA1 - SJT101" shape, else first slot token in row.
    String slotText = '';
    String venue = '';
    final slotVenueMatch = RegExp(
      r'([A-G][12](?:\s*\+\s*(?:[A-G][12]|T[A-Z]{1,3}[12]|L\d{1,3}|V\d{1,2}))*'
      r'|T[A-Z]{1,3}[12](?:\s*\+\s*(?:[A-G][12]|T[A-Z]{1,3}[12]|L\d{1,3}|V\d{1,2}))*'
      r'|L\d{1,3}(?:\s*\+\s*L\d{1,3})*)\s*-\s*([A-Z0-9]+(?:-[A-Z0-9]+)*|NIL)',
      caseSensitive: false,
    ).firstMatch(flat);
    if (slotVenueMatch != null) {
      slotText = slotVenueMatch.group(1)!;
      venue = slotVenueMatch.group(2)!.toUpperCase();
    } else {
      slotText = _slotToken.firstMatch(flat)?.group(0) ?? '';
    }
    if (slotText.trim().isEmpty || slotText.toUpperCase().contains('NIL')) {
      continue; // online / NIL row: nothing to schedule
    }

    // Faculty: for single-line tab rows it's the last cell; for multi-line
    // paste it's the last multi-word line that is not metadata.
    String faculty = '';
    if (!record.contains('\n')) {
      final cells = _splitCells(record);
      if (cells.length >= 2) {
        final candidate = cells.last;
        final up = candidate.toUpperCase();
        if (!up.contains('NIL') &&
            candidate.split(RegExp(r'\s+')).length >= 2 &&
            !_slotToken.hasMatch(candidate) &&
            !RegExp(r'^[A-Z]{1,3}\d').hasMatch(candidate)) {
          faculty = candidate;
        }
      }
    }
    if (faculty.isEmpty) {
      final rowLines = record
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList()
          .reversed;
      for (final line in rowLines) {
        final clean = line.replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final up = clean.toUpperCase();
        if (clean.isEmpty ||
            up.contains('NIL') ||
            up.contains('SCOPE') ||
            up.contains('REGISTERED') ||
            up.contains('MANUAL') ||
            up.contains('SEMESTER') ||
            up.contains('CORE') ||
            up.contains('ELECTIVE') ||
            up.contains('UNIVERSITY') ||
            RegExp(r'^\d').hasMatch(clean) ||
            RegExp(r'^[A-Z]{1,3}\d').hasMatch(clean)) {
          continue;
        }
        if (clean.split(' ').length >= 2) {
          faculty = clean;
          break;
        }
      }
    }

    if (faculty.isEmpty) {
      warnings.add('Row ${i + 1}: missing faculty for $courseCode.');
    }
    if (venue.isEmpty) {
      warnings.add('Row ${i + 1}: missing venue for $courseCode.');
    }

    final slotCodes = _expandSlots(slotText);
    if (slotCodes.isEmpty) {
      warnings.add('Row ${i + 1}: no slots in "$slotText", skipped.');
      continue;
    }
    for (final slotCode in slotCodes) {
      final times = pattern[slotCode];
      if (times == null) {
        warnings.add('Row ${i + 1}: unsupported slot "$slotCode" (Sat/weekend?), skipped.');
        continue;
      }
      for (final t in times) {
        final key = '$courseCode|$slotCode|${t.$1}|${t.$2}|$venue|$faculty';
        if (!seen.add(key)) continue;
        slots.add(
          DecodedSlot(
            courseCode: courseCode,
            courseName: courseName,
            slotCode: slotCode,
            day: t.$1,
            start: t.$2,
            end: t.$3,
            venue: venue.isEmpty ? 'NIL' : venue,
            faculty: faculty.isEmpty ? 'Unknown' : faculty,
          ),
        );
      }
    }
  }

  slots.sort((a, b) =>
      a.day != b.day ? a.day.compareTo(b.day) : a.start.compareTo(b.start));
  if (slots.isEmpty && warnings.isEmpty) {
    warnings.add('No classes found. Paste complete rows from your table.');
  }
  return DecodeResult(List.unmodifiable(slots), List.unmodifiable(warnings));
}
