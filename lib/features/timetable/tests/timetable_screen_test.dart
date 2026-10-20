// Tests stay within the assigned feature folder; flutter_test is a dev dependency.
// ignore_for_file: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/models/user.dart';
import '../../auth/auth_provider.dart';
import '../timetable_entry.dart';
import '../timetable_parser.dart';
import '../timetable_screen.dart';
import '../timetable_store.dart';
import 'timetable_parser_test.dart' show exampleTable;

class MemoryRepository implements TimetableRepository {
  List<TimetableEntry> entries = previewVitTable(exampleTable).entries;
  bool fail = false;
  @override
  Future<List<TimetableEntry>> load(String ownerId) async => entries;
  @override
  Future<void> save(String ownerId, List<TimetableEntry> entries, {String? displayName}) async {
    if (fail) throw StateError('Storage unavailable');
    this.entries = entries;
  }
  @override
  Future<List<SavedUserTimetable>> loadAllUsers() async => [
    SavedUserTimetable(ownerId: 'student_other', displayName: 'Student', entries: entries),
  ];
}

Future<void> openTimetable(
  WidgetTester tester,
  MemoryRepository repo, {
  bool admin = false,
  double width = 390,
  double height = 1200,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(
          AppUser(
            id: 'student',
            username: 'Student',
            role: admin ? UserRole.admin : UserRole.user,
          ),
        ),
        timetableRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
        builder: (context, child) => RepaintBoundary(
          key: const ValueKey('timetable-preview'),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: const TimetableScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'student views weekday schedule and navigates groups',
    (tester) async {
      await openTimetable(tester, MemoryRepository());
      expect(find.text('My Schedule'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('Timetable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin schedule displays user widgets, supports long-press selection and combined timetable',
    (tester) async {
      final repo = MemoryRepository();
      await openTimetable(tester, repo, admin: true);

      // Verify Admin navigation: Schedule and Groups
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);

      // Verify clickable individual widgets in a list
      expect(find.text('My Timetable (Admin)'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);

      // Tap individual user widget to view their timetable
      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();
      expect(find.text("Student's Timetable"), findsOneWidget);
      expect(find.text('Matrix View'), findsOneWidget);

      // Toggle to Matrix View
      await tester.tap(find.text('Matrix View'));
      await tester.pumpAndSettle();
      expect(find.text('MASTER TIMETABLE MATRIX'), findsOneWidget);

      // Toggle back to Schedule
      await tester.tap(find.text('Schedule').last);
      await tester.pumpAndSettle();

      // Go back
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Step 1 — Long-press a person to activate selection mode
      await tester.longPress(find.text('My Timetable (Admin)'));
      await tester.pumpAndSettle();
      expect(find.text('Select People (1)'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Step 2 — Select multiple people
      await tester.tap(find.text('Student'));
      await tester.pumpAndSettle();
      expect(find.text('Select People (2)'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

      // Step 3 — Show the combined timetable option
      expect(find.text('Selected: 2 people'), findsOneWidget);
      expect(find.text('View Combined Timetable'), findsOneWidget);

      // Step 4 — Generate the combined matrix
      await tester.tap(find.text('View Combined Timetable'));
      await tester.pumpAndSettle();

      // Verify combined matrix screen is opened
      expect(find.textContaining('Combined Timetable'), findsWidgets);
      expect(find.text('2 MEMBERS SELECTED'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      // Return back to admin schedule
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin groups tab retains existing group functionality',
    (tester) async {
      final repo = MemoryRepository();
      await openTimetable(tester, repo, admin: true);

      // Switch to Groups tab
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();

      expect(find.text('Study Squad'), findsOneWidget);
      expect(find.text('SQUAD CODE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow screen and enlarged text do not overflow', (
    tester,
  ) async {
    await openTimetable(tester, MemoryRepository(), width: 400, scale: 1.3);
    expect(tester.takeException(), isNull);
  });
}
