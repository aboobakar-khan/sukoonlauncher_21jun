import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/productivity_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../models/installed_app.dart';
import '../providers/theme_provider.dart';
import '../providers/zen_mode_provider.dart';

import '../models/productivity_models.dart';
import '../providers/ambient_sound_provider.dart';
import '../services/native_app_blocker_service.dart';
import '../widgets/swipe_back_wrapper.dart';
import '../widgets/edge_to_edge.dart';
import 'zen_mode_entry_screen.dart';
import 'screen_time_settings_screen.dart';
import 'notification_feed_screen.dart';
import '../providers/screen_time_provider.dart';
import '../providers/notification_filter_provider.dart';
import '../utils/smooth_page_route.dart';
import 'pomodoro_screen.dart';
import 'new_schedule_screen.dart';


// ─── Sukoon Design Tokens ────────────────────────────────────────────────────
const Color _warmBrown = Color(0xFFA67B5B);
const Color _oasisGreen = Color(0xFF7BAE6E);
const Color _desertWarm = Color(0xFFD4A96A);
const Color _desertSunset = Color(0xFFE8915A);

// ─── Dark Theme Tokens ──────────────────────────────────────────────────────
const Color _ftBg = Color(0xFF000000);         // pure black background
final Color _ftCard = Colors.white.withValues(alpha: 0.04);       // semi-transparent card surface
final Color _ftCardLight = Colors.white.withValues(alpha: 0.06);  // slightly lighter card variant
const Color _ftText = Color(0xFFE8E8E8);       // light text on dark
const Color _ftTextSoft = Color(0xFF8A8A8A);   // muted text
final Color _ftBorder = Colors.white.withValues(alpha: 0.08);     // subtle border
const Color _ftGold = Color(0xFFBFA76A);       // gold accent for streaks

// ─── Shadow Systems ─────────────────────────────────────────────────────────
const Color _shadowDark = Color(0xFF000000);

final List<BoxShadow> _darkCardShadowNormal = [
  BoxShadow(color: _shadowDark.withValues(alpha: 0.25), offset: const Offset(0, 4), blurRadius: 16, spreadRadius: -2),
  BoxShadow(color: _shadowDark.withValues(alpha: 0.15), offset: const Offset(0, 1), blurRadius: 4),
];
final List<BoxShadow> _darkCardShadowElevated = [
  BoxShadow(color: _shadowDark.withValues(alpha: 0.35), offset: const Offset(0, 4), blurRadius: 16, spreadRadius: -2),
  BoxShadow(color: _shadowDark.withValues(alpha: 0.15), offset: const Offset(0, 1), blurRadius: 4),
];

/// 🌙 Productivity Hub — Distraction-free tools
/// Features: Todo · Pomodoro · Academic Doubts · Events · App Blocker
class ProductivityHubScreen extends ConsumerStatefulWidget {
  const ProductivityHubScreen({super.key});

  @override
  ConsumerState<ProductivityHubScreen> createState() =>
      _ProductivityHubScreenState();
}

class _ProductivityHubScreenState extends ConsumerState<ProductivityHubScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {

  // Keep the page alive in the PageView so initState (and its expensive
  // refreshUsageStats MethodChannel calls) only runs once, not every time
  // the user swipes near this page.
  @override
  bool get wantKeepAlive => true;

