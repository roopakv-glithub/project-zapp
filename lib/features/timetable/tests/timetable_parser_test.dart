// Tests stay within the assigned feature folder; flutter_test is a dev dependency.
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';

import '../slot_pattern.dart';
import '../timetable_entry.dart';
import '../timetable_parser.dart';

const exampleTable =
    'Course Code\tCourse Title\tSlot - Venue\tFaculty\n'
    'BMAT101L\tCalculus\tA1+TA1 - SJT101\tDr Ada\n'
    'BCSE102P\tProgramming Lab\tL31+L32 - AB3-405\tDr Grace';

void main() {
  test(
    'expands repeated theory occurrences and individual labs with details',
    () {
      final result = previewVitTable(exampleTable);
      expect(result.errors, isEmpty);
      expect(result.entries, hasLength(5));
      final theory = result.entries.where((e) => e.slotCode == 'A1').toList();
      expect(theory.map((e) => (e.day, e.startTime)), [
        (1, '08:00'),
        (3, '08:55'),
      ]);
      expect(theory.first.teacher, 'Dr Ada');
      expect(theory.first.course, 'Calculus');
      expect(theory.first.venue, 'SJT101');
      final labs = result.entries
          .where((e) => e.slotCode.startsWith('L'))
          .toList();
      expect(labs.map((e) => e.day), [1, 1]);
      expect(labs.map((e) => e.startTime), ['14:00', '14:50']);
      expect(labs.first.venue, 'AB3-405');
      expect(result.entries.any((e) => e.slotCode == 'AB3'), isFalse);
    },
  );
  test('supports reordered headers, pipe tables and separate venue', () {
    final result = previewVitTable(
      'Faculty | Venue | Course Code | Slots | Course Name\n'
      'Dr Ada | TT101 | BMAT101L | a1 + taa1 | Calculus',
    );
    expect(result.canSave, isTrue);
    expect(result.entries, hasLength(3));
    expect(
      result.entries.every((e) => e.teacher == 'Dr Ada' && e.venue == 'TT101'),
      isTrue,
    );
  });
  test('standard VTOP registration order and duplicate rows', () {
    const row =
        '1\tBCSE101L\tProgramming\tETH\t3\tVL20260001\tA1+TA1 - SJT101\tDr Ada';
    expect(previewVitTable('$row\n$row').entries, hasLength(3));
  });
  test('rejects unknown codes without accepting a partial timetable', () {
    final result = previewVitTable(
      exampleTable.replaceFirst('A1+TA1', 'A1+TZZ1'),
    );
    expect(result.canSave, isFalse);
    expect(result.errors.join(), contains('TZZ1'));
    expect(
      parseVitTable(exampleTable.replaceFirst('A1+TA1', 'A1+TZZ1')),
      isEmpty,
    );
  });
  test('rejects missing metadata, malformed paste and empty input', () {
    for (final raw in [
      '',
      'A1+TA1 - SJT101',
      'Course Code | Course Title | Slot | Faculty | Venue\nBMAT101L | Calculus | A1 | | SJT101',
    ]) {
      expect(previewVitTable(raw).canSave, isFalse);
    }
  });
  test('all 60 lab periods are mapped once and JSON round trips', () {
    for (var lab = 1; lab <= 60; lab++) {
      expect(timetablePattern['L$lab'], isNotEmpty);
    }
    final entry = previewVitTable(exampleTable).entries.first;
    expect(TimetableEntry.fromJson(entry.toJson()).toJson(), entry.toJson());
  });
  test('correctly parses multi-line VTOP registration blocks with separated fields', () {
    const rawBlock = '''
1
IASWE201 - Requirements Engineering and Management
Theory Only
3 1 0 0 4.0
Professional Core Courses
Regular
CH2026270100756
A1+TA1+TAA1 -
AB4-502
RAMA PRABHA K P - SCOPE
27-Jun-2026 10:19 -
Manual
''';
    final result = previewVitTable(rawBlock);
    expect(result.canSave, isTrue);
    expect(result.entries, isNotEmpty);
    final first = result.entries.first;
    expect(first.courseCode, 'IASWE201');
    expect(first.course, 'Requirements Engineering and Management');
    expect(first.venue, 'AB4-502');
    expect(first.teacher, 'RAMA PRABHA K P');
    expect(first.registrationSlot, 'A1+TA1+TAA1');
  });
  test('keeps theory and lab registrations of same course code separate', () {
    const rawMultiple = '''
1
IASWE206 - Database Systems
Theory Only
3 0 0 0 3.0
Professional Core Courses
Regular
CH2026270100757
B1+TB1 -
AB4-502
M. PREMALATHA - SCOPE
27-Jun-2026 10:19 -
Manual

2
IASWE206 - Database Systems
Lab Only
0 0 2 0 1.0
Professional Core Courses
Regular
CH2026270100758
L31+L32 -
AB1-209
M. PREMALATHA - SCOPE
27-Jun-2026 10:19 -
Manual
''';
    final result = previewVitTable(rawMultiple);
    expect(result.canSave, isTrue);
    final theory = result.entries.where((e) => e.venue == 'AB4-502').toList();
    final lab = result.entries.where((e) => e.venue == 'AB1-209').toList();
    expect(theory, isNotEmpty);
    expect(lab, isNotEmpty);
    expect(theory.every((e) => e.courseCode == 'IASWE206'), isTrue);
    expect(lab.every((e) => e.courseCode == 'IASWE206'), isTrue);
    expect(theory.every((e) => e.slotCode == 'B1' || e.slotCode == 'TB1'), isTrue);
    expect(lab.every((e) => e.slotCode == 'L31' || e.slotCode == 'L32'), isTrue);
  });
}
