import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/prayer_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/prayer_history_dashboard_redesigned.dart';

/// Prayer Tracker Widget - Professional Minimalist Design
/// 
/// Design Principles:
/// 1. Minimalist UI - Clean, uncluttered interface
/// 2. Micro-interactions - Subtle animations for engagement
/// 3. Visual Progress - Clear completion status at a glance
/// 4. Contextual Feedback - Islamic context with each prayer
/// 5. Touch Targets - 44x44px minimum for accessibility
class PrayerTrackerWidget extends ConsumerStatefulWidget {
  const PrayerTrackerWidget({super.key});

  @override
  ConsumerState<PrayerTrackerWidget> createState() => _PrayerTrackerWidgetState();
}

class _PrayerTrackerWidgetState extends ConsumerState<PrayerTrackerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Track which day we're viewing: 0 = today, 1 = yesterday
  int _selectedDayOffset = 0;
  
  // Whether nafil section is expanded
  bool _showNafil = false;

  /// Whether the pulse animation is currently running.
  bool _pulseRunning = false;

  /// Celebration overlay tracking
  bool _hasShownCelebration = false;
  int _lastCompletedCount = 0;

  // ☪️ Sukoon brand design tokens — semi-transparent to follow dashboard theme
  static final Color _bgDark = Colors.white.withValues(alpha: 0.02);
  static final Color _cardBg = Colors.white.withValues(alpha: 0.03);
  static final Color _borderColor = Colors.white.withValues(alpha: 0.06);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _textMuted = Color(0xFF484F58);

  // Prayer data with Islamic context
  static const List<Map<String, dynamic>> _prayers = [
    {
      'name': 'Fajr',
      'arabicName': 'الفجر',
      'icon': Icons.wb_twilight_rounded,
      'time': 'Dawn',
      'virtue': 'Better than the world',
    },
    {
      'name': 'Dhuhr',
      'arabicName': 'الظهر',
      'icon': Icons.wb_sunny_rounded,
      'time': 'Noon',
      'virtue': 'Midday reward',
    },
    {
      'name': 'Asr',
      'arabicName': 'العصر',
      'icon': Icons.wb_sunny_outlined,
      'time': 'Afternoon',
      'virtue': 'Protected from Fire',
    },
    {
      'name': 'Maghrib',
      'arabicName': 'المغرب',
      'icon': Icons.nights_stay_outlined,
      'time': 'Sunset',
      'virtue': 'Breaking fast reward',
    },
    {
      'name': 'Isha',
      'arabicName': 'العشاء',
      'icon': Icons.dark_mode_rounded,
      'time': 'Night',
      'virtue': 'Half night prayer',
    },
  ];

  // Nafil (voluntary) prayers
  static const List<Map<String, dynamic>> _nafilPrayers = [
    {
      'name': 'Tahajjud',
      'arabicName': 'تهجد',
      'icon': Icons.bedtime_rounded,
      'time': 'Last third of night',
    },
    {
      'name': 'Ishraq',
      'arabicName': 'اشراق',
      'icon': Icons.wb_twilight_rounded,
      'time': '15min after sunrise',
    },
    {
      'name': 'Chasht',
      'arabicName': 'چاشت',
      'icon': Icons.light_mode_rounded,
      'time': 'Mid-morning',
    },
    {
      'name': 'Awwabin',
      'arabicName': 'اوابین',
      'icon': Icons.nights_stay_rounded,
      'time': 'After Maghrib',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // DO NOT start .repeat() here.
    // This widget lives on the WidgetDashboardScreen (page 1) which uses
    // AutomaticKeepAliveClientMixin — it stays mounted even when the user
    // is on the home page or app list.  A repeating animation on a kept-
    // alive but off-screen widget burns CPU+GPU continuously because
    // SingleTickerProviderStateMixin only pauses the ticker when the
    // entire route/tree is off-screen (i.e., pushed route), NOT when a
    // PageView sibling is off-viewport.
    //
    // Instead, we start/stop via the VisibilityDetector pattern: the
    // parent build method calls _ensurePulseRunning() so the animation
    // only runs while the widget is actually being painted.
  }

  @override
  void deactivate() {
    // Widget is being removed from the tree (page swiped away, route pushed).
    // Stop the animation immediately to free the ticker.
    if (_pulseRunning) {
      _pulseController.stop();
      _pulseRunning = false;
    }
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    // Widget is re-inserted into the tree — restart the animation.
    if (!_pulseRunning) {
      _pulseController.repeat(reverse: true);
      _pulseRunning = true;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  DateTime _getSelectedDate() {
    return DateTime.now().subtract(Duration(days: _selectedDayOffset));
  }

  String _getDateKey(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return '${dateOnly.year}-${dateOnly.month.toString().padLeft(2, '0')}-${dateOnly.day.toString().padLeft(2, '0')}';
  }

  dynamic _getRecordForSelectedDay() {
    final allRecords = ref.watch(prayerRecordListProvider);
    final dateKey = _getDateKey(_getSelectedDate());
    
    try {
      return allRecords.firstWhere((r) => r.dateKey == dateKey);
    } catch (e) {
      return null;
    }
  }

  bool _isEditable() {
    // Only today and yesterday are editable
    return _selectedDayOffset <= 1;
  }

  int _getCompletedCount(dynamic todayRecord) {
    if (todayRecord == null) return 0;
    int count = 0;
    if (todayRecord.fajr) count++;
    if (todayRecord.dhuhr) count++;
    if (todayRecord.asr) count++;
    if (todayRecord.maghrib) count++;
    if (todayRecord.isha) count++;
    return count;
  }

  bool _isPrayerCompleted(dynamic todayRecord, String prayerName) {
    if (todayRecord == null) return false;
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return todayRecord.fajr;
      case 'dhuhr':
        return todayRecord.dhuhr;
      case 'asr':
        return todayRecord.asr;
      case 'maghrib':
        return todayRecord.maghrib;
      case 'isha':
        return todayRecord.isha;
      case 'tahajjud':
        return todayRecord.tahajjud;
      case 'ishraq':
        return todayRecord.ishraq;
      case 'chasht':
        return todayRecord.chasht;
      case 'awwabin':
        return todayRecord.awwabin;
      default:
        return false;
    }
  }

  int _getNafilCount(dynamic record) {
    if (record == null) return 0;
    int count = 0;
    if (record.tahajjud) count++;
    if (record.ishraq) count++;
    if (record.chasht) count++;
    if (record.awwabin) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    // Lazy-start the pulse animation on the first build frame.
    // This ensures it only runs when the widget is actually visible.
    if (!_pulseRunning) {
      _pulseController.repeat(reverse: true);
      _pulseRunning = true;
    }

    final themeColor = ref.watch(themeColorProvider);
    final selectedRecord = _getRecordForSelectedDay();
    final completedCount = _getCompletedCount(selectedRecord);
    final progress = completedCount / 5;
    final isEditable = _isEditable();
    final accent = themeColor.color;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const PrayerHistoryDashboard(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: completedCount == 5 
                ? accent.withValues(alpha: 0.25) 
                : _borderColor,
            width: completedCount == 5 ? 1.0 : 1,
          ),
          boxShadow: completedCount == 5
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.06),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            // Header with day selector
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Progress ring
                      _buildProgressRing(progress, completedCount, accent),
                      const SizedBox(width: 16),
                      
                      // Title & stats
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'SALAH TRACKER',
                                  style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: accent.withValues(alpha: 0.9),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: _textMuted,
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              completedCount == 5 
                                  ? 'All prayers completed! ✨'
                                  : '${5 - completedCount} ${(5 - completedCount) == 1 ? 'prayer' : 'prayers'} remaining',
                              style: TextStyle(
                                fontSize: 14,
                                color: completedCount == 5 
                                    ? accent.withValues(alpha: 0.8) 
                                    : _textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Day selector
                  const SizedBox(height: 12),
                  _buildDaySelector(accent),
                ],
              ),
            ),

            // Prayer pills
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _prayers.map((prayer) {
                  final isCompleted = _isPrayerCompleted(selectedRecord, prayer['name']);
                  return _buildPrayerPill(
                    prayer: prayer,
                    isCompleted: isCompleted,
                    themeColor: accent,
                    isEditable: isEditable,
                  );
                }).toList(),
              ),
            ),

            // ── Nafil section ──
            _buildNafilSection(selectedRecord, accent, isEditable),

            // Bottom padding for visual balance
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector(Color accent) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildDayTab('Today', 0, accent),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildDayTab('Yesterday', 1, accent),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTab(String label, int dayOffset, Color accent) {
    final isSelected = _selectedDayOffset == dayOffset;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDayOffset = dayOffset;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent.withValues(alpha: 0.5) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected && dayOffset == 0)
              Icon(
                Icons.today_rounded,
                color: accent,
                size: 14,
              ),
            if (isSelected && dayOffset == 1)
              Icon(
                Icons.history_rounded,
                color: accent,
                size: 14,
              ),
            if (isSelected) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? accent : _textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRing(double progress, int completed, Color accent) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          CustomPaint(
            size: const Size(52, 52),
            painter: _RingPainter(
              progress: 1.0,
              color: _borderColor,
              strokeWidth: 4,
            ),
          ),
          // Progress ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return CustomPaint(
                size: const Size(52, 52),
                painter: _RingPainter(
                  progress: value,
                  color: accent,
                  strokeWidth: 4,
                ),
              );
            },
          ),
          // Center indicator — ring carries progress visually; the exact
          // count lives in the adjacent label, so we avoid restating a number
          // here. Only a checkmark appears on full completion.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: completed == 5
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('check'),
                    color: accent,
                    size: 24,
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ],
      ),
    );
  }
  Widget _buildNafilSection(dynamic selectedRecord, Color accent, bool isEditable) {
    final nafilCount = _getNafilCount(selectedRecord);
    
    return Column(
      children: [
        // Toggle button
        GestureDetector(
          onTap: () {
            setState(() => _showNafil = !_showNafil);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: nafilCount > 0
                    ? accent.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: nafilCount > 0
                      ? accent.withValues(alpha: 0.15)
                      : _borderColor,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 13,
                    color: nafilCount > 0
                        ? accent.withValues(alpha: 0.7)
                        : _textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    nafilCount > 0
                        ? 'NAFIL · $nafilCount/4'
                        : 'NAFIL PRAYERS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: nafilCount > 0
                          ? accent.withValues(alpha: 0.7)
                          : _textMuted,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _showNafil ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: _textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Nafil pills (collapsible)
        AnimatedCrossFade(
          firstChild: const SizedBox(height: 0, width: double.infinity),
          secondChild: Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _nafilPrayers.map((prayer) {
                final isCompleted = _isPrayerCompleted(selectedRecord, prayer['name']);
                return _buildPrayerPill(
                  prayer: prayer,
                  isCompleted: isCompleted,
                  themeColor: accent,
                  isEditable: isEditable,
                );
              }).toList(),
            ),
          ),
          crossFadeState: _showNafil
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }

  Widget _buildPrayerPill({
    required Map<String, dynamic> prayer,
    required bool isCompleted,
    required Color themeColor,
    required bool isEditable,
  }) {
    final Color pillBg;
    final Color pillBorder;
    final Color iconColor;
    final Color textColor;
    final double opacity;
    
    if (isCompleted) {
      // Dark tinted fill — NOT bright white/bright accent
      pillBg = themeColor.withValues(alpha: 0.10);
      pillBorder = themeColor.withValues(alpha: 0.28);
      iconColor = themeColor.withValues(alpha: 0.85);
      textColor = themeColor.withValues(alpha: 0.70);
      opacity = 1.0;
    } else if (!isEditable) {
      pillBg = Colors.white.withValues(alpha: 0.01);
      pillBorder = Colors.white.withValues(alpha: 0.04);
      iconColor = _textMuted.withValues(alpha: 0.4);
      textColor = _textMuted.withValues(alpha: 0.5);
      opacity = 0.5;
    } else {
      pillBg = Colors.white.withValues(alpha: 0.03);
      pillBorder = Colors.white.withValues(alpha: 0.06);
      iconColor = _textMuted;
      textColor = _textSecondary;
      opacity = 1.0;
    }

    return GestureDetector(
      onTap: isEditable
          ? () {
              final selectedDate = _getSelectedDate();
              ref.read(prayerRecordListProvider.notifier).togglePrayer(
                selectedDate,
                prayer['name'],
              );
              // Check if all 5 Fard prayers completed → celebrate
              if (_selectedDayOffset == 0) {
                Future.delayed(const Duration(milliseconds: 150), () {
                  final todayRecord = ref.read(todayPrayerRecordProvider);
                  if (todayRecord != null &&
                      todayRecord.fajr && todayRecord.dhuhr && todayRecord.asr &&
                      todayRecord.maghrib && todayRecord.isha &&
                      !_hasShownCelebration) {
                    _hasShownCelebration = true;
                    if (mounted) _showCelebrationOverlay(context, themeColor);
                  } else if (todayRecord != null && !(todayRecord.fajr && todayRecord.dhuhr &&
                      todayRecord.asr && todayRecord.maghrib && todayRecord.isha)) {
                    _hasShownCelebration = false;
                  }
                });
              }
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: opacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: pillBorder,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isCompleted ? Icons.check_circle_rounded : prayer['icon'],
                  key: ValueKey('${prayer['name']}_$isCompleted'),
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                prayer['name'],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCelebrationOverlay(BuildContext context, Color accent) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      barrierDismissible: true,
      builder: (ctx) => _CelebrationDialog(accent: accent),
    );
  }
}

/// Fresh-leaf celebration dialog — shown once when all 5 prayers are marked
class _CelebrationDialog extends StatefulWidget {
  final Color accent;
  const _CelebrationDialog({required this.accent});

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _glowAnim;

  // minimal floating dot positions
  final _rng = math.Random(7);
  late final List<_Star> _dots;

  static const _green = Color(0xFF4CAF50);
  static const _greenLight = Color(0xFF81C784);

  @override
  void initState() {
    super.initState();
    _dots = List.generate(14, (i) => _Star(
      x: _rng.nextDouble(),
      y: _rng.nextDouble(),
      size: 2.0 + _rng.nextDouble() * 3.0,
      opacity: 0.15 + _rng.nextDouble() * 0.25,
    ));

    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _glowCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);

    _scaleAnim = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutBack);
    _fadeAnim  = CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
    _glowAnim  = CurvedAnimation(parent: _glowCtrl,  curve: Curves.easeInOut);

    _enterCtrl.forward();

    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Subtle floating dots
            ..._dots.map((d) => Positioned(
              left: d.x * size.width,
              top: d.y * size.height,
              child: AnimatedBuilder(
                animation: _glowAnim,
                builder: (_, __) {
                  final pulse = (math.sin(_glowAnim.value * math.pi * 2) + 1) / 2;
                  return Container(
                    width: d.size,
                    height: d.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: d.opacity * (0.5 + pulse * 0.5)),
                    ),
                  );
                },
              ),
            )),

            // Main card
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF080808),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: _green.withValues(alpha: 0.18),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.10),
                          blurRadius: 48,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon — glowing leaf circle
                        AnimatedBuilder(
                          animation: _glowAnim,
                          builder: (_, __) => Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _green.withValues(alpha: 0.06 + _glowAnim.value * 0.06),
                              boxShadow: [
                                BoxShadow(
                                  color: _green.withValues(alpha: 0.12 + _glowAnim.value * 0.10),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 32,
                              color: _greenLight,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Main headline
                        Text(
                          'All 5 Salah Complete',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white.withValues(alpha: 0.90),
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Sub-message
                        Text(
                          'May Allah accept your prayers\nand grant you peace.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.38),
                            height: 1.65,
                            letterSpacing: 0.1,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // 5 prayer completion dots in green
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) => AnimatedBuilder(
                            animation: _glowAnim,
                            builder: (_, __) {
                              final stagger = (math.sin(_glowAnim.value * math.pi * 2 + i * 0.6) + 1) / 2;
                              return Container(
                                width: 6, height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _green.withValues(alpha: 0.5 + stagger * 0.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _green.withValues(alpha: 0.3 * stagger),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              );
                            },
                          )),
                        ),

                        const SizedBox(height: 24),

                        // Dismiss note
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 16, height: 1,
                              color: _green.withValues(alpha: 0.15),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'TAP TO CLOSE',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.18),
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 16, height: 1,
                              color: _green.withValues(alpha: 0.15),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Star {
  final double x, y, size, opacity;
  const _Star({required this.x, required this.y, required this.size, required this.opacity});
}

/// Custom ring painter for progress indicator
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
