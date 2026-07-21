import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/islamic_theme_provider.dart';
import '../providers/screen_time_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../services/native_app_blocker_service.dart';
import '../services/offline_content_manager.dart';
import '../services/wisdom_service.dart';
import '../utils/motion.dart';
import '../widgets/app_session_timer_sheet.dart';
import '../widgets/year_dots_wallpaper.dart';
import 'home_clock_screen.dart';
import 'widget_dashboard_screen.dart';
import 'app_list_screen.dart';
import 'productivity_hub_screen.dart';
import '../features/quran/screens/surah_list_screen.dart';
import '../features/hadith_dua/screens/minimalist_hadith_screen.dart';
import '../features/hadith_dua/screens/minimalist_dua_screen.dart';
import '../features/islamic_library/screens/book_home_screen.dart';
// Pre-warm providers — imported for background initialization
import '../features/quran/providers/quran_provider.dart';
import '../features/islamic_library/providers/book_provider.dart';
import '../features/hadith_dua/providers/hadith_dua_provider.dart';
import '../features/hadith_dua/screens/dua_adhkar_category_screen.dart';

import '../providers/zen_mode_provider.dart';
import '../providers/launcher_page_provider.dart';
import 'zen_mode_active_screen.dart';
import '../services/app_update_service.dart';
import '../providers/page_indicator_provider.dart';
import '../providers/display_settings_provider.dart';
import '../providers/tasbih_provider.dart';
import '../providers/app_update_provider.dart';
import '../utils/hive_box_manager.dart';
import '../utils/launcher_physics.dart';
import '../utils/smooth_page_route.dart' show DeferredFade;

/// ─────────────────────────────────────────────────────────────────────────
///  GESTURE-ARENA DISAMBIGUATION  (horizontal page  vs.  vertical content)
/// ─────────────────────────────────────────────────────────────────────────
///
/// The launcher is a horizontal [PageView] whose pages each hold a vertically
/// scrolling feed. The PageView's [HorizontalDragGestureRecognizer] and the
/// inner [VerticalDragGestureRecognizer] compete in the SAME gesture arena —
/// whichever axis travels its touch-slop distance FIRST wins and sweeps the
/// loser out.
///
/// With framework defaults both recognizers share one touch slop
/// (kTouchSlop = 18px), so the win boundary sits at exactly 45°. A drag only
/// slightly more horizontal than vertical — or a curved diagonal drag — lets
/// the horizontal recognizer win, and the page drifts sideways while the user
/// is really trying to scroll vertically.
///
/// FIX — give the two axes ASYMMETRIC touch slop:
///   • The PageView is wrapped in a [MediaQuery] whose
///     [DeviceGestureSettings.touchSlop] is raised to `base × [_kPageSlopMultiplier]`,
///     so a page change needs a longer, clearly-horizontal drag.
///   • Each page's content is re-wrapped in a [MediaQuery] that restores the
///     base [_kInnerTouchSlop], keeping vertical scrolling responsive.
///
/// Net effect: the dominant axis wins decisively. A vertical drag reaches its
/// (smaller) slop long before the horizontal recognizer reaches its (larger)
/// one, so the page does NOT move at all; only a drag within ≈30° of
/// horizontal changes pages.
const double _kInnerTouchSlop = kTouchSlop; // 18px — vertical content scroll
const double _kPageSlopMultiplier = 1.7; // horizontal page slop = base × this

/// Crisp, drift-free snap spring for page settling.
///
/// Slightly overdamped (ratio 1.1 → no overshoot/bounce) and stiffer than the
/// framework default (stiffness 100), so the page lands quickly and decisively
/// instead of coasting with a long, loose tail.
// ── Lawnchair (Launcher3 PagedView) page-swipe constants ──
// Ported from LawnchairLauncher/lawnchair PagedView.java. Logical px ≈ dp, so
// the dp/s thresholds map ~1:1 to Flutter's logical px/s.
const double _kLcFlingThreshold = 500.0; // decisive flick → advance one page
const double _kLcSoftFling = 80.0; // gentle motion → directional commit
const double _kLcSignificantMove = 0.40; // drag past 40% of a page → commit

// Crisp, decisive snap matching Launcher3's quintic SCROLL ease-out: a slightly
// over-damped spring (no overshoot), tuned to settle ~300ms for a full page and
// shorter for partial snaps — the "fast Lawnchair land".
final SpringDescription _kPageSnapSpring = SpringDescription.withDampingRatio(
  mass: 0.5,
  stiffness: 220.0,
  ratio: 1.05,
);

/// Launcher page physics — any horizontal swipe from a non-home page
/// navigates directly to the Home page (index 2). This gives the user
/// a Samsung One-UI / iOS Springboard feel where Home is always one
/// swipe away, regardless of which page they are on.
///
/// Uses [ClampingScrollPhysics] boundary (no overscroll bounce) and
/// Flutter's built-in [PageScrollPhysics] for snapping, tightened with a
/// crisp snap spring and a higher fling threshold (see below).
class _LauncherPagePhysics extends PageScrollPhysics {
  const _LauncherPagePhysics({super.parent});

  @override
  _LauncherPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _LauncherPagePhysics(parent: buildParent(ancestor));
  }

  // Crisp snap: stiffer, non-overshooting spring (see [_kPageSnapSpring]).
  @override
  SpringDescription get spring => _kPageSnapSpring;

  // Require a more intentional flick before a low-momentum release commits to
  // the next page. Below this velocity the page snaps to the nearest page by
  // position instead of coasting — this kills the "loose / drifty" feel.
  @override
  double get minFlingVelocity => 80.0;

  // ── Lawnchair page selection on release (single page per gesture) ──
  // Replaces Flutter's velocity-biased rounding with Launcher3's richer commit:
  //   • decisive flick (>500 px/s) → one page in the FLING direction;
  //   • gentle drag past 40% of a page → one page in the DRAG direction;
  //   • a back-flick before that cancels (return-to-original);
  //   • otherwise snap to the nearest page.
  // The chosen page is always one of the adjacent pair, so a single gesture can
  // never skip pages. Settled by the over-damped [spring] (quintic-like, no
  // bounce). MUST return a real ScrollSpringSimulation so the gesture-arena
  // release (_killBallisticIfSettling) keeps working — never a plain jump.
  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final tol = toleranceFor(position);
    final dim = position.viewportDimension;
    if (dim <= 0) return super.createBallisticSimulation(position, velocity);

    final page = position.pixels / dim;
    final lower = page.floorToDouble();
    final upper = lower + 1.0;
    final f = page - lower; // 0..1 within the current adjacent pair

    final speed = velocity.abs();
    double target;
    if (speed > _kLcFlingThreshold) {
      // Decisive flick → commit one page in the fling direction.
      target = velocity > 0 ? upper : lower;
    } else if (velocity > _kLcSoftFling) {
      // Gentle forward motion → commit forward once dragged past 40%.
      target = f > _kLcSignificantMove ? upper : lower;
    } else if (velocity < -_kLcSoftFling) {
      // Gentle backward motion → commit back once dragged past 40% (f < 0.60).
      target = f < (1.0 - _kLcSignificantMove) ? lower : upper;
    } else {
      // Near-still release → nearest page.
      target = f >= 0.5 ? upper : lower;
    }

    // Range clamp (single-page is inherent — target is one of the pair).
    final minPage = position.minScrollExtent / dim;
    final maxPage = position.maxScrollExtent / dim;
    target = target.clamp(minPage, maxPage);

    final targetPixels = target * dim;
    if ((targetPixels - position.pixels).abs() < tol.distance) {
      return null; // already there — rest, freeing the gesture arena cleanly
    }
    return ScrollSpringSimulation(
        spring, position.pixels, targetPixels, velocity,
        tolerance: tol);
  }

  // ── Boundary: hard clamp (zero overscroll at first/last page) ──
  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.pixels &&
        position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    if (position.maxScrollExtent <= position.pixels &&
        position.pixels < value) {
      return value - position.pixels;
    }
    if (value < position.minScrollExtent &&
        position.minScrollExtent < position.pixels) {
      return value - position.minScrollExtent;
    }
    if (position.pixels < position.maxScrollExtent &&
        position.maxScrollExtent < value) {
      return value - position.maxScrollExtent;
    }
    return 0.0;
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// A [ScrollBehavior] applied to every vertical [Scrollable] inside each
/// PageView page: plain [ClampingScrollPhysics] — no overscroll bounce or glow.
///
/// NOTE: axis disambiguation is NOT handled here. The [Scrollable] gesture
/// recognizers only honour the touch slop carried by the ambient
/// [MediaQuery]'s [DeviceGestureSettings] — they ignore
/// `ScrollPhysics.dragStartDistanceMotionThreshold`. Horizontal-vs-vertical
/// intent is therefore resolved by the asymmetric touch slop wired up in
/// [build]; see [_kPageSlopMultiplier].
class _PageInnerScrollBehavior extends ScrollBehavior {
  const _PageInnerScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

/// Main launcher shell with swipeable pages
/// Layout: [Islamic Hub] ← [Dashboard] ← [HOME] → [App List] → [Productivity]
class LauncherShell extends ConsumerStatefulWidget {
  const LauncherShell({super.key});

