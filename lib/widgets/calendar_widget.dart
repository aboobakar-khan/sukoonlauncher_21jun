import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import '../providers/prayer_provider.dart';
import '../providers/theme_provider.dart';
import '../models/prayer_record.dart';
import '../providers/friday_sunnah_provider.dart';
import '../providers/productivity_provider.dart';
import '../models/productivity_models.dart';

const _shortDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

// ─── Islamic Events Model ────────────────────────────────────────────────────
class _HijriEvent {
  final int hijriDay;
  final int hijriMonth;
  final String hijriMonthName;
  final String hijriDateDisplay;
  final String eventName;
  final String shortDescription;
  final String importance;
  final String category;
  final String authenticityNote;

  const _HijriEvent({
    required this.hijriDay,
    required this.hijriMonth,
    required this.hijriMonthName,
    required this.hijriDateDisplay,
    required this.eventName,
    required this.shortDescription,
    required this.importance,
    required this.category,
    required this.authenticityNote,
  });

  factory _HijriEvent.fromJson(Map<String, dynamic> json) => _HijriEvent(
    hijriDay: json['hijri_day'] as int,
    hijriMonth: json['hijri_month'] as int,
    hijriMonthName: json['hijri_month_name'] as String,
    hijriDateDisplay: json['hijri_date_display'] as String,
    eventName: json['event_name'] as String,
    shortDescription: json['short_description'] as String,
    importance: json['importance'] as String,
    category: json['category'] as String,
    authenticityNote: json['authenticity_note'] as String,
  );

  String get categoryEmoji => switch (category) {
    'Worship' => '🤲',
    'Battle' => '⚔️',
    'Historical' => '📜',
    "Prophet's Life" => '🕌',
    'Calendar' => '🌙',
    _ => '✨',
  };
}

// Static cache for loaded events
Map<String, List<_HijriEvent>>? _loadedEvents;

