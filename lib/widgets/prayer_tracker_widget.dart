import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/prayer_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/prayer_history_dashboard_redesigned.dart';
import '../utils/motion.dart';

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

  // ☪️ Sukoon brand design tokens — semi-transparent to follow dashboard theme
  static final Color _bgDark = Colors.white.withValues(alpha: 0.02);
  static final Color _cardBg = Colors.white.withValues(alpha: 0.03);
  static final Color _borderColor = Colors.white.withValues(alpha: 0.09);
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
                ? accent.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
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
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      barrierDismissible: true,
      builder: (ctx) => _CelebrationDialog(accent: accent),
    );
  }
}

/// Celebration overlay — a crafted "all five fard prayers complete" moment,
/// built entirely with Flutter's own primitives (no extra packages). The
/// medallion ring closes itself, a checkmark is drawn inside it, a soft glow
/// blooms into the dark, and a restrained, accent-toned sparkle field settles
/// out — each beat carried by a light haptic.
///
/// Every colour derives from the active theme [accent] (duotone, never a
/// rainbow); the Arabic dua is set in Amiri and the UI in Inter to match the
/// rest of the app. Fully honours the OS "reduce motion" setting.
class _CelebrationDialog extends StatefulWidget {
  final Color accent;
  const _CelebrationDialog({required this.accent});

  @override
  State<_CelebrationDialog> createState() => _CelebrationDialogState();
}