  @override
  ConsumerState<LauncherShell> createState() => _LauncherShellState();
}

class _LauncherShellState extends ConsumerState<LauncherShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  late AnimationController _animController;
  /// Return-from-app animation: fade+scale when coming back from external app.
  late AnimationController _returnFromAppController;
  bool _animRunning = false;
  bool _offlineInitialized = false;
  bool _hasShownLauncherPrompt = false; // Only show once per session
  int _yearDotsKey = 0; // Increments on resume to refresh year dots

  /// Tracks the previous page for snap-to-home direction detection.
  // ignore: unused_field
  int _prevPage = 3; // Start on Home

  /// True while a programmatic animateToPage/jumpToPage is in flight.
  /// While set, [didChangeAppLifecycleState] skips its setState to avoid
  /// a double-rebuild that competes with the in-flight page animation.
  bool _pageAnimating = false;

  /// Timestamp of last pause — used to distinguish quick permission dialogs
  /// (GPS, notification) from genuine app switches when deciding whether to
  /// pop all routes on resume.
  DateTime? _lastPausedAt;

  /// True when the last lifecycle pause was caused by the screen turning OFF
  /// (lock button / auto-lock timeout) rather than the user switching to
  /// another app. When this is true, resume must NEVER reset the page or
  /// pop any pushed routes — the user expects to land exactly where they left.
  bool _wasScreenOff = false;

  /// Debounce: timestamp of last "times up" overlay shown.
  /// Prevents the overlay from appearing in a loop on rapid resume cycles.
  DateTime? _lastTimesUpShown;

  /// SharedPreferences key for persisting the last active page index.
  static const _kLastPageKey = 'launcher_last_page_index';

  // Page layout: [Islamic(0), Widget(1), Home(2), Apps(3), Productivity(4)]
  static const int _homeIndex = 2;

  static const _launcherChannel = MethodChannel('com.sukoon.launcher/launcher');