  // (unused _lastFetchedDate field removed — refresh always runs on resume)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ambient sound sync via listener (timer self-ticks inside PomodoroNotifier)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(pomodoroProvider, (prev, next) {
        if (prev?.state != next.state) {
          _syncAmbientSound(next.state);
        }
      });
      // Refresh usage stats now so the widget shows today's data immediately
      _refreshScreenTimeIfNeeded();
    });
  }

  /// Refresh screen time usage stats — always fetches today's window fresh.
  /// Called on first build and whenever app resumes from background.
  ///
  /// IMPORTANT: The refresh is delayed so that it never competes with an
  /// in-progress PageView swipe animation.  The native getUsageStats /
  /// getDailyUsageStats calls iterate every UsageEvent for 7 days on the
  /// Android main (platform) thread.  If they run mid-swipe they block
  /// Flutter's frame delivery ➜ visible jank.  An 800 ms delay lets the
  /// swipe settle before the platform thread is busy.
  void _refreshScreenTimeIfNeeded() {
    final st = ref.read(screenTimeProvider);
    if (st.featureEnabled) {
      // Defer the expensive MethodChannel calls so a concurrent PageView
      // swipe animation completes first (typically < 500 ms).
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        ref.read(screenTimeProvider.notifier).refreshUsageStats();
      });
    }
  }


  /// Called by WidgetsBindingObserver when the app returns to the foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _refreshScreenTimeIfNeeded();
    }
  }

  PomodoroState? _lastPomodoroState;
  final TextEditingController _todoCtrl = TextEditingController();
  final FocusNode _todoFocusNode = FocusNode();

  // ── Hub always uses dark mode ──
  Color get _card => ref.watch(themeColorProvider).isLight
      ? Colors.black.withValues(alpha: 0.04)
      : _ftCard;
  Color get _cardLight => ref.watch(themeColorProvider).isLight
      ? Colors.black.withValues(alpha: 0.06)
      : _ftCardLight;
  Color get _text => ref.watch(themeColorProvider).isLight
      ? const Color(0xFF0D0D0D)
      : _ftText;
  Color get _textSoft => ref.watch(themeColorProvider).isLight
      ? const Color(0xFF6B6B6B)
      : _ftTextSoft;
  Color get _border => ref.watch(themeColorProvider).isLight
      ? Colors.black.withValues(alpha: 0.08)
      : _ftBorder;
  
  // 🎨 Theme-aware primary color (replaces sage green with user's theme choice)
  Color get _sage => ref.watch(themeColorProvider).color;
  Color get _gold => _ftGold;

  /// Paper shadow — always dark mode
  List<BoxShadow> _paperShadow({bool elevated = false}) {
    return elevated ? _darkCardShadowElevated : _darkCardShadowNormal;
  }

  /// Sync ambient sound with pomodoro timer state
  void _syncAmbientSound(PomodoroState currentState) {
    if (_lastPomodoroState == currentState) return;
    final prev = _lastPomodoroState;
    _lastPomodoroState = currentState;

    final ambient = ref.read(ambientSoundProvider);
    final ambientNotifier = ref.read(ambientSoundProvider.notifier);

    // Timer started running → auto-play sound (even first time with default)
    if ((currentState == PomodoroState.focusing ||
         currentState == PomodoroState.shortBreak ||
         currentState == PomodoroState.longBreak) &&
        (prev == PomodoroState.paused || prev == PomodoroState.idle || prev == null)) {
      if (!ambient.isPlaying) {
        final soundId = ambient.currentSoundId ?? 'rain';
        ambientNotifier.selectAndPlay(soundId);
      }
    }
    // Timer paused → pause sound
    else if (currentState == PomodoroState.paused && ambient.isPlaying) {
      ambientNotifier.togglePlayPause();
    }
    // Timer stopped/reset → stop sound completely
    // Use a tiny delay so auto-start break/focus transitions don't cause audio glitch
    else if (currentState == PomodoroState.idle && prev != null && prev != PomodoroState.idle) {
      Future.delayed(const Duration(milliseconds: 120), () {
        // Re-read state after delay — if timer auto-started a new session, don't stop
        final currentPomo = ref.read(pomodoroProvider);
        if (currentPomo.state == PomodoroState.idle) {
          ref.read(ambientSoundProvider.notifier).stop();
        }
      });
    }
  }

  @override
  void dispose() {
    _todoFocusNode.dispose();
    _todoCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Time-of-day contextual greeting (Psychology: emotional anchor) ──
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Late night';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Wind down';
  }

  String get _greetingSubtext {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Rest is productive too';
    if (hour < 12) return 'Start with intention';
    if (hour < 17) return 'Stay in the flow';
    if (hour < 21) return 'Finish strong';
    return 'Reflect on your progress';
  }

  IconData get _greetingIcon {
    final hour = DateTime.now().hour;
    if (hour < 5) return Icons.bedtime_rounded;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.light_mode_rounded;
    if (hour < 21) return Icons.wb_twilight_rounded;
    return Icons.nightlight_round;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final pomo = ref.watch(pomodoroProvider);
    final todos = ref.watch(todoProvider);
    final streak = ref.watch(focusStreakProvider);
    final zen = ref.watch(zenModeProvider);
    final blockRules = ref.watch(appBlockRuleProvider);
    final st = ref.watch(screenTimeProvider);
    final nf = ref.watch(notificationFilterProvider);
    final pendingTodos = todos.where((t) => !t.isCompleted).toList();
    final completedToday = todos.where((t) => t.isCompleted).length;
    final isFocusing = pomo.state == PomodoroState.focusing ||
        pomo.state == PomodoroState.shortBreak ||
        pomo.state == PomodoroState.longBreak;
    final isPaused = pomo.state == PomodoroState.paused;
    final isTimerActive = isFocusing || isPaused;
    final activeBlockedCount = blockRules
        .where((r) => r.isEnabled)
        .fold<int>(0, (sum, r) => sum + r.blockedPackages.length);
    final activeRules = blockRules.where((r) => r.isEnabled).toList();
    final hasActiveBlocker = activeRules.isNotEmpty;
    final isScreenTimeActive = st.featureEnabled;
    final isNotifActive = nf.featureEnabled;

    // ── Responsive scaling ──
    final screenW = MediaQuery.of(context).size.width;
    // Scale factor: 1.0 at 375px (iPhone SE), clamp 0.85–1.25
    final sf = (screenW / 375).clamp(0.85, 1.25);
    final hPad = (screenW * 0.058).clamp(18.0, 32.0); // increased from ~20 to ~24 at 375

    // Timer display
    final totalSec = pomo.remainingSeconds;
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    // Focus minutes today
    final totalFocusMin = pomo.totalFocusMinutesToday;
    final focusHours = totalFocusMin ~/ 60;
    final focusMins = totalFocusMin % 60;
    final focusTimeLabel = focusHours > 0 ? '${focusHours}h ${focusMins}m' : '${focusMins}m';

    // Screen time
    final todayTotal = st.todayTotal;
    final stHours = todayTotal.inHours;
    final stMins = todayTotal.inMinutes.remainder(60);
    final stLabel = stHours > 0 ? '${stHours}h ${stMins}m' : '${stMins}m';

    // Protection score (how many tools are active)
    final protectionActive = [hasActiveBlocker, isScreenTimeActive, isNotifActive, zen.isActive]
        .where((b) => b).length;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
          child: RepaintBoundary(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // ═══════════════════════════════════════════════════════
                  // 1. CONTEXTUAL HEADER — greeting + streak + theme toggle
                  //    Psychology: Emotional anchoring, personal connection
                  // ═══════════════════════════════════════════════════════
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                               Icon(
                                  _greetingIcon,
                                  size: 20 * sf,
                                  color: _sage.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _greeting,
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: (24 * sf).clamp(20.0, 30.0),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.6,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _greetingSubtext,
                              style: TextStyle(
                                color: _textSoft,
                                fontSize: (14 * sf).clamp(12.0, 17.0),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ── Inline stats ribbon (streak + focus today + tasks done) ──
                  Wrap(
                    spacing: (8 * sf).clamp(5.0, 12.0),
                    runSpacing: (6 * sf).clamp(4.0, 10.0),
                    children: [
                      if (streak > 0)
                        _miniChip(
                          icon: Icons.local_fire_department_rounded,
                          label: '$streak day streak',
                          color: const Color(0xFFE8915A),
                          sf: sf,
                        ),
                      if (totalFocusMin > 0)
                        _miniChip(
                          icon: Icons.timer_outlined,
                          label: '$focusTimeLabel focused',
                          color: _sage,
                          sf: sf,
                        ),
                      if (completedToday > 0)
                        _miniChip(
                          icon: Icons.check_circle_outline_rounded,
                          label: '$completedToday done',
                          color: _sage,
                          sf: sf,
                        ),
                    ],
                  ),

                  SizedBox(height: (18 * sf).clamp(14.0, 26.0)),

                  // ═══════════════════════════════════════════════════════
                  // 2. HERO FOCUS CARD — tap to open full Focus screen
                  // ═══════════════════════════════════════════════════════
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        SmoothForwardRoute(
                          child: PomodoroScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: (20 * sf).clamp(16.0, 26.0), vertical: (18 * sf).clamp(14.0, 24.0)),
                      decoration: BoxDecoration(
                        color: isTimerActive
                            ? _sage.withValues(alpha: 0.06)
                            : _card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isTimerActive
                              ? _sage.withValues(alpha: 0.2)
                              : _border,
                          width: isTimerActive ? 1.2 : 0.6,
                        ),
                        boxShadow: _paperShadow(elevated: isTimerActive),
                      ),
                      child: Row(
                        children: [
                          // Timer ring (compact) — responsive
                          SizedBox(
                            width: (64 * sf).clamp(52.0, 78.0),
                            height: (64 * sf).clamp(52.0, 78.0),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox.expand(
                                  child: CustomPaint(
                                    painter: _FocusRingPainter(
                                      progress: isTimerActive ? pomo.progress : 0.0,
                                      trackColor: _border.withValues(alpha: 0.5),
                                      progressColor: isFocusing
                                          ? _sage
                                          : isPaused
                                              ? _sage.withValues(alpha: 0.4)
                                              : _border.withValues(alpha: 0.4),
                                      strokeWidth: (3.0 * sf).clamp(2.5, 4.0),
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: isTimerActive
                                            ? _text
                                            : _text.withValues(alpha: 0.45),
                                        fontSize: (16 * sf).clamp(13.0, 19.0),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: (16 * sf).clamp(10.0, 20.0)),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isFocusing
                                      ? (pomo.state == PomodoroState.focusing
                                          ? 'Deep Focus'
                                          : pomo.state == PomodoroState.shortBreak
                                              ? 'Short Break'
                                              : 'Long Break')
                                      : isPaused
                                          ? 'Paused'
                                          : 'Focus',
                                  style: TextStyle(
                                    color: _text,
                                    fontSize: (19 * sf).clamp(16.0, 26.0),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: (3 * sf).clamp(2.0, 5.0)),
                                Text(
                                  isTimerActive
                                      ? 'Session ${pomo.completedSessions + 1} · $focusTimeLabel today'
                                      : 'Tap to start focusing',
                                  style: TextStyle(
                                    color: isTimerActive
                                        ? _sage.withValues(alpha: 0.7)
                                        : _textSoft,
                                    fontSize: (12 * sf).clamp(10.0, 15.0),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: (8 * sf).clamp(6.0, 12.0)),
                          // Play / Pause — responsive
                          GestureDetector(
                            onTap: () {
                              if (isPaused) {
                                ref.read(pomodoroProvider.notifier).resume();
                              } else if (isFocusing) {
                                ref.read(pomodoroProvider.notifier).pause();
                              } else {
                                ref.read(pomodoroProvider.notifier).startFocus();
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: (46 * sf).clamp(38.0, 56.0),
                              height: (46 * sf).clamp(38.0, 56.0),
                              decoration: BoxDecoration(
                                color: isTimerActive
                                    ? _sage.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isTimerActive
                                      ? _sage.withValues(alpha: 0.3)
                                      : _sage.withValues(alpha: 0.45),
                                  width: 1.4,
                                ),
                              ),
                              child: Icon(
                                isPaused
                                    ? Icons.play_arrow_rounded
                                    : isFocusing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                color: _sage.withValues(alpha: isTimerActive ? 0.9 : 0.6),
                                size: (24 * sf).clamp(20.0, 30.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. TASKS — inline minimalist to-do list
                  // ═══════════════════════════════════════════════════════
                  _buildInlineTodoList(context, todos, sf),

                  const SizedBox(height: 12),

                  // ═══════════════════════════════════════════════════════
                  // 4. DIGITAL WELLBEING — 2×2 grid of widget tiles
                  // ═══════════════════════════════════════════════════════
                  Row(
                    children: [
                      Text(
                        'DIGITAL WELLBEING',
                        style: TextStyle(
                          color: _textSoft.withValues(alpha: 0.45),
                          fontSize: 11.5 * sf,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),
                      if (protectionActive > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _sage.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── 2×2 grid ──
                  Row(
                    children: [
                      Expanded(
                        child: _wellbeingTile(
                          icon: zen.isActive
                              ? Icons.self_improvement_rounded
                              : Icons.phone_android_rounded,
                          label: 'Kahf Mode',
                          value: zen.isActive ? 'Active' : 'Off',
                          isActive: zen.isActive,
                          onTap: () {
                            if (zen.isActive) {
                              ref.read(zenModeProvider.notifier).endZenMode();
                            } else {
                              Navigator.push(context, SmoothForwardRoute(
                                child: const ZenModeEntryScreen()));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _wellbeingTile(
                          icon: Icons.notifications_outlined,
                          label: 'Notifs',
                          value: isNotifActive
                              ? '${nf.totalCount} queued'
                              : 'Off',
                          isActive: isNotifActive,
                          badge: isNotifActive && nf.totalCount > 0
                              ? nf.totalCount : null,
                          onTap: () => Navigator.push(context, SmoothForwardRoute(
                              child: const NotificationFeedScreen())),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _wellbeingTile(
                          icon: Icons.shield_rounded,
                          label: 'App Blocker',
                          value: hasActiveBlocker
                              ? '$activeBlockedCount blocked'
                              : 'Off',
                          isActive: hasActiveBlocker,
                          onTap: () => Navigator.push(context, SmoothForwardRoute(
                              child: _ProductivitySubScreen(
                                title: 'App Blocker',
                                child: _BlockerTab()))),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _wellbeingTile(
                          icon: Icons.timer_outlined,
                          label: 'App Timer',
                          value: isScreenTimeActive ? stLabel : 'Off',
                          isActive: isScreenTimeActive,
                          onTap: () => Navigator.push(context, SmoothForwardRoute(
                              child: const ScreenTimeSettingsScreen())),
                        ),
                      ),
                    ],
                  ),

                  // Bottom safe area padding — responsive
                  SizedBox(height: (16 * sf).clamp(10.0, 32.0)),
                ],              // Column children
              ),                // Column
            ),                  // Padding
          ),                    // SingleChildScrollView
        ),                      // RepaintBoundary
        ),                      // SafeArea
      ),                        // Container
    );                          // GestureDetector
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MINI CHIP — inline stat pill for the greeting area
  // ─────────────────────────────────────────────────────────────────────────
  Widget _miniChip({
    required IconData icon,
    required String label,
    required Color color,
    double sf = 1.0,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (12 * sf).clamp(8.0, 16.0),
        vertical: (6 * sf).clamp(4.0, 10.0),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: (14 * sf).clamp(11.0, 18.0), color: color.withValues(alpha: 0.7)),
          SizedBox(width: (6 * sf).clamp(4.0, 10.0)),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: (12.5 * sf).clamp(10.0, 16.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }



  // ─────────────────────────────────────────────────────────────────────────
  // WELLBEING TILE — compact 2×2 grid card (replaces stacked rows)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _wellbeingTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
    required VoidCallback onTap,
    int? badge,
  }) {
    final color = _sage;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.06) : _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.20) : _border,
            width: 0.9,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: icon + status dot
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? color.withValues(alpha: 0.15)
                        : _textSoft.withValues(alpha: 0.07),
                  ),
                  child: Icon(icon, size: 16,
                    color: isActive
                        ? color.withValues(alpha: 0.90)
                        : _textSoft.withValues(alpha: 0.35)),
                ),
                const Spacer(),
                // Active status dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? color.withValues(alpha: 0.75)
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Label
            Text(label, style: TextStyle(
              color: isActive
                  ? _text.withValues(alpha: 0.90)
                  : _text.withValues(alpha: 0.55),
              fontSize: 13.5,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: -0.2,
            )),
            const SizedBox(height: 3),
            // Value or badge
            badge != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$badge', style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w700,
                    )),
                  )
                : Text(value, style: TextStyle(
                    color: isActive
                        ? color.withValues(alpha: 0.60)
                        : _textSoft.withValues(alpha: 0.35),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  )),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // (Old status bar and focus engine removed — replaced by new hub design)
  // ─────────────────────────────────────────────────────────────────────────


  // ─────────────────────────────────────────────────────────────────────────
  // 3. INLINE TO-DO LIST
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildInlineTodoList(BuildContext context, List<TodoItem> allTodos, double sf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'Your To Do',
            style: TextStyle(
              color: _text,
              fontSize: (18.5 * sf).clamp(15.0, 24.0),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        
        SizedBox(height: (8 * sf).clamp(6.0, 12.0)),

        // Input Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _todoCtrl,
                  focusNode: _todoFocusNode,
                  onTapOutside: (_) => _todoFocusNode.unfocus(),
                  style: TextStyle(
                    color: _text.withValues(alpha: 0.85),
                    fontSize: (16 * sf).clamp(14.0, 20.0),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add new task',
                    hintStyle: TextStyle(
                      color: _textSoft.withValues(alpha: 0.5),
                      fontSize: (16 * sf).clamp(14.0, 20.0),
                    ),
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(color: _border, width: 1.5),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _border, width: 1.5),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: _sage, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    isDense: true,
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) {
                      ref.read(todoProvider.notifier).addTodo(title: val.trim());
                      _todoCtrl.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final val = _todoCtrl.text.trim();
                  if (val.isNotEmpty) {
                    ref.read(todoProvider.notifier).addTodo(title: val);
                    _todoCtrl.clear();
                  }
                },
                child: Container(
                  width: (40 * sf).clamp(34.0, 48.0),
                  height: (40 * sf).clamp(34.0, 48.0),
                  decoration: BoxDecoration(
                    color: _text.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add_rounded, color: _text, size: 22 * sf),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Task List — Standard preview (showing 3)
        ...allTodos.take(3).map((todo) {
          final isDone = todo.isCompleted;

          return Padding(
            padding: EdgeInsets.only(bottom: (4 * sf).clamp(2.0, 6.0)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: (14 * sf).clamp(10.0, 18.0),
                vertical: (8 * sf).clamp(6.0, 12.0),
              ),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Row(
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: () {
                      ref.read(todoProvider.notifier).toggleTodo(todo.id);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: (24 * sf).clamp(20.0, 28.0),
                      height: (24 * sf).clamp(20.0, 28.0),
                      decoration: BoxDecoration(
                        color: isDone ? _textSoft.withValues(alpha: 0.7) : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: isDone ? Colors.transparent : _border.withValues(alpha: 0.8),
                          width: 1.6,
                        ),
                      ),
                      child: isDone
                          ? Icon(Icons.check_rounded, size: 18 * sf, color: _card)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title
                  Expanded(
                    child: Text(
                      todo.title,
                      style: TextStyle(
                        color: isDone
                            ? _textSoft.withValues(alpha: 0.5)
                            : _text.withValues(alpha: 0.85),
                          fontSize: (15.5 * sf).clamp(13.0, 20.0),
                        fontWeight: isDone ? FontWeight.w500 : FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationThickness: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Delete button
                  GestureDetector(
                    onTap: () {
                      ref.read(todoProvider.notifier).deleteTodo(todo.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: (18 * sf).clamp(14.0, 22.0),
                        color: _textSoft.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        
        if (allTodos.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0, left: 4.0),
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.push(
                  context,
                  SmoothForwardRoute(
                    child: _ProductivitySubScreen(
                      title: 'Tasks',
                      child: _TodoTab(),
                    ),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                '+${allTodos.length - 3} more',
                style: TextStyle(
                  color: _textSoft,
                  fontSize: (14 * sf).clamp(12.0, 17.0),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        
        if (allTodos.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Your space is clear. Relax.',
                  style: TextStyle(
                    color: _textSoft.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOCUS RING CUSTOM PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _FocusRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _FocusRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}

/// Wrapper screen for Productivity sub-screens (Focus, Tasks, Doubts, Blocker)
class _ProductivitySubScreen extends ConsumerWidget {
  final String title;
  final Widget child;
  const _ProductivitySubScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme-aware colors for sub-screen header
    final isLight = ref.watch(themeColorProvider).isLight;
    final themeBg = isLight ? const Color(0xFFF5F5F5) : Colors.black;
    final themeText = isLight
        ? const Color(0xFF0D0D0D).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.85);
    final themeIcon = isLight
        ? const Color(0xFF0D0D0D).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);

    final textColor = themeText;
    final iconColor = themeIcon;

    return SwipeBackWrapper(
      child: Scaffold(
      // Scaffold fills edge-to-edge behind the system bars; EdgeToEdge insets
      // the content. Icon brightness follows the light/dark theme.
      backgroundColor: themeBg,
      body: EdgeToEdge(
        iconBrightness: isLight ? Brightness.dark : Brightness.light,
        child: Column(
          children: [
            // Minimal back header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Child screen
            Expanded(child: child),
          ],
        ),
      ),
    ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 📋 TODO TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _TodoTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_TodoTab> createState() => _TodoTabState();
}

class _TodoTabState extends ConsumerState<_TodoTab> {

  // ── Theme-aware colors ──
  bool get _isLight => ref.watch(themeColorProvider).isLight;
  Color get _bg => _isLight ? const Color(0xFFF5F5F5) : _ftBg;
  Color get _card => _isLight ? Colors.black.withValues(alpha: 0.04) : _ftCard;
  Color get _text => _isLight ? const Color(0xFF0D0D0D) : _ftText;
  Color get _textSoft => _isLight ? const Color(0xFF6B6B6B) : _ftTextSoft;
  Color get _border => _isLight ? Colors.black.withValues(alpha: 0.08) : _ftBorder;
  Color get _sage => ref.watch(themeColorProvider).color;
  Color get _sageDark {
    final themeColor = ref.watch(themeColorProvider).color;
    final hslColor = HSLColor.fromColor(themeColor);
    return hslColor
        .withLightness((hslColor.lightness * 0.85).clamp(0.0, 1.0))
        .toColor();
  }
  Color get _gold => _ftGold;
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final todos = ref.watch(todoProvider);
    final events = ref.watch(productivityEventProvider);
    final filtered = _filter == 'all'
        ? todos
        : _filter == 'active'
            ? todos.where((t) => !t.isCompleted).toList()
            : todos.where((t) => t.isCompleted).toList();
    final pending = todos.where((t) => !t.isCompleted).length;

    // Events: show today's + upcoming (only in 'all' or 'active' filter)
    final now = DateTime.now();
    final todayEvents = (_filter != 'done')
        ? events.where((e) {
            final d = e.startTime;
            return d.year == now.year && d.month == now.month && d.day == now.day;
          }).toList()
        : <ProductivityEvent>[];
    final upcomingEvents = (_filter != 'done')
        ? events
            .where((e) => e.startTime.isAfter(now) &&
                !(e.startTime.year == now.year &&
                    e.startTime.month == now.month &&
                    e.startTime.day == now.day))
            .take(3)
            .toList()
        : <ProductivityEvent>[];

    // Build a unified list: today events → todos → upcoming events
    final hasEvents = todayEvents.isNotEmpty || upcomingEvents.isNotEmpty;
    final isEmpty = filtered.isEmpty && !hasEvents;

    return Column(
      children: [
        // Stats bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Text(
                '$pending tasks pending',
                style: TextStyle(
                  color: _textSoft,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              _filterChip('all'),
              const SizedBox(width: 6),
              _filterChip('active'),
              const SizedBox(width: 6),
              _filterChip('done'),
            ],
          ),
        ),
        // Unified list
        Expanded(
          child: isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 48,
                          color: _border),
                      const SizedBox(height: 12),
                      Text(
                        _filter == 'done'
                            ? 'No completed tasks'
                            : 'A productive day starts with intention.\nAdd your first task — Bismillah.',
                        style: TextStyle(
                            color: _textSoft,
                            height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    // Today's events
                    if (todayEvents.isNotEmpty) ...[
                      _sectionLabel('Today\'s Events'),
                      ...todayEvents.map((e) => _inlineEventTile(e)),
                      const SizedBox(height: 8),
                    ],
                    // Todos
                    ...filtered.map((t) => _todoTile(t)),
                    // Upcoming events
                    if (upcomingEvents.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _sectionLabel('Upcoming'),
                      ...upcomingEvents.map((e) => _inlineEventTile(e)),
                    ],
                  ],
                ),
        ),
        // Add buttons row — task + event
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _AddButton(
                  label: 'Add Task',
                  icon: Icons.add,
                  onTap: () => _showAddTodo(context),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showAddEvent(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gold.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_outlined,
                          size: 16, color: _gold.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text('Event',
                          style: TextStyle(
                            color: _gold.withValues(alpha: 0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text,
        style: TextStyle(
          color: _textSoft,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _inlineEventTile(ProductivityEvent event) {
    final color = Color(int.parse('FF${event.color}', radix: 16));
    String timeText;
    if (event.isAllDay) {
      timeText = 'All day';
    } else if (event.endTime != null) {
      timeText = '${DateFormat('h:mm a').format(event.startTime)} — ${DateFormat('h:mm a').format(event.endTime!)}';
    } else if (event.startTime.hour == 9 && event.startTime.minute == 0) {
      timeText = DateFormat('MMM d').format(event.startTime);
    } else {
      timeText = DateFormat('h:mm a').format(event.startTime);
    }

    return GestureDetector(
      onLongPress: () => _showEventOptions(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 3, height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TextStyle(
                          color: _text,
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(timeText,
                      style: TextStyle(
                          color: _textSoft,
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.event_outlined, size: 14,
                color: color.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  void _showEventOptions(ProductivityEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.add_task, color: _sage),
              title: Text('Create Todo from Event',
                  style: TextStyle(color: _text)),
              onTap: () {
                ref.read(todoProvider.notifier).addTodo(
                      title: event.title,
                      dueDate: event.startTime,
                      linkedEventId: event.id,
                    );
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.shield_outlined,
                  color: _gold),
              title: Text('Block apps during event',
                  style: TextStyle(color: _text)),
              onTap: () {
                Navigator.pop(ctx);
                _createBlockRuleForEvent(event);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Colors.red.withValues(alpha: 0.6)),
              title: Text('Delete',
                  style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.7))),
              onTap: () {
                ref
                    .read(productivityEventProvider.notifier)
                    .deleteEvent(event.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createBlockRuleForEvent(ProductivityEvent event) {
    final endHour = event.endTime?.hour ?? (event.startTime.hour + 1);
    final endMinute = event.endTime?.minute ?? event.startTime.minute;
    ref.read(appBlockRuleProvider.notifier).addRule(
          name: '${event.title} block',
          isTimeBased: true,
          startHour: event.startTime.hour,
          startMinute: event.startTime.minute,
          endHour: endHour,
          endMinute: endMinute,
          activeDays: [event.startTime.weekday],
          linkedEventId: event.id,
        );
  }

  Widget _filterChip(String label) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? _sage.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _sage.withValues(alpha: 0.3)
                : _border,
          ),
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: TextStyle(
            fontSize: 12,
            color: selected ? _sageDark : _textSoft,
          ),
        ),
      ),
    );
  }

  Widget _todoTile(TodoItem todo) {
    final priorityColors = [
      _textSoft,
      _sage,
      _gold,
      const Color(0xFFD97B4A),
    ];
    final color = priorityColors[todo.priority.clamp(0, 3)];

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline,
            color: Colors.red.withValues(alpha: 0.5)),
      ),
      onDismissed: (_) => ref.read(todoProvider.notifier).deleteTodo(todo.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: ListTile(
          dense: true,
          leading: GestureDetector(
            onTap: () {
              ref.read(todoProvider.notifier).toggleTodo(todo.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: todo.isCompleted
                    ? _sage.withValues(alpha: 0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: todo.isCompleted
                      ? _sage
                      : color.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: todo.isCompleted
                  ? Icon(Icons.check, size: 14, color: _sage)
                  : null,
            ),
          ),
          title: Text(
            todo.title,
            style: TextStyle(
              color: todo.isCompleted
                  ? _textSoft.withValues(alpha: 0.5)
                  : _text,
              fontSize: 15,
              decoration:
                  todo.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: todo.dueDate != null
              ? Text(
                  DateFormat('MMM d, h:mm a').format(todo.dueDate!),
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDueToday(todo.dueDate!)
                        ? const Color(0xFFD97B4A)
                        : _textSoft,
                  ),
                )
              : null,
          trailing: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  bool _isDueToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showAddTodo(BuildContext context) {
    final controller = TextEditingController();
    int priority = 1;
    DateTime? dueDate;
    String? linkedDoubtId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text('New Task',
                  style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              // Text field
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: _text),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle:
                      TextStyle(color: _textSoft),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _sage.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Priority row
              Row(
                children: [
                  Text('Priority:',
                      style: TextStyle(
                          color: _textSoft,
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  for (int p = 1; p <= 3; p++)
                    GestureDetector(
                      onTap: () => setBS(() => priority = p),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: priority == p
                              ? [
                                  Colors.transparent,
                                  _sage,
                                  _gold,
                                  const Color(0xFFD97B4A)
                                ][p]
                                  .withValues(alpha: 0.12)
                              : _bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: priority == p
                                ? [Colors.transparent, _sage, _gold, const Color(0xFFD97B4A)][p].withValues(alpha: 0.3)
                                : _border,
                          ),
                        ),
                        child: Text(
                          ['', 'Low', 'Med', 'High'][p],
                          style: TextStyle(
                            fontSize: 11,
                            color: priority == p
                                ? [Colors.transparent, _sageDark, _gold, const Color(0xFFD97B4A)][p]
                                : _textSoft,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Due date
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null && ctx.mounted) {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        setBS(() {
                          dueDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time?.hour ?? 23,
                            time?.minute ?? 59,
                          );
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: dueDate != null
                            ? _gold.withValues(alpha: 0.1)
                            : _bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: dueDate != null ? _gold.withValues(alpha: 0.25) : _border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12,
                              color: dueDate != null
                                  ? _gold
                                  : _textSoft),
                          if (dueDate != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d').format(dueDate!),
                              style: TextStyle(
                                  fontSize: 11, color: _gold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // Link to doubt
              Consumer(builder: (ctx, cRef, _) {
                final doubts = cRef.watch(academicDoubtProvider)
                    .where((d) => !d.isResolved)
                    .toList();
                if (doubts.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GestureDetector(
                    onTap: () {
                      _showLinkDoubtPicker(ctx, doubts, (id) {
                        setBS(() => linkedDoubtId = id);
                      });
                    },
                    child: Row(
                      children: [
                        Icon(Icons.link,
                            size: 14,
                            color: linkedDoubtId != null
                                ? _sage
                                : _textSoft),
                        const SizedBox(width: 6),
                        Text(
                          linkedDoubtId != null
                              ? 'Linked to doubt ✓'
                              : 'Link to academic doubt',
                          style: TextStyle(
                            fontSize: 12,
                            color: linkedDoubtId != null
                                ? _sage
                                : _textSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (controller.text.trim().isEmpty) return;
                    ref.read(todoProvider.notifier).addTodo(
                          title: controller.text.trim(),
                          priority: priority,
                          dueDate: dueDate,
                          linkedDoubtId: linkedDoubtId,
                        );
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sage.withValues(alpha: 0.15),
                    foregroundColor: _sageDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Add Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkDoubtPicker(BuildContext context, List<AcademicDoubt> doubts,
      void Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SizedBox(
        height: 300,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: doubts.length,
          itemBuilder: (ctx, i) => ListTile(
            dense: true,
            title: Text(doubts[i].question,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _text, fontSize: 13)),
            subtitle: Text(doubts[i].subject,
                style: TextStyle(
                    color: _gold, fontSize: 11)),
            onTap: () {
              onSelect(doubts[i].id);
              Navigator.pop(ctx);
            },
          ),
        ),
      ),
    );
  }

  void _showAddEvent(BuildContext context) {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;
    bool isAllDay = false;
    bool hasSpecificTime = false;
    String selectedColor = 'C2A366';

    final colorOptions = {
      'C2A366': _gold,
      'A67B5B': _warmBrown,
      '7BAE6E': _sage,
      'E8915A': const Color(0xFFD97B4A),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Event',
                    style: TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: TextStyle(color: _text),
                  decoration: InputDecoration(
                    hintText: 'Event title',
                    hintStyle:
                        TextStyle(color: _textSoft),
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _sage.withValues(alpha: 0.4))),
                  ),
                ),
                const SizedBox(height: 12),
                // Date picker
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) setBS(() => selectedDate = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: _gold),
                        const SizedBox(width: 10),
                        Text(DateFormat('EEE, MMM d').format(selectedDate),
                            style: TextStyle(color: _text, fontSize: 13)),
                        const Spacer(),
                        Icon(Icons.chevron_right, size: 16, color: _textSoft),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // All day
                Row(
                  children: [
                    Text('All day', style: TextStyle(color: _textSoft, fontSize: 13)),
                    const Spacer(),
                    Switch(value: isAllDay, onChanged: (v) => setBS(() { isAllDay = v; if (v) hasSpecificTime = false; }), activeThumbColor: _sage),
                  ],
                ),
                if (!isAllDay) ...[
                  Row(
                    children: [
                      Text('Set time', style: TextStyle(color: _textSoft, fontSize: 13)),
                      const Spacer(),
                      Switch(value: hasSpecificTime, onChanged: (v) => setBS(() { hasSpecificTime = v; if (v && selectedStartTime == null) selectedStartTime = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1))); }), activeThumbColor: _sage),
                    ],
                  ),
                  if (hasSpecificTime) ...[
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(context: ctx, initialTime: selectedStartTime ?? TimeOfDay.now());
                        if (time != null) setBS(() => selectedStartTime = time);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                        child: Row(children: [
                          Text('Start', style: TextStyle(color: _textSoft, fontSize: 12)),
                          const Spacer(),
                          Text(selectedStartTime?.format(ctx) ?? 'Set', style: TextStyle(color: _text, fontSize: 13)),
                        ]),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(context: ctx, initialTime: selectedEndTime ?? TimeOfDay(hour: (selectedStartTime?.hour ?? TimeOfDay.now().hour) + 1, minute: selectedStartTime?.minute ?? 0));
                        if (time != null) setBS(() => selectedEndTime = time);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                        child: Row(children: [
                          Text('End (optional)', style: TextStyle(color: _textSoft, fontSize: 12)),
                          const Spacer(),
                          Text(selectedEndTime?.format(ctx) ?? '—', style: TextStyle(color: selectedEndTime != null ? _text : _textSoft, fontSize: 13)),
                        ]),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                // Color
                Row(
                  children: [
                    Text('Color', style: TextStyle(color: _textSoft, fontSize: 12)),
                    const SizedBox(width: 12),
                    ...colorOptions.entries.map((e) => GestureDetector(
                          onTap: () => setBS(() => selectedColor = e.key),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8), width: 24, height: 24,
                            decoration: BoxDecoration(color: e.value, shape: BoxShape.circle,
                              border: selectedColor == e.key ? Border.all(color: _text, width: 2) : null),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      DateTime finalStart;
                      DateTime? finalEnd;
                      if (isAllDay) {
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                      } else if (hasSpecificTime && selectedStartTime != null) {
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedStartTime!.hour, selectedStartTime!.minute);
                        if (selectedEndTime != null) {
                          finalEnd = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedEndTime!.hour, selectedEndTime!.minute);
                        }
                      } else {
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 9, 0);
                      }
                      ref.read(productivityEventProvider.notifier).addEvent(
                            title: titleCtrl.text.trim(),
                            startTime: finalStart,
                            endTime: finalEnd,
                            color: selectedColor,
                            isAllDay: isAllDay,
                          );
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sage.withValues(alpha: 0.15),
                      foregroundColor: _sageDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Create Event'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 📝 ACADEMIC DOUBTS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _DoubtsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DoubtsTab> createState() => _DoubtsTabState();
}

class _DoubtsTabState extends ConsumerState<_DoubtsTab> {

  // ── Theme-aware colors ──
  bool get _isLight => ref.watch(themeColorProvider).isLight;
  Color get _bg => _isLight ? const Color(0xFFF5F5F5) : _ftBg;
  Color get _card => _isLight ? Colors.black.withValues(alpha: 0.04) : _ftCard;
  Color get _text => _isLight ? const Color(0xFF0D0D0D) : _ftText;
  Color get _textSoft => _isLight ? const Color(0xFF6B6B6B) : _ftTextSoft;
  Color get _border => _isLight ? Colors.black.withValues(alpha: 0.08) : _ftBorder;
  Color get _sage => ref.watch(themeColorProvider).color;
  Color get _sageDark {
    final themeColor = ref.watch(themeColorProvider).color;
    final hslColor = HSLColor.fromColor(themeColor);
    return hslColor
        .withLightness((hslColor.lightness * 0.85).clamp(0.0, 1.0))
        .toColor();
  }
  Color get _gold => _ftGold;
  String _subjectFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final doubts = ref.watch(academicDoubtProvider);
    final subjects = ['All', ...ref.read(academicDoubtProvider.notifier).allSubjects];
    final filtered = _subjectFilter == 'All'
        ? doubts
        : doubts.where((d) => d.subject == _subjectFilter).toList();
    final unresolved = doubts.where((d) => !d.isResolved).length;

    return Column(
      children: [
        // Subject filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: subjects.map((s) {
                final selected = _subjectFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _subjectFilter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? _sage.withValues(alpha: 0.12)
                            : _card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? _sage.withValues(alpha: 0.3)
                              : _border,
                        ),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 11,
                          color: selected
                              ? _sageDark
                              : _textSoft,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '$unresolved unresolved',
                style: TextStyle(
                    color: const Color(0xFFD97B4A),
                    fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${doubts.length} total',
                style: TextStyle(
                    color: _textSoft, fontSize: 11),
              ),
            ],
          ),
        ),
        // Doubts list
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 48,
                          color: _border),
                      const SizedBox(height: 12),
                      Text('No doubts yet',
                          style: TextStyle(
                              color: _textSoft)),
                      const SizedBox(height: 4),
                      Text('Note down academic questions',
                          style: TextStyle(
                              color: _textSoft.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _doubtCard(filtered[i]),
                ),
        ),
        // Add
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AddButton(
            label: 'Add Doubt',
            icon: Icons.add,
            onTap: () => _showAddDoubt(context),
          ),
        ),
      ],
    );
  }

  Widget _doubtCard(AcademicDoubt doubt) {
    return GestureDetector(
      onTap: () => _showDoubtDetail(doubt),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: doubt.isResolved
                ? _sage.withValues(alpha: 0.25)
                : _border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(doubt.subject,
                      style:
                          TextStyle(fontSize: 10, color: _gold)),
                ),
                const Spacer(),
                if (doubt.isResolved)
                  Icon(Icons.check_circle,
                      size: 16,
                      color: _sage),
                if (!doubt.isResolved)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      doubt.urgency.clamp(1, 3),
                      (_) => Icon(Icons.priority_high,
                          size: 10,
                          color: const Color(0xFFD97B4A).withValues(alpha: 0.6)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              doubt.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (doubt.answer != null && doubt.answer!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                doubt.answer!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _sage,
                  fontSize: 11,
                ),
              ),
            ],
            if (doubt.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: doubt.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _border),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: _textSoft)),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDoubtDetail(AcademicDoubt doubt) {
    final answerController = TextEditingController(text: doubt.answer ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(doubt.subject,
                      style:
                          TextStyle(fontSize: 11, color: _gold)),
                ),
                const Spacer(),
                // Delete
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18,
                      color: Colors.red.withValues(alpha: 0.5)),
                  onPressed: () {
                    ref
                        .read(academicDoubtProvider.notifier)
                        .deleteDoubt(doubt.id);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              doubt.question,
              style: TextStyle(
                color: _text,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Text('Answer / Resolution',
                style: TextStyle(
                    color: _textSoft,
                    fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: answerController,
              maxLines: 4,
              style: TextStyle(color: _text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type your answer or resolution...',
                hintStyle:
                    TextStyle(color: _textSoft),
                filled: true,
                fillColor: _bg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _sage.withValues(alpha: 0.4))),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (answerController.text.trim().isNotEmpty) {
                        ref
                            .read(academicDoubtProvider.notifier)
                            .resolveDoubt(
                                doubt.id, answerController.text.trim());
                      }
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sage.withValues(alpha: 0.15),
                      foregroundColor: _sageDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(doubt.isResolved
                        ? 'Update'
                        : 'Mark Resolved'),
                  ),
                ),
                // Create todo from doubt
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ref.read(todoProvider.notifier).addTodo(
                          title: 'Resolve: ${doubt.question}',
                          priority: doubt.urgency,
                          linkedDoubtId: doubt.id,
                        );
                    Navigator.pop(ctx);
                    // Brief non-blocking overlay instead of sticky snackbar
                    if (context.mounted) {
                      final overlay = Overlay.of(context);
                      final entry = OverlayEntry(
                        builder: (context) => Positioned(
                          top: MediaQuery.of(context).padding.top + 60,
                          left: 40,
                          right: 40,
                          child: Material(
                            color: Colors.transparent,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, -10 * (1 - value)),
                                  child: child,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _sage.withValues(alpha: 0.2)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_outline,
                                        color: _sage, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Todo created ✓',
                                        style: TextStyle(color: _text,
                                            fontSize: 13, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                      overlay.insert(entry);
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        entry.remove();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_task,
                        size: 20, color: _gold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDoubt(BuildContext context) {
    final questionCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    int urgency = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Doubt',
                  style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              // Subject
              TextField(
                controller: subjectCtrl,
                style: TextStyle(color: _text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Subject (e.g. Math, Physics)',
                  hintStyle:
                      TextStyle(color: _textSoft),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _sage.withValues(alpha: 0.4))),
                ),
              ),
              const SizedBox(height: 10),
              // Question
              TextField(
                controller: questionCtrl,
                autofocus: true,
                maxLines: 3,
                style: TextStyle(color: _text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe your doubt...',
                  hintStyle:
                      TextStyle(color: _textSoft),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _sage.withValues(alpha: 0.4))),
                ),
              ),
              const SizedBox(height: 10),
              // Tags
              TextField(
                controller: tagsCtrl,
                style: TextStyle(color: _text, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Tags (comma separated)',
                  hintStyle:
                      TextStyle(color: _textSoft),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _sage.withValues(alpha: 0.4))),
                ),
              ),
              const SizedBox(height: 10),
              // Urgency
              Row(
                children: [
                  Text('Urgency:',
                      style: TextStyle(
                          color: _textSoft,
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  for (int u = 1; u <= 3; u++)
                    GestureDetector(
                      onTap: () => setBS(() => urgency = u),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: urgency == u
                              ? [
                                  Colors.transparent,
                                  _sage,
                                  _gold,
                                  const Color(0xFFD97B4A)
                                ][u]
                                  .withValues(alpha: 0.12)
                              : _bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: urgency == u
                                ? [Colors.transparent, _sage, _gold, const Color(0xFFD97B4A)][u].withValues(alpha: 0.3)
                                : _border,
                          ),
                        ),
                        child: Text(
                          ['', 'Low', 'Medium', 'Urgent'][u],
                          style: TextStyle(
                            fontSize: 11,
                            color: urgency == u
                                ? [Colors.transparent, _sageDark, _gold, const Color(0xFFD97B4A)][u]
                                : _textSoft,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (questionCtrl.text.trim().isEmpty) return;
                    final tags = tagsCtrl.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    ref.read(academicDoubtProvider.notifier).addDoubt(
                          subject: subjectCtrl.text.trim().isEmpty
                              ? 'General'
                              : subjectCtrl.text.trim(),
                          question: questionCtrl.text.trim(),
                          urgency: urgency,
                          tags: tags.isEmpty ? null : tags,
                        );
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sage.withValues(alpha: 0.15),
                    foregroundColor: _sageDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Add Doubt'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 📅 EVENTS TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _EventsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends ConsumerState<_EventsTab> {

  // ── Theme-aware colors ──
  bool get _isLight => ref.watch(themeColorProvider).isLight;
  Color get _bg => _isLight ? const Color(0xFFF5F5F5) : _ftBg;
  Color get _card => _isLight ? Colors.black.withValues(alpha: 0.04) : _ftCard;
  Color get _text => _isLight ? const Color(0xFF0D0D0D) : _ftText;
  Color get _textSoft => _isLight ? const Color(0xFF6B6B6B) : _ftTextSoft;
  Color get _border => _isLight ? Colors.black.withValues(alpha: 0.08) : _ftBorder;
  Color get _sage => ref.watch(themeColorProvider).color;
  Color get _sageDark {
    final themeColor = ref.watch(themeColorProvider).color;
    final hslColor = HSLColor.fromColor(themeColor);
    return hslColor
        .withLightness((hslColor.lightness * 0.85).clamp(0.0, 1.0))
        .toColor();
  }

  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(productivityEventProvider);
    final dateEvents = ref.watch(eventsForDateProvider(_selectedDate));
    final upcoming = events
        .where((e) => e.startTime.isAfter(DateTime.now()))
        .take(5)
        .toList();

    return Column(
      children: [
        // Date selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: _WeekStrip(
            selected: _selectedDate,
            eventDates: ref.watch(productivityEventDatesProvider),
            onSelect: (d) => setState(() => _selectedDate = d),
          ),
        ),
        // Events for date
        Expanded(
          child: dateEvents.isEmpty && upcoming.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_outlined,
                          size: 48,
                          color: _border),
                      const SizedBox(height: 12),
                      Text('No events',
                          style: TextStyle(
                              color: _textSoft)),
                    ],
                  ),
                )
              : ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    if (dateEvents.isNotEmpty) ...[
                      Text(
                        DateFormat('EEEE, MMMM d').format(_selectedDate),
                        style: TextStyle(
                            color: _textSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      ...dateEvents.map(_eventCard),
                    ],
                    if (dateEvents.isEmpty && upcoming.isNotEmpty) ...[
                      Text('Upcoming',
                          style: TextStyle(
                              color: _textSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      ...upcoming.map(_eventCard),
                    ],
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _AddButton(
            label: 'Add Event',
            icon: Icons.add,
            onTap: () => _showAddEvent(context),
          ),
        ),
      ],
    );
  }

  Widget _eventCard(ProductivityEvent event) {
    final color = Color(int.parse('FF${event.color}', radix: 16));
    final now = DateTime.now();
    final isActive = event.startTime.isBefore(now) && 
        (event.endTime?.isAfter(now) ?? event.startTime.day == now.day);

    String timeText;
    if (event.isAllDay) {
      timeText = 'All day';
    } else if (event.endTime != null) {
      timeText = '${DateFormat('h:mm a').format(event.startTime)} — ${DateFormat('h:mm a').format(event.endTime!)}';
    } else if (event.startTime.hour == 9 && event.startTime.minute == 0) {
      // Date-only event (no specific time set)
      timeText = DateFormat('MMM d').format(event.startTime);
    } else {
      timeText = DateFormat('h:mm a').format(event.startTime);
    }

    return GestureDetector(
      onLongPress: () => _showEventOptions(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.1)
              : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.3)
                : _border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      color: _text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeText,
                    style: TextStyle(
                      color: _textSoft,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (event.linkedBlockRuleId != null)
              Icon(Icons.shield_outlined,
                  size: 16,
                  color: _desertSunset.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _showEventOptions(ProductivityEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.add_task, color: _sage),
              title: Text('Create Todo from Event',
                  style: TextStyle(color: _text)),
              onTap: () {
                ref.read(todoProvider.notifier).addTodo(
                      title: event.title,
                      dueDate: event.startTime,
                      linkedEventId: event.id,
                    );
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.shield_outlined,
                  color: _desertSunset),
              title: Text('Block apps during event',
                  style: TextStyle(color: _text)),
              onTap: () {
                Navigator.pop(ctx);
                _createBlockRuleForEvent(event);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Colors.red.withValues(alpha: 0.6)),
              title: Text('Delete',
                  style: TextStyle(
                      color: Colors.red.withValues(alpha: 0.7))),
              onTap: () {
                ref
                    .read(productivityEventProvider.notifier)
                    .deleteEvent(event.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createBlockRuleForEvent(ProductivityEvent event) {
    // Auto-create a time-based block rule matching event time
    final endHour = event.endTime?.hour ?? (event.startTime.hour + 1);
    final endMinute = event.endTime?.minute ?? event.startTime.minute;
    ref.read(appBlockRuleProvider.notifier).addRule(
          name: '${event.title} block',
          isTimeBased: true,
          startHour: event.startTime.hour,
          startMinute: event.startTime.minute,
          endHour: endHour,
          endMinute: endMinute,
          activeDays: [event.startTime.weekday],
          linkedEventId: event.id,
        ).then((rule) {
      // Auto-open app selector for the new rule
      if (mounted) {
        _showEditAppsForRule(context, ref, rule);
      }
    });
  }

  void _showEditAppsForRule(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    final allApps = ref.read(installedAppsProvider);
    final selected = Set<String>.from(rule.blockedPackages);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Select Apps to Block',
                              style: TextStyle(
                                  color: _text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Block rule: ${rule.name}',
                              style: TextStyle(
                                  color: _sage.withValues(alpha: 0.5),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ref
                            .read(appBlockRuleProvider.notifier)
                            .updateRule(rule.id,
                                blockedPackages: selected.toList());
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${selected.length} apps will be blocked during event'),
                            backgroundColor: _sage,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _sage.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Done',
                            style: TextStyle(
                                color: _sageDark, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: allApps.length,
                  itemBuilder: (ctx, i) {
                    final app = allApps[i];
                    final isSelected =
                        selected.contains(app.packageName);
                    return ListTile(
                      dense: true,
                      title: Text(app.appName,
                          style: TextStyle(
                              color: _text, fontSize: 13)),
                      subtitle: Text(app.packageName,
                          style: TextStyle(
                              color: _textSoft,
                              fontSize: 10)),
                      trailing: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isSelected
                            ? _desertSunset
                            : _border,
                        size: 20,
                      ),
                      onTap: () {
                        setBS(() {
                          if (isSelected) {
                            selected.remove(app.packageName);
                          } else {
                            selected.add(app.packageName);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEvent(BuildContext context) {
    final accent = _sage;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
    TimeOfDay? selectedStartTime;
    TimeOfDay? selectedEndTime;
    bool isAllDay = false;
    bool hasSpecificTime = false;
    String selectedColor = 'C2A366';

    final colorOptions = {
      'C2A366': accent,
      'A67B5B': _warmBrown,
      '7BAE6E': _oasisGreen,
      'E8915A': _desertSunset,
      'D4A96A': _desertWarm,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Event',
                    style: TextStyle(
                        color: _text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  style: TextStyle(color: _text),
                  decoration: InputDecoration(
                    hintText: 'Event title',
                    hintStyle:
                        TextStyle(color: _textSoft),
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent.withValues(alpha: 0.4))),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: _text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: TextStyle(color: _textSoft),
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: accent.withValues(alpha: 0.4))),
                  ),
                ),
                const SizedBox(height: 12),
                // Date picker (always shown)
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setBS(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: accent.withValues(alpha: 0.7)),
                        const SizedBox(width: 10),
                        Text('Date',
                            style: TextStyle(
                                color: _textSoft,
                                fontSize: 12)),
                        const Spacer(),
                        Text(
                          DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                          style: TextStyle(color: _text, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 16,
                            color: _textSoft),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // All day toggle
                Row(
                  children: [
                    Text('All day',
                        style: TextStyle(
                            color: _textSoft,
                            fontSize: 13)),
                    const Spacer(),
                    Switch(
                      value: isAllDay,
                      onChanged: (v) => setBS(() {
                        isAllDay = v;
                        if (v) hasSpecificTime = false;
                      }),
                      activeThumbColor: accent,
                    ),
                  ],
                ),
                if (!isAllDay) ...[
                  // Add specific time toggle
                  Row(
                    children: [
                      Text('Add specific time',
                          style: TextStyle(
                              color: _textSoft,
                              fontSize: 13)),
                      const Spacer(),
                      Switch(
                        value: hasSpecificTime,
                        onChanged: (v) => setBS(() {
                          hasSpecificTime = v;
                          if (v && selectedStartTime == null) {
                            selectedStartTime = TimeOfDay.fromDateTime(
                                DateTime.now().add(const Duration(hours: 1)));
                          }
                        }),
                        activeThumbColor: accent,
                      ),
                    ],
                  ),
                  if (hasSpecificTime) ...[
                    // Start time
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: selectedStartTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setBS(() => selectedStartTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Text('Start',
                                style: TextStyle(
                                    color: _textSoft,
                                    fontSize: 12)),
                            const Spacer(),
                            Text(
                              selectedStartTime?.format(ctx) ?? 'Set time',
                              style: TextStyle(color: _text, fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 16,
                                color: _textSoft),
                          ],
                        ),
                      ),
                    ),
                    // End time (optional)
                    GestureDetector(
                      onTap: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: selectedEndTime ??
                              TimeOfDay(
                                  hour: (selectedStartTime?.hour ?? TimeOfDay.now().hour) + 1,
                                  minute: selectedStartTime?.minute ?? 0),
                        );
                        if (time != null) {
                          setBS(() => selectedEndTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Text('End',
                                style: TextStyle(
                                    color: _textSoft,
                                    fontSize: 12)),
                            const SizedBox(width: 4),
                            Text('(optional)',
                                style: TextStyle(
                                    color: _textSoft.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic)),
                            const Spacer(),
                            Text(
                              selectedEndTime?.format(ctx) ?? '—',
                              style: TextStyle(
                                  color: selectedEndTime != null
                                      ? _text
                                      : _textSoft,
                                  fontSize: 13),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right,
                                size: 16,
                                color: _textSoft),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                // Color picker
                Row(
                  children: [
                    Text('Color',
                        style: TextStyle(
                            color: _textSoft,
                            fontSize: 12)),
                    const SizedBox(width: 12),
                    ...colorOptions.entries.map((e) => GestureDetector(
                          onTap: () => setBS(() => selectedColor = e.key),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border: selectedColor == e.key
                                  ? Border.all(color: _text, width: 2)
                                  : null,
                            ),
                          ),
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      // Build startTime from date + optional time
                      DateTime finalStart;
                      DateTime? finalEnd;
                      if (isAllDay) {
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                        finalEnd = null;
                      } else if (hasSpecificTime && selectedStartTime != null) {
                        finalStart = DateTime(selectedDate.year, selectedDate.month,
                            selectedDate.day, selectedStartTime!.hour, selectedStartTime!.minute);
                        if (selectedEndTime != null) {
                          finalEnd = DateTime(selectedDate.year, selectedDate.month,
                              selectedDate.day, selectedEndTime!.hour, selectedEndTime!.minute);
                        }
                      } else {
                        // Date only, no specific time
                        finalStart = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 9, 0);
                        finalEnd = null;
                      }
                      ref
                          .read(productivityEventProvider.notifier)
                          .addEvent(
                            title: titleCtrl.text.trim(),
                            description: descCtrl.text.trim().isEmpty
                                ? null
                                : descCtrl.text.trim(),
                            startTime: finalStart,
                            endTime: finalEnd,
                            color: selectedColor,
                            isAllDay: isAllDay,
                          );
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.2),
                      foregroundColor: accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Create Event'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ APP BLOCKER TAB
// ═══════════════════════════════════════════════════════════════════════════════

/// A ready-made block schedule the user can flip on/off with one switch.
class _BlockPreset {
  final String name; // also the AppBlockRule identity
  final IconData icon;
  final int startHour, startMinute, endHour, endMinute;
  final List<int> days; // 1=Mon .. 7=Sun
  const _BlockPreset({
    required this.name,
    required this.icon,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.days,
  });
}

const _kAllDays = [1, 2, 3, 4, 5, 6, 7];
const _kWeekdays = [1, 2, 3, 4, 5];

const _kBlockPresets = <_BlockPreset>[
  _BlockPreset(
    name: 'Fajr Focus',
    icon: Icons.wb_twilight_rounded,
    startHour: 4, startMinute: 30, endHour: 6, endMinute: 30,
    days: _kAllDays,
  ),
  _BlockPreset(
    name: 'Work Focus',
    icon: Icons.work_outline_rounded,
    startHour: 9, startMinute: 0, endHour: 17, endMinute: 0,
    days: _kWeekdays,
  ),
  _BlockPreset(
    name: 'Evening Wind-down',
    icon: Icons.nights_stay_rounded,
    startHour: 21, startMinute: 0, endHour: 23, endMinute: 30,
    days: _kAllDays,
  ),
];

/// Common distracting apps a preset blocks — intersected with what's actually
/// installed when the preset is first switched on.
const _kDistractingPackages = <String>[
  'com.instagram.android',
  'com.zhiliaoapp.musically', // TikTok
  'com.ss.android.ugc.trill', // TikTok (intl)
  'com.facebook.katana', // Facebook
  'com.facebook.orca', // Messenger
  'com.google.android.youtube',
  'com.twitter.android',
  'com.x.android', // X
  'com.snapchat.android',
  'com.reddit.frontpage',
  'com.netflix.mediaclient',
  'com.pinterest',
  'com.linkedin.android',
  'com.whatsapp',
];

class _BlockerTab extends ConsumerStatefulWidget {
  const _BlockerTab();
  @override
  ConsumerState<_BlockerTab> createState() => _BlockerTabState();
}

class _BlockerTabState extends ConsumerState<_BlockerTab> {
  // ── Theme-aware colors ──
  bool get _isLight => ref.watch(themeColorProvider).isLight;
  Color get _card => _isLight ? Colors.black.withValues(alpha: 0.04) : _ftCard;
  Color get _text => _isLight ? const Color(0xFF0D0D0D) : _ftText;
  Color get _textSoft => _isLight ? const Color(0xFF6B6B6B) : _ftTextSoft;
  Color get _border => _isLight ? Colors.black.withValues(alpha: 0.08) : _ftBorder;
  Color get _sage => ref.watch(themeColorProvider).color;
  // Readable ink for text/icons sitting on a solid [_sage] fill — flips to
  // dark on light theme colors, white on dark ones.
  Color get _onSage =>
      ref.watch(themeColorProvider).color.computeLuminance() > 0.55
          ? const Color(0xFF0D0D0D)
          : Colors.white;

  @override
  Widget build(BuildContext context) {
    final allRules = ref.watch(appBlockRuleProvider);
    // Preset-backed rules are surfaced as their own toggle cards below, so
    // keep them out of the custom-rules list to avoid a duplicate entry.
    final presetNames = _kBlockPresets.map((p) => p.name).toSet();
    final rules =
        allRules.where((r) => !presetNames.contains(r.name)).toList();

    return Column(
      children: [
        // Active rules count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(Icons.shield,
                  size: 14,
                  color: allRules.any((r) => r.isEnabled && !r.isSnoozed)
                      ? _sage
                      : _textSoft),
              const SizedBox(width: 6),
              Text(
                '${allRules.where((r) => r.isEnabled && !r.isSnoozed).length} active now',
                style: TextStyle(
                    color: _textSoft,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        // Unified list: ready-made presets (always shown) + custom schedules.
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              for (final p in _kBlockPresets)
                _scheduleCard(preset: p, rule: _ruleForPreset(allRules, p)),
              for (final r in rules) _scheduleCard(preset: null, rule: r),
            ],
          ),
        ),
        // ── Primary: New schedule (time-window block) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: GestureDetector(
            onTap: () => _launchNewSchedule(context, ref),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _sage,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_alarm_rounded, size: 18, color: _onSage),
                  const SizedBox(width: 8),
                  Text(
                    'New schedule',
                    style: TextStyle(
                      color: _onSage,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
      ],
    );
  }

  // ── Quick presets ────────────────────────────────────────────────────

  AppBlockRule? _ruleForPreset(List<AppBlockRule> rules, _BlockPreset p) {
    for (final r in rules) {
      if (r.name == p.name) return r;
    }
    return null;
  }

  String _fmt12(int h, int m) {
    final period = h < 12 ? 'AM' : 'PM';
    final hh = (h % 12 == 0) ? 12 : h % 12;
    return '${hh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  /// One schedule card. [rule] is null for a preset that hasn't been turned on
  /// yet (it shows in the "off" state and materialises a rule on first toggle).
  Widget _scheduleCard({_BlockPreset? preset, required AppBlockRule? rule}) {
    final name = rule?.name ?? preset!.name;
    final icon = preset?.icon ?? Icons.lock_clock_rounded;
    final timeBased = rule?.isTimeBased ?? true;
    final sh = rule?.startHour ?? preset?.startHour ?? 0;
    final sm = rule?.startMinute ?? preset?.startMinute ?? 0;
    final eh = rule?.endHour ?? preset?.endHour ?? 0;
    final em = rule?.endMinute ?? preset?.endMinute ?? 0;
    final days = rule?.activeDays ?? preset?.days ?? _kAllDays;
    final appCount = rule?.blockedPackages.length ?? 0;

    final on = rule != null && rule.isEnabled && !rule.isSnoozed;
    final snoozed = rule != null && rule.isEnabled && rule.isSnoozed;
    final accent = _sage;

    final timeLabel = timeBased
        ? '${_fmt12(sh, sm)} – ${_fmt12(eh, em)}'
        : (rule?.expiresAt != null ? 'Until timer ends' : 'Always on');
    // Secondary line carries the full "when": time window + a readable day
    // summary ("Every day" / "Weekdays") instead of raw letter glyphs.
    final whenLine =
        timeBased ? '$timeLabel  ·  ${_daysSummary(days)}' : timeLabel;

    return GestureDetector(
      // Tapping a real schedule opens it for editing (rename, times, apps).
      onTap: rule != null ? () => _openEdit(rule) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.10) : _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: on ? accent.withValues(alpha: 0.45) : _border,
            width: on ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Primary: icon · (name + when) · switch ──
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on
                        ? accent.withValues(alpha: 0.18)
                        : (_isLight
                            ? Colors.black.withValues(alpha: 0.05)
                            : Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Icon(icon, size: 20, color: on ? accent : _textSoft),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color:
                                  on ? _text : _text.withValues(alpha: 0.78),
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3)),
                      const SizedBox(height: 3),
                      Text(whenLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: on
                                  ? accent.withValues(alpha: 0.85)
                                  : _textSoft,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Switch.adaptive(
                  value: on,
                  activeTrackColor: accent,
                  onChanged: (v) => _onCardSwitch(preset, rule, v),
                ),
              ],
            ),
            // ── Tertiary: app count / snooze controls + overflow menu ──
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 55),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: snoozed
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Paused — turns back on tomorrow',
                                  style: TextStyle(
                                      color: _textSoft, fontSize: 12)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => ref
                                    .read(appBlockRuleProvider.notifier)
                                    .forceDisableRule(rule.id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _border),
                                  ),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.block_rounded,
                                            size: 15, color: _textSoft),
                                        const SizedBox(width: 8),
                                        Text('Turn off permanently',
                                            style: TextStyle(
                                                color: _text,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500)),
                                      ]),
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              rule == null
                                  ? 'Blocks common distractions'
                                  : '$appCount app${appCount == 1 ? '' : 's'} blocked  ·  tap to edit',
                              style: TextStyle(
                                  color: _textSoft.withValues(alpha: 0.75),
                                  fontSize: 11.5),
                            ),
                          ),
                  ),
                  if (rule != null) _cardMenuButton(rule),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Human-readable recurrence ("Every day", "Weekdays", "Mon, Wed, Fri").
  String _daysSummary(List<int> days) {
    final s = days.toSet();
    if (s.length >= 7) return 'Every day';
    if (s.length == 5 && s.containsAll(const {1, 2, 3, 4, 5})) {
      return 'Weekdays';
    }
    if (s.length == 2 && s.containsAll(const {6, 7})) return 'Weekends';
    const names = {
      1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'
    };
    final sorted = s.toList()..sort();
    return sorted.map((d) => names[d]).join(', ');
  }

  Future<void> _openEdit(AppBlockRule rule) async {
    await Navigator.push<bool>(
      context,
      SmoothForwardRoute(child: NewScheduleScreen(existing: rule)),
    );
  }

  Widget _cardMenuButton(AppBlockRule rule) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, size: 18, color: _textSoft),
      color: _isLight ? Colors.white : const Color(0xFF1A1A1A),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'edit') {
          _openEdit(rule);
        } else if (v == 'delete') {
          _confirmDelete(rule);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(children: [
            Icon(Icons.edit_outlined, size: 18, color: _textSoft),
            const SizedBox(width: 10),
            Text('Edit', style: TextStyle(color: _text, fontSize: 14)),
          ]),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_outline_rounded,
                size: 18, color: Color(0xFFD97B4A)),
            const SizedBox(width: 10),
            Text('Delete', style: TextStyle(color: _text, fontSize: 14)),
          ]),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(AppBlockRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete schedule?',
            style: TextStyle(
                color: _text, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('"${rule.name}" will be removed.',
            style: TextStyle(color: _textSoft, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: _textSoft))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD97B4A)),
              child: const Text('Delete',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (ok == true) {
      ref.read(appBlockRuleProvider.notifier).deleteRule(rule.id);
    }
  }

  Future<void> _onCardSwitch(
      _BlockPreset? preset, AppBlockRule? rule, bool v) async {
    final notifier = ref.read(appBlockRuleProvider.notifier);
    if (v) {
      if (!await _ensureBlockerPermissions(context)) return;
      if (rule == null && preset != null) {
        await _createPresetRule(preset);
      } else if (rule != null) {
        await notifier.enableRule(rule.id);
      }
    } else if (rule != null && rule.isEnabled) {
      // Switch off = pause for today; auto-resumes tomorrow.
      await notifier.snoozeRuleUntilTomorrow(rule.id);
    }
  }

  /// Materialise a preset into a real rule that blocks whichever common
  /// distracting apps are actually installed.
  Future<void> _createPresetRule(_BlockPreset p) async {
    final installed =
        ref.read(installedAppsProvider).map((a) => a.packageName).toSet();
    var pkgs = _kDistractingPackages.where(installed.contains).toList();
    if (pkgs.isEmpty) pkgs = List<String>.from(_kDistractingPackages);
    await ref.read(appBlockRuleProvider.notifier).addRule(
          name: p.name,
          blockedPackages: pkgs,
          isTimeBased: true,
          startHour: p.startHour,
          startMinute: p.startMinute,
          endHour: p.endHour,
          endMinute: p.endMinute,
          activeDays: List<int>.from(p.days),
        );
  }

  // ── Permission check helper — returns true if all permissions granted ──
  Future<bool> _ensureBlockerPermissions(BuildContext context) async {
    final hasUsage = await NativeAppBlockerService.hasUsageStatsPermission();
    final hasNotif = await NativeAppBlockerService.hasNotificationPermission();

    if (!hasUsage || !hasNotif) {
      if (context.mounted) {
        final granted = await Navigator.push<bool>(
          context,
          SmoothForwardRoute(
            child: _BlockerPermissionScreen(
              hasUsageStats: hasUsage,
              hasNotification: hasNotif,
            ),
          ),
        );
        return granted == true;
      }
      return false;
    }
    return true;
  }

  void _launchNewSchedule(BuildContext context, WidgetRef ref) async {
    if (!await _ensureBlockerPermissions(context)) return;
    if (!context.mounted) return;
    final created = await Navigator.push<bool>(
      context,
      SmoothForwardRoute(child: const NewScheduleScreen()),
    );
    if (created == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Schedule created'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }


}


// ─── Full-Screen App Selection ──────────────────────────────────────────────


class _AppSelectionScreen extends ConsumerStatefulWidget {
  final List<InstalledApp> allApps;
  final Set<String> preSelected;
  const _AppSelectionScreen({required this.allApps, required this.preSelected});

  @override
  ConsumerState<_AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends ConsumerState<_AppSelectionScreen> {
  // ── Theme-aware colors ──
  bool get _isLight => ref.watch(themeColorProvider).isLight;
  Color get _bg => _isLight ? const Color(0xFFF5F5F5) : _ftBg;
  Color get _card => _isLight ? Colors.black.withValues(alpha: 0.04) : _ftCard;
  Color get _text => _isLight ? const Color(0xFF0D0D0D) : _ftText;
  Color get _textSoft => _isLight ? const Color(0xFF6B6B6B) : _ftTextSoft;
  Color get _border => _isLight ? Colors.black.withValues(alpha: 0.08) : _ftBorder;
  Color get _sage => ref.watch(themeColorProvider).color;
  Color get _sageDark {
    final themeColor = ref.watch(themeColorProvider).color;
    final hslColor = HSLColor.fromColor(themeColor);
    return hslColor
        .withLightness((hslColor.lightness * 0.85).clamp(0.0, 1.0))
        .toColor();
  }
  late Set<String> _selected;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.preSelected);
  }

  List<InstalledApp> get _filteredApps {
    if (_searchQuery.isEmpty) return widget.allApps;
    final q = _searchQuery.toLowerCase();
    return widget.allApps
        .where((a) =>
            a.appName.toLowerCase().contains(q) ||
            a.packageName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Icon(Icons.arrow_back_ios_new,
                        color: _textSoft, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select Apps',
                          style: TextStyle(
                              color: _text,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      Text('${_selected.length} app${_selected.length == 1 ? '' : 's'} selected',
                          style: TextStyle(
                              color: _sage,
                              fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context, _selected);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _sage.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Done',
                        style: TextStyle(
                            color: _sageDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: _text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  hintStyle: TextStyle(color: _textSoft),
                  prefixIcon: Icon(Icons.search, color: _textSoft),
                  filled: true,
                  fillColor: _card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _sage)),
                ),
              ),
            ),
            // Quick actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _selected = widget.allApps
                        .map((a) => a.packageName)
                        .toSet();
                  }),
                  child: Text('Select All',
                      style: TextStyle(
                          color: _sage,
                          fontSize: 12)),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => setState(() => _selected.clear()),
                  child: Text('Clear',
                      style: TextStyle(
                          color: _textSoft,
                          fontSize: 12)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            // App list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _filteredApps.length,
                itemBuilder: (ctx, i) {
                  final app = _filteredApps[i];
                  final isSelected = _selected.contains(app.packageName);
                  return ListTile(
                    dense: true,
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selected.remove(app.packageName);
                        } else {
                          _selected.add(app.packageName);
                        }
                      });
                    },
                    title: Text(app.appName,
                        style: TextStyle(
                            color: isSelected
                                ? _text
                                : _textSoft,
                            fontSize: 14)),
                    subtitle: Text(app.packageName,
                        style: TextStyle(
                            color: _textSoft,
                            fontSize: 10)),
                    trailing: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(7),
                        color: isSelected
                            ? _sage.withValues(alpha: 0.15)
                            : _bg,
                        border: Border.all(
                            color: isSelected
                                ? _sage.withValues(alpha: 0.5)
                                : _border),
                      ),
                      child: isSelected
                          ? Icon(Icons.check_rounded,
                              color: _sage, size: 16)
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🔧 SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _AddButton extends ConsumerWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AddButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sage = ref.watch(themeColorProvider).color;
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: sage.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sage.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: sage.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: sage.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekStrip extends ConsumerStatefulWidget {
  final DateTime selected;
  final Set<DateTime> eventDates;
  final void Function(DateTime) onSelect;

  const _WeekStrip({
    required this.selected,
    required this.eventDates,
    required this.onSelect,
  });

  @override
  ConsumerState<_WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends ConsumerState<_WeekStrip> {
  late ScrollController _scrollController;
  static const int _totalDays = 21; // 10 past + today + 10 future
  static const int _pastDays = 10;
  static const double _itemWidth = 44;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(_WeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);
    final selectedNorm = DateTime(widget.selected.year, widget.selected.month, widget.selected.day);
    final diffDays = selectedNorm.difference(todayNorm).inDays;
    final index = _pastDays + diffDays;
    final offset = (index * _itemWidth) - (MediaQuery.of(context).size.width / 2) + (_itemWidth / 2);
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: _pastDays));
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SizedBox(
      height: 60,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _totalDays,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, i) {
          final day = startDate.add(Duration(days: i));
          final isSelected = day.year == widget.selected.year &&
              day.month == widget.selected.month &&
              day.day == widget.selected.day;
          final isToday = day.year == today.year &&
              day.month == today.month &&
              day.day == today.day;
          final hasEvent = widget.eventDates.contains(
              DateTime(day.year, day.month, day.day));

          return GestureDetector(
            onTap: () => widget.onSelect(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _itemWidth,
              padding: const EdgeInsets.symmetric(vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isToday && !isSelected
                    ? Border.all(
                        color: accent.withValues(alpha: 0.2))
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabels[day.weekday - 1],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? accent
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasEvent)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 🛡️ BLOCKER PERMISSION SETUP SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class _BlockerPermissionScreen extends StatefulWidget {
  final bool hasUsageStats;
  final bool hasNotification;

  const _BlockerPermissionScreen({
    required this.hasUsageStats,
    required this.hasNotification,
  });

  @override
  State<_BlockerPermissionScreen> createState() => _BlockerPermissionScreenState();
}

class _BlockerPermissionScreenState extends State<_BlockerPermissionScreen>
    with WidgetsBindingObserver {
  late bool _usageGranted;
  late bool _notifGranted;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _usageGranted = widget.hasUsageStats;
    _notifGranted = widget.hasNotification;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check permissions when user comes back from system settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckPermissions();
    }
  }

  Future<void> _recheckPermissions() async {
    if (_checking) return;
    _checking = true;
    final u = await NativeAppBlockerService.hasUsageStatsPermission();
    final n = await NativeAppBlockerService.hasNotificationPermission();
    if (mounted) {
      setState(() {
        _usageGranted = u;
        _notifGranted = n;
      });

      // All permissions granted → auto-proceed
      if (_usageGranted && _notifGranted) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) Navigator.pop(context, true);
      }
    }
    _checking = false;
  }

  bool get _allGranted => _usageGranted && _notifGranted;

  @override
  Widget build(BuildContext context) {
    final grantedCount = (_usageGranted ? 1 : 0) + (_notifGranted ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // ── Back button ──
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _ftCard,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_rounded,
                      color: _ftTextSoft, size: 20),
                ),
              ),

              const SizedBox(height: 32),

              // ── Shield icon ──
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _desertSunset.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.shield_rounded,
                      color: _desertSunset.withValues(alpha: 0.8), size: 40),
                ),
              ),

              const SizedBox(height: 24),

              // ── Title ──
              Center(
                child: Text(
                  'Setup App Blocker',
                  style: TextStyle(
                    color: _ftText,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Center(
                child: Text(
                  'To block apps from all entry points —\nnotifications, recent apps & more',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ftTextSoft,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Progress ──
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _oasisGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$grantedCount / 2 permissions granted',
                    style: TextStyle(
                      color: _oasisGreen.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Permission 1: Usage Stats ──
              _PermissionCard(
                step: 1,
                icon: Icons.bar_chart_rounded,
                title: 'Usage Access',
                description:
                    'Required to detect which app is in the foreground.\nThis is how the blocker knows when a blocked app opens.',
                isGranted: _usageGranted,
                onGrant: () async {
                  await NativeAppBlockerService.requestUsageStatsPermission();
                },
              ),

              const SizedBox(height: 14),

              // ── Permission 2: Notifications ──
              _PermissionCard(
                step: 2,
                icon: Icons.notifications_active_rounded,
                title: 'Notifications',
                description:
                    'Required to keep the blocker running in the background.\nShows a small "Focus Mode Active" notification.',
                isGranted: _notifGranted,
                onGrant: () async {
                  await NativeAppBlockerService.requestNotificationPermission();
                  // Small delay then re-check (Android dialog is quick)
                  await Future.delayed(const Duration(milliseconds: 800));
                  _recheckPermissions();
                },
              ),

              const Spacer(),

              // ── Continue button ──
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    if (_allGranted) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please grant all permissions to continue'),
                          backgroundColor: _desertSunset.withValues(alpha: 0.9),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _allGranted
                          ? _oasisGreen.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _allGranted
                            ? _oasisGreen.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _allGranted
                              ? Icons.check_circle_rounded
                              : Icons.lock_rounded,
                          color: _allGranted
                              ? _oasisGreen
                              : Colors.white.withValues(alpha: 0.3),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _allGranted
                              ? 'Continue to Create Rule'
                              : 'Grant All Permissions to Continue',
                          style: TextStyle(
                            color: _allGranted
                                ? _oasisGreen
                                : Colors.white.withValues(alpha: 0.3),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Individual Permission Card ──
class _PermissionCard extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onGrant;

  const _PermissionCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isGranted ? null : onGrant,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isGranted
              ? _oasisGreen.withValues(alpha: 0.06)
              : _desertSunset.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted
                ? _oasisGreen.withValues(alpha: 0.25)
                : _desertSunset.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step number / check icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isGranted
                    ? _oasisGreen.withValues(alpha: 0.15)
                    : _desertSunset.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isGranted
                    ? Icon(Icons.check_rounded,
                        color: _oasisGreen, size: 20)
                    : Text(
                        '$step',
                        style: TextStyle(
                          color: _desertSunset.withValues(alpha: 0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon,
                          size: 16,
                          color: isGranted
                              ? _oasisGreen.withValues(alpha: 0.7)
                              : _desertSunset.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          color: _ftText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (isGranted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _oasisGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('GRANTED',
                              style: TextStyle(
                                  color: _oasisGreen,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _desertSunset.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('GRANT',
                              style: TextStyle(
                                  color: _desertSunset,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: _ftTextSoft,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
