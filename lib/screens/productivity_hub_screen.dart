import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'zen_mode_entry_screen.dart';
import 'screen_time_settings_screen.dart';
import 'notification_feed_screen.dart';
import '../providers/screen_time_provider.dart';
import '../providers/notification_filter_provider.dart';
import '../utils/smooth_page_route.dart';
import 'pomodoro_screen.dart';

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
    final hPad = (screenW * 0.053).clamp(14.0, 28.0); // ~20 at 375

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

    return Container(
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
                  const SizedBox(height: 16),

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
                                  size: 18 * sf,
                                  color: _sage.withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _greeting,
                                    style: TextStyle(
                                      color: _text,
                                      fontSize: (22 * sf).clamp(18.0, 28.0),
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
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
                                fontSize: (13 * sf).clamp(11.0, 16.0),
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
                  // Psychology: Progress visibility (Endowed Progress Effect)
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

                  SizedBox(height: (20 * sf).clamp(14.0, 28.0)),

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
                      padding: EdgeInsets.all((20 * sf).clamp(14.0, 26.0)),
                      decoration: BoxDecoration(
                        color: isTimerActive
                            ? _sage.withValues(alpha: 0.06)
                            : _card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isTimerActive
                              ? _sage.withValues(alpha: 0.2)
                              : _border,
                          width: isTimerActive ? 1 : 0.5,
                        ),
                        boxShadow: _paperShadow(elevated: isTimerActive),
                      ),
                      child: Row(
                        children: [
                          // Timer ring (compact) — responsive
                          SizedBox(
                            width: (56 * sf).clamp(44.0, 68.0),
                            height: (56 * sf).clamp(44.0, 68.0),
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
                                      strokeWidth: (2.5 * sf).clamp(2.0, 3.5),
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: isTimerActive
                                            ? _text
                                            : _text.withValues(alpha: 0.45),
                                        fontSize: (14 * sf).clamp(11.0, 17.0),
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
                                    fontSize: (17 * sf).clamp(14.0, 22.0),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
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
                              HapticFeedback.mediumImpact();
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
                              width: (44 * sf).clamp(36.0, 54.0),
                              height: (44 * sf).clamp(36.0, 54.0),
                              decoration: BoxDecoration(
                                color: isTimerActive
                                    ? _sage.withValues(alpha: 0.12)
                                    : _sage,
                                shape: BoxShape.circle,
                                border: isTimerActive
                                    ? Border.all(
                                        color: _sage.withValues(alpha: 0.25),
                                        width: 1.5,
                                      )
                                    : null,
                                boxShadow: !isTimerActive
                                    ? [BoxShadow(
                                        color: _sage.withValues(alpha: 0.25),
                                        offset: const Offset(0, 4),
                                        blurRadius: 12,
                                      )]
                                    : null,
                              ),
                              child: Icon(
                                isPaused
                                    ? Icons.play_arrow_rounded
                                    : isFocusing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                color: isTimerActive
                                    ? _sage
                                    : (_sage.computeLuminance() > 0.45
                                        ? Colors.black
                                        : Colors.white),
                                size: (22 * sf).clamp(18.0, 28.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════════════
                  // 3. TASKS — inline preview (no extra card chrome)
                  //    Psychology: Zeigarnik Effect — showing incomplete
                  //    tasks creates urge to complete them
                  // ═══════════════════════════════════════════════════════
                  _buildTaskPreview(context, pendingTodos, sf),

                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════════════════════
                  // 4. DIGITAL WELLBEING SECTION — grouped protection tools
                  //    Psychology: Gestalt Law of Proximity — related tools
                  //    are perceived as belonging together
                  // ═══════════════════════════════════════════════════════
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Digital Wellbeing',
                          style: TextStyle(
                            color: _text,
                            fontSize: (15 * sf).clamp(13.0, 19.0),
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (protectionActive > 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 7 * sf, vertical: 3 * sf),
                          decoration: BoxDecoration(
                            color: _sage.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$protectionActive active',
                            style: TextStyle(
                              color: _sage,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── 2x2 Compact Grid: Zen Mode · Notifications · Blocker · Screen Time ──
                  // Psychology: Miller's Law — chunked into digestible groups
                  Row(
                    children: [
                      // Zen Mode
                      Expanded(
                        child: _wellbeingTile(
                          icon: zen.isActive
                              ? Icons.self_improvement_rounded
                              : Icons.phone_android_rounded,
                          label: 'Muraqaba',
                          value: zen.isActive ? 'Active' : 'Off',
                          isActive: zen.isActive,
                          accentColor: zen.isActive ? _sage : null,
                          sf: sf,
                          onTap: () {
                            if (zen.isActive) {
                              ref.read(zenModeProvider.notifier).endZenMode();
                            } else {
                              Navigator.push(context, SmoothForwardRoute(
                                child: const ZenModeEntryScreen(),
                              ));
                            }
                          },
                        ),
                      ),
                      SizedBox(width: (10 * sf).clamp(6.0, 14.0)),
                      // Notifications
                      Expanded(
                        child: _wellbeingTile(
                          icon: Icons.notifications_outlined,
                          label: 'Notifications',
                          value: isNotifActive
                              ? '${nf.totalCount} queued'
                              : 'Off',
                          isActive: isNotifActive,
                          badge: isNotifActive && nf.totalCount > 0
                              ? nf.totalCount
                              : null,
                          sf: sf,
                          onTap: () {
                            Navigator.push(context, SmoothForwardRoute(
                              child: const NotificationFeedScreen(),
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: (10 * sf).clamp(6.0, 14.0)),
                  Row(
                    children: [
                      // App Blocker
                      Expanded(
                        child: _wellbeingTile(
                          icon: Icons.shield_rounded,
                          label: 'App Blocker',
                          value: hasActiveBlocker
                              ? '$activeBlockedCount blocked'
                              : 'Off',
                          isActive: hasActiveBlocker,
                          sf: sf,
                          onTap: () {
                            Navigator.push(context, SmoothForwardRoute(
                              child: _ProductivitySubScreen(
                                title: 'App Blocker',
                                child: _BlockerTab(),
                              ),
                            ));
                          },
                        ),
                      ),
                      SizedBox(width: (10 * sf).clamp(6.0, 14.0)),
                      // Screen Time
                      Expanded(
                        child: _wellbeingTile(
                          icon: Icons.timer_outlined,
                          label: 'Screen Time',
                          value: isScreenTimeActive ? stLabel : 'Off',
                          isActive: isScreenTimeActive,
                          sf: sf,
                          onTap: () {
                            Navigator.push(context, SmoothForwardRoute(
                              child: const ScreenTimeSettingsScreen(),
                            ));
                          },
                        ),
                      ),
                    ],
                  ),

                  // Bottom safe area padding — responsive
                  SizedBox(height: (32 * sf).clamp(20.0, 48.0)),
                ],              // Column children
              ),                // Column
            ),                  // Padding
          ),                    // SingleChildScrollView
        ),                      // RepaintBoundary
      ),                        // SafeArea
    );                          // Container
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
        horizontal: (10 * sf).clamp(6.0, 14.0),
        vertical: (5 * sf).clamp(3.0, 8.0),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: (13 * sf).clamp(10.0, 17.0), color: color.withValues(alpha: 0.7)),
          SizedBox(width: (5 * sf).clamp(3.0, 8.0)),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: (11.5 * sf).clamp(9.0, 15.0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WELLBEING TILE — compact card for the 2x2 grid
  // ─────────────────────────────────────────────────────────────────────────
  Widget _wellbeingTile({
    required IconData icon,
    required String label,
    required String value,
    required bool isActive,
    required VoidCallback onTap,
    Color? accentColor,
    int? badge,
    double sf = 1.0,
  }) {
    final color = accentColor ?? _sage;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all((16 * sf).clamp(12.0, 22.0)),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.20)
                : _border,
            width: 0.5,
          ),
          boxShadow: _paperShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all((8 * sf).clamp(6.0, 12.0)),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color.withValues(alpha: 0.10)
                        : _cardLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: (16 * sf).clamp(13.0, 20.0), color: isActive ? color : _textSoft),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6 * sf, vertical: 2 * sf),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        color: color,
                        fontSize: (10 * sf).clamp(8.0, 13.0),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else if (isActive)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: (12 * sf).clamp(8.0, 16.0)),
            Text(
              label,
              style: TextStyle(
                color: _text,
                fontSize: (13.5 * sf).clamp(11.0, 17.0),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: isActive ? color : _textSoft,
                fontSize: (11.5 * sf).clamp(9.5, 15.0),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // (Old status bar and focus engine removed — replaced by new hub design)
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // 3. COMPACT TASK PREVIEW
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTaskPreview(BuildContext context, List<TodoItem> pendingTodos, double sf) {
    final previewTodos = pendingTodos.take(2).toList();
    final remaining = pendingTodos.length - previewTodos.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all((20 * sf).clamp(14.0, 26.0)),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 0.5),
        boxShadow: _paperShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                'Tasks',
                style: TextStyle(
                  color: _text,
                  fontSize: (17 * sf).clamp(14.0, 22.0),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: _sage,
                        fontSize: (12.5 * sf).clamp(10.0, 16.0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: (13 * sf).clamp(10.0, 16.0),
                      color: _sage,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: (16 * sf).clamp(10.0, 22.0)),

          // Task rows
          if (previewTodos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'All done for today ✨',
                style: TextStyle(
                  color: _textSoft.withValues(alpha: 0.7),
                  fontSize: (13.5 * sf).clamp(11.0, 17.0),
                  fontWeight: FontWeight.w400,
                ),
              ),
            )
          else
            ...previewTodos.asMap().entries.map((entry) {
              final i = entry.key;
              final todo = entry.value;
              final isHigh = todo.priority >= 2;
              final isLast = i == previewTodos.length - 1 && remaining <= 0;

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: (8 * sf).clamp(5.0, 12.0)),
                    child: Row(
                      children: [
                        // Checkbox circle — responsive
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            ref.read(todoProvider.notifier).toggleTodo(todo.id);
                          },
                          child: Container(
                            width: (22 * sf).clamp(18.0, 30.0),
                            height: (22 * sf).clamp(18.0, 30.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _cardLight,
                              border: Border.all(
                                color: _border,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: (12 * sf).clamp(8.0, 16.0)),
                        // Priority indicator
                        if (isHigh)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              size: 14,
                              color: _gold.withValues(alpha: 0.8),
                            ),
                          ),
                        // Task title
                        Expanded(
                          child: Text(
                            todo.title,
                            style: TextStyle(
                              color: _text.withValues(alpha: 0.8),
                              fontSize: (14.5 * sf).clamp(12.0, 18.0),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Priority dot
                        Container(
                          width: (6 * sf).clamp(4.0, 8.0),
                          height: (6 * sf).clamp(4.0, 8.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isHigh
                                ? _sage
                                : _border,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      height: 0.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _border.withValues(alpha: 0.0),
                            _border.withValues(alpha: 0.3),
                            _border.withValues(alpha: 0.3),
                            _border.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.2, 0.8, 1.0],
                        ),
                      ),
                    ),
                ],
              );
            }),

          // "+N more" indicator
          if (remaining > 0)
            Padding(
              padding: EdgeInsets.only(top: (8 * sf).clamp(5.0, 12.0)),
              child: Text(
                '+$remaining more',
                style: TextStyle(
                  color: _textSoft.withValues(alpha: 0.6),
                  fontSize: (12.5 * sf).clamp(10.0, 16.0),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // (Old doubts/blocker/screen-time/notification/zen-mode cards removed
  //  — replaced by new hub Digital Wellbeing 2x2 grid)
  // ─────────────────────────────────────────────────────────────────────────
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
      backgroundColor: themeBg,
      body: SafeArea(
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
                  fontSize: 12,
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
                            fontSize: 12,
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
          fontSize: 11,
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
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(timeText,
                      style: TextStyle(
                          color: _textSoft,
                          fontSize: 11)),
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
            fontSize: 11,
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
              HapticFeedback.lightImpact();
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
              fontSize: 14,
              decoration:
                  todo.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: todo.dueDate != null
              ? Text(
                  DateFormat('MMM d, h:mm a').format(todo.dueDate!),
                  style: TextStyle(
                    fontSize: 11,
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

class _BlockerTab extends ConsumerStatefulWidget {
  const _BlockerTab();
  @override
  ConsumerState<_BlockerTab> createState() => _BlockerTabState();
}

class _BlockerTabState extends ConsumerState<_BlockerTab> {
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

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(appBlockRuleProvider);

    return Column(
      children: [
        // Active rules count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Icon(Icons.shield,
                  size: 14,
                  color: rules.any((r) => r.isEnabled)
                      ? _sage
                      : _textSoft),
              const SizedBox(width: 6),
              Text(
                '${rules.where((r) => r.isEnabled).length} active rules',
                style: TextStyle(
                    color: _textSoft,
                    fontSize: 12),
              ),
            ],
          ),
        ),
        // Rules list
        Expanded(
          child: rules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 48,
                          color: _border),
                      const SizedBox(height: 12),
                      Text('No block rules',
                          style: TextStyle(
                              color: _textSoft)),
                      const SizedBox(height: 4),
                      Text('Block distracting apps 🌙',
                          style: TextStyle(
                              color: _textSoft.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: rules.length,
                  itemBuilder: (ctx, i) => _ruleCard(ctx, ref, rules[i]),
                ),
        ),
        // ── Direct access buttons: Custom Block + Smart Packs ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: _AddButton(
                  label: 'Custom Block',
                  icon: Icons.tune_rounded,
                  onTap: () => _launchCustomBlock(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AddButton(
                  label: 'Smart Packs',
                  icon: Icons.inventory_2_rounded,
                  onTap: () => _launchSmartPacks(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ruleCard(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    final dangerColor = const Color(0xFFD97B4A);
    return GestureDetector(
      onTap: () => _showRuleInfoSheet(context, ref, rule),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rule.isHardBlock
            ? dangerColor.withValues(alpha: 0.06)
            : _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rule.isHardBlock
              ? dangerColor.withValues(alpha: 0.25)
              : rule.isEnabled
                  ? _sage.withValues(alpha: 0.25)
                  : _border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (rule.isHardBlock) ...[
                Icon(Icons.lock, size: 14, color: dangerColor.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  rule.name,
                  style: TextStyle(
                    color: _text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (rule.isHardBlock)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: dangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'HARD BLOCK',
                    style: TextStyle(
                      color: dangerColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
              else
                // Toggle
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (rule.isEnabled) {
                      _showDeactivateConfirmation(context, ref, rule);
                    } else {
                      ref.read(appBlockRuleProvider.notifier).toggleRule(rule.id);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 24,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: rule.isEnabled
                          ? _sage.withValues(alpha: 0.3)
                          : _border,
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: rule.isEnabled
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              rule.isEnabled ? _sage : _textSoft,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Time / type info
          Row(
            children: [
              Icon(
                rule.isTimeBased ? Icons.schedule : Icons.block,
                size: 12,
                color: _textSoft,
              ),
              const SizedBox(width: 4),
              Text(
                rule.isTimeBased
                    ? '${_formatHour(rule.startHour, rule.startMinute)} — ${_formatHour(rule.endHour, rule.endMinute)}'
                    : 'Manual toggle',
                style: TextStyle(
                    color: _textSoft,
                    fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${rule.blockedPackages.length} apps',
                style: TextStyle(
                    color: _textSoft,
                    fontSize: 11),
              ),
            ],
          ),
          if (rule.allowBreaks) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.free_breakfast_outlined, size: 11,
                    color: _textSoft.withValues(alpha: 0.6)),
                const SizedBox(width: 4),
                Text(
                  'Breaks allowed',
                  style: TextStyle(
                      color: _textSoft.withValues(alpha: 0.6), fontSize: 10),
                ),
              ],
            ),
          ],
          if (rule.isHardBlock)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 11, color: _textSoft.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(
                    'Locked — cannot be modified or deleted',
                    style: TextStyle(
                      color: _textSoft.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
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

  String _formatHour(int? h, int? m) {
    if (h == null) return '--:--';
    final hour = h % 12 == 0 ? 12 : h % 12;
    final ampm = h < 12 ? 'AM' : 'PM';
    return '$hour:${(m ?? 0).toString().padLeft(2, '0')} $ampm';
  }

  // ── Deactivation confirmation for easy-mode blockers ──
  void _showDeactivateConfirmation(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    final dangerColor = const Color(0xFFD97B4A);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            // Shield icon
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: dangerColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, size: 30,
                  color: dangerColor.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              'Stay Focused',
              style: TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You set this blocker for a reason.\nDisabling it now means giving in to distraction.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textSoft,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _gold.withValues(alpha: 0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.format_quote, size: 14,
                      color: _gold.withValues(alpha: 0.6)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '"Discipline is choosing between what you\nwant now and what you want most."',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Keep it ON button (primary)
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _sage.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _sage.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      'Keep Blocker Active',
                      style: TextStyle(
                        color: _sageDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Confirm deactivate
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    SmoothForwardRoute(
                      child: _DeactivateRuleConfirmScreen(
                        ruleId: rule.id,
                        ruleName: rule.name,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Confirm Deactivate',
                      style: TextStyle(
                        color: _textSoft,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
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

  // ── Rule Info Sheet (shown after creation) ──
  void _showRuleInfoSheet(BuildContext context, WidgetRef ref, AppBlockRule rule) {
    final allApps = ref.read(installedAppsProvider);
    final dayLabels = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Success indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _sage.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: _sage, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rule Created',
                            style: TextStyle(
                                color: _sage,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(rule.name,
                            style: TextStyle(
                                color: _text,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (rule.isHardBlock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _desertSunset.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 10, color: _desertSunset.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text('HARD',
                              style: TextStyle(
                                  color: _desertSunset.withValues(alpha: 0.8),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Schedule / Timer info ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14,
                            color: _gold),
                        const SizedBox(width: 6),
                        Text('Schedule',
                            style: TextStyle(
                                color: _gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _infoChip(
                            Icons.play_arrow_rounded,
                            'Start',
                            _formatHour(rule.startHour, rule.startMinute),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 12,
                            color: _border),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _infoChip(
                            Icons.stop_rounded,
                            'End',
                            _formatHour(rule.endHour, rule.endMinute),
                          ),
                        ),
                      ],
                    ),
                    if (rule.activeDays.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: rule.activeDays.map((d) {
                          final label = d >= 1 && d <= 7 ? dayLabels[d] : '?';
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(label,
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Blocked Apps ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.block_rounded, size: 14,
                            color: _desertSunset.withValues(alpha: 0.7)),
                        const SizedBox(width: 6),
                        Text('Blocked Apps',
                            style: TextStyle(
                                color: _desertSunset.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text('${rule.blockedPackages.length}',
                            style: TextStyle(
                                color: _textSoft,
                                fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: rule.blockedPackages.map((pkg) {
                        final appName = allApps
                            .where((a) => a.packageName == pkg)
                            .map((a) => a.appName)
                            .firstOrNull ?? pkg.split('.').last;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _desertSunset.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _desertSunset.withValues(alpha: 0.12)),
                          ),
                          child: Text(appName,
                              style: TextStyle(
                                  color: _text,
                                  fontSize: 11)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Settings info ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    _settingPill(Icons.shield, rule.isHardBlock ? 'Hard Block' : 'Easy Block',
                        rule.isHardBlock ? _desertSunset : _sage),
                    const SizedBox(width: 8),
                    if (rule.allowBreaks)
                      _settingPill(Icons.free_breakfast_outlined, 'Breaks On', _gold),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Delete button ──
              if (!rule.isHardBlock)
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        SmoothForwardRoute(
                          child: _DeleteRuleConfirmScreen(
                            ruleId: rule.id,
                            ruleName: rule.name,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 16,
                              color: Colors.red.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Text('Delete Rule',
                              style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Done button ──
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _sage.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('Done',
                          style: TextStyle(
                              color: _sageDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: _textSoft),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(
                  color: _textSoft, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(
              color: _text, fontSize: 13,
              fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _settingPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
              color: color.withValues(alpha: 0.8), fontSize: 11,
              fontWeight: FontWeight.w500)),
        ],
      ),
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

  // ── Direct launch: Custom Block (skips chooser) ──
  void _launchCustomBlock(BuildContext context, WidgetRef ref) async {
    if (!await _ensureBlockerPermissions(context)) return;
    if (!context.mounted) return;
    _showUnifiedBlockSheet(context, ref);
  }

  // ── Direct launch: Smart Packs (skips chooser) ──
  void _launchSmartPacks(BuildContext context, WidgetRef ref) async {
    if (!await _ensureBlockerPermissions(context)) return;
    if (!context.mounted) return;
    _showSmartPackSheet(context, ref);
  }

  // ── Unified Block Sheet (replaces Block Now + Scheduled Block) ──
  void _showUnifiedBlockSheet(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    Set<String> selectedApps = {};
    int scheduleMode = 0; // 0=Always, 1=Duration, 2=Time Window
    int durationMinutes = 30;
    int startH = 9, startM = 0, endH = 17, endM = 0;
    Set<int> activeDays = {1, 2, 3, 4, 5};
    int breakDifficulty = 0;
    final durations = [15, 30, 45, 60, 90, 120];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.tune_rounded,
                      color: _sage, size: 20),
                  const SizedBox(width: 8),
                  Text('Custom Block',
                      style: TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 16),
                // Rule name
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: _text),
                  decoration: InputDecoration(
                    hintText: 'Rule name (e.g. Study Focus)',
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
                        borderSide: BorderSide(color: _sage)),
                  ),
                ),
                const SizedBox(height: 16),
                // Add Apps
                _buildAddAppsButton(ctx, ref, selectedApps, setBS),
                const SizedBox(height: 16),

                // Schedule mode selector
                Text('Schedule',
                    style: TextStyle(
                        color: _textSoft,
                        fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  _buildScheduleChip("Always On", 0, scheduleMode, _sage, (v) => setBS(() => scheduleMode = v)),
                  const SizedBox(width: 8),
                  _buildScheduleChip("Duration", 1, scheduleMode, _sage, (v) => setBS(() => scheduleMode = v)),
                  const SizedBox(width: 8),
                  _buildScheduleChip("Time Window", 2, scheduleMode, _sage, (v) => setBS(() => scheduleMode = v)),
                ]),

                // Duration picker (mode 1)
                if (scheduleMode == 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: durations.map((d) {
                      final isSelected = durationMinutes == d;
                      final label = d >= 60 ? '${d ~/ 60}h${d % 60 > 0 ? " ${d % 60}m" : ""}' : '${d}m';
                      return GestureDetector(
                        onTap: () => setBS(() => durationMinutes = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _sage.withValues(alpha: 0.12)
                                : _bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected
                                    ? _sage.withValues(alpha: 0.4)
                                    : _border),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  color: isSelected
                                      ? _sageDark
                                      : _textSoft,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Time window picker (mode 2)
                if (scheduleMode == 2) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                              context: ctx, initialTime: TimeOfDay(hour: startH, minute: startM));
                          if (time != null) setBS(() { startH = time.hour; startM = time.minute; });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Text('Start: ${_formatHour(startH, startM)}',
                              style: TextStyle(color: _text, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                              context: ctx, initialTime: TimeOfDay(hour: endH, minute: endM));
                          if (time != null) setBS(() { endH = time.hour; endM = time.minute; });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Text('End: ${_formatHour(endH, endM)}',
                              style: TextStyle(color: _text, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      final active = activeDays.contains(day);
                      return GestureDetector(
                        onTap: () => setBS(() {
                          if (active) {
                            activeDays.remove(day);
                          } else {
                            activeDays.add(day);
                          }
                        }),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? _sage.withValues(alpha: 0.15)
                                : _bg,
                          ),
                          child: Center(
                            child: Text(labels[i],
                                style: TextStyle(
                                    fontSize: 12,
                                    color: active ? _sageDark : _textSoft)),
                          ),
                        ),
                      );
                    }),
                  ),
                ],

                const SizedBox(height: 16),
                // Break difficulty
                _buildBreakDifficultySelector(ref, breakDifficulty, (v) => setBS(() => breakDifficulty = v), ctx),
                const SizedBox(height: 20),
                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text('Please enter a rule name'),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }
                      if (selectedApps.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text('Please add at least one app to block'),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }

                      int sH = 0, sM = 0, eH = 23, eM = 59;
                      List<int> days = List.generate(7, (i) => i + 1);
                      bool isTimeBased = true;
                      DateTime? expiresAt;

                      if (scheduleMode == 1) {
                        final now = DateTime.now();
                        final end = now.add(Duration(minutes: durationMinutes));
                        sH = now.hour; sM = now.minute;
                        eH = end.hour; eM = end.minute;
                        days = [now.weekday];
                        expiresAt = end; // Exact expiry time for duration-based blocks
                      } else if (scheduleMode == 2) {
                        sH = startH; sM = startM;
                        eH = endH; eM = endM;
                        days = activeDays.toList();
                      } else {
                        isTimeBased = false;
                      }

                      final newRule = await ref.read(appBlockRuleProvider.notifier).addRule(
                        name: nameCtrl.text.trim(),
                        blockedPackages: selectedApps.toList(),
                        isTimeBased: isTimeBased,
                        startHour: sH,
                        startMinute: sM,
                        endHour: eH,
                        endMinute: eM,
                        activeDays: days,
                        isHardBlock: breakDifficulty == 1,
                        allowBreaks: breakDifficulty == 0,
                        expiresAt: expiresAt,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      if (context.mounted) {
                        _showRuleInfoSheet(context, ref, newRule);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _sage.withValues(alpha: 0.15),
                      foregroundColor: _sageDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(scheduleMode == 1
                        ? 'Start Blocking \u00b7 ${durationMinutes}min'
                        : 'Create Rule'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Smart Packs (pre-built app packs) ──
  static const _smartPacks = <Map<String, dynamic>>[
    {
      'id': 'social_media',
      'name': 'Social Media',
      'icon': Icons.people_alt_rounded,
      'color': Color(0xFFE8915A), // desertSunset
      'desc': 'Instagram, TikTok, Facebook, Twitter & more',
      'apps': <Map<String, String>>[
        {'pkg': 'com.instagram.android', 'name': 'Instagram'},
        {'pkg': 'com.facebook.katana', 'name': 'Facebook'},
        {'pkg': 'com.twitter.android', 'name': 'X (Twitter)'},
        {'pkg': 'com.snapchat.android', 'name': 'Snapchat'},
        {'pkg': 'com.tiktok.android', 'name': 'TikTok'},
        {'pkg': 'com.zhiliaoapp.musically', 'name': 'TikTok Lite'},
        {'pkg': 'com.pinterest', 'name': 'Pinterest'},
        {'pkg': 'com.reddit.frontpage', 'name': 'Reddit'},
        {'pkg': 'com.linkedin.android', 'name': 'LinkedIn'},
        {'pkg': 'org.telegram.messenger', 'name': 'Telegram'},
        {'pkg': 'com.whatsapp', 'name': 'WhatsApp'},
        {'pkg': 'com.discord', 'name': 'Discord'},
        {'pkg': 'com.Slack', 'name': 'Slack'},
      ],
    },
    {
      'id': 'entertainment',
      'name': 'Entertainment',
      'icon': Icons.movie_rounded,
      'color': Color(0xFFC2A366), // sandGold
      'desc': 'YouTube, Netflix, Spotify, Twitch & more',
      'apps': <Map<String, String>>[
        {'pkg': 'com.google.android.youtube', 'name': 'YouTube'},
        {'pkg': 'com.netflix.mediaclient', 'name': 'Netflix'},
        {'pkg': 'com.spotify.music', 'name': 'Spotify'},
        {'pkg': 'tv.twitch.android.app', 'name': 'Twitch'},
        {'pkg': 'com.amazon.avod.thirdpartyclient', 'name': 'Prime Video'},
        {'pkg': 'com.disney.disneyplus', 'name': 'Disney+'},
        {'pkg': 'com.hulu.livingroomplus', 'name': 'Hulu'},
      ],
    },
    {
      'id': 'gaming',
      'name': 'Gaming',
      'icon': Icons.sports_esports_rounded,
      'color': Color(0xFF7BAE6E), // oasisGreen
      'desc': 'Popular games & game stores',
      'apps': <Map<String, String>>[
        {'pkg': 'com.supercell.clashofclans', 'name': 'Clash of Clans'},
        {'pkg': 'com.supercell.clashroyale', 'name': 'Clash Royale'},
        {'pkg': 'com.supercell.brawlstars', 'name': 'Brawl Stars'},
        {'pkg': 'com.kiloo.subwaysurf', 'name': 'Subway Surfers'},
        {'pkg': 'com.epicgames.fortnite', 'name': 'Fortnite'},
        {'pkg': 'com.mojang.minecraftpe', 'name': 'Minecraft'},
        {'pkg': 'com.activision.callofduty.shooter', 'name': 'COD Mobile'},
        {'pkg': 'com.tencent.ig', 'name': 'PUBG Mobile'},
        {'pkg': 'com.riotgames.league.wildrift', 'name': 'Wild Rift'},
        {'pkg': 'com.mobile.legends', 'name': 'Mobile Legends'},
      ],
    },
  ];

  // Check if a smart pack is already active (has a matching rule)
  Map<String, dynamic>? _getActivePackRule(WidgetRef ref, Map<String, dynamic> pack) {
    final rules = ref.read(appBlockRuleProvider);
    final packName = pack['name'] as String;
    final packApps = (pack['apps'] as List<Map<String, String>>).map((a) => a['pkg']!).toSet();

    for (final rule in rules) {
      // Match by name containing pack name, OR by significant overlap in blocked apps
      final rulePackages = rule.blockedPackages.toSet();
      final overlap = rulePackages.intersection(packApps);
      if (rule.name.toLowerCase().contains(packName.toLowerCase()) ||
          (overlap.length >= 3 && overlap.length >= rulePackages.length * 0.5)) {
        return {'rule': rule, 'isEnabled': rule.isEnabled};
      }
    }
    return null;
  }

  void _showSmartPackSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.inventory_2_rounded, color: _gold, size: 20),
              const SizedBox(width: 8),
              Text("Smart Packs",
                  style: TextStyle(
                      color: _text,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Text("One-tap block packs — review & customize apps",
                style: TextStyle(
                    color: _textSoft, fontSize: 13)),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _smartPacks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final pack = _smartPacks[i];
                  final packColor = pack['color'] as Color;
                  final apps = pack['apps'] as List<Map<String, String>>;
                  final activeInfo = _getActivePackRule(ref, pack);
                  final isActive = activeInfo != null && activeInfo['isEnabled'] == true;
                  final isInactive = activeInfo != null && activeInfo['isEnabled'] == false;

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      if (isActive || isInactive) {
                        // Edit existing rule — pass the active rule
                        final existingRule = activeInfo['rule'] as AppBlockRule;
                        _showPackEditSheet(context, ref, pack, existingRule);
                      } else {
                        _showPackCustomizeSheet(context, ref, pack);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isActive
                            ? packColor.withValues(alpha: 0.1)
                            : packColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isActive
                              ? packColor.withValues(alpha: 0.4)
                              : packColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: packColor.withValues(alpha: isActive ? 0.18 : 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(pack['icon'] as IconData, color: packColor.withValues(alpha: 0.8), size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(pack['name'] as String,
                                          style: TextStyle(
                                              color: _text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    if (isActive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _sage.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.shield_rounded, size: 10, color: _sage),
                                            const SizedBox(width: 3),
                                            Text("ACTIVE",
                                                style: TextStyle(
                                                    color: _sageDark,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 0.5)),
                                          ],
                                        ),
                                      ),
                                    ] else if (isInactive) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _bg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text("PAUSED",
                                            style: TextStyle(
                                                color: _textSoft,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.5)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(pack['desc'] as String,
                                    style: TextStyle(
                                        color: _textSoft,
                                        fontSize: 12)),
                                const SizedBox(height: 6),
                                Text(isActive
                                    ? "${apps.length} apps \u00b7 Blocking"
                                    : "${apps.length} apps included",
                                    style: TextStyle(
                                        color: isActive
                                            ? _sage
                                            : packColor.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          Icon(isActive ? Icons.edit_rounded : Icons.arrow_forward_ios,
                              size: 14, color: _textSoft),
                        ],
                      ),
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

  // ── Pack customizer: review apps, pick schedule, create rule ──
  void _showPackCustomizeSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> pack) {
    final packApps = (pack['apps'] as List<Map<String, String>>);
    final packColor = pack['color'] as Color;
    final packName = pack['name'] as String;
    final allInstalledApps = ref.read(installedAppsProvider);
    final installedPkgs = allInstalledApps.map((a) => a.packageName).toSet();

    // Pre-select only apps that are installed on the device
    Set<String> selectedApps = {};
    Map<String, String> appLabels = {};
    for (final app in packApps) {
      final pkg = app['pkg']!;
      appLabels[pkg] = app['name']!;
      if (installedPkgs.contains(pkg)) {
        selectedApps.add(pkg);
      }
    }

    int scheduleMode = 0; // 0=Always, 1=Block Now (duration), 2=Scheduled
    int durationMinutes = 60;
    int startH = 9, startM = 0, endH = 17, endM = 0;
    Set<int> activeDays = {1, 2, 3, 4, 5};
    int breakDifficulty = 1; // Default Hard for packs
    final durations = [15, 30, 45, 60, 90, 120];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.88),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Icon(pack['icon'] as IconData, color: packColor.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Text("$packName Pack",
                      style: TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: packColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text("${selectedApps.length} apps",
                        style: TextStyle(color: packColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 16),

                // Apps list with toggles
                Text("Apps to Block",
                    style: TextStyle(color: _textSoft, fontSize: 13)),
                const SizedBox(height: 4),
                Text("Remove any apps you want to keep accessible",
                    style: TextStyle(color: _textSoft, fontSize: 11)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: packApps.map((app) {
                    final pkg = app['pkg']!;
                    final name = app['name']!;
                    final isSelected = selectedApps.contains(pkg);
                    final isInstalled = installedPkgs.contains(pkg);
                    return GestureDetector(
                      onTap: isInstalled ? () {
                        HapticFeedback.selectionClick();
                        setBS(() {
                          if (isSelected) {
                            selectedApps.remove(pkg);
                          } else {
                            selectedApps.add(pkg);
                          }
                        });
                      } : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: !isInstalled
                              ? _bg
                              : isSelected
                                  ? packColor.withValues(alpha: 0.10)
                                  : _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isInstalled
                                ? _border
                                : isSelected
                                    ? packColor.withValues(alpha: 0.3)
                                    : _border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected && isInstalled)
                              Icon(Icons.check_circle_rounded, size: 15, color: packColor.withValues(alpha: 0.8))
                            else if (!isInstalled)
                              Icon(Icons.block_rounded, size: 15, color: _border)
                            else
                              Icon(Icons.circle_outlined, size: 15, color: _textSoft),
                            const SizedBox(width: 6),
                            Text(name,
                                style: TextStyle(
                                    color: !isInstalled
                                        ? _textSoft
                                        : isSelected
                                            ? _text
                                            : _textSoft,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400)),
                            if (!isInstalled) ...[
                              const SizedBox(width: 4),
                              Text("not installed",
                                  style: TextStyle(color: _textSoft, fontSize: 9)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Schedule mode selector
                Text("Schedule",
                    style: TextStyle(color: _textSoft, fontSize: 13)),
                const SizedBox(height: 8),
                Row(children: [
                  _buildScheduleChip("Always On", 0, scheduleMode, packColor, (v) => setBS(() => scheduleMode = v)),
                  const SizedBox(width: 8),
                  _buildScheduleChip("Duration", 1, scheduleMode, packColor, (v) => setBS(() => scheduleMode = v)),
                  const SizedBox(width: 8),
                  _buildScheduleChip("Time Window", 2, scheduleMode, packColor, (v) => setBS(() => scheduleMode = v)),
                ]),

                // Duration picker (mode 1)
                if (scheduleMode == 1) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: durations.map((d) {
                      final isSelected = durationMinutes == d;
                      final label = d >= 60 ? '${d ~/ 60}h${d % 60 > 0 ? " ${d % 60}m" : ""}' : '${d}m';
                      return GestureDetector(
                        onTap: () => setBS(() => durationMinutes = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? packColor.withValues(alpha: 0.10)
                                : _bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: isSelected
                                    ? packColor.withValues(alpha: 0.4)
                                    : _border),
                          ),
                          child: Text(label,
                              style: TextStyle(
                                  color: isSelected
                                      ? packColor
                                      : _textSoft,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                // Time window picker (mode 2)
                if (scheduleMode == 2) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                              context: ctx, initialTime: TimeOfDay(hour: startH, minute: startM));
                          if (time != null) setBS(() { startH = time.hour; startM = time.minute; });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Text("Start: ${_formatHour(startH, startM)}",
                              style: TextStyle(color: _text, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final time = await showTimePicker(
                              context: ctx, initialTime: TimeOfDay(hour: endH, minute: endM));
                          if (time != null) setBS(() { endH = time.hour; endM = time.minute; });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _border),
                          ),
                          child: Text("End: ${_formatHour(endH, endM)}",
                              style: TextStyle(color: _text, fontSize: 13),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      final active = activeDays.contains(day);
                      return GestureDetector(
                        onTap: () => setBS(() {
                          if (active) {
                            activeDays.remove(day);
                          } else {
                            activeDays.add(day);
                          }
                        }),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? packColor.withValues(alpha: 0.15)
                                : _bg,
                          ),
                          child: Center(
                            child: Text(labels[i],
                                style: TextStyle(
                                    fontSize: 12,
                                    color: active ? packColor : _textSoft)),
                          ),
                        ),
                      );
                    }),
                  ),
                ],

                const SizedBox(height: 16),
                // Break difficulty
                _buildBreakDifficultySelector(ref, breakDifficulty, (v) => setBS(() => breakDifficulty = v), ctx),

                const SizedBox(height: 20),
                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedApps.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text("Select at least one app to block"),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }

                      int sH = 0, sM = 0, eH = 23, eM = 59;
                      List<int> days = List.generate(7, (i) => i + 1);
                      bool isTimeBased = true;
                      DateTime? expiresAt;

                      if (scheduleMode == 1) {
                        // Duration-based: start now, end after X minutes
                        final now = DateTime.now();
                        final end = now.add(Duration(minutes: durationMinutes));
                        sH = now.hour; sM = now.minute;
                        eH = end.hour; eM = end.minute;
                        days = [now.weekday];
                        expiresAt = end; // Exact expiry time for duration-based blocks
                      } else if (scheduleMode == 2) {
                        // Scheduled time window
                        sH = startH; sM = startM;
                        eH = endH; eM = endM;
                        days = activeDays.toList();
                      } else {
                        // Always on = not time-based
                        isTimeBased = false;
                      }

                      final newRule = await ref.read(appBlockRuleProvider.notifier).addRule(
                        name: "$packName Block",
                        blockedPackages: selectedApps.toList(),
                        isTimeBased: isTimeBased,
                        startHour: sH,
                        startMinute: sM,
                        endHour: eH,
                        endMinute: eM,
                        activeDays: days,
                        isHardBlock: breakDifficulty == 1,
                        allowBreaks: breakDifficulty == 0,
                        expiresAt: expiresAt,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      if (context.mounted) {
                        _showRuleInfoSheet(context, ref, newRule);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: packColor.withValues(alpha: 0.2),
                      foregroundColor: packColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text("Activate $packName Block"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Pack EDIT sheet: edit apps on an existing active smart pack rule ──
  void _showPackEditSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> pack, AppBlockRule existingRule) {
    final packApps = (pack['apps'] as List<Map<String, String>>);
    final packColor = pack['color'] as Color;
    final packName = pack['name'] as String;
    final allInstalledApps = ref.read(installedAppsProvider);
    final installedPkgs = allInstalledApps.map((a) => a.packageName).toSet();

    // These are LOCKED — already blocked, cannot be removed
    final lockedApps = Set<String>.from(existingRule.blockedPackages);

    // Selected starts with locked apps; user can only ADD more
    Set<String> selectedApps = Set<String>.from(lockedApps);
    Map<String, String> appLabels = {};
    for (final app in packApps) {
      appLabels[app['pkg']!] = app['name']!;
    }
    // Also add labels for any apps in rule that aren't in pack definition
    for (final pkg in existingRule.blockedPackages) {
      if (!appLabels.containsKey(pkg)) {
        final appName = allInstalledApps
            .where((a) => a.packageName == pkg)
            .map((a) => a.appName)
            .firstOrNull ?? pkg.split('.').last;
        appLabels[pkg] = appName;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Icon(pack['icon'] as IconData, color: packColor.withValues(alpha: 0.7), size: 20),
                  const SizedBox(width: 8),
                  Text("Edit $packName",
                      style: TextStyle(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _sage.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded, size: 10, color: _sage),
                        const SizedBox(width: 4),
                        Text("${selectedApps.length} blocked",
                            style: TextStyle(color: _sageDark, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                Text("🔒 Existing apps are locked · Tap to add new apps",
                    style: TextStyle(color: _textSoft, fontSize: 12)),
                const SizedBox(height: 12),

                // Pack apps with toggle
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: packApps.map((app) {
                    final pkg = app['pkg']!;
                    final name = app['name']!;
                    final isSelected = selectedApps.contains(pkg);
                    final isInstalled = installedPkgs.contains(pkg);
                    final isLocked = lockedApps.contains(pkg);
                    return GestureDetector(
                      onTap: (isInstalled && !isLocked) ? () {
                        HapticFeedback.selectionClick();
                        setBS(() {
                          if (isSelected) {
                            selectedApps.remove(pkg);
                          } else {
                            selectedApps.add(pkg);
                          }
                        });
                      } : isLocked ? () {
                        HapticFeedback.heavyImpact();
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text("🔒 Active blocked apps can't be removed"),
                          backgroundColor: _textSoft,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      } : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: !isInstalled
                              ? _bg
                              : isLocked
                                  ? packColor.withValues(alpha: 0.12)
                                  : isSelected
                                      ? packColor.withValues(alpha: 0.10)
                                      : _bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isInstalled
                                ? _border
                                : isLocked
                                    ? packColor.withValues(alpha: 0.5)
                                    : isSelected
                                        ? packColor.withValues(alpha: 0.3)
                                        : _border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLocked)
                              Icon(Icons.lock_rounded, size: 15, color: packColor.withValues(alpha: 0.9))
                            else if (isSelected && isInstalled)
                              Icon(Icons.check_circle_rounded, size: 15, color: packColor.withValues(alpha: 0.8))
                            else if (!isInstalled)
                              Icon(Icons.block_rounded, size: 15, color: _border)
                            else
                              Icon(Icons.circle_outlined, size: 15, color: _textSoft),
                            const SizedBox(width: 6),
                            Text(name,
                                style: TextStyle(
                                    color: !isInstalled
                                        ? _textSoft
                                        : isLocked
                                            ? _text
                                            : isSelected
                                                ? _text
                                                : _textSoft,
                                    fontSize: 12,
                                    fontWeight: isLocked ? FontWeight.w600 : isSelected ? FontWeight.w500 : FontWeight.w400)),
                            if (isLocked) ...[
                              const SizedBox(width: 4),
                              Text("locked",
                                  style: TextStyle(color: packColor.withValues(alpha: 0.6), fontSize: 9, fontWeight: FontWeight.w600)),
                            ],
                            if (!isInstalled) ...[
                              const SizedBox(width: 4),
                              Text("not installed",
                                  style: TextStyle(color: _textSoft, fontSize: 9)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (selectedApps.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: const Text("At least 1 app must be blocked"),
                          backgroundColor: Colors.red.withValues(alpha: 0.8),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                        return;
                      }
                      ref.read(appBlockRuleProvider.notifier).updateRule(
                        existingRule.id,
                        blockedPackages: selectedApps.toList(),
                      );
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text('$packName updated · ${selectedApps.length} apps blocked'),
                        backgroundColor: _sage,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: packColor.withValues(alpha: 0.2),
                      foregroundColor: packColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Save Changes"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleChip(String label, int value, int selected, Color color, ValueChanged<int> onTap) {
    final isActive = selected == value;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(value); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.10) : _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.3) : _border,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                color: isActive ? color : _textSoft,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }

  // ── Shared: "Add Apps" button + selected chips ──
  Widget _buildAddAppsButton(
      BuildContext ctx, WidgetRef ref, Set<String> selectedApps, StateSetter setBS) {
    final allApps = ref.read(installedAppsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Apps to Block',
              style: TextStyle(
                  color: _textSoft, fontSize: 13)),
          const Spacer(),
          if (selectedApps.isNotEmpty)
            Text('${selectedApps.length} selected',
                style: TextStyle(
                    color: _sage, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        // Selected app chips
        if (selectedApps.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedApps.map((pkg) {
              final appName = allApps
                  .where((a) => a.packageName == pkg)
                  .map((a) => a.appName)
                  .firstOrNull ?? pkg.split('.').last;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _sage.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _sage.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(appName,
                        style: TextStyle(
                            color: _text,
                            fontSize: 12)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setBS(() => selectedApps.remove(pkg)),
                      child: Icon(Icons.close,
                          size: 14,
                          color: _textSoft),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        // "Add Apps" button
        GestureDetector(
          onTap: () async {
            final result = await Navigator.of(ctx, rootNavigator: true).push<Set<String>>(
              PageRouteBuilder(
                fullscreenDialog: true,
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 200),
                pageBuilder: (c, anim, _) => _AppSelectionScreen(
                  allApps: allApps,
                  preSelected: selectedApps,
                ),
                transitionsBuilder: (c, anim, _, child) =>
                    SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.3), end: Offset.zero)
                          .animate(CurvedAnimation(
                              parent: anim, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
              ),
            );
            if (result != null) {
              setBS(() {
                selectedApps.clear();
                selectedApps.addAll(result);
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded,
                    color: _sage, size: 18),
                const SizedBox(width: 8),
                Text(
                  selectedApps.isEmpty ? 'Add Apps' : 'Change Apps',
                  style: TextStyle(
                      color: _sageDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Hard Mode Info Page ──
  void _showHardModeInfo(BuildContext ctx, VoidCallback onConfirm) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (bsCtx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 28,
          bottom: MediaQuery.of(bsCtx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red lock icon
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD93025).withValues(alpha: 0.06),
                border: Border.all(color: const Color(0xFFD93025).withValues(alpha: 0.15)),
              ),
              child: Icon(Icons.lock_rounded, color: const Color(0xFFD93025).withValues(alpha: 0.7), size: 26),
            ),
            const SizedBox(height: 18),
            Text('Hard Mode',
              style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('This cannot be undone easily',
              style: TextStyle(color: _textSoft, fontSize: 13)),
            const SizedBox(height: 24),
            // Rules
            _hardModeRule(Icons.block_rounded, "Can't disable or delete this rule"),
            const SizedBox(height: 12),
            _hardModeRule(Icons.pause_circle_outline_rounded, "Can't pause or take breaks"),
            const SizedBox(height: 12),
            _hardModeRule(Icons.delete_forever_rounded, "Can't uninstall blocked apps"),
            const SizedBox(height: 12),
            _hardModeRule(Icons.timer_off_rounded, "Only expires when the timer ends"),
            const SizedBox(height: 28),
            // Confirm
            GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pop(bsCtx);
                onConfirm();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFD93025).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD93025).withValues(alpha: 0.25)),
                ),
                child: const Center(
                  child: Text('I understand, enable Hard Mode',
                    style: TextStyle(color: Color(0xFFD93025), fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(bsCtx),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text('Cancel',
                    style: TextStyle(color: _textSoft, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hardModeRule(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _textSoft, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
            style: TextStyle(color: _text, fontSize: 14)),
        ),
      ],
    );
  }

  // ── Shared: Break Difficulty Selector ──
  Widget _buildBreakDifficultySelector(
      WidgetRef ref, int difficulty, ValueChanged<int> onChanged, BuildContext ctx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Break Difficulty',
            style: TextStyle(
                color: _textSoft, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          // Easy
          Expanded(
            child: GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); onChanged(0); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: difficulty == 0
                      ? _sage.withValues(alpha: 0.08)
                      : _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: difficulty == 0
                        ? _sage.withValues(alpha: 0.3)
                        : _border,
                  ),
                ),
                child: Column(children: [
                  Icon(Icons.lock_open_rounded,
                      size: 22,
                      color: difficulty == 0
                          ? _sage
                          : _textSoft),
                  const SizedBox(height: 6),
                  Text('Easy',
                      style: TextStyle(
                          color: difficulty == 0
                              ? _sageDark
                              : _textSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Can take breaks\n& pause anytime',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _textSoft,
                          fontSize: 10)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Hard
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                // Show Hard Mode info page first
                _showHardModeInfo(ctx, () => onChanged(1));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: difficulty == 1
                      ? _desertSunset.withValues(alpha: 0.06)
                      : _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: difficulty == 1
                        ? _desertSunset.withValues(alpha: 0.3)
                        : _border,
                  ),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lock_rounded,
                        size: 22,
                        color: difficulty == 1
                            ? _desertSunset
                            : _textSoft),
                  ]),
                  const SizedBox(height: 6),
                  Text('Hard',
                      style: TextStyle(
                          color: difficulty == 1
                              ? _desertSunset
                              : _textSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text("Can't break, leave\nor uninstall app",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _textSoft,
                          fontSize: 10)),
                ]),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

// ─── 100-Tap Deactivate Confirmation ────────────────────────────────────────

class _DeactivateRuleConfirmScreen extends ConsumerStatefulWidget {
  final String ruleId;
  final String ruleName;
  const _DeactivateRuleConfirmScreen({required this.ruleId, required this.ruleName});

  @override
  ConsumerState<_DeactivateRuleConfirmScreen> createState() => _DeactivateRuleConfirmScreenState();
}

class _DeactivateRuleConfirmScreenState extends ConsumerState<_DeactivateRuleConfirmScreen> {
  // ── Theme-aware colors ──
  bool get _isLight => ref.watch(themeColorProvider).isLight;
  Color get _bg => _isLight ? const Color(0xFFF5F5F5) : _ftBg;
  Color get _card => _isLight ? Colors.black.withValues(alpha: 0.04) : _ftCard;
  Color get _text => _isLight ? const Color(0xFF0D0D0D) : _ftText;
  Color get _textSoft => _isLight ? const Color(0xFF6B6B6B) : _ftTextSoft;
  Color get _border => _isLight ? Colors.black.withValues(alpha: 0.08) : _ftBorder;

  int _tapCount = 0;
  static const int _requiredTaps = 100;

  void _handleTap() {
    HapticFeedback.selectionClick();
    setState(() => _tapCount++);
    if (_tapCount >= _requiredTaps) {
      HapticFeedback.heavyImpact();
      ref.read(appBlockRuleProvider.notifier).toggleRule(widget.ruleId);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rule "${widget.ruleName}" deactivated'),
          backgroundColor: _desertSunset.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tapCount / _requiredTaps;
    final remaining = _requiredTaps - _tapCount;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
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
                    child: Text('Deactivate Blocker',
                        style: TextStyle(
                            color: _text,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning icon
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: _desertSunset.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shield_outlined, size: 40,
                            color: _desertSunset.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Stay focused?',
                        style: TextStyle(
                          color: _text,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deactivating "${widget.ruleName}" removes\nyour focus protection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textSoft,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: _border,
                          color: Color.lerp(
                            _desertSunset.withValues(alpha: 0.3),
                            _desertSunset.withValues(alpha: 0.8),
                            progress,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$remaining taps remaining',
                        style: TextStyle(
                          color: _textSoft,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tap target
                      GestureDetector(
                        onTap: _handleTap,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                              _desertSunset.withValues(alpha: 0.04),
                              _desertSunset.withValues(alpha: 0.18),
                              progress,
                            ),
                            border: Border.all(
                              color: Color.lerp(
                                _desertSunset.withValues(alpha: 0.12),
                                _desertSunset.withValues(alpha: 0.5),
                                progress,
                              )!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_tapCount',
                                style: TextStyle(
                                  color: _desertSunset.withValues(alpha: 0.5 + progress * 0.4),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to\ndeactivate',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _desertSunset.withValues(alpha: 0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tap the button $_requiredTaps times to deactivate',
                        style: TextStyle(
                          color: _textSoft,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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

// ─── 100-Tap Delete Confirmation ────────────────────────────────────────────

class _DeleteRuleConfirmScreen extends ConsumerStatefulWidget {
  final String ruleId;
  final String ruleName;
  const _DeleteRuleConfirmScreen({required this.ruleId, required this.ruleName});

  @override
  ConsumerState<_DeleteRuleConfirmScreen> createState() => _DeleteRuleConfirmScreenState();
}

class _DeleteRuleConfirmScreenState extends ConsumerState<_DeleteRuleConfirmScreen> {
  // ── Theme-aware colors ──
  bool get _isLight => ref.watch(themeColorProvider).isLight;
  Color get _bg => _isLight ? const Color(0xFFF5F5F5) : _ftBg;
  Color get _card => _isLight ? Colors.black.withValues(alpha: 0.04) : _ftCard;
  Color get _text => _isLight ? const Color(0xFF0D0D0D) : _ftText;
  Color get _textSoft => _isLight ? const Color(0xFF6B6B6B) : _ftTextSoft;
  Color get _border => _isLight ? Colors.black.withValues(alpha: 0.08) : _ftBorder;

  int _tapCount = 0;
  static const int _requiredTaps = 100;

  void _handleTap() {
    HapticFeedback.selectionClick();
    setState(() => _tapCount++);
    if (_tapCount >= _requiredTaps) {
      HapticFeedback.heavyImpact();
      ref.read(appBlockRuleProvider.notifier).deleteRule(widget.ruleId);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rule "${widget.ruleName}" deleted'),
          backgroundColor: Colors.red.withValues(alpha: 0.8),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tapCount / _requiredTaps;
    final remaining = _requiredTaps - _tapCount;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
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
                    child: Text('Delete Rule',
                        style: TextStyle(
                            color: _text,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Warning icon
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.warning_amber_rounded, size: 40,
                            color: Colors.red.withValues(alpha: 0.6)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Are you absolutely sure?',
                        style: TextStyle(
                          color: _text,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deleting "${widget.ruleName}" means removing\nyour focus protection.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textSoft,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: _border,
                          color: Color.lerp(
                            Colors.red.withValues(alpha: 0.3),
                            Colors.red.withValues(alpha: 0.8),
                            progress,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$remaining taps remaining',
                        style: TextStyle(
                          color: _textSoft,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Tap target
                      GestureDetector(
                        onTap: _handleTap,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color.lerp(
                              Colors.red.withValues(alpha: 0.04),
                              Colors.red.withValues(alpha: 0.18),
                              progress,
                            ),
                            border: Border.all(
                              color: Color.lerp(
                                Colors.red.withValues(alpha: 0.12),
                                Colors.red.withValues(alpha: 0.5),
                                progress,
                              )!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_tapCount',
                                style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.5 + progress * 0.4),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to\nconfirm',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.red.withValues(alpha: 0.35),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Tap the button $_requiredTaps times to delete',
                        style: TextStyle(
                          color: _textSoft,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
                    HapticFeedback.lightImpact();
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
                      HapticFeedback.selectionClick();
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
        HapticFeedback.lightImpact();
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
                  HapticFeedback.mediumImpact();
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
                  HapticFeedback.mediumImpact();
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
                      HapticFeedback.lightImpact();
                      Navigator.pop(context, true);
                    } else {
                      HapticFeedback.heavyImpact();
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
