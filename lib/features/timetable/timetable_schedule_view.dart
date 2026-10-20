import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart' as api;
import '../../core/theme.dart';
import 'group_manage_screen.dart';
import 'slot_pattern.dart';
import 'timetable_entry.dart';

// ── Design tokens & Apple constants ──────────────────────────────────────────

const _dayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
const _dayFull = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];

/// Data model representing a standard college timetable slot across the day.
class FullComparisonSlot {
  final int column;
  final String slotCode;
  final String startTime;
  final String endTime;
  final String label;

  const FullComparisonSlot({
    required this.column,
    required this.slotCode,
    required this.startTime,
    required this.endTime,
    required this.label,
  });
}

/// Member data for study squad comparison.
class SquadMember {
  final String id;
  final String name;
  final String initial;
  final String branch;
  final Color avatarBg;
  final Color avatarText;
  final List<String> busySlots; // slot codes where they have class

  const SquadMember({
    required this.id,
    required this.name,
    required this.initial,
    required this.branch,
    required this.avatarBg,
    required this.avatarText,
    required this.busySlots,
  });

  factory SquadMember.fromJson(Map<String, dynamic> json) {
    final nameStr = json['name']?.toString() ?? 'Member';
    return SquadMember(
      id: json['id']?.toString() ?? '',
      name: nameStr,
      initial: nameStr.isNotEmpty ? nameStr.substring(0, 1).toUpperCase() : 'M',
      branch: json['branch']?.toString() ?? 'ENG',
      avatarBg: const Color(0xFFE0F2FE),
      avatarText: const Color(0xFF0369A1),
      busySlots: (json['busySlots'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

// ── Widget ───────────────────────────────────────────────────────────────────

/// Apple-grade Timetable Schedule View following design.md:
/// - Pure white & F5F5F7 surfaces with Apple Blue (#0071E3) interactivity.
/// - Full 11-slot comparison matrix with sticky member column.
/// - Equal spacing, zero overflow, and fluid responsiveness.
class TimetableScheduleView extends StatefulWidget {
  final List<TimetableEntry> entries;
  final VoidCallback? onReimport;
  final String? initialSquadCode;
  final List<SquadMember>? initialSquadMembers;
  final int initialTabIndex;
  final String? customTitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool isCombinedOnly;
  final bool hideGroupsTab;

  const TimetableScheduleView({
    super.key,
    required this.entries,
    this.onReimport,
    this.initialSquadCode,
    this.initialSquadMembers,
    this.initialTabIndex = 0,
    this.customTitle,
    this.showBackButton = false,
    this.onBack,
    this.isCombinedOnly = false,
    this.hideGroupsTab = false,
  });

  @override
  State<TimetableScheduleView> createState() => _TimetableScheduleViewState();
}

class _TimetableScheduleViewState extends State<TimetableScheduleView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late DateTime _selected;
  late List<DateTime> _week;
  final ScrollController _comparisonScroll = ScrollController();

  late String _squadCode;
  late List<SquadMember> _squadMembers;
  bool _isDemoSquad = false;

  @override
  void initState() {
    super.initState();
    final tabCount = (widget.isCombinedOnly || widget.hideGroupsTab) ? 1 : 2;
    final initialTab = (widget.isCombinedOnly || widget.hideGroupsTab)
        ? 0
        : widget.initialTabIndex.clamp(0, 1);
    _tabs = TabController(length: tabCount, vsync: this, initialIndex: initialTab);
    final now = DateTime.now();
    // Monday–Friday strictly (1–5)
    if (now.weekday > 5) {
      _selected = now.add(Duration(days: 8 - now.weekday));
    } else {
      _selected = now;
    }
    _buildWeek();
    _squadCode = widget.initialSquadCode ?? 'K8M2-9PL4';
    if (widget.initialSquadMembers != null) {
      _squadMembers = List.from(widget.initialSquadMembers!);
      _isDemoSquad = false;
    } else {
      _initDemoSquad();
      _isDemoSquad = true;
    }
  }

  void _initDemoSquad() {
    _squadMembers = const [
      SquadMember(
        id: 'arav',
        name: 'Arav',
        initial: 'A',
        branch: 'CSE',
        avatarBg: Color(0xFFFEF7E0),
        avatarText: Color(0xFFB06000),
        busySlots: ['F1', 'D1', 'A2', 'TB2', 'B1', 'C2', 'TD2'],
      ),
      SquadMember(
        id: 'ram',
        name: 'Ram',
        initial: 'R',
        branch: 'ECE',
        avatarBg: Color(0xFFE8F7EC),
        avatarText: Color(0xFF248A3D),
        busySlots: ['A1', 'TG1', 'F2', 'B2', 'G1', 'TC1', 'V5'],
      ),
      SquadMember(
        id: 'sarah',
        name: 'Sarah',
        initial: 'S',
        branch: 'IT',
        avatarBg: Color(0xFFF3E8FD),
        avatarText: Color(0xFF7E22CE),
        busySlots: ['TB1', 'D2', 'TG2', 'E1', 'TAA1', 'F1', 'TE2'],
      ),
      SquadMember(
        id: 'priya',
        name: 'Priya',
        initial: 'P',
        branch: 'AIML',
        avatarBg: Color(0xFFFEE8E6),
        avatarText: Color(0xFFC5221F),
        busySlots: ['D1', 'A2', 'V3', 'TC1', 'G2', 'B1', 'TCC2'],
      ),
      SquadMember(
        id: 'arjun',
        name: 'Arjun',
        initial: 'A',
        branch: 'MECH',
        avatarBg: Color(0xFFE0F2FE),
        avatarText: Color(0xFF0369A1),
        busySlots: ['A1', 'F1', 'TB1', 'B2', 'E2', 'C1', 'TA1'],
      ),
    ];
  }

  Future<void> _joinSquad(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return;
    setState(() {
      _squadCode = clean;
    });
    try {
      final res = await api.getSquad(clean);
      if (res != null && res['members'] is List) {
        final membersList = (res['members'] as List)
            .map((m) => SquadMember.fromJson(m as Map<String, dynamic>))
            .toList();
        setState(() {
          _squadMembers = membersList;
          _isDemoSquad = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to squad $clean (${membersList.length} members)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } catch (_) {}
    setState(() {
      _isDemoSquad = false;
      _squadMembers = [];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Squad $clean active. Share code with peers to sync timetables.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showJoinSquadDialog() {
    final controller = TextEditingController(text: _squadCode);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter Study Squad Code', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a shared squad code to connect with peer schedules from the backend.',
              style: TextStyle(fontSize: 13, color: kAppleTextSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. K8M2-9PL4',
                prefixIcon: const Icon(Icons.group_rounded, color: kAppleBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kAppleTextSecondary)),
          ),
          FilledButton(
            onPressed: () {
              final code = controller.text.trim();
              Navigator.pop(ctx);
              if (code.isNotEmpty) {
                _joinSquad(code);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: kAppleBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _buildWeek() {
    final mon = _selected.subtract(Duration(days: _selected.weekday - 1));
    _week = List.generate(5, (i) => mon.add(Duration(days: i)));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _comparisonScroll.dispose();
    super.dispose();
  }

  // ── Helper: Get All 11 Slots for Day ──────────────────────────────────────

  List<FullComparisonSlot> _getDaySlots(int day) {
    const validCols = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
    final dayIndex = (day - 1).clamp(0, 4);
    final row = theoryRows[dayIndex];

    return validCols.map((col) {
      final code = row[col];
      final start = theoryStarts[col];
      final end = theoryEnds[col];
      return FullComparisonSlot(
        column: col,
        slotCode: code.isNotEmpty ? code : 'S$col',
        startTime: start,
        endTime: end,
        label: '$start–$end',
      );
    }).toList();
  }

  bool _isUserFreeInSlot(FullComparisonSlot slot, int day) {
    final slotStart = TimetableEntry.minutes(slot.startTime);
    final slotEnd = TimetableEntry.minutes(slot.endTime);
    for (final e in widget.entries) {
      if (e.day == day) {
        if (e.slotCode == slot.slotCode) return false;
        if (e.startMinute < slotEnd && e.endMinute > slotStart) return false;
      }
    }
    return true;
  }

  TimetableEntry? _getUserClassInSlot(FullComparisonSlot slot, int day) {
    final slotStart = TimetableEntry.minutes(slot.startTime);
    final slotEnd = TimetableEntry.minutes(slot.endTime);
    for (final e in widget.entries) {
      if (e.day == day) {
        if (e.slotCode == slot.slotCode ||
            (e.startMinute < slotEnd && e.endMinute > slotStart)) {
          return e;
        }
      }
    }
    return null;
  }

  // ── Root Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAppleSurface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Apple Top Navigation Bar
            _buildTopBar(),
            const SizedBox(height: 12),

            // Apple Segmented Control (Pill)
            if (!widget.isCombinedOnly && !widget.hideGroupsTab) ...[
              _buildSegmentedTabs(),
              const SizedBox(height: 12),
            ],

            // Main Tab View
            Expanded(
              child: widget.isCombinedOnly
                  ? _buildGroupsTab()
                  : widget.hideGroupsTab
                      ? _buildMyScheduleTab()
                      : TabBarView(
                          controller: _tabs,
                          children: [
                            _buildMyScheduleTab(),
                            _buildGroupsTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Navigation Bar ─────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: kAppleSurface,
      child: Row(
        children: [
          if (widget.showBackButton)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onBack ?? () => Navigator.of(context).maybePop(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kAppleBlue),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: kAppleBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (widget.onReimport != null)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onReimport,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kAppleBlue),
                    SizedBox(width: 4),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: kAppleBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Text(
              widget.customTitle ?? 'Timetable',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kAppleTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ),
          if (!widget.isCombinedOnly)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GroupManageScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Group', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: kAppleBlue,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ── Segmented Control (Pill) ───────────────────────────────────────────────

  Widget _buildSegmentedTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E9EC),
          borderRadius: BorderRadius.circular(999),
        ),
        child: TabBar(
          controller: _tabs,
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
          tabAlignment: TabAlignment.fill,
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
            Tab(text: 'My Schedule'),
            Tab(text: 'Groups'),
          ],
        ),
      ),
    );
  }

  // ── My Schedule Tab ────────────────────────────────────────────────────────

  Widget _buildMyScheduleTab() {
    final day = _selected.weekday > 5 ? 1 : _selected.weekday;
    final classes = widget.entries.where((e) => e.day == day).toList()
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Horizontal Day Selector
        _buildDaySelector(),
        const SizedBox(height: 20),

        // Section Title: "MONDAY • 4 CLASSES"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${_dayFull[day - 1].toUpperCase()} • ${classes.length} CLASS${classes.length == 1 ? '' : 'ES'}',
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
              Text(
                '${widget.entries.length} weekly loaded',
                style: const TextStyle(
                  color: kAppleTextTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (classes.isEmpty)
          _buildEmptyDay(day)
        else
          for (var i = 0; i < classes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildClassCard(classes[i]),
            ),
      ],
    );
  }

  // ── Horizontal Day Selector ────────────────────────────────────────────────

  Widget _buildDaySelector() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAppleBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_week.length, (i) {
          final d = _week[i];
          final isSelected = d.year == _selected.year &&
              d.month == _selected.month &&
              d.day == _selected.day;
          final isToday = d.year == now.year &&
              d.month == now.month &&
              d.day == now.day;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() {
                _selected = d;
                _buildWeek();
              }),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayAbbr[i],
                    style: TextStyle(
                      color: isSelected ? kAppleBlue : kAppleTextSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isSelected ? kAppleBlue : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${d.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : kAppleTextPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (isToday)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? kAppleBlue : kAppleTextTertiary,
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Class Card (Apple Style – minimal: code + time) ────────────────────────

  Widget _buildClassCard(TimetableEntry entry) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAppleBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showClassDetails(entry),
          onDoubleTap: () => _showClassDetails(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Course Code (prominent)
                Text(
                  entry.courseCode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kAppleTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 10),
                // Slot badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAppleBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.slotCode,
                    style: const TextStyle(
                      color: kAppleBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Time
                const Icon(Icons.schedule_rounded, size: 14, color: kAppleTextSecondary),
                const SizedBox(width: 4),
                Text(
                  '${entry.startTime} – ${entry.endTime}',
                  style: const TextStyle(
                    color: kAppleTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 18, color: kAppleTextTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty Day View ─────────────────────────────────────────────────────────

  Widget _buildEmptyDay(int day) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAppleBorderLight),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: kAppleSuccess.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 28,
              color: kAppleSuccess,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No classes on ${_dayFull[day - 1]}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kAppleTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enjoy your free time or schedule a study session with your squad.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: kAppleTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Groups Tab ─────────────────────────────────────────────────────────────

  Widget _buildGroupsTab() {
    final day = _selected.weekday > 5 ? 1 : _selected.weekday;
    final daySlots = _getDaySlots(day);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 1. Study Squad / Combined Info Card
        if (widget.isCombinedOnly)
          _buildCombinedInfoCard()
        else
          _buildStudySquadCard(),
        const SizedBox(height: 16),

        // 2. Day Selector for Schedule Matrix
        _buildDaySelector(),
        const SizedBox(height: 16),

        // 3. FULL TIMETABLE COMPARISON CARD (All 12 slots)
        _buildFullComparisonCard(day, daySlots),
        const SizedBox(height: 16),

        // 4. Recreation / Playtime Card
        _buildPlaytimeCard(),
      ],
    );
  }

  Widget _buildCombinedInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAppleBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
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
            child: Text(
              '${_squadMembers.length} MEMBERS SELECTED',
              style: const TextStyle(
                color: kAppleBlue,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Combined Timetable',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kAppleTextPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Comparing schedules for ${_squadMembers.map((m) => m.name).join(", ")}',
            style: const TextStyle(
              color: kAppleTextSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final m in _squadMembers) ...[
                  _buildAvatarPill(m.name, m.initial, m.avatarText, m.avatarBg),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Study Squad Info Card ──────────────────────────────────────────────────

  Widget _buildStudySquadCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAppleBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title & Subtitle (Manage button removed as requested)
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Study Squad',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kAppleTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '6 active members · 4 free right now',
                style: TextStyle(
                  color: kAppleTextSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Squad Code Box (Equal Spacing, No Overflow, Apple Design)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kAppleSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kAppleBorderLight),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 260;
                final codeColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        const Icon(Icons.key_rounded, size: 13, color: kAppleBlue),
                        const Text(
                          'SQUAD CODE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: kAppleTextSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (_isDemoSquad)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'SAMPLE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _squadCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kAppleTextPrimary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                );

                final buttons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: _squadCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Squad Code $_squadCode copied!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: kAppleBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded, size: 13, color: kAppleBlue),
                            SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kAppleBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _showJoinSquadDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: kAppleBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 14, color: kAppleBlue),
                            SizedBox(width: 4),
                            Text(
                              'Switch',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kAppleBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      codeColumn,
                      const SizedBox(height: 10),
                      buttons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: codeColumn),
                    buttons,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Member Avatars Row with Horizontal Scroll (Zero Overflow, Equal Spacing)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildAvatarPill('You', 'Y', kAppleBlue, kAppleBlue.withValues(alpha: 0.1)),
                const SizedBox(width: 8),
                for (final m in _squadMembers) ...[
                  _buildAvatarPill(m.name, m.initial, m.avatarText, m.avatarBg),
                  const SizedBox(width: 8),
                ],
                if (_squadMembers.isEmpty) ...[
                  InkWell(
                    onTap: _showJoinSquadDialog,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kAppleSurface,
                        border: Border.all(color: kAppleBorder),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 14, color: kAppleBlue),
                          SizedBox(width: 4),
                          Text(
                            'Invite peers',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kAppleBlue),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarPill(String name, String initial, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 8,
            backgroundColor: textColor,
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            name,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── FULL TIMETABLE COMPARISON CARD (ALL 11 SLOTS) ───────────────────────────

  Widget _buildFullComparisonCard(int day, List<FullComparisonSlot> slots) {
    final dayName = _dayFull[day - 1];

    // Compute best overlapping slots across all members
    final freeCountPerSlot = slots.map((slot) {
      int freeCount = _isUserFreeInSlot(slot, day) ? 1 : 0;
      for (final m in _squadMembers) {
        if (!m.busySlots.contains(slot.slotCode)) {
          freeCount++;
        }
      }
      return freeCount;
    }).toList();

    int maxFree = 0;
    String bestSlotName = slots.isNotEmpty ? '${slots.first.startTime} (${slots.first.slotCode})' : '';
    for (var i = 0; i < slots.length; i++) {
      if (freeCountPerSlot[i] > maxFree) {
        maxFree = freeCountPerSlot[i];
        bestSlotName = '${slots[i].startTime} (${slots[i].slotCode})';
      }
    }

    return Container(
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayName Schedule Matrix',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: kAppleTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All ${slots.length} slots • ${_squadMembers.length + 1} members${_isDemoSquad ? ' (Sample Overlap)' : ''}',
                      style: const TextStyle(color: kAppleTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kAppleBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${slots.length} Slots',
                  style: const TextStyle(
                    color: kAppleBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Overlap Insight Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kAppleSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: kAppleBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Peak overlap: $bestSlotName with $maxFree/6 free. Tap cell for details.',
                    style: const TextStyle(
                      color: kAppleTextSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Synchronized Two-Pane Table with Frozen Member Column
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kAppleBorderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. LEFT FROZEN COLUMN (Members)
                SizedBox(
                  width: 96,
                  child: Column(
                    children: [
                      // Header Cell
                      Container(
                        height: 48,
                        color: kAppleSurface,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 10),
                        child: const Text(
                          'MEMBER',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kAppleTextSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Divider(height: 1, thickness: 1, color: kAppleBorderLight),

                      // User "You" Row
                      _buildFrozenMemberCell('You', 'Y', kAppleBlue, kAppleBlue.withValues(alpha: 0.1), isYou: true),
                      const Divider(height: 1, thickness: 1, color: kAppleBorderLight),

                      // Squad Members Rows
                      for (var i = 0; i < _squadMembers.length; i++) ...[
                        _buildFrozenMemberCell(
                          _squadMembers[i].name,
                          _squadMembers[i].initial,
                          _squadMembers[i].avatarText,
                          _squadMembers[i].avatarBg,
                        ),
                        if (i < _squadMembers.length - 1)
                          const Divider(height: 1, thickness: 1, color: kAppleBorderLight),
                      ],
                    ],
                  ),
                ),

                const VerticalDivider(width: 1, thickness: 1, color: kAppleBorderLight),

                // 2. RIGHT SCROLLABLE GRID (All 11 slots)
                Expanded(
                  child: SingleChildScrollView(
                    controller: _comparisonScroll,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Slot Headers
                        Container(
                          height: 48,
                          color: kAppleSurface,
                          child: Row(
                            children: [
                              for (var colIdx = 0; colIdx < slots.length; colIdx++) ...[
                                Container(
                                  width: 88,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        slots[colIdx].slotCode,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: kAppleTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        slots[colIdx].startTime,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: kAppleTextSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (colIdx < slots.length - 1)
                                  Container(width: 1, height: 48, color: kAppleBorderLight),
                              ],
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1, color: kAppleBorderLight),

                        // "You" Status Row
                        Row(
                          children: [
                            for (var colIdx = 0; colIdx < slots.length; colIdx++) ...[
                              _buildStatusCell(
                                isFree: _isUserFreeInSlot(slots[colIdx], day),
                                onTap: () => _showCellDetails(slots[colIdx], day, 'You', true),
                              ),
                              if (colIdx < slots.length - 1)
                                Container(width: 1, height: 46, color: kAppleBorderLight),
                            ],
                          ],
                        ),
                        const Divider(height: 1, thickness: 1, color: kAppleBorderLight),

                        // Squad Members Status Rows
                        for (var mIdx = 0; mIdx < _squadMembers.length; mIdx++) ...[
                          Row(
                            children: [
                              for (var colIdx = 0; colIdx < slots.length; colIdx++) ...[
                                _buildStatusCell(
                                  isFree: !_squadMembers[mIdx].busySlots.contains(slots[colIdx].slotCode),
                                  onTap: () => _showCellDetails(
                                    slots[colIdx],
                                    day,
                                    _squadMembers[mIdx].name,
                                    !_squadMembers[mIdx].busySlots.contains(slots[colIdx].slotCode),
                                  ),
                                ),
                                if (colIdx < slots.length - 1)
                                  Container(width: 1, height: 46, color: kAppleBorderLight),
                              ],
                            ],
                          ),
                          if (mIdx < _squadMembers.length - 1)
                            const Divider(height: 1, thickness: 1, color: kAppleBorderLight),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Legend
          const Row(
            children: [
              Text('Legend: ', style: TextStyle(color: kAppleTextSecondary, fontSize: 12)),
              SizedBox(width: 4),
              Icon(Icons.circle, size: 8, color: kAppleSuccess),
              SizedBox(width: 4),
              Text('Free', style: TextStyle(color: kAppleTextSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              SizedBox(width: 12),
              Icon(Icons.circle, size: 8, color: kAppleTextTertiary),
              SizedBox(width: 4),
              Text('In Class', style: TextStyle(color: kAppleTextSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFrozenMemberCell(String name, String initial, Color textColor, Color bgColor, {bool isYou = false}) {
    return Container(
      height: 46,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: bgColor,
            child: Text(
              initial,
              style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isYou ? FontWeight.w700 : FontWeight.w600,
                color: isYou ? kAppleBlue : kAppleTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell({required bool isFree, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 46,
        color: Colors.white,
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isFree ? const Color(0xFFE8F7EC) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isFree ? 'Free' : 'Class',
            style: TextStyle(
              color: isFree ? const Color(0xFF248A3D) : kAppleTextSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ── Recreation / Playtime Card ─────────────────────────────────────────────

  Widget _buildPlaytimeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kAppleBorderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Recreation & Sports',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kAppleTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kAppleSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('Playtime', style: TextStyle(color: kAppleTextSecondary, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Next free slot for squad games: Tomorrow at 5:00 PM',
                  style: TextStyle(color: kAppleTextSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kAppleTextTertiary),
        ],
      ),
    );
  }

  // ── Bottom Sheet Modals ────────────────────────────────────────────────────

  void _showClassDetails(TimetableEntry entry) {
    final slotToDisplay = entry.registrationSlot?.isNotEmpty == true
        ? entry.registrationSlot!
        : entry.slotCode;
    final timeStr = '${entry.startTime} – ${entry.endTime}';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COURSE DETAILS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kAppleTextSecondary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.courseName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: kAppleTextPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: kAppleTextSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                decoration: BoxDecoration(
                  color: kAppleSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kAppleBorderLight),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCourseDetailTile('Course Name', entry.courseName, Icons.book_outlined),
                    const Divider(height: 18, color: kAppleBorderLight),
                    _buildCourseDetailTile('Course Code', entry.courseCode, Icons.tag_rounded),
                    const Divider(height: 18, color: kAppleBorderLight),
                    _buildCourseDetailTile('Faculty', entry.facultyName.isNotEmpty ? entry.facultyName : 'NIL', Icons.person_outline_rounded),
                    const Divider(height: 18, color: kAppleBorderLight),
                    _buildCourseDetailTile('Slot', slotToDisplay, Icons.grid_view_rounded),
                    const Divider(height: 18, color: kAppleBorderLight),
                    _buildCourseDetailTile('Venue', entry.venue.isNotEmpty ? entry.venue : 'NIL', Icons.location_on_outlined),
                    const Divider(height: 18, color: kAppleBorderLight),
                    _buildCourseDetailTile('Time', '${_dayFull[entry.day - 1]} · $timeStr', Icons.schedule_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kAppleBlue,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseDetailTile(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: kAppleBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kAppleTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: kAppleTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCellDetails(FullComparisonSlot slot, int day, String memberName, bool isFree) {
    final dayName = _dayFull[day - 1];
    final userClass = _getUserClassInSlot(slot, day);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$dayName • ${slot.startTime}–${slot.endTime}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: kAppleTextPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Slot ${slot.slotCode} Overview',
                style: const TextStyle(color: kAppleTextSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kAppleSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$memberName Status:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isFree ? const Color(0xFFE8F7EC) : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isFree ? 'Free / Available' : 'In Class',
                            style: TextStyle(
                              color: isFree ? const Color(0xFF248A3D) : kAppleTextSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (userClass != null && memberName == 'You') ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Your Course: ${userClass.course} (${userClass.courseCode}) at ${userClass.venue}',
                          style: const TextStyle(color: kAppleTextSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Study session invite created for ${slot.startTime}!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.group_add_rounded, size: 18),
                label: const Text('Invite Squad to Study in this Slot'),
                style: FilledButton.styleFrom(
                  backgroundColor: kAppleBlue,
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