Future<Map<String, List<_HijriEvent>>> _loadHijriEvents() async {
  if (_loadedEvents != null) return _loadedEvents!;
  try {
    final data = await rootBundle.loadString('assets/islamic_hijri_events.json');
    final list = (jsonDecode(data) as List)
        .map((e) => _HijriEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    final map = <String, List<_HijriEvent>>{};
    for (final event in list) {
      final key = '${event.hijriMonth}-${event.hijriDay}';
      map.putIfAbsent(key, () => []).add(event);
    }
    _loadedEvents = map;
    return map;
  } catch (_) {
    _loadedEvents = {};
    return {};
  }
}

// Quick lookup for the simple occasion dot on date cells
const Map<String, Map<String, String>> _islamicOccasions = {
  '1-1': {'name': 'Islamic New Year', 'emoji': '🌙'},
  '1-10': {'name': 'Day of Ashura', 'emoji': '🤲'},
  '3-12': {'name': 'Mawlid al-Nabi ﷺ', 'emoji': '🕌'},
  '7-27': {'name': "Isra' Mi'raj", 'emoji': '✨'},
  '8-1': {'name': 'Sha\'ban — Sunnah Fasting', 'emoji': '🌙'},
  '8-15': {'name': 'Laylat al-Bara\'ah', 'emoji': '🌕'},
  '9-1': {'name': 'Ramadan Begins', 'emoji': '🌙'},
  '9-17': {'name': 'Battle of Badr', 'emoji': '⚔️'},
  '9-27': {'name': 'Laylat al-Qadr', 'emoji': '⭐'},
  '10-1': {'name': 'Eid al-Fitr', 'emoji': '🎉'},
  '12-1': {'name': 'Dhul Hijjah — Best Days', 'emoji': '🕋'},
  '12-8': {'name': 'Day of Tarwiyah', 'emoji': '🕋'},
  '12-9': {'name': 'Day of Arafah', 'emoji': '🤲'},
  '12-10': {'name': 'Eid al-Adha', 'emoji': '🐪'},
};

bool _isSunnahFast(HijriCalendar h, DateTime g) {
  if (g.weekday == DateTime.monday || g.weekday == DateTime.thursday)
    return true;
  if (h.hDay == 13 || h.hDay == 14 || h.hDay == 15) return true;
  if (h.hMonth == 12 && h.hDay == 9) return true;
  if (h.hMonth == 1 && (h.hDay == 9 || h.hDay == 10)) return true;
  return false;
}

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _months = [
  'jan',
  'feb',
  'mar',
  'apr',
  'may',
  'jun',
  'jul',
  'aug',
  'sep',
  'oct',
  'nov',
  'dec',
];
const _longMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Horizontal minimalist calendar widget.
class CalendarWidget extends ConsumerStatefulWidget {
  final VoidCallback? onExpand;
  const CalendarWidget({super.key, this.onExpand});

  @override
  ConsumerState<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends ConsumerState<CalendarWidget> {
  DateTime _selectedDate = DateTime.now();
  late ScrollController _scrollCtrl;
  bool _isAutoScrolling = false;
  final int _pastDays = 365;
  final int _futureDays = 365;
  final double _itemWidth = 56.0;
  Map<String, List<_HijriEvent>> _hijriEvents = {};

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _loadHijriEvents().then((events) {
      if (mounted) setState(() => _hijriEvents = events);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(DateTime.now(), animate: false);
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToDate(DateTime date, {bool animate = true}) {
    if (!_scrollCtrl.hasClients) return;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final targetMidnight = DateTime(date.year, date.month, date.day);
    final diff = targetMidnight.difference(todayMidnight).inDays;
    final index = _pastDays + diff;

    // Calculate exact offset
    final containerWidth = _scrollCtrl.position.viewportDimension;
    // 24.0 is for the start padding of the ListView
    final offset =
        (index * _itemWidth) + 24.0 - (containerWidth / 2) + (_itemWidth / 2);

    if (animate) {
      _isAutoScrolling = true;
      _scrollCtrl
          .animateTo(
            offset,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          )
          .then((_) => _isAutoScrolling = false);
    } else {
      _scrollCtrl.jumpTo(offset);
    }
  }

  void _goToday() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() => _selectedDate = now);
    _scrollToDate(now);
  }

  bool _handleScroll(ScrollNotification notification) {
    if (_isAutoScrolling || !notification.metrics.hasPixels) return false;

    final containerWidth = notification.metrics.viewportDimension;
    if (containerWidth == 0.0) return false;

    if (notification is ScrollUpdateNotification) {
      final centerOffset = notification.metrics.pixels + (containerWidth / 2);
      final rawIndex = ((centerOffset - 24.0) / _itemWidth).floor();
      final index = rawIndex.clamp(0, _pastDays + _futureDays);

      final date = DateTime.now().subtract(Duration(days: _pastDays - index));
      if (!_isSameDay(date, _selectedDate)) {
        setState(() => _selectedDate = date);
        HapticFeedback.selectionClick();
      }
    } else if (notification is ScrollEndNotification) {
      final centerOffset = notification.metrics.pixels + (containerWidth / 2);
      final rawIndex = ((centerOffset - 24.0) / _itemWidth).round();
      final index = rawIndex.clamp(0, _pastDays + _futureDays);

      final date = DateTime.now().subtract(Duration(days: _pastDays - index));

      // Calculate where it should sit
      final targetOffset =
          (index * _itemWidth) + 24.0 - (containerWidth / 2) + (_itemWidth / 2);
      if ((notification.metrics.pixels - targetOffset).abs() > 2.0) {
        _scrollToDate(date, animate: true);
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hijriSel = HijriCalendar.fromDate(_selectedDate);
    final occasionKey = '${hijriSel.hMonth}-${hijriSel.hDay}';
    final isJummah = _selectedDate.weekday == DateTime.friday;
    final isSunFast = _isSunnahFast(hijriSel, _selectedDate);
    final events = _hijriEvents[occasionKey];
    
    final allTodos = ref.watch(todoProvider);
    final dayTodos = allTodos.where((t) => t.dueDate != null && _isSameDay(t.dueDate!, _selectedDate)).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month header & Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _goToday,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      '${_longMonths[_selectedDate.month - 1]} · ${hijriSel.longMonthName} ${hijriSel.hYear} AH',
                      style: TextStyle(
                        color: const Color(0xFF5A5A5A),
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _goToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Today', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showAddTaskDialog,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF1E1E1E),
                    ),
                    child: Icon(Icons.add, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          // Date strip
          SizedBox(
            height: 90,
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.15, 0.85, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.builder(
                  controller: _scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _pastDays + _futureDays + 1,
                  itemBuilder: (context, index) {
                    final date = DateTime.now().subtract(
                      Duration(days: _pastDays - index),
                    );
                    
                    // Check for events/tasks for this specific date in the list
                    final h = HijriCalendar.fromDate(date);
                    final hasEvent = _hijriEvents.containsKey('${h.hMonth}-${h.hDay}');
                    final hasTask = allTodos.any((t) => t.dueDate != null && _isSameDay(t.dueDate!, date));
                    
                    return _buildDateCell(date, hasEvent: hasEvent, hasTask: hasTask);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Hero section & Events
          _buildHeroAndEvents(hijriSel, isJummah, isSunFast, events, dayTodos),
        ],
      ),
    );
  }

  Widget _buildDateCell(DateTime date, {bool hasEvent = false, bool hasTask = false}) {
    final isSelected = _isSameDay(date, _selectedDate);
    final isFriday = date.weekday == DateTime.friday;
    final shortDayParts = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

    // Determine which dot to show above date (Friday overrides, else task/event)
    // Priority: Jumu'ah (gold) > Event (green) > Task (blue)
    Color? topDotColor;
    if (isFriday) {
      topDotColor = const Color(0xFFC9A84C);
    } else if (hasEvent) {
      topDotColor = const Color(0xFF4CAF50); // Fresh leaf green
    } else if (hasTask) {
      topDotColor = const Color(0xFF5B9BFF); // Blue
    }

    // Show a second dot below the first when BOTH event AND task exist
    final showSecondDot = hasEvent && hasTask;

    final isToday = _isSameDay(date, DateTime.now());

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedDate = date);
        _scrollToDate(date);
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _itemWidth,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Primary dot (Jumu'ah / Event / Task)
            Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: topDotColor ?? Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            // Date number with Today highlight
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: isToday ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC9A84C).withValues(alpha: 0.35), width: 1.5),
              ) : null,
              child: Text(
                date.day.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : (isToday ? const Color(0xFFC9A84C) : const Color(0xFF383838)),
                  fontSize: isSelected ? 26 : 20,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              shortDayParts[date.weekday - 1].toUpperCase(),
              style: TextStyle(
                color: isSelected 
                    ? const Color(0xFFC9A84C) 
                    : (isToday ? const Color(0xFFC9A84C).withValues(alpha: 0.7) : const Color(0xFF383838).withValues(alpha: 0.5)),
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : (isToday ? FontWeight.w700 : FontWeight.w600),
                letterSpacing: 0.5,
              ),
            ),
            // Second dot
            Container(
              width: 3,
              height: 3,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: showSecondDot ? const Color(0xFF5B9BFF) : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroAndEvents(HijriCalendar hijri, bool isJummah, bool isSunFast, List<_HijriEvent>? events, List<TodoItem> dayTodos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero section
          Text(
            _selectedDate.day.toString(),
            style: TextStyle(
              color: const Color(0xFFF5F5F5),
              fontSize: 72,
              fontWeight: FontWeight.w300,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_longMonths[_selectedDate.month-1]} ${_selectedDate.year}  ·  ${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH',
            style: TextStyle(
              color: const Color(0xFF5A5A5A),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          
          const SizedBox(height: 48),

          // Events
          if (events != null && events.isNotEmpty) ...[
            ...events.map((e) => _buildMinimalEvent(e.eventName, e.category, e.category == 'Worship' || e.category == 'Calendar', fullEvent: e)),
            const SizedBox(height: 24),
          ],
          
          if (dayTodos.isNotEmpty) ...[
            ...dayTodos.map((t) => _buildTodoEvent(t)),
            const SizedBox(height: 24),
          ],

          if (isJummah) _buildMinimalEvent('Jumu\'ah', 'Weekly Sacred Day', true),
          if (isSunFast) _buildMinimalEvent('Sunnah Fast', 'Recommended', true),

          // Empty state: no events, tasks or special day
          if ((events == null || events.isEmpty) && dayTodos.isEmpty && !isJummah && !isSunFast)
            GestureDetector(
              onTap: _showAddTaskDialog,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Icon(Icons.add, size: 14, color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Add a task for this day',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          if (isJummah) ...[
            const SizedBox(height: 24),
            Text(
              'Friday Sunnahs',
              style: TextStyle(
                color: const Color(0xFFC9A84C).withOpacity(0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildFridaySunnahsListMinimal(),
          ]
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showEventDetails(_HijriEvent event) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, 
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                _buildCategoryPill(event.category.toUpperCase(), const Color(0xFFF59E0B)),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              event.eventName,
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              '${event.hijriDateDisplay}  ·  ${event.importance}',
              style: TextStyle(color: const Color(0xFFC9A84C), fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Text(
              event.shortDescription,
              style: TextStyle(color: const Color(0xFFD0D0D0), fontSize: 16, height: 1.6),
            ),
            if (event.authenticityNote.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 18),
                    const SizedBox(width: 12),
                    Expanded(child: Text(event.authenticityNote, style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalEvent(String name, String category, bool isSacred, { _HijriEvent? fullEvent }) {
    return GestureDetector(
      onTap: fullEvent != null ? () => _showEventDetails(fullEvent) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 2,
                // Hijri events from JSON always get fresh leaf green; Jumu'ah/sacred keep gold
                color: fullEvent != null
                    ? const Color(0xFF4CAF50)   // fresh leaf green for JSON events
                    : isSacred
                        ? const Color(0xFFC9A84C) // gold for Jumu'ah
                        : const Color(0xFF1E1E1E),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: const Color(0xFFD0D0D0),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildCategoryPill(
                      category.toUpperCase(),
                      fullEvent != null
                          ? const Color(0xFF4CAF50)   // fresh leaf green for JSON events
                          : const Color(0xFFF59E0B),  // amber for inline events
                    ),
                  ],
                ),
              ),
              if (fullEvent != null)
                const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodoEvent(TodoItem todo) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(todoProvider.notifier).toggleTodo(todo.id);
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E1E1E),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4, 
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: Colors.white70),
                    title: Text('Edit Task', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditTaskDialog(todo);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                    title: Text('Delete Task', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      ref.read(todoProvider.notifier).deleteTodo(todo.id);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 2,
                color: todo.isCompleted ? const Color(0xFF404040) : const Color(0xFF5B9BFF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        color: todo.isCompleted ? const Color(0xFF606060) : const Color(0xFFD0D0D0),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Task',
                      style: TextStyle(
                        color: const Color(0xFF404040),
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: todo.isCompleted ? const Color(0xFF5B9BFF) : const Color(0xFF2A2A2A),
                    width: 1.5,
                  ),
                ),
                child: todo.isCompleted
                    ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF5B9BFF), shape: BoxShape.circle)))
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaskDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Task', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: Colors.white),
          cursorColor: const Color(0xFFC9A84C),
          decoration: InputDecoration(
            hintText: 'E.g., Read Quran, Call parents...',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A84C))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final txt = textController.text.trim();
              if (txt.isNotEmpty) {
                ref.read(todoProvider.notifier).addTodo(
                  title: txt,
                  dueDate: _selectedDate,
                  category: 'calendar',
                );
              }
              Navigator.pop(ctx);
            },
            child: Text('Add', style: TextStyle(color: const Color(0xFFC9A84C), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditTaskDialog(TodoItem todo) {
    final textController = TextEditingController(text: todo.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Task', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: textController,
          autofocus: true,
          style: TextStyle(color: Colors.white),
          cursorColor: const Color(0xFFC9A84C),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC9A84C))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              final txt = textController.text.trim();
              if (txt.isNotEmpty && txt != todo.title) {
                ref.read(todoProvider.notifier).updateTodo(todo.id, title: txt);
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: const Color(0xFFC9A84C), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFridaySunnahsListMinimal() {
    final sunnahs = [
      {'id': 'kahf', 'txt': 'Read Surah Kahf'},
      {'id': 'durood', 'txt': 'Send Salawat (Durood)'},
      {'id': 'ghusl', 'txt': 'Take a Ghusl (Bath)'},
      {'id': 'miswak', 'txt': 'Use Miswak & Ittar'},
    ];
    final dateKey = _dateKey(_selectedDate);
    final provider = ref.watch(fridaySunnahProvider);
    final notifier = ref.read(fridaySunnahProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sunnahs.map((sunnah) {
        final isDone = provider['${dateKey}_${sunnah['id']}'] ?? false;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            notifier.toggleSunnah(dateKey, sunnah['id']!);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? const Color(0xFFC9A84C) : const Color(0xFF2A2A2A),
                      width: 1.5,
                    ),
                  ),
                  child: isDone
                      ? Center(child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFC9A84C), shape: BoxShape.circle)))
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  sunnah['txt']!,
                  style: TextStyle(
                    color: isDone ? const Color(0xFF808080) : const Color(0xFFA0A0A0),
                    fontSize: 13,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