  /// Navigation channel — receives 'goHome' from native when home button
  /// is pressed while the user is in an external app.
  static const _navChannel = MethodChannel('com.sukoon.launcher/navigation');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _homeIndex, viewportFraction: 1.0);
    // Share the page controller so other screens can navigate
    Future.microtask(() {
      ref.read(launcherPageControllerProvider.notifier).state = _pageController;
    });
    _animController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // Return-from-app animation controller
    _returnFromAppController = AnimationController(
      duration: LauncherDuration.returnFromApp,
      vsync: this,
    )..value = 1.0; // Start fully visible (no animation on first build)

    // ── Native → Flutter navigation: home button press from external app ──
    _navChannel.setMethodCallHandler((call) async {
      if (call.method == 'goHome') {
        _goHome(popRoutes: true);
      }
    });

    // ── RESTORE LAST PAGE: Jump to where the user was before screen-off/restart ──
    // Reads the persisted page index and jumps there after the first frame.
    // This ensures that locking/unlocking the phone never drops the user back
    // to the home page when they were on the Quran, App List, Settings, etc.
    _restoreLastPage();

    // 🧘 ZEN MODE SURVIVAL: Check if Zen Mode is active (survives restart/reboot)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final zen = ref.read(zenModeProvider);
      if (zen.isActive && !zen.hasExpired) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ZenModeActiveScreen(),
          ),
        );
      } else if (zen.isActive && zen.hasExpired) {
        ref.read(zenModeProvider.notifier).endZenMode();
      }
      // Initialize offline content manager ONCE (moved out of build)
      if (!_offlineInitialized) {
        _offlineInitialized = true;
        ref.read(offlineContentProvider);
      }
      // Check default launcher on first launch
      _checkDefaultLauncher();

      // ── In-App Update: check silently 3s after launch ──
      // Sets _updateAvailable flag — HomeClockScreen reads it to show
      // a subtle 'Update available' label (no intrusive popup).
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        AppUpdateService().initialize(
          onUpdateReady: () {
            // Update downloaded — set provider for inline display
            if (mounted) {
              ref.read(appUpdateStateProvider.notifier).state =
                  ref.read(appUpdateStateProvider).copyWith(updateReady: true);
            }
          },
        );
        _checkForUpdate();

        // ── PRE-WARM Islamic Library providers ──
        // Trigger lazy FutureProviders so their heavy I/O + JSON parsing
        // runs in the background BEFORE the user taps Quran/Hadith/Dua/Seerah.
        // By the time they navigate, the data is already cached in memory.
        _preWarmIslamicProviders();
      });
    });
  }

  /// Pre-warm Islamic Library providers in the background.
  /// Called 3s after launch — gives the home screen time to render first,
  /// then silently parses Quran JSON (2.4 MB, in isolate), Hisnul Muslim,
  /// Seerah chapters, and daily hadith so opening those screens is instant.
  void _preWarmIslamicProviders() {
    // Quran: triggers 2.4 MB JSON parse in background isolate
    ref.read(surahsProvider);
    // Dua: triggers 89 KB hisnul_muslim.json parse
    ref.read(hisnulMuslimProvider);
    // Seerah: triggers parallel chapter loading
    ref.read(bookProvider);
    // Hadith: triggers Hive cache lookup + daily hadith fetch
    ref.read(dailyHadithProvider);
  }

  /// Restore the last active page index from SharedPreferences.
  /// Called once in initState — jumps the PageView after the first frame.
  /// Always starts on the home page; saved page is intentionally ignored
  /// so that opening the launcher always lands on Home.
  Future<void> _restoreLastPage() async {
    try {
      // Always land on home — do not restore the last visited page.
      // The "last page" is only used by the lifecycle resume handler
      // (which skips the restore for short absences anyway).
      // Clearing any stale saved page keeps behaviour consistent.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastPageKey, _homeIndex);
    } catch (_) {
      // SharedPreferences failure is non-fatal
    }
  }

  /// Persist the current page index so it survives screen-off/on and restarts.
  Future<void> _saveCurrentPage(int pageIndex) async {
    _prevPage = pageIndex;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastPageKey, pageIndex);
    } catch (_) {}
  }

  /// Check if the screen is currently off using the native PowerManager.
  /// Sets [_wasScreenOff] = true when the screen is off so that the
  /// resumed handler knows this is a lock/unlock cycle (not an app switch).
  static const _powerChannel = MethodChannel('com.sukoon.launcher/power');

  Future<void> _checkIsScreenOff() async {
    try {
      final isInteractive = await _powerChannel.invokeMethod<bool>('isInteractive') ?? true;
      _wasScreenOff = !isInteractive;
    } catch (_) {
      // Channel not implemented yet — fall back to heuristic:
      // If the pause-to-resume gap is very short (< 800ms) it's almost
      // certainly a quick screen-off/on cycle rather than an app switch.
      // We'll refine this in the resumed handler.
      _wasScreenOff = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // ── GOING AWAY (fully backgrounded) ──
      // Record when we paused — used on resume to distinguish quick
      // permission dialogs / screen lock cycles from genuine app switches.
      _lastPausedAt = DateTime.now();

      // Check native PowerManager to detect screen-off vs app-switch.
      // _checkIsScreenOff() is async — it sets _wasScreenOff before
      // the resumed event fires (screen-off/on always takes > 500ms).
      _checkIsScreenOff();

      // ── Flush pending data saves ──
      // Tasbih uses debounced saves during rapid tapping — flush to disk
      // before we go away so no dhikr counts are lost.
      ref.read(tasbihProvider.notifier).flushPendingSave();
      // Compact all open Hive boxes to reclaim disk space (fire-and-forget)
      HiveBoxManager.compactAll();

      // Do NOT jump to home page here. The paused state fires during:
      //   1. Genuine backgrounding (home button / app switch)
      //   2. Navigator.push transitions (brief lifecycle bounce)
      //   3. Permission dialogs / system overlays
      //   4. Screen turning off (auto-lock / power button)
      // Jumping PageView during case 2/4 causes the user to land on the
      // wrong page when they pop back.

      // Reset the flag so resumed won't fight with an old animation.
      _pageAnimating = false;
    }

    // inactive = system overlay (permission dialog, phone call, notification
    // shade). Do NOT jump to home or pop routes — user expects to stay put.
    if (state == AppLifecycleState.inactive) {
      _lastPausedAt ??= DateTime.now(); // Only set if not already paused
    }

    if (state == AppLifecycleState.resumed) {
      // ── COMING BACK ──
      final pauseDuration = _lastPausedAt != null
          ? DateTime.now().difference(_lastPausedAt!)
          : const Duration(seconds: 10);
      _lastPausedAt = null; // Reset for next cycle

      // SCREEN-OFF UNLOCK: The user simply locked and unlocked the phone
      // while staying inside the launcher. Never reset the page position or
      // pop any routes — they expect to see exactly what they had before.
      //
      // Two ways to detect a screen-off cycle:
      //  1. _wasScreenOff flag set by the native power channel (most reliable).
      //  2. Heuristic fallback: lock/unlock cycles are very quick — the phone
      //     turns off, user picks it up and unlocks, total elapsed < 3s means
      //     it's almost certainly a screen-off/on rather than an app switch.
      //     (An app switch of < 3s goes through Home → other app → back, which
      //     requires at least 2-3 taps and is practically never < 1.5s anyway.)
      final isScreenOffCycle = _wasScreenOff || pauseDuration.inSeconds < 3;
      _wasScreenOff = false;

      // Only take action for genuine app returns (> 8s away, not a lock cycle
      // and not a quick permission dialog).
      //
      // WHY 8s? Permission dialogs, location settings, battery optimization
      // popups, and notification permission flows often take 3-10 seconds.
      // With the old 3s threshold, these were falsely detected as "genuine
      // returns" causing the homepage jump the user reported.
      final isGenuineReturn = !isScreenOffCycle && pauseDuration.inMilliseconds > 8000;

      if (isScreenOffCycle) {
        // Lock/unlock: restore the saved page silently — no route popping,
        // no home-jump, no visual disruption to the user.
        _restoreLastPage();
      } else if (isGenuineReturn) {
        final hasModalRoute = Navigator.of(context).canPop();

        if (hasModalRoute) {
          // User had a pushed screen open (Settings, Prayer, etc.).
          // Pop back to the base launcher — but do NOT also jump the
          // PageView to home. They expect to land on the page they
          // were browsing before they pushed the sub-screen.
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          // No modal routes — user was on a raw PageView page.
          // Jump to home (Samsung One UI / stock launcher behaviour).
          if (_pageController.hasClients) {
            final currentPage = _pageController.page?.round() ?? _homeIndex;
            if (currentPage != _homeIndex) {
              _pageController.jumpToPage(_homeIndex);
              _saveCurrentPage(_homeIndex);
            }
          }
        }

        // ── Return-from-app animation (Samsung One UI feel) ──
        // Brief fade+scale to simulate the external app "shrinking back"
        // into the home screen. Runs after route changes settle.
        _returnFromAppController.value = 0.0;
        _returnFromAppController.animateTo(
          1.0,
          duration: LauncherDuration.returnFromApp,
          curve: LauncherEasing.emphasizedDecelerate,
        );
      }
      // Else (not screen-off AND not genuine return): user was briefly
      // away (permission dialog, share sheet, etc). Do nothing — keep
      // the exact page and route state they had before.

      // Schedule non-critical visual updates for AFTER the first frame.
      // These don't affect interactivity, so they can wait.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Refresh year dots wallpaper ONLY if that wallpaper is active.
        // Avoids triggering a full shell rebuild (all 5 pages) on every resume.
        final currentWallpaper = ref.read(wallpaperProvider);
        if (currentWallpaper == WallpaperType.yearDots && mounted) {
          setState(() => _yearDotsKey++);
        }
      });

      // Skip the platform channel call entirely while a page animation is
      // running — the async round-trip would queue behind the animation and
      // add latency to gesture recognition on the very next frame.
      if (!_hasShownLauncherPrompt && !_pageAnimating) {
        Future.microtask(_checkDefaultLauncher);
      }

      // ── Check if native blocker has a "time's up" or "prompt timer" event pending ──
      Future.microtask(_checkNativeTimers);

      // ── Zen Mode safety net: auto-end if timer expired while away ──
      // The ZenModeNotifier has its own periodic check, but this catches
      // the edge case where the provider was not ticking (e.g. app restart).
      final zen = ref.read(zenModeProvider);
      if (zen.isActive && zen.hasExpired) {
        ref.read(zenModeProvider.notifier).endZenMode();
      }

      // ── In-App Update: re-check silently on resume ──
      if (isGenuineReturn) {
        Future.microtask(_checkForUpdate);
      }

      // NOTE: Subscription checks removed — all features are free (donation model)
    }
  }

  /// Poll native for pending timer events (either times_up or prompt_timer).
  Future<void> _checkNativeTimers() async {
    if (!mounted) return;

    final screenTimeState = ref.read(screenTimeProvider);
    if (!screenTimeState.featureEnabled) {
      // Clean up orphaned data
      final data = await NativeAppBlockerService.getPendingTimesUp();
      if (data != null) {
        final pkg = data['packageName'] as String? ?? '';
        if (pkg.isNotEmpty) NativeAppBlockerService.endTimedSession(pkg);
      }
      return;
    }

    // Check for "prompt_timer" first (app opened from recents without session)
    final promptData = await NativeAppBlockerService.getPendingPromptTimer();
    if (promptData != null && mounted) {
      final packageName = promptData['packageName'] as String? ?? '';
      if (packageName.isNotEmpty) {
        final installedApps = ref.read(installedAppsProvider);
        final matchingApp = installedApps.where((a) => a.packageName == packageName).toList();
        final appName = matchingApp.isNotEmpty ? matchingApp.first.appName : _friendlyName(packageName);
        final config = screenTimeState.appConfigs[packageName];

        if (config != null) {
          final minutes = await AppSessionPrompt.show(
            context,
            packageName: packageName,
            appName: appName,
            defaultMinutes: config.defaultMinutes,
          );
          if (!mounted) return;
          if (minutes != null && minutes > 0) {
            // Chose a limit → start a timed session, then open the app.
            ref
                .read(screenTimeProvider.notifier)
                .startSession(packageName, appName, minutes);
            _launchPkg(packageName);
          } else if (minutes == 0) {
            // "Open without a limit" → open it this once, no session.
            _launchPkg(packageName);
          }
          // minutes == null → dismissed; stay on Sukoon.
        }
      }
      return; // Do not check times_up if we handled prompt_timer
    }

    // Debounce "times up"
    if (_lastTimesUpShown != null &&
        DateTime.now().difference(_lastTimesUpShown!).inSeconds < 5) {
      return;
    }

    try {
      final data = await NativeAppBlockerService.getPendingTimesUp();
      if (data == null || !mounted) return;

      final packageName = data['packageName'] as String? ?? '';
      if (packageName.isEmpty) return;

      final extensionsUsed = data['extensionsUsed'] as int? ?? 0;
      final nativeMinutesSpent = data['minutesSpent'] as int? ?? 0;

      final session = ref.read(screenTimeProvider).activeSession;
      final minutesSpent = nativeMinutesSpent > 0
          ? nativeMinutesSpent
          : (session != null ? session.elapsedMinutes : 0);

      final todayDuration = ref.read(screenTimeProvider.notifier).getTodayUsage(packageName);
      final weekDuration = ref.read(screenTimeProvider.notifier).getWeekUsage(packageName);

      final installedApps = ref.read(installedAppsProvider);
      final matchingApp = installedApps.where((a) => a.packageName == packageName).toList();
      final appName = matchingApp.isNotEmpty
          ? matchingApp.first.appName
          : (session?.appName ?? _friendlyName(packageName));

      _lastTimesUpShown = DateTime.now();

      if (!mounted) return;

      TimesUpOverlay.showAsDialog(
        context,
        appName: appName,
        minutesSpent: minutesSpent.clamp(1, 99999),
        extensionsUsed: extensionsUsed,
        todayUsage: todayDuration,
        weekUsage: weekDuration,
        onExit: () {
          if (!mounted) return;
          // End the session cleanly and return to the launcher home.
          ref.read(screenTimeProvider.notifier).endSession();
          _goHome(popRoutes: true);
        },
        onExtend: (mins) {
          if (!mounted) return;
          // Native already ENDED the session before showing "time's up", so a
          // plain extend has nothing to extend. Start a FRESH session (reschedules
          // the exact alarm), then reopen the app — this is why extend works now.
          ref
              .read(screenTimeProvider.notifier)
              .startSession(packageName, appName, mins);
          _launchPkg(packageName);
        },
      );
    } catch (_) {}
  }

  /// Open an app by package via the native launch channel.
  void _launchPkg(String packageName) {
    try {
      const MethodChannel('com.sukoon.launcher/apps')
          .invokeMethod('launchApp', {'packageName': packageName});
    } catch (_) {}
  }

  /// Convert a raw package name like "com.whatsapp.android" into a
  /// human-readable fallback name ("whatsapp") when neither the installed-apps
  /// list nor the active session provides a label.
  String _friendlyName(String packageName) {
    final parts = packageName.split('.');
    // Drop common noise segments
    final meaningful = parts.where(
      (p) => p != 'com' && p != 'org' && p != 'net' && p != 'android' && p != 'app',
    );
    final label = meaningful.isNotEmpty ? meaningful.last : parts.last;
    // Capitalise first letter
    return label.isNotEmpty
        ? '${label[0].toUpperCase()}${label.substring(1)}'
        : label;
  }

  /// Single source of truth for "go home".
  ///
  /// [popRoutes] — when true, pops ALL pushed routes (Settings, Prayer screen,
  /// etc.) before jumping the PageView. This is the behaviour for:
  ///   • Home button press (via native → Flutter channel)
  ///   • Back press while not on home page
  ///
  /// When false (swipe-up gesture within the shell), only the PageView is
  /// animated — we don't pop routes because the user is already inside the
  /// shell and no sub-routes are open.
  void _goHome({bool popRoutes = false}) {
    if (!mounted) return;

    // Pop any pushed sub-routes (Settings, Prayer screen, etc.) first
    if (popRoutes && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }

    // Then animate the PageView to the home page
    _navigateToHome();
  }

  /// Navigate to the Home page (index 2) with instant gesture release.
  ///
  /// Strategy: use a very short animation (180ms) instead of 350ms so that
  /// the [DrivenScrollActivity] finishes quickly and the gesture arena is
  /// unblocked for horizontal swipes as fast as possible.
  /// The [_pageAnimating] flag prevents competing work (lifecycle setState,
  /// platform channel calls) from piling up while the animation runs.
  void _navigateToHome() {
    if (_pageAnimating) return;
    final currentPage = _pageController.page?.round() ?? _homeIndex;
    if (currentPage == _homeIndex) return;

    final distance = (currentPage - _homeIndex).abs();

    _pageAnimating = true;

    // Scale duration by distance so multi-page jumps feel proportional
    // but never too slow. 1 page = 250ms, 2 pages = 350ms.
    final duration = Duration(milliseconds: 200 + (distance * 75).clamp(0, 150));

    _pageController
        .animateToPage(
          _homeIndex,
          duration: duration,
          curve: Curves.easeOutCubic,
        )
        .whenComplete(_onPageAnimationDone);
  }

  void _onPageAnimationDone() {
    if (!mounted) return;
    _pageAnimating = false;
  }

  /// Snap-to-home: when the user swipes toward Home and lands on an
  /// intermediate page, automatically continue the animation to Home.
  ///
  /// This gives a Samsung One-UI / iOS Springboard feel: Home is always
  /// a single swipe away from ANY page.
  ///
  /// Logic:
  ///  • Pages LEFT of Home (0, 1, 2): if user is swiping rightward
  ///    (toward Home) and lands on a page that's still left of Home,
  ///    auto-continue to Home.
  ///  • Pages RIGHT of Home (4, 5): if user is swiping leftward
  ///    (toward Home) and lands on a page that's still right of Home,
  ///    auto-continue to Home.
  ///  • If user is swiping AWAY from Home (e.g. Home → Dashboard),
  ///    allow it — they intentionally want that page.
  void _snapToHomeIfIntermediate(int currentPage) {
    // Natural navigation: one swipe = one page.
    // No auto-skipping to home. Each page is a deliberate stop.
  }

  // ── Gesture-arena release: kill ballistic on new pointer down ──

  /// Called by the [Listener] wrapping the [PageView] on every
  /// [PointerDownEvent], BEFORE any gesture recognizer receives the event.
  ///
  /// If the PageView's scroll position is in the tail phase of a ballistic
  /// settle (very close to the target page but not yet idle), we force it
  /// to snap to the exact page. This converts the scroll activity to idle
  /// and frees the gesture arena so inner vertical scrollables can claim
  /// the pointer immediately.
  ///
  /// IMPORTANT: We only snap when drift is very small (< 8px). If the page
  /// is still far from the target, the ballistic is doing meaningful work
  /// and we must not interfere — otherwise horizontal swipes feel broken.
  void _killBallisticIfSettling(PointerDownEvent event) {
    if (!_pageController.hasClients) return;
    // Don't kill our own programmatic animations (e.g. _navigateToHome).
    if (_pageAnimating) return;

    final pos = _pageController.position;
    final viewportWidth = pos.viewportDimension;
    if (viewportWidth <= 0) return;

    final currentPage = (pos.pixels / viewportWidth).round();
    final targetPixels = currentPage * viewportWidth;
    final drift = (pos.pixels - targetPixels).abs();

    // Only kill ballistic tail — page is nearly settled but simulation
    // hasn't met tolerance yet. 8px is close enough that the user
    // cannot perceive the snap, but the ballistic tail can run 100-200ms
    // in this zone keeping the arena contested.
    if (drift > 0.5 && drift < 8.0) {
      pos.jumpTo(targetPixels);
    }
  }

  Future<void> _checkDefaultLauncher() async {
    if (_hasShownLauncherPrompt) return;
    try {
      final isDefault = await _launcherChannel.invokeMethod<bool>('isDefaultLauncher') ?? false;
      if (!isDefault && mounted) {
        _hasShownLauncherPrompt = true;
        _showDefaultLauncherDialog();
      }
    } catch (_) {
      // Silently ignore — platform may not support this check
    }
  }

  void _showDefaultLauncherDialog() {
    final accent = ref.read(themeColorProvider).color;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(Icons.home_rounded, color: accent, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Set as Default',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Sukoon Launcher works best as your default home app. Set it now for the full experience.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Later',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _launcherChannel.invokeMethod('openHomeLauncherSettings');
            },
            style: TextButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              'Set Now',
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Start/stop gradient animation based on wallpaper type
  void _syncAnimController(WallpaperType wallpaper) {
    final needsAnimation = wallpaper != WallpaperType.black &&
        wallpaper != WallpaperType.customImage &&
        wallpaper != WallpaperType.islamicNamazMat &&
        wallpaper != WallpaperType.islamicInshallah &&
        wallpaper != WallpaperType.islamicFlag &&
        wallpaper != WallpaperType.islamicQuranDark &&
        wallpaper != WallpaperType.yearDots;
    
    if (needsAnimation && !_animRunning) {
      _animController.repeat(reverse: true);
      _animRunning = true;
    } else if (!needsAnimation && _animRunning) {
      _animController.stop();
      _animRunning = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navChannel.setMethodCallHandler(null);
    _pageController.dispose();
    _animController.dispose();
    _returnFromAppController.dispose();
    AppUpdateService().dispose();
    super.dispose();
  }

  // ── In-App Update: sets provider state instead of showing popups ──
  // HomeClockScreen reads appUpdateStateProvider to show a subtle text label.
  Future<void> _checkForUpdate() async {
    if (!mounted) return;
    final hasUpdate = await AppUpdateService().checkForUpdate(silent: true);
    if (hasUpdate && mounted) {
      ref.read(appUpdateStateProvider.notifier).state =
          ref.read(appUpdateStateProvider).copyWith(updateAvailable: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DisplaySettings>(displaySettingsProvider, (prev, next) {
      if (prev?.showStatusBar != next.showStatusBar) {
        SystemChrome.setEnabledSystemUIMode(
          next.showStatusBar ? SystemUiMode.edgeToEdge : SystemUiMode.manual,
          overlays: next.showStatusBar ? SystemUiOverlay.values : [SystemUiOverlay.bottom],
        );
      }
    });

    final wallpaper = ref.watch(wallpaperProvider);
    
    // Use the selected wallpaper directly

    // Start/stop gradient animation based on wallpaper type (saves GPU when not needed)
    _syncAnimController(wallpaper);

    // ── Asymmetric touch slop for clean gesture-arena disambiguation ──
    //
    // `pageMq` raises the touch slop seen by the PageView's horizontal drag
    // recognizer so only a clearly-horizontal drag changes pages. Each page's
    // content is re-wrapped (via [_pageContent]) with the base `mq`, restoring
    // the smaller inner slop so vertical scrolling stays responsive. See
    // [_kPageSlopMultiplier] for the full rationale.
    final MediaQueryData mq = MediaQuery.of(context);
    final double innerSlop = mq.gestureSettings.touchSlop ?? _kInnerTouchSlop;
    final MediaQueryData pageMq = mq.copyWith(
      gestureSettings: DeviceGestureSettings(
        touchSlop: innerSlop * _kPageSlopMultiplier,
      ),
    );

    // Wraps a single PageView page: restores the base (inner) touch slop and
    // strips overscroll glow/stretch on its vertical scrollables.
    Widget pageContent(Widget child) => MediaQuery(
          data: mq,
          child: ScrollConfiguration(
            behavior: const _PageInnerScrollBehavior(),
            child: child,
          ),
        );

    // Back button: navigate to Home page. If already on Home, do nothing.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // If a sub-route is pushed (Settings, Prayer, etc.), pressing
          // back should just pop that screen — NOT also jump the PageView.
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            // No pushed routes — user is on a raw PageView page.
            // Task List — Standard preview (showing 3)
            // ...allTodos.take(3).map((todo) {
            // Navigate the PageView to home.
            final currentPage = _pageController.page?.round() ?? _homeIndex;
            if (currentPage != _homeIndex) {
              _navigateToHome();
            }
            // If already on home: launchers never exit — do nothing.
          }
        }
      },
      child: Scaffold(
        // Prevent the Scaffold from resizing when the keyboard opens.
        // Without this, opening the keyboard on the AppList page causes the
        // PageView viewport to shrink then re-expand, producing a visible
        // horizontal bounce / jump animation.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Background
            _buildBackground(wallpaper),

            // ── Ballistic-kill layer ──
            //
            // WHY THIS EXISTS:
            // After a horizontal fling, the PageView's ScrollPosition runs a
            // BallisticScrollActivity (SpringSimulation). While this activity
            // is alive — even in its very last frames when the page is already
            // visually snapped — the PageView's internal Scrollable keeps its
            // HorizontalDragGestureRecognizer registered in the gesture arena.
            // Any new pointer that arrives during this phase enters a
            // CONTESTED arena: horizontal vs vertical. The arena waits for
            // kTouchSlop (18px) of directional movement to pick a winner →
            // user perceives ~200-400ms of "shake" or blocked vertical scroll.
            //
            // SOLUTION:
            // A raw Listener sits ABOVE the PageView in the hit-test order.
            // On PointerDownEvent it checks if the PageView's ScrollPosition
            // is in a ballistic settle phase. If so, it force-jumps to the
            // current pixel offset — which internally calls goIdle() on the
            // ScrollPosition, converting BallisticScrollActivity → 
            // IdleScrollActivity. The gesture arena is now empty before any
            // gesture recognizer even sees the pointer.
            //
            // The Listener uses HitTestBehavior.translucent so the pointer
            // event continues down to the PageView and its children normally.
            // The PageView is wrapped in `pageMq` (raised touch slop) so its
            // horizontal recognizer only wins on a clearly-horizontal drag;
            // each page restores the base slop via `pageContent`.
            MediaQuery(
              data: pageMq,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _killBallisticIfSettling,
                child: PageView(
                  controller: _pageController,
                  physics: const _LauncherPagePhysics(),
                  clipBehavior: Clip.none,
                  allowImplicitScrolling: true,
                  pageSnapping: true,
                  onPageChanged: (index) {
                    _snapToHomeIfIntermediate(index);
                    _saveCurrentPage(index);
                  },
                  children: [
                    pageContent(
                      RepaintBoundary(
                        child: IslamicHubScreen(pageController: _pageController),
                      ),
                    ),
                    pageContent(
                      const RepaintBoundary(
                        child: WidgetDashboardScreen(),
                      ),
                    ),
                    pageContent(
                      const RepaintBoundary(
                        child: HomeClockScreen(),
                      ),
                    ),
                    pageContent(
                      const RepaintBoundary(
                        child: AppListScreen(),
                      ),
                    ),
                    pageContent(
                      const RepaintBoundary(
                        child: ProductivityHubScreen(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Swipe-up zone — go Home from non-home pages ────────────
            //
            // Only covers the bottom 56px of non-home pages. On the home
            // page this zone is DISABLED so the HomeClockScreen's own
            // configurable swipe-up gesture (App List, Quick Access, etc.)
            // can fire without being intercepted.
            AnimatedBuilder(
              animation: _pageController,
              builder: (_, __) {
                final page = _pageController.hasClients
                    ? (_pageController.page ?? _homeIndex.toDouble())
                    : _homeIndex.toDouble();
                final onHome = (page - _homeIndex).abs() < 0.5;
                if (onHome) return const SizedBox.shrink();
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 56,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragEnd: (d) {
                      final velocity = d.primaryVelocity ?? 0;
                      if (velocity < -SwipeTuning.commitVelocity) {
                        GestureHaptics.swipeCommit();
                        _goHome(popRoutes: true);
                      }
                    },
                  ),
                );
              },
            ),

            // ── 6-dot page indicator ───────────────────────────────────
            // Minimalist 6 dots at top-center. Hidden on home (index 3).
            // Fades in during navigation and auto-hides after 1.5s.
            if (ref.watch(pageIndicatorProvider))
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 20,
                child: _TransientPageIndicator(
                  pageController: _pageController,
                  homeIndex: _homeIndex,
                  accentColor: ref.watch(islamicThemeColorsProvider).accent,
                ),
              ),

          ],
        ),
      ),
    );
  }

  Widget _buildBackground(WallpaperType wallpaper) {
    // Year dots wallpaper — static, no gradient
    if (wallpaper == WallpaperType.yearDots) {
      final accent = ref.read(themeColorProvider).color;
      return Positioned.fill(
        child: YearDotsWallpaper(
          key: ValueKey('year_dots_$_yearDotsKey'),
          accentColor: accent,
        ),
      );
    }

    // Premium asset wallpapers
    final assetPath = wallpaperAssetPath(wallpaper);
    if (assetPath != null) {
      return Positioned.fill(
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    if (wallpaper == WallpaperType.customImage) {
      final imagePath = ref.read(wallpaperProvider.notifier).customImagePath;
      if (imagePath != null && File(imagePath).existsSync()) {
        return Positioned.fill(
          child: Image.file(
            File(imagePath),
            fit: BoxFit.cover,
          ),
        );
      }
    }

    return Positioned.fill(
      child: RepaintBoundary(
        // Isolate the animated gradient into its own compositing layer.
        //
        // Without this, AnimatedBuilder schedules a markNeedsPaint on the
        // Positioned.fill subtree on every animation tick (~60 fps). Because
        // this Positioned is a sibling of the PageView in the same Stack,
        // the Stack's RenderObject walks all children to determine whether a
        // relayout is needed — indirectly causing the PageView's pages to
        // receive a layout pass, which changes their measured constraints by
        // sub-pixel amounts and causes cards to visually resize/bounce.
        //
        // RepaintBoundary promotes this gradient to its own layer. The
        // compositor composites it directly with the GPU without touching
        // the layout tree of any sibling — zero layout cost.
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: _getWallpaperGradient(wallpaper),
              ),
            );
          },
        ),
      ),
    );
  }

  LinearGradient _getWallpaperGradient(WallpaperType wallpaper) {
    switch (wallpaper) {
      case WallpaperType.black:
        return const LinearGradient(colors: [Colors.black, Colors.black]);
      case WallpaperType.darkGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0a0a0a), const Color(0xFF1a1a1a), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF0f0f0f), const Color(0xFF1a1a1a), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.desertGradient:
        // 🌙 Desert gradient - warm sand tones
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1A150D), const Color(0xFF2A1F12), _animController.value)!,
            const Color(0xFF0A0805),
            Color.lerp(const Color(0xFF1F180E), const Color(0xFF2A1F12), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.blueGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0d1b2a), const Color(0xFF1b263b), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF0f1f2f), const Color(0xFF1b263b), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.purpleGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1a0a2e), const Color(0xFF16213e), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF0f0a1f), const Color(0xFF1a0a2e), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.redGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2d0a0a), const Color(0xFF1a0a0a), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF1f0a0a), const Color(0xFF2d0a0a), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.greenGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0a2d0a), const Color(0xFF0a1a0a), _animController.value)!,
            const Color(0xFF000000),
            Color.lerp(const Color(0xFF0a1f0a), const Color(0xFF0a2d0a), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.customImage:
        return const LinearGradient(colors: [Colors.black, Colors.black]);
      case WallpaperType.islamicNamazMat:
      case WallpaperType.islamicInshallah:
      case WallpaperType.islamicFlag:
      case WallpaperType.islamicQuranDark:
      case WallpaperType.yearDots:
        return const LinearGradient(colors: [Colors.black, Colors.black]);

      // ── Aesthetic light-toned gradients ──
      case WallpaperType.leafGreenGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0D1F0D), const Color(0xFF1A3A1A), _animController.value)!,
            const Color(0xFF071007),
            Color.lerp(const Color(0xFF142814), const Color(0xFF1F3D1F), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.beigeGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1F1A12), const Color(0xFF302818), _animController.value)!,
            const Color(0xFF0D0B07),
            Color.lerp(const Color(0xFF2A2218), const Color(0xFF352C1C), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.roseGoldGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2A1A1A), const Color(0xFF3A2222), _animController.value)!,
            const Color(0xFF0D0808),
            Color.lerp(const Color(0xFF2D1C18), const Color(0xFF3D2820), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.lavenderGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF1A142A), const Color(0xFF251C3A), _animController.value)!,
            const Color(0xFF0A0810),
            Color.lerp(const Color(0xFF1E1830), const Color(0xFF2A2040), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.oceanTealGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0A1F1F), const Color(0xFF0F2D2A), _animController.value)!,
            const Color(0xFF050E0E),
            Color.lerp(const Color(0xFF0D2525), const Color(0xFF123530), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.sunsetPeachGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2A1810), const Color(0xFF3A2215), _animController.value)!,
            const Color(0xFF0D0905),
            Color.lerp(const Color(0xFF2D1A12), const Color(0xFF3D2618), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.mintGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF0D2018), const Color(0xFF143025), _animController.value)!,
            const Color(0xFF060E0A),
            Color.lerp(const Color(0xFF10281E), const Color(0xFF18382A), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
      case WallpaperType.dustyRoseGradient:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF221418), const Color(0xFF301C22), _animController.value)!,
            const Color(0xFF0D080A),
            Color.lerp(const Color(0xFF28181E), const Color(0xFF352028), _animController.value)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        );
    }
  }
}

