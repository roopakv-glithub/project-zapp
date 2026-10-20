import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../core/theme.dart';
import '../auth/auth_provider.dart';
import 'slot_pattern.dart';
import 'timetable_entry.dart';
import 'timetable_parser.dart';
import 'timetable_schedule_view.dart';
import 'timetable_store.dart';

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  final store = TimetableStore();
  ref.onDispose(store.close);
  return store;
});

final _savedTimetableProvider = FutureProvider.autoDispose
    .family<List<TimetableEntry>, String>(
      (ref, ownerId) => ref.watch(timetableRepositoryProvider).load(ownerId),
    );

final _allSavedUsersProvider = FutureProvider.autoDispose<List<SavedUserTimetable>>(
  (ref) => ref.watch(timetableRepositoryProvider).loadAllUsers(),
);

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  final _paste = TextEditingController();
  bool _saving = false;
  bool _forceImportView = false;
  String? _message;
  final Set<String> _selectedUserIds = {};
  bool _selectionMode = false;

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _handlePreviewAndSave(String ownerId) async {
    final text = _paste.text.trim();
    if (text.isEmpty) {
      setState(() => _message = 'Please paste your VTOP timetable table.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = previewVitTable(text);
      if (result.entries.isNotEmpty) {
        await ref
            .read(timetableRepositoryProvider)
            .save(ownerId, result.entries);
        if (!mounted) return;
        ref.invalidate(_savedTimetableProvider(ownerId));
        setState(() {
          _forceImportView = false;
          _paste.clear();
          _message = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.entries.length} weekly classes loaded successfully!'),
              backgroundColor: kAppleBlue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() {
          _message = result.errors.isNotEmpty
              ? result.errors.first
              : 'No valid classes found. Paste complete rows from your VTOP table.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Error parsing timetable: $e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const Scaffold(
        backgroundColor: kAppleSurface,
        body: Center(
          child: Text(
            'Sign in to view your timetable.',
            style: TextStyle(color: kAppleTextSecondary, fontSize: 16),
          ),
        ),
      );
    }
    final saved = ref.watch(_savedTimetableProvider(user.id));
    return saved.when(
      loading: () => const Scaffold(
        backgroundColor: kAppleSurface,
        body: Center(child: CircularProgressIndicator(color: kAppleBlue)),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: kAppleSurface,
        appBar: AppBar(title: const Text('My Timetable')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load your saved timetable.', style: TextStyle(color: kAppleTextSecondary)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(_savedTimetableProvider(user.id)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (entries) {
        if (user.isAdmin) {
          if (_forceImportView) {
            return _buildImportView(user.id, hasExisting: entries.isNotEmpty);
          }
          return _buildAdminScaffold(context, user, entries);
        }
        if (entries.isNotEmpty && !_forceImportView) {
          return TimetableScheduleView(
            entries: entries,
            onReimport: () => setState(() => _forceImportView = true),
          );
        }
        return _buildImportView(user.id, hasExisting: entries.isNotEmpty);
      },
    );
  }

  Widget _buildImportView(String ownerId, {required bool hasExisting}) {
    return Scaffold(
      backgroundColor: kAppleSurface,
      appBar: AppBar(
        title: const Text('Import Timetable'),
        leading: hasExisting
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: kAppleBlue),
                tooltip: 'Back to timetable',
                onPressed: () => setState(() => _forceImportView = false),
              )
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Apple Minimalist Hero Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kAppleBorderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: kAppleBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'VTOP COMPATIBLE',
                      style: TextStyle(
                        color: kAppleBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Make room for your semester.',
                    style: TextStyle(
                      color: kAppleTextPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Import your Vellore campus classes to sync weekly schedules, view study squads, and find instant free periods.',
                    style: TextStyle(color: kAppleTextSecondary, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Import Form Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: kAppleBorderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'PASTE VTOP TIMETABLE',
                    style: TextStyle(
                      color: kAppleTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Copy the entire course registration table from VTOP and paste the raw text below.',
                    style: TextStyle(color: kAppleTextSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _paste,
                    enabled: !_saving,
                    minLines: 5,
                    maxLines: 9,
                    onChanged: (_) => setState(() => _message = null),
                    style: const TextStyle(fontSize: 14, color: kAppleTextPrimary),
                    decoration: InputDecoration(
                      hintText: 'Course Code | Course Title | Slot | Faculty | Venue...',
                      hintStyle: const TextStyle(color: kAppleTextTertiary, fontSize: 13),
                      filled: true,
                      fillColor: kAppleSurface,
                      contentPadding: const EdgeInsets.all(16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kAppleBorderLight),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: kAppleBlue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kAppleBlue,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _saving ? null : () => _handlePreviewAndSave(ownerId),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Process & Save Timetable',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kAppleError.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _message!,
                        style: const TextStyle(
                          color: kAppleError,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminScaffold(
    BuildContext context,
    AppUser user,
    List<TimetableEntry> adminEntries,
  ) {
    final allUsersAsync = ref.watch(_allSavedUsersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kAppleSurface,
        appBar: AppBar(
          backgroundColor: kAppleSurface,
          elevation: 0,
          leading: _selectionMode
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: kAppleTextPrimary),
                  tooltip: 'Cancel selection',
                  onPressed: () {
                    setState(() {
                      _selectionMode = false;
                      _selectedUserIds.clear();
                    });
                  },
                )
              : null,
          title: Text(
            _selectionMode
                ? 'Select People (${_selectedUserIds.length})'
                : 'Admin Timetable',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: kAppleTextPrimary,
            ),
          ),
          actions: [
            if (_selectionMode)
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectionMode = false;
                    _selectedUserIds.clear();
                  });
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: kAppleBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else ...[
              IconButton(
                icon: const Icon(Icons.table_chart_outlined, color: kAppleBlue),
                tooltip: 'Master Slot Matrix',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        backgroundColor: kAppleSurface,
                        appBar: AppBar(title: const Text('Master Timetable Matrix')),
                        body: SafeArea(child: _adminGrid(adminEntries)),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.cloud_upload_outlined, color: kAppleBlue),
                tooltip: 'Import My Timetable',
                onPressed: () => setState(() => _forceImportView = true),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: kAppleBlue),
                tooltip: 'Refresh Users',
                onPressed: () => ref.invalidate(_allSavedUsersProvider),
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Segmented Tabs: Schedule | Groups
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E9EC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerHeight: 0,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    labelColor: kAppleTextPrimary,
                    unselectedLabelColor: kAppleTextSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: const [
                      Tab(text: 'Schedule'),
                      Tab(text: 'Groups'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // TabBarView: Schedule Tab & Groups Tab
              Expanded(
                child: TabBarView(
                  children: [
                    allUsersAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: kAppleBlue),
                      ),
                      error: (err, _) => Center(
                        child: Text(
                          'Error loading users: $err',
                          style: const TextStyle(color: kAppleError),
                        ),
                      ),
                      data: (users) => _buildAdminScheduleTab(
                        context,
                        user,
                        adminEntries,
                        users,
                      ),
                    ),
                    // Groups Tab (keeps existing group functionality)
                    TimetableScheduleView(
                      entries: adminEntries,
                      initialTabIndex: 1,
                      showBackButton: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminScheduleTab(
    BuildContext context,
    AppUser user,
    List<TimetableEntry> adminEntries,
    List<SavedUserTimetable> allUsers,
  ) {
    final otherUsers = allUsers.where((u) => u.ownerId != user.id).toList();

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            _selectedUserIds.length >= 2 ? 96 : 32,
          ),
          children: [
            // Section Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      _selectionMode
                          ? 'SELECT PEOPLE • ${_selectedUserIds.length} SELECTED'
                          : 'ALL TIMETABLES',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kAppleTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _selectionMode
                          ? 'Select 2+ to combine'
                          : 'Long-press to select',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kAppleTextTertiary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // 1. 👤 My Timetable (Admin)
            _buildUserWidgetCard(
              id: 'admin_self',
              displayName: 'My Timetable (Admin)',
              subtitle: adminEntries.isNotEmpty
                  ? '${adminEntries.length} weekly classes loaded'
                  : 'Tap to import your classes',
              avatarIcon: Icons.admin_panel_settings_rounded,
              avatarBg: const Color(0xFFE0F2FE),
              avatarText: kAppleBlue,
              entries: adminEntries,
              isSelected: _selectedUserIds.contains('admin_self') ||
                  _selectedUserIds.contains(user.id),
              onTap: () {
                if (_selectionMode) {
                  _toggleUserSelection('admin_self');
                } else {
                  if (adminEntries.isNotEmpty) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TimetableScheduleView(
                          entries: adminEntries,
                          customTitle: 'My Timetable (Admin)',
                          showBackButton: true,
                          hideGroupsTab: true,
                        ),
                      ),
                    );
                  } else {
                    setState(() => _forceImportView = true);
                  }
                }
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _selectionMode = true;
                  _selectedUserIds.add('admin_self');
                });
              },
            ),
            const SizedBox(height: 10),

            // 2. 👤 Individual users
            for (final u in otherUsers) ...[
              _buildUserWidgetCard(
                id: u.ownerId,
                displayName: u.displayName,
                subtitle: '${u.entries.length} weekly classes',
                initial: u.displayName.isNotEmpty
                    ? u.displayName.substring(0, 1).toUpperCase()
                    : 'U',
                avatarBg: _avatarColorFor(u.displayName).$1,
                avatarText: _avatarColorFor(u.displayName).$2,
                entries: u.entries,
                isSelected: _selectedUserIds.contains(u.ownerId),
                onTap: () {
                  if (_selectionMode) {
                    _toggleUserSelection(u.ownerId);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TimetableScheduleView(
                          entries: u.entries,
                          customTitle: "${u.displayName}'s Timetable",
                          showBackButton: true,
                          hideGroupsTab: true,
                        ),
                      ),
                    );
                  }
                },
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _selectionMode = true;
                    _selectedUserIds.add(u.ownerId);
                  });
                },
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),

        // Bottom action bar when at least two people are selected
        if (_selectedUserIds.length >= 2)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kAppleBorderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        size: 15,
                        color: kAppleBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Selected: ${_selectedUserIds.length} people',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kAppleTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: kAppleBlue,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      onPressed: () => _openCombinedTimetable(
                        context,
                        user,
                        adminEntries,
                        allUsers,
                      ),
                      icon: const Icon(Icons.grid_view_rounded, size: 15),
                      label: const Text(
                        'View Combined Timetable',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserWidgetCard({
    required String id,
    required String displayName,
    required String subtitle,
    required List<TimetableEntry> entries,
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
    IconData? avatarIcon,
    String? initial,
    required Color avatarBg,
    required Color avatarText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? kAppleBlue : kAppleBorderLight,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.04 : 0.015),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: avatarBg,
                  child: avatarIcon != null
                      ? Icon(avatarIcon, color: avatarText, size: 20)
                      : Text(
                          initial ?? 'U',
                          style: TextStyle(
                            color: avatarText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(width: 14),

                // Name and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: kAppleTextPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: kAppleTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing: Tick mark or Chevron
                if (_selectionMode)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? kAppleBlue : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? kAppleBlue : const Color(0xFFC7C7CC),
                        width: 1.8,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFC7C7CC),
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleUserSelection(String id) {
    setState(() {
      if (_selectedUserIds.contains(id)) {
        _selectedUserIds.remove(id);
        if (_selectedUserIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedUserIds.add(id);
      }
    });
  }

  static const _avatarColorPalettes = [
    (Color(0xFFE0F2FE), Color(0xFF0369A1)),
    (Color(0xFFFEF7E0), Color(0xFFB06000)),
    (Color(0xFFE8F7EC), Color(0xFF248A3D)),
    (Color(0xFFF3E8FD), Color(0xFF7E22CE)),
    (Color(0xFFFEE8E6), Color(0xFFC5221F)),
    (Color(0xFFEDE9FE), Color(0xFF5B21B6)),
  ];

  (Color, Color) _avatarColorFor(String name) {
    final idx = name.hashCode.abs() % _avatarColorPalettes.length;
    return _avatarColorPalettes[idx];
  }

  void _openCombinedTimetable(
    BuildContext context,
    AppUser admin,
    List<TimetableEntry> adminEntries,
    List<SavedUserTimetable> allUsers,
  ) {
    final List<SquadMember> members = [];

    // If admin is selected
    if (_selectedUserIds.contains('admin_self') || _selectedUserIds.contains(admin.id)) {
      members.add(
        SquadMember(
          id: admin.id,
          name: 'My Timetable (Admin)',
          initial: 'A',
          branch: 'ADMIN',
          avatarBg: const Color(0xFFE0F2FE),
          avatarText: kAppleBlue,
          busySlots: adminEntries.map((e) => e.slotCode).toSet().toList(),
        ),
      );
    }

    // Add selected users
    for (final u in allUsers) {
      if (_selectedUserIds.contains(u.ownerId)) {
        final colors = _avatarColorFor(u.displayName);
        members.add(
          SquadMember(
            id: u.ownerId,
            name: u.displayName,
            initial: u.displayName.isNotEmpty
                ? u.displayName.substring(0, 1).toUpperCase()
                : 'U',
            branch: 'VIT',
            avatarBg: colors.$1,
            avatarText: colors.$2,
            busySlots: u.entries.map((e) => e.slotCode).toSet().toList(),
          ),
        );
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimetableScheduleView(
          entries: const [],
          initialSquadMembers: members,
          isCombinedOnly: true,
          showBackButton: true,
          customTitle: 'Combined Timetable (${members.length})',
        ),
      ),
    );
  }

  Widget _adminGrid(List<TimetableEntry> entries) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kAppleBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MASTER TIMETABLE MATRIX',
              style: TextStyle(
                color: kAppleTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Horizontal view of all Monday–Friday theory & lab slot hours.',
              style: TextStyle(color: kAppleTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(110),
                columnWidths: const {0: FixedColumnWidth(80)},
                border: TableBorder.all(color: kAppleBorderLight),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: kAppleSurface),
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'DAY',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kAppleTextSecondary),
                        ),
                      ),
                      for (var column = 0; column < 12; column++)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            theoryStarts[column].isEmpty
                                ? 'Lunch'
                                : '${theoryStarts[column]}–${theoryEnds[column]}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  for (var day = 1; day <= 5; day++) ...[
                    for (final lab in [false, true])
                      TableRow(
                        children: [
                          Container(
                            color: kAppleSurface,
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${_days[day - 1]}\n${lab ? 'Lab' : 'Theory'}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kAppleTextPrimary),
                            ),
                          ),
                          for (var column = 0; column < 12; column++)
                            _gridCell(entries, day, column, lab),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _gridCell(
    List<TimetableEntry> entries,
    int day,
    int column,
    bool lab,
  ) {
    final code = day > 5
        ? ''
        : lab
            ? labCode(day, column)
            : theoryRows[day - 1][column];
    final matches = entries
        .where((e) => e.day == day && e.slotCode == code)
        .toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      color: matches.isEmpty ? Colors.white : const Color(0xFFE8F7EC),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code.isEmpty ? '—' : code,
            style: const TextStyle(fontSize: 11, color: kAppleTextSecondary, fontWeight: FontWeight.w600),
          ),
          for (final entry in matches)
            InkWell(
              onTap: () => _details(entry),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${entry.courseCode}\n${entry.venue}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF248A3D),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _details(TimetableEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entry.course,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kAppleTextPrimary),
              ),
              const SizedBox(height: 4),
              Text('${entry.courseCode} · ${entry.slotCode}', style: const TextStyle(color: kAppleBlue, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: kAppleTextSecondary),
                title: Text('${_days[entry.day - 1]} · ${entry.startTime}–${entry.endTime}'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, color: kAppleTextSecondary),
                title: Text(entry.teacher.isNotEmpty ? entry.teacher : 'Faculty: NIL'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined, color: kAppleTextSecondary),
                title: Text(entry.venue.isNotEmpty ? entry.venue : 'Room: NIL'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
