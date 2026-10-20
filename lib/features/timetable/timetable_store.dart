import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'slot_pattern.dart';
import 'timetable_entry.dart';

class SavedUserTimetable {
  final String ownerId;
  final String displayName;
  final List<TimetableEntry> entries;

  const SavedUserTimetable({
    required this.ownerId,
    required this.displayName,
    required this.entries,
  });
}

abstract class TimetableRepository {
  Future<List<TimetableEntry>> load(String ownerId);
  Future<void> save(String ownerId, List<TimetableEntry> entries, {String? displayName});
  Future<List<SavedUserTimetable>> loadAllUsers();
}

/// One atomic snapshot per authenticated user, shared by both role views.
class TimetableStore implements TimetableRepository {
  TimetableStore({DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? databaseFactory;
  final DatabaseFactory _factory;
  final String? databasePath;
  Future<Database>? _opening;
  Future<Database> _database() async {
    final pending = _opening;
    if (pending != null) return pending;
    final opening = _open();
    _opening = opening;
    try {
      return await opening;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async => _factory.openDatabase(
    databasePath ??
        p.join(await _factory.getDatabasesPath(), 'zapp_timetables.db'),
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE timetables ('
          'owner_id TEXT PRIMARY KEY, snapshot TEXT NOT NULL)',
        );
      },
    ),
  );
  @override
  Future<List<TimetableEntry>> load(String ownerId) async {
    final db = await _database();
    final rows = await db.query(
      'timetables',
      where: 'owner_id = ?',
      whereArgs: [ownerId],
    );
    if (rows.isEmpty) return [];
    final snapshot =
        jsonDecode(rows.first['snapshot'] as String) as Map<String, dynamic>;
    if (snapshot['schemaVersion'] != 1) {
      throw const FormatException('Unsupported timetable version');
    }
    return (snapshot['entries'] as List)
        .map(
          (entry) =>
              TimetableEntry.fromJson(Map<String, Object?>.from(entry as Map)),
        )
        .toList();
  }

  @override
  Future<void> save(String ownerId, List<TimetableEntry> entries, {String? displayName}) async {
    if (ownerId.isEmpty || entries.isEmpty) {
      throw ArgumentError('A user and a non-empty timetable are required');
    }
    final db = await _database();
    await db.transaction((txn) async {
      await txn.insert('timetables', {
        'owner_id': ownerId,
        'snapshot': jsonEncode({
          'schemaVersion': 1,
          'slotPattern': 'vellore-weekday-v1',
          'displayName': displayName ?? ownerId,
          'entries': entries.map((e) => e.toJson()).toList(),
        }),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<List<SavedUserTimetable>> loadAllUsers() async {
    final db = await _database();
    final rows = await db.query('timetables');
    final result = <SavedUserTimetable>[];
    for (final row in rows) {
      try {
        final ownerId = row['owner_id'] as String;
        final snapshot =
            jsonDecode(row['snapshot'] as String) as Map<String, dynamic>;
        final entries = (snapshot['entries'] as List)
            .map(
              (entry) =>
                  TimetableEntry.fromJson(Map<String, Object?>.from(entry as Map)),
            )
            .toList();
        final displayName = (snapshot['displayName'] as String?) ?? ownerId;
        result.add(SavedUserTimetable(
          ownerId: ownerId,
          displayName: displayName,
          entries: entries,
        ));
      } catch (_) {}
    }

    final existingIds = result.map((u) => u.displayName.toLowerCase()).toSet();
    for (final seed in _demoSeedUsers) {
      if (!existingIds.contains(seed.displayName.toLowerCase())) {
        result.add(seed);
      }
    }

    return result;
  }

  Future<void> close() async {
    final pending = _opening;
    _opening = null;
    if (pending != null) await (await pending).close();
  }
}

List<SavedUserTimetable> get _demoSeedUsers => [
  SavedUserTimetable(
    ownerId: 'roopa_seed',
    displayName: 'Roopa',
    entries: _buildSeedEntries([
      ('MAT2001', 'Calculus and Laplace', 'A1', 'Dr. V. Raman', 'SJT 101'),
      ('CSE2005', 'Data Structures', 'F1', 'Prof. Priya S', 'SJT 204'),
      ('ENG1002', 'Professional English', 'TB1', 'Dr. Michael K', 'TT 312'),
      ('PHY1001', 'Engineering Physics', 'A2', 'Dr. R. Anitha', 'PRP 402'),
      ('CSE2005L', 'Data Structures Lab', 'L1', 'Prof. Priya S', 'SJT LAB 2'),
      ('CSE2005L', 'Data Structures Lab', 'L2', 'Prof. Priya S', 'SJT LAB 2'),
    ]),
  ),
  SavedUserTimetable(
    ownerId: 'karavind_seed',
    displayName: 'Karavind',
    entries: _buildSeedEntries([
      ('CSE3002', 'Operating Systems', 'B1', 'Dr. K. Suresh', 'SJT 105'),
      ('CSE2004', 'Database Systems', 'G1', 'Prof. Deepa M', 'TT 208'),
      ('MAT3003', 'Probability & Stats', 'TC1', 'Dr. John Alex', 'MB 112'),
      ('EEE1001', 'Basic Electrical Eng', 'B2', 'Dr. S. Karthik', 'GDN 301'),
      ('CSE2004L', 'Database Systems Lab', 'L7', 'Prof. Deepa M', 'SJT LAB 5'),
      ('CSE2004L', 'Database Systems Lab', 'L8', 'Prof. Deepa M', 'SJT LAB 5'),
    ]),
  ),
  SavedUserTimetable(
    ownerId: 'arun_seed',
    displayName: 'Arun',
    entries: _buildSeedEntries([
      ('CSE3001', 'Software Engineering', 'C1', 'Dr. Malathi N', 'SJT 302'),
      ('MAT2001', 'Calculus and Laplace', 'A1', 'Dr. V. Raman', 'SJT 101'),
      ('ECE2002', 'Digital Electronics', 'TD1', 'Prof. S. Nathan', 'TT 415'),
      ('CSE3003', 'Computer Networks', 'C2', 'Dr. C. Meena', 'PRP 103'),
      ('ECE2002L', 'Digital Electronics Lab', 'L13', 'Prof. S. Nathan', 'TT LAB 1'),
      ('ECE2002L', 'Digital Electronics Lab', 'L14', 'Prof. S. Nathan', 'TT LAB 1'),
    ]),
  ),
  SavedUserTimetable(
    ownerId: 'priya_seed',
    displayName: 'Priya',
    entries: _buildSeedEntries([
      ('CSE2006', 'Theory of Computation', 'D1', 'Dr. R. Shanthi', 'SJT 201'),
      ('CSE3002', 'Operating Systems', 'B1', 'Dr. K. Suresh', 'SJT 105'),
      ('HUM1001', 'Ethics and Values', 'TE1', 'Dr. V. Lakshmi', 'MB 204'),
      ('CSE2008', 'Web Technologies', 'D2', 'Prof. K. Ramesh', 'TT 109'),
      ('CSE2008L', 'Web Technologies Lab', 'L19', 'Prof. K. Ramesh', 'SJT LAB 4'),
      ('CSE2008L', 'Web Technologies Lab', 'L20', 'Prof. K. Ramesh', 'SJT LAB 4'),
    ]),
  ),
];

List<TimetableEntry> _buildSeedEntries(
  List<(String code, String name, String slot, String teacher, String venue)> courses,
) {
  final entries = <TimetableEntry>[];
  for (final c in courses) {
    final times = timetablePattern[c.$3] ?? [];
    for (final t in times) {
      entries.add(
        TimetableEntry(
          day: t.$1,
          slotCode: c.$3,
          course: c.$2,
          startTime: t.$2,
          endTime: t.$3,
          courseCode: c.$1,
          teacher: c.$4,
          venue: c.$5,
          registrationSlot: c.$3,
        ),
      );
    }
  }
  return entries;
}