/// Islamic Hub — premium minimalist entry to Quran, Hadith, Dua
class IslamicHubScreen extends ConsumerStatefulWidget {
  final PageController pageController;
  const IslamicHubScreen({super.key, required this.pageController});

  @override
  ConsumerState<IslamicHubScreen> createState() => _IslamicHubScreenState();
}

class _IslamicHubScreenState extends ConsumerState<IslamicHubScreen> {

  String _prayerContextLabel() {
    final h = DateTime.now().hour;
    if (h >= 4  && h < 6)  return 'Fajr — the hour of the devoted';
    if (h >= 6  && h < 12) return 'Begin your day with His name';
    if (h >= 12 && h < 13) return 'Dhuhr — pause & pray';
    if (h >= 13 && h < 16) return 'Afternoon — stay connected';
    if (h >= 16 && h < 18) return 'Asr — the middle prayer';
    if (h >= 18 && h < 20) return 'Maghrib — sunset, gratitude';
    if (h >= 20 && h < 22) return 'Isha — close with prayer';
    return 'Night — the hour of sincere dua';
  }

  @override
  Widget build(BuildContext context) {
    // ── Theme-aware colors (accent follows the selected Islamic palette) ──
    // The hub sits over the launcher wallpaper — always dark backdrop.
    // We always pull from the DARK variant of the selected palette so the
    // accent color correctly reflects the theme (e.g. Catppuccin → purple,
    // Tokyo Night → blue) regardless of the light/dark reading mode.
    final master = ref.watch(masterThemeProvider);
    final mode   = ref.watch(islamicThemeProvider);
    final darkColors = master.colorsFor(IslamicThemeMode.dark);
    final accent = darkColors.accent;
    final hubGreen = darkColors.green; // palette's primary hue

    // Light mode adds a slightly warmer, lighter overlay on the wallpaper;
    // dark mode keeps the deep translucent scrim.
    final overlayAlpha = mode == IslamicThemeMode.light ? 0.28 : 0.18;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        color: Colors.black.withValues(alpha: overlayAlpha),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                  // ── Header ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _prayerContextLabel(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: -0.5,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Arabic ligature — decorative, matches palette accent
                        Text(
                          'بِسْمِ اللَّهِ',
                          style: TextStyle(
                            color: hubGreen.withValues(alpha: 0.45),
                            fontSize: 15,
                            fontFamily: 'Amiri',
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _showThemePicker(context, ref, accent, hubGreen, master, mode),
                          behavior: HitTestBehavior.opaque,
                          child: Icon(
                            Icons.palette_rounded,
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // ── Today's Wisdom ──────────────────────────────────────
                const _WisdomWidget(),

                const SizedBox(height: 18),

                // ── Section label ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Text(
                        'LIBRARY',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 0.5,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Quran hero card ─────────────────────────────────────
                _QuranHeroCard(
                  accentColor: hubGreen,
                  onTap: () => Navigator.push(
                    context,
                    _SmoothForwardRoute(
                        child: const _IslamicSubScreen(
                            title: 'Quran', child: SurahListScreen()))),
                ),
                const SizedBox(height: 8),

                // ── Dua · Hadith · Seerah ───────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _SmallHubCard(
                        icon: Icons.spa_rounded,
                        label: 'Dua',
                        sublabel: 'Adhkar',
                        accentColor: hubGreen,
                        onTap: () => Navigator.push(
                            context,
                            _SmoothForwardRoute(
                                child: const _IslamicSubScreen(
                                    title: 'Dua & Adhkar',
                                    child: MinimalistDuaScreen()))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallHubCard(
                        icon: Icons.brightness_4_rounded,
                        label: 'Hadith',
                        sublabel: 'Collections',
                        accentColor: hubGreen,
                        onTap: () {
                          ref.read(hadithNavDepthProvider.notifier).state = 0;
                          Navigator.push(
                              context,
                              _SmoothForwardRoute(
                                  child: _IslamicSubScreen(
                                      title: 'Hadith',
                                      child: MinimalistHadithScreen())));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SmallHubCard(
                        icon: Icons.auto_stories_rounded,
                        label: 'Seerah',
                        sublabel: 'Sealed Nectar',
                        accentColor: hubGreen,
                        onTap: () => Navigator.push(
                            context,
                            _SmoothForwardRoute(
                                child: DeferredFade(
                                    background:
                                        ref.read(islamicThemeColorsProvider).background,
                                    child: const BookHomeScreen()))),
                      ),
                    ),
                  ],
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, Color accent, Color hubGreen, MasterTheme currentMaster, IslamicThemeMode currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Library Theme',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Customize colors and reading mode for the Islamic Library',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              Consumer(builder: (context, ref, _) {
                final master = ref.watch(masterThemeProvider);
                final mode = ref.watch(islamicThemeProvider);
                final darkColors = master.colorsFor(IslamicThemeMode.dark);
                final accent = darkColors.accent;
                return _ThemePickerRow(
                  accent: accent,
                  hubGreen: darkColors.green,
                  currentMaster: master,
                  currentMode: mode,
                  onSelectMaster: (t) => ref.read(masterThemeProvider.notifier).select(t),
                  onToggleMode: () => ref.read(islamicThemeProvider.notifier).toggle(),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}



// ── Inline Theme Picker Row ───────────────────────────────────────────────────
// Shows palette dots (one per MasterTheme) + a light/dark segmented toggle
// inline in the Islamic Hub — no need to dig into settings.

class _ThemePickerRow extends StatelessWidget {
  final Color accent;
  final Color hubGreen;
  final MasterTheme currentMaster;
  final IslamicThemeMode currentMode;
  final ValueChanged<MasterTheme> onSelectMaster;
  final VoidCallback onToggleMode;

  const _ThemePickerRow({
    required this.accent,
    required this.hubGreen,
    required this.currentMaster,
    required this.currentMode,
    required this.onSelectMaster,
    required this.onToggleMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Row(
        children: [
          // ── Palette dots ──────────────────────────────────────
          Expanded(
            child: Row(
              children: MasterTheme.values.map((theme) {
                final def = kMasterThemes[theme]!;
                final isSelected = theme == currentMaster;
                return GestureDetector(
                  onTap: () => onSelectMaster(theme),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 28 : 20,
                      height: isSelected ? 28 : 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [def.dots[0], def.dots[1]],
                        ),
                        border: isSelected
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.60),
                                width: 2,
                              )
                            : Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                                width: 1,
                              ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: def.dots[0].withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Light / Dark toggle pill ───────────────────────────
          GestureDetector(
            onTap: onToggleMode,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: accent.withValues(alpha: 0.10),
                border: Border.all(
                  color: accent.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentMode == IslamicThemeMode.light
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    size: 14,
                    color: accent.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    currentMode == IslamicThemeMode.light ? 'Light' : 'Dark',
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wisdom Widget ────────────────────────────────────────────────────

class _WisdomWidget extends ConsumerStatefulWidget {
  const _WisdomWidget();

  @override
  ConsumerState<_WisdomWidget> createState() => _WisdomWidgetState();
}

class _WisdomWidgetState extends ConsumerState<_WisdomWidget> {
  WisdomEntry? _entry;

  @override
  void initState() {
    super.initState();
    WisdomService.todaysWisdom().then((e) {
      if (mounted) setState(() => _entry = e);
    });
  }

  void _showDetail(BuildContext ctx, WisdomEntry e, IslamicThemeColors tc, IslamicThemeMode mode) {
    final accent = tc.accent;
    final isLight = mode == IslamicThemeMode.light;
    
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: tc.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
                  children: [
                    // Pills row
                    Row(
                      children: [
                        _pill(e.category, accent),
                        const SizedBox(width: 6),
                        _pill(e.sourceType, Colors.white.withValues(alpha: 0.3)),
                        const Spacer(),
                        if (e.hadithReference != null)
                          Text(e.hadithReference!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.20),
                                fontSize: 9, letterSpacing: 0.1,
                              )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quote
                    Text(
                      '\u201c${e.wisdom}\u201d',
                      style: TextStyle(
                        color: tc.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\u2014 ${e.attributedTo}',
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                    Text(
                      e.knownAs,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _detailSection('Related Ayah', e.detail.relatedAyah, tc),
                    _detailSection('Lesson', e.detail.lesson, tc),
                    _detailSection('Context', e.detail.context, tc),
                    _detailSection('Deed & Reward', e.detail.deedOrReward, tc),
                    _detailSection('About', e.detail.biography, tc),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Allah knows best',
                        style: TextStyle(
                          color: tc.textTertiary,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
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

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Text(label, style: TextStyle(
          color: color.withValues(alpha: 0.80),
          fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.4,
        )),
      );

  Widget _detailSection(String title, String body, IslamicThemeColors tc) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(
            color: tc.accent,
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2,
          )),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(
            color: tc.textSecondary,
            fontSize: 14.5,
            height: 1.6,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(islamicThemeColorsProvider);
    final mode = ref.watch(islamicThemeProvider);
    final accent = tc.accent;
    final isLight = mode == IslamicThemeMode.light;
    final e = _entry;

    // Skeleton shown while loading
    if (e == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.03),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "TODAY'S WISDOM",
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                Icon(Icons.more_horiz_rounded, size: 16, color: Colors.white.withValues(alpha: 0.1)),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 8, width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(height: 8, width: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 10),
            Container(height: 6, width: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(3))),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showDetail(context, e, tc, mode),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: accent.withValues(alpha: 0.03),
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 12, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      "TODAY'S WISDOM",
                      style: TextStyle(
                        color: accent.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.more_horiz_rounded, size: 16, color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
            const SizedBox(height: 12),
            // Wisdom text — prominent
            Text(
              e.wisdom,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.55,
                letterSpacing: -0.15,
              ),
            ),
            const SizedBox(height: 10),
            // Attribution — small, muted
            Text(
              '\u2014 ${e.attributedTo}',
              style: TextStyle(
                color: accent.withValues(alpha: 0.50),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quran Hero Card ──────────────────────────────────────────────────────────

class _QuranHeroCard extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onTap;
  const _QuranHeroCard({required this.accentColor, required this.onTap});

  @override
  State<_QuranHeroCard> createState() => _QuranHeroCardState();
}

class _QuranHeroCardState extends State<_QuranHeroCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: accent.withValues(alpha: 0.08),
            border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ]
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.menu_book_rounded, size: 24,
                    color: accent.withValues(alpha: 0.95)),
              ),
              const SizedBox(width: 18),
              // Text block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quran',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Read · Listen · Reflect · Tafseer',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              // Arabic بِسْمِ اللَّهِ
              Text(
                'بِسْمِ اللَّهِ',
                style: TextStyle(
                  color: accent.withValues(alpha: 0.22),
                  fontSize: 13,
                  fontFamily: 'Amiri',
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small Hub Card (Dua / Hadith) ─────────────────────────────────────────────

class _SmallHubCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color accentColor;
  final VoidCallback onTap;
  const _SmallHubCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_SmallHubCard> createState() => _SmallHubCardState();
}

class _SmallHubCardState extends State<_SmallHubCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedOpacity(
        opacity: _pressed ? 0.65 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(widget.icon, size: 18,
                    color: accent.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 14),
              Text(widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2)),
              const SizedBox(height: 3),
              Text(widget.sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                      letterSpacing: 0.1)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper screen for Islamic sub-screens (Quran, Hadith, Dua)
/// Provides proper background, SafeArea, and back navigation
/// Samsung One UI-style forward navigation transition.
///
/// Combines a horizontal slide (20% offset → center) with fade + subtle scale
/// for a smooth, premium feel. The incoming screen slides in from the right
/// while fading up, and the outgoing screen stays mostly still — matching
/// Samsung's "shared axis" forward/backward pattern.
/// Apple-style page route — full-width iOS slide with interactive swipe-back.
class _SmoothForwardRoute<T> extends CupertinoPageRoute<T> {
  _SmoothForwardRoute({required Widget child})
      : super(builder: (_) => child);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// Respects Islamic theme mode (light cream / pure dark)
class _IslamicSubScreen extends ConsumerWidget {
  final String title;
  final Widget child;
  const _IslamicSubScreen({required this.title, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(islamicThemeColorsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.background,
        statusBarIconBrightness: colors.statusBarBrightness,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness: colors.statusBarBrightness,
      ),
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Minimal back header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        // For Hadith screen: step back through depths first
                        if (title == 'Hadith') {
                          final depth = ref.read(hadithNavDepthProvider);
                          if (depth == 2) {
                            ref.read(hadithNavDepthProvider.notifier).state = 1;
                            return;
                          } else if (depth == 1) {
                            ref.read(hadithNavDepthProvider.notifier).state = 0;
                            return;
                          }
                        }
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: colors.textSecondary.withValues(alpha: 0.6),
                        size: 22,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.text.withValues(alpha: 0.85),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    // Theme toggle in sub-screen too
                    GestureDetector(
                      onTap: () {
                        ref.read(islamicThemeProvider.notifier).toggle();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          ref.watch(islamicThemeProvider).icon,
                          color: colors.accent.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Child screen
              Expanded(child: DeferredFade(background: colors.background, child: child)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Transient Page Indicator ──────────────────────────────────────────

class _TransientPageIndicator extends StatefulWidget {
  final PageController pageController;
  final int homeIndex;
  final Color accentColor;

  const _TransientPageIndicator({
    required this.pageController,
    required this.homeIndex,
    required this.accentColor,
  });

  @override
  State<_TransientPageIndicator> createState() => _TransientPageIndicatorState();
}

class _TransientPageIndicatorState extends State<_TransientPageIndicator> {
  Timer? _hideTimer;
  bool _isVisible = false;
  double _lastPage = 0;

  @override
  void initState() {
    super.initState();
    _lastPage = widget.homeIndex.toDouble();
    widget.pageController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onScroll);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.pageController.hasClients) return;
    
    final page = widget.pageController.page ?? widget.homeIndex.toDouble();
    
    // Only show if actually moving (more than a tiny jitter) and not strictly on the home page
    final distFromHome = (page - widget.homeIndex).abs();
    if ((page - _lastPage).abs() > 0.005 && distFromHome > 0.05) {
      if (!_isVisible) {
        setState(() => _isVisible = true);
      }
      
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _isVisible = false);
      });
    }
    _lastPage = page;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 400),
        child: AnimatedBuilder(
          animation: widget.pageController,
          builder: (_, __) {
            final page = widget.pageController.hasClients
                ? (widget.pageController.page ?? widget.homeIndex.toDouble())
                : widget.homeIndex.toDouble();
                
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final dist = (page - i).abs();
                final isActive = dist < 0.5;
                final dotOpacity = isActive
                    ? 1.0
                    : (1.0 - dist.clamp(0.0, 1.0)) * 0.25 + 0.12;
                    
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 6 : 5,
                  height: isActive ? 6 : 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? widget.accentColor
                        : Colors.white.withValues(alpha: dotOpacity * 0.8),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