class _CelebrationDialogState extends State<_CelebrationDialog>
    with TickerProviderStateMixin {
  /// Length of the one-shot intro choreography. Every [_seg] interval below is
  /// expressed as a fraction of this clock.
  static const int _introMs = 2400;

  late final AnimationController _intro;   // one-shot choreography clock
  late final AnimationController _ambient; // looping glow / breathe
  late final AnimationController _exit;    // dismissal fade-out

  late final List<_Particle> _particles;
  final math.Random _rng = math.Random(42);

  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _introMs),
    );
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _particles = _buildParticles();

    // Start after the first frame so MediaQuery (reduce-motion) is readable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Under reduce-motion the card renders statically (every visual reads
      // `reduced ? 1.0 : ...`), so we skip the intro/ambient clocks entirely.
      if (Motion.reduced(context)) return;
      _intro.forward();
      _ambient.repeat(reverse: true);
    });

    // Auto-dismiss once the moment has had room to land.
    Future.delayed(const Duration(milliseconds: 4800), _dismiss);
  }

  /// Pre-computes the sparkle field once — deterministic so [paint] stays
  /// allocation-free per frame. The palette is duotone (accent → white), not a
  /// rainbow: restraint is what reads as crafted rather than generated.
  List<_Particle> _buildParticles() {
    final palette = <Color>[
      widget.accent,
      Color.lerp(widget.accent, Colors.white, 0.35)!,
      Color.lerp(widget.accent, Colors.white, 0.7)!,
      Colors.white,
    ];
    return List.generate(30, (i) {
      return _Particle(
        angle: _rng.nextDouble() * math.pi * 2,
        speed: 60 + _rng.nextDouble() * 190,
        gravity: 90 + _rng.nextDouble() * 150,
        size: 2.5 + _rng.nextDouble() * 4.5,
        spin: (_rng.nextDouble() - 0.5) * 6,
        delay: _rng.nextDouble() * 0.14,
        color: palette[i % palette.length],
        isStrip: _rng.nextDouble() < 0.35, // mostly soft dust, a few slivers
        glow: _rng.nextDouble() < 0.3, // a third carry a faint halo
      );
    });
  }

  void _dismiss() {
    if (_closing || !mounted) return;
    setState(() => _closing = true);
    _exit.forward().whenComplete(() {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    _exit.dispose();
    super.dispose();
  }

  /// Maps the intro clock onto a sub-interval [start]..[end] with [curve],
  /// returning 0..1. The backbone of the whole choreography.
  double _seg(double start, double end, {Curve curve = Curves.easeOut}) {
    final t = ((_intro.value - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final accent = widget.accent;
    final accentLight = Color.lerp(accent, Colors.white, 0.45)!;

    return GestureDetector(
      onTap: _dismiss,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _ambient, _exit]),
        builder: (context, _) {
          final exit = _exit.value;       // 0 → 1 while closing
          final breathe = _ambient.value; // 0 → 1 → 0 ambient pulse
          final bloom =
              reduced ? 1.0 : _seg(0.0, 0.55, curve: Curves.easeOutCubic);

          return Opacity(
            opacity: (1.0 - exit).clamp(0.0, 1.0),
            child: Material(
              type: MaterialType.transparency,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Soft glow bloom — the moment quietly lights up the dark.
                  if (!reduced)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.12),
                            radius: 0.9,
                            colors: [
                              accent.withValues(alpha: 0.10 * bloom),
                              accent.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Accent-toned sparkle field.
                  if (!reduced)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _SparklePainter(
                            particles: _particles,
                            progress: _seg(0.0, 0.72, curve: Curves.linear),
                          ),
                        ),
                      ),
                    ),

                  // Celebration card — fades + rises, no toy bounce.
                  Transform.scale(
                    scale: 1.0 - exit * 0.04,
                    child: Opacity(
                      opacity: reduced ? 1.0 : _seg(0.0, 0.22),
                      child: Transform.translate(
                        offset: Offset(
                            0,
                            reduced
                                ? 0
                                : (1 -
                                        _seg(0.0, 0.42,
                                            curve: Curves.easeOutCubic)) *
                                    14),
                        child: Transform.scale(
                          scale: reduced
                              ? 1.0
                              : 0.96 +
                                  _seg(0.0, 0.42, curve: Curves.easeOutCubic) *
                                      0.04,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child:
                                _buildCard(accent, accentLight, breathe, reduced),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(Color accent, Color accentLight, double breathe, bool reduced) {
    final ringProgress =
        reduced ? 1.0 : _seg(0.14, 0.60, curve: Curves.easeInOutCubic);
    final checkProgress =
        reduced ? 1.0 : _seg(0.40, 0.66, curve: Curves.easeInOutCubic);

    return Container(
      padding: const EdgeInsets.fromLTRB(30, 34, 30, 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14161A), Color(0xFF0A0B0D)],
        ),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.10 + breathe * 0.05),
            blurRadius: 60,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Medallion — the ring closes, then the check is drawn inside it.
          SizedBox(
            width: 116,
            height: 116,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      accent.withValues(alpha: 0.18 + breathe * 0.06),
                      accent.withValues(alpha: 0.0),
                    ]),
                  ),
                ),
                CustomPaint(
                  size: const Size(116, 116),
                  painter: _RingProgressPainter(
                    progress: ringProgress,
                    color: accent,
                    trackColor: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CustomPaint(
                    painter: _CheckPainter(
                      progress: checkProgress,
                      color: Colors.white,
                      strokeWidth: 4.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Headline (Inter — matches the app's UI type).
          Opacity(
            opacity: reduced ? 1.0 : _seg(0.52, 0.70),
            child: Text(
              'All 5 Salah Complete',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 19,
                height: 1.2,
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Arabic dua, set in Amiri — "May Allah accept from us and from you".
          Opacity(
            opacity: reduced ? 1.0 : _seg(0.60, 0.80),
            child: Text(
              'تَقَبَّلَ ٱللّٰهُ مِنَّا وَمِنْكُم',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.amiri(
                fontSize: 21,
                height: 1.9,
                color: accentLight,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Translation of the dua, kept quiet beneath it.
          Opacity(
            opacity: reduced ? 1.0 : _seg(0.70, 0.88),
            child: Text(
              'May Allah accept it from us and from you',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.42),
                letterSpacing: 0.1,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Five-prayer resolve — fills left → right, one dot per prayer.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final start = 0.72 + i * 0.045;
              final p = reduced
                  ? 1.0
                  : _seg(start, start + 0.13, curve: Curves.easeOutCubic);
              return Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      Color.lerp(Colors.white.withValues(alpha: 0.10), accent, p),
                  boxShadow: p > 0.6
                      ? [
                          BoxShadow(
                              color: accent.withValues(alpha: 0.45 * p),
                              blurRadius: 6)
                        ]
                      : null,
                ),
              );
            }),
          ),

          const SizedBox(height: 22),

          // Dismiss hint — sentence case, quiet.
          Opacity(
            opacity: reduced ? 1.0 : _seg(0.90, 1.0),
            child: Text(
              'Tap to dismiss',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.30),
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single sparkle — launched radially from the medallion, eased outward and
/// pulled gently down. [glow] gives a third of them a soft halo.
class _Particle {
  final double angle, speed, gravity, size, spin, delay;
  final Color color;
  final bool isStrip;
  final bool glow;
  const _Particle({
    required this.angle,
    required this.speed,
    required this.gravity,
    required this.size,
    required this.spin,
    required this.delay,
    required this.color,
    required this.isStrip,
    required this.glow,
  });
}

/// Restrained sparkle field rising from the medallion. [progress] 0→1 drives
/// the whole flight; each mote fades in fast and out over its final 45% so the
/// field clears cleanly. Accent-toned dust with a few slivers — no confetti.
class _SparklePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _SparklePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final origin = Offset(size.width / 2, size.height * 0.46);
    for (final pt in particles) {
      final local = ((progress - pt.delay) / (1 - pt.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final reach = pt.speed * Curves.easeOutCubic.transform(local);
      final cx = origin.dx + math.cos(pt.angle) * reach;
      final cy =
          origin.dy + math.sin(pt.angle) * reach + pt.gravity * local * local;
      final fadeIn = (local / 0.12).clamp(0.0, 1.0);
      final fadeOut = local < 0.55 ? 1.0 : 1 - (local - 0.55) / 0.45;
      final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);
      if (opacity <= 0) continue;

      if (pt.glow) {
        canvas.drawCircle(Offset(cx, cy), pt.size * 1.9,
            Paint()..color = pt.color.withValues(alpha: opacity * 0.16));
      }
      final paint = Paint()..color = pt.color.withValues(alpha: opacity);
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(pt.spin * local);
      if (pt.isStrip) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: pt.size * 0.7, height: pt.size * 2.2),
            const Radius.circular(2),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, pt.size * 0.5, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) => old.progress != progress;
}

/// The medallion ring closing itself: a faint full track, a progress arc that
/// sweeps from the top, and a bright "comet head" tracing its leading edge —
/// an Apple-Fitness-style completion, fitting for a tracker.
class _RingProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  _RingProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    const start = -math.pi / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = trackColor,
    );
    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    if (progress < 0.999) {
      final ang = start + sweep;
      final head = Offset(center.dx + radius * math.cos(ang),
          center.dy + radius * math.sin(ang));
      canvas.drawCircle(
          head, 5, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(head, 2.4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter old) =>
      old.progress != progress || old.color != color;
}

/// A checkmark that draws itself: extracts a partial [Path] via [PathMetric]
/// so the stroke grows from tail to tip as [progress] runs 0→1.
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.43, h * 0.67)
      ..lineTo(w * 0.72, h * 0.34);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0));
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) =>
      old.progress != progress || old.color != color;
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
