/// Vellore weekday FFCS pattern. Do not use for another campus/slot revision.
/// Source and limitations: README.md in this feature directory.
typedef SlotTime = (int day, String start, String end);

const theoryRows = [
  ['A1', 'F1', 'D1', 'TB1', 'TG1', 'S11', 'A2', 'F2', 'D2', 'TB2', 'TG2', 'S3'],
  ['B1', 'G1', 'E1', 'TC1', 'TAA1', 'L12', 'B2', 'G2', 'E2', 'TC2', 'TAA2', 'S1'],
  ['C1', 'A1', 'F1', 'TD1', 'TBB1', 'L18', 'C2', 'A2', 'F2', 'TD2', 'TBB2', 'S4'],
  ['D1', 'B1', 'G1', 'TE1', 'TCC1', 'L24', 'D2', 'B2', 'G2', 'TE2', 'TCC2', 'S2'],
  ['E1', 'C1', 'TA1', 'TF1', 'TDD1', 'S15', 'E2', 'C2', 'TA2', 'TF2', 'TDD2', 'L60'],
];
const theoryStarts = [
  '08:00',
  '08:55',
  '09:50',
  '10:45',
  '11:40',
  '12:35',
  '14:00',
  '14:55',
  '15:50',
  '16:45',
  '17:40',
  '18:35',
];
const theoryEnds = [
  '08:50',
  '09:45',
  '10:40',
  '11:35',
  '12:30',
  '13:25',
  '14:50',
  '15:45',
  '16:40',
  '17:35',
  '18:30',
  '19:25',
];
const labStarts = [
  '08:00',
  '08:50',
  '09:50',
  '10:40',
  '11:40',
  '12:30',
  '14:00',
  '14:50',
  '15:50',
  '16:40',
  '17:40',
  '18:30',
];
const labEnds = [
  '08:50',
  '09:40',
  '10:40',
  '11:30',
  '12:30',
  '13:20',
  '14:50',
  '15:40',
  '16:40',
  '17:30',
  '18:30',
  '19:20',
];

String labCode(int day, int column) {
  if (column < 6) {
    return 'L${(day - 1) * 6 + column + 1}';
  } else {
    return 'L${30 + (day - 1) * 6 + (column - 6) + 1}';
  }
}

final Map<String, List<SlotTime>> timetablePattern = _buildPattern();
Map<String, List<SlotTime>> _buildPattern() {
  final result = <String, List<SlotTime>>{};
  for (var day = 1; day <= 5; day++) {
    for (var column = 0; column < 12; column++) {
      final theory = theoryRows[day - 1][column];
      if (theory.isNotEmpty) {
        result.putIfAbsent(theory, () => []).add((
          day,
          theoryStarts[column],
          theoryEnds[column],
        ));
      }
      final lab = labCode(day, column);
      result.putIfAbsent(lab, () => []).add((
        day,
        labStarts[column],
        labEnds[column],
      ));
    }
  }
  return result;
}
