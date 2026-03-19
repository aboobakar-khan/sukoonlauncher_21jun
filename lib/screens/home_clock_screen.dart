import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:installed_apps/installed_apps.dart';
import 'app_list_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/clock_style_provider.dart';
import '../providers/time_format_provider.dart';
import '../providers/clock_opacity_provider.dart';
import '../providers/favorite_apps_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/quick_action_provider.dart';
import '../providers/productivity_provider.dart';
import '../providers/swipe_gesture_provider.dart';
import '../providers/launcher_page_provider.dart';
import '../providers/double_tap_provider.dart';
import '../providers/display_settings_provider.dart';
import '../services/app_settings_service.dart';
import '../widgets/blocked_app_screen.dart';
import '../widgets/clock_variants.dart';
import '../widgets/quick_search_overlay.dart';
import '../widgets/prayer_time_widget.dart';
import '../widgets/app_session_timer_sheet.dart';
import '../providers/screen_time_provider.dart';
import '../utils/usage_permission_helper.dart';
import 'clock_style_picker_screen.dart';
import 'favorite_picker_screen.dart';

/// Apple-style page route — full-width iOS slide with interactive swipe-back.
class _SmoothForwardRoute<T> extends CupertinoPageRoute<T> {
  _SmoothForwardRoute({required Widget child})
      : super(builder: (_) => child);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// Home Clock Screen - Minimalist clock and date display
class HomeClockScreen extends ConsumerStatefulWidget {
  const HomeClockScreen({super.key});

  @override
  ConsumerState<HomeClockScreen> createState() => _HomeClockScreenState();
}

class _HomeClockScreenState extends ConsumerState<HomeClockScreen>
    with AutomaticKeepAliveClientMixin {
  // No cache needed - favorites stored permanently in Hive with app names
  
  @override
  bool get wantKeepAlive => true; // Keep state alive during PageView scrolling
  
  // Vertical gesture tracking
  double _verticalDragStart = 0;
  double _horizontalDragStart = 0;
  bool _dragDirectionLocked = false; // true = vertical, false = horizontal/undecided
  static const double _swipeThreshold = 100;
  // Minimum ratio of vertical:horizontal movement to claim gesture as vertical.
  static const double _directionLockRatio = 1.5;

  // ── Open system clock/alarm app ──
  Future<void> _openSystemClock() async {
    try {
      // Try common clock/alarm package names
      const clockPackages = [
        'com.sec.android.app.clockpackage',     // Samsung
        'com.google.android.deskclock',          // Google/Pixel
        'com.android.deskclock',                 // AOSP
        'com.oneplus.deskclock',                 // OnePlus
        'com.coloros.alarmclock',                // Oppo/Realme
        'com.miui.deskclock',                    // Xiaomi
        'com.huawei.deskclock',                  // Huawei
      ];
      for (final pkg in clockPackages) {
        try {
          await InstalledApps.startApp(pkg);
          return;
        } catch (_) {}
      }
      // Fallback — open via Android alarm intent
      const platform = MethodChannel('app_settings');
      await platform.invokeMethod('openClock');
    } catch (_) {
      // Silently fail but inform user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clock app not found. Long-press to change style.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ── Execute a configurable swipe action ──
  void _executeSwipeAction(SwipeAction action, {String? appPackage}) {
    switch (action) {
      case SwipeAction.notifications:
        AppSettingsService.expandNotifications();
        break;
      case SwipeAction.quickAccess:
        showQuickSearchOverlay(context);
        break;
      case SwipeAction.appList:
        // Open app list as a full-screen bottom-to-top slide overlay
        if (mounted) {
          Navigator.of(context).push(_SlideUpRoute(
            child: const AppListScreen(isOverlay: true),
          ));
        }
        break;
      case SwipeAction.openApp:
        if (appPackage != null && appPackage.isNotEmpty) {
          HapticFeedback.mediumImpact();
          _launchApp(appPackage);
        }
        break;
      case SwipeAction.none:
        break;
    }
  }

  // ── Execute double-tap action ──
  static const _blockerChannel = MethodChannel('com.sukoon.launcher/app_blocker');

  void _executeDoubleTap(DoubleTapState dtState) {
    switch (dtState.action) {
      case DoubleTapAction.lockScreen:
        HapticFeedback.heavyImpact();
        _tryLockScreen();
        break;
      case DoubleTapAction.flashlight:
        _blockerChannel.invokeMethod('toggleFlashlight');
        break;
      case DoubleTapAction.openCamera:
        // Respect the user's saved camera app (if any), otherwise native intent
        final savedCamera = ref.read(quickActionProvider).cameraApp;
        if (savedCamera != null) {
          _launchApp(savedCamera);
        } else {
          _blockerChannel.invokeMethod('openCamera');
        }
        break;
      case DoubleTapAction.expandNotifications:
        AppSettingsService.expandNotifications();
        break;
      case DoubleTapAction.quickAccess:
        showQuickSearchOverlay(context);
        break;
      case DoubleTapAction.openApp:
        if (dtState.appPackage != null && dtState.appPackage!.isNotEmpty) {
          _launchApp(dtState.appPackage!);
        }
        break;
      case DoubleTapAction.none:
        break;
    }
  }

  /// Attempts to lock the screen via Device Admin.
  /// If Device Admin is not granted, shows a one-time prompt with a button
  /// to open the system Device Admin activation screen.
  Future<void> _tryLockScreen() async {
    try {
      final result = await _blockerChannel.invokeMethod('lockScreen');
      if (result == 'needs_admin' && mounted) {
        _showDeviceAdminPrompt();
      }
    } catch (_) {
      if (mounted) _showDeviceAdminPrompt();
    }
  }

  void _showDeviceAdminPrompt() {
    final accent = ref.read(themeColorProvider).color;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: accent, size: 22),
            const SizedBox(width: 10),
            Text('Enable Lock Screen',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16)),
          ],
        ),
        content: Text(
          'To lock the screen with a double-tap, Sukoon needs Device Admin permission.\n\nTap "Enable" and select Sukoon in the list.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.35))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _blockerChannel.invokeMethod('requestDeviceAdmin');
            },
            child: Text('Enable', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchApp(String packageName) async {
    // Check app blocker
    final blocker = ref.read(appBlockRuleProvider.notifier);
    if (blocker.isAppBlocked(packageName)) {
      if (mounted) {
        _showBlockedAppScreen(packageName);
      }
      return;
    }

    // ── App Time Intent: ask "how long?" before launch ──
    final screenTime = ref.read(screenTimeProvider);
    int? timerMinutes; // will be set if user chose a time
    String? timerAppName;
    if (screenTime.featureEnabled && screenTime.hasTimerFor(packageName)) {
      // Ensure Usage Access is granted — required for precision timing
      if (!mounted) return;
      final hasPermission = await UsagePermissionHelper.ensureGranted(context);
      if (!hasPermission) return; // User denied — don't launch with timer

      final allApps = ref.read(installedAppsProvider);
      timerAppName = allApps
          .where((a) => a.packageName == packageName)
          .map((a) => a.appName)
          .firstOrNull ?? packageName.split('.').last;
      final config = screenTime.appConfigs[packageName];
      final defaultMins = config?.defaultMinutes ?? 15;

      if (!mounted) return;
      // Show prompt — user picks a time or dismisses to go back
      final chosenMinutes = await AppSessionPrompt.show(
        context,
        packageName: packageName,
        appName: timerAppName,
        defaultMinutes: defaultMins,
      );
      // User dismissed (back/swipe) → go back to home, DON'T launch the app
      if (chosenMinutes == null || chosenMinutes <= 0) return;

      timerMinutes = chosenMinutes;
    }

    // Launch the app FIRST — user sees it open directly.
    // Starting the timer session AFTER ensures no blank screen race condition.
    try {
      // Special handling for Google Pay - use native intent
      if (packageName.contains('paisa') || packageName.contains('pay')) {
        await AppSettingsService.launchGooglePay();
      } else {
        await InstalledApps.startApp(packageName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cannot open app: $e')));
      }
      return;
    }

    // Now that the app is visible, start the timed session on native side
    if (timerMinutes != null) {
      ref.read(screenTimeProvider.notifier).startSession(
        packageName, timerAppName ?? packageName, timerMinutes,
      );
    }

    // Jump to home AFTER the app is covering the screen — invisible to user.
    Future.delayed(const Duration(milliseconds: 300), () {
      final pageCtrl = ref.read(launcherPageControllerProvider);
      if (pageCtrl != null && pageCtrl.hasClients) {
        final current = pageCtrl.page?.round() ?? 2;
        if (current != 2) pageCtrl.jumpToPage(2);
      }
    });
  }

  void _showBlockedAppScreen(String packageName) {
    final allApps = ref.read(installedAppsProvider);
    final appName = allApps
        .where((a) => a.packageName == packageName)
        .map((a) => a.appName)
        .firstOrNull ?? packageName.split('.').last;
    
    BlockedAppScreen.showAsDialog(context, appName);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final themeColor = ref.watch(themeColorProvider);
    final clockStyle = ref.watch(clockStyleProvider);
    final timeFormat = ref.watch(timeFormatProvider);
    final clockOpacity = ref.watch(clockOpacityProvider);
    final favorites = ref.watch(favoriteAppsProvider);
    final swipeConfig = ref.watch(swipeGestureProvider);
    final doubleTapConfig = ref.watch(doubleTapProvider);
    final displaySettings = ref.watch(displaySettingsProvider);

    return GestureDetector(
      // Swipe gestures only — NO onDoubleTap here!
      // Double-tap is handled in the upper content area only,
      // so it doesn't add ~300ms arena delay to favorite app taps.
      //
      // Pan-based vertical swipe with direction lock.
      // Using onPan* instead of onVerticalDrag* is critical: a
      // VerticalDragGestureRecognizer competes directly with the PageView's
      // HorizontalDragGestureRecognizer in the gesture arena. Both try to
      // claim the pointer simultaneously, and the arena waits for one to
      // win before dispatching — adding ~1 frame of latency to horizontal
      // swipes on the home page.
      //
      // A PanGestureRecognizer defers to other recognizers by default and
      // only claims the gesture when enough directional movement is confirmed
      // by our own direction-lock logic. This lets the PageView's horizontal
      // recognizer win instantly without arena contention.
      onPanStart: (details) {
        _verticalDragStart = details.globalPosition.dy;
        _horizontalDragStart = details.globalPosition.dx;
        _dragDirectionLocked = false;
      },
      onPanUpdate: (details) {
        if (_dragDirectionLocked) return;
        final dy = (details.globalPosition.dy - _verticalDragStart).abs();
        final dx = (details.globalPosition.dx - _horizontalDragStart).abs();
        // Only lock vertical once we have at least 8px of movement AND the
        // vertical component clearly dominates — otherwise let it go.
        if (dy + dx > 8) {
          _dragDirectionLocked = dy > dx * _directionLockRatio;
        }
      },
      onPanEnd: (details) {
        if (!_dragDirectionLocked) return; // horizontal drag — ignore
        final delta = details.globalPosition.dy - _verticalDragStart;
        final velocity = details.velocity.pixelsPerSecond.dy;

        // Swipe UP (negative delta, high velocity)
        if (delta < -_swipeThreshold || velocity < -500) {
          _executeSwipeAction(swipeConfig.swipeUp, appPackage: swipeConfig.swipeUpApp);
        }
        // Swipe DOWN (positive delta, high velocity)
        else if (delta > _swipeThreshold || velocity > 500) {
          _executeSwipeAction(swipeConfig.swipeDown, appPackage: swipeConfig.swipeDownApp);
        }
        _dragDirectionLocked = false;
      },
      // translucent: lets horizontal pointer events fall through to PageView
      // without being consumed by this GestureDetector first.
      behavior: HitTestBehavior.translucent,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height -
              MediaQuery.paddingOf(context).top -
              MediaQuery.paddingOf(context).bottom,
          child: Stack(
            children: [
              // Main scrollable content — prevents bottom overflow when
              // Prayer + Dua widgets both show on smaller screens.
              // Stops before the favorites zone so they don't overlap.
              // SafeArea already consumed bottom padding — no double-add.
              Positioned.fill(
                bottom: 220,
                child: GestureDetector(
                  // Double-tap ONLY on upper area (clock, prayer widgets)
                  // This keeps favorite apps instant with zero arena delay
                  onDoubleTap: doubleTapConfig.action != DoubleTapAction.none
                      ? () => _executeDoubleTap(doubleTapConfig)
                      : null,
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                        const SizedBox(height: 30),

                        // Clock widget — tap to open system clock, long-press for style picker
                        // Uses isolated _ClockTicker widget — only the clock rebuilds every second
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              _openSystemClock();
                            },
                            onLongPress: () {
                              HapticFeedback.mediumImpact();
                              Navigator.push(
                                context,
                                _SmoothForwardRoute(
                                  child: const ClockStylePickerScreen(),
                                ),
                              );
                            },
                            child: _ClockTicker(
                              clockStyle: clockStyle,
                              themeColor: themeColor,
                              timeFormat: timeFormat,
                              opacityMultiplier: clockOpacity.value,
                            ),
                          ),
                        ),

                        // 🕌 Prayer + Fasting unified widget
                        if (displaySettings.showPrayerWidget || displaySettings.showFastingWidget)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: PrayerTimeWidget(),
                          ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

                  // Favorite apps at the bottom
                  // SafeArea already consumed bottom padding — no double-add
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 59,
                    child: favorites.isNotEmpty
                        ? _buildFavoriteApps(themeColor)
                        : InkWell(
                            onTap: () {
                              _showAddFavoritesDialog(themeColor);
                            },
                            borderRadius: BorderRadius.circular(12),
                            splashColor: themeColor.color.withValues(alpha: 0.1),
                            highlightColor: themeColor.color.withValues(alpha: 0.1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              child: _buildEmptyFavoritesHint(themeColor),
                            ),
                          ),
                  ),

                  // Quick action buttons at the corners bottom
                  // SafeArea already removed bottom padding — use fixed 16px offset only
                  // Phone button - left corner
                  Positioned(
                    left: 20,
                    bottom: 16,
                    child: InkWell(
                      onTap: () => _handleQuickAction(
                        'phone',
                        ref.read(quickActionProvider).phoneApp,
                        themeColor,
                      ),
                      onLongPress: () =>
                          _showAppSelectionDialog('phone', themeColor),
                      borderRadius: BorderRadius.circular(24),
                      splashColor: themeColor.color.withValues(alpha: 0.15),
                      highlightColor: themeColor.color.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(
                          Icons.call,
                          size: 28,
                          color: themeColor.color.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),

                  // Camera button - right corner
                  Positioned(
                    right: 20,
                    bottom: 16,
                    child: InkWell(
                      onTap: () => _handleQuickAction(
                        'camera',
                        ref.read(quickActionProvider).cameraApp,
                        themeColor,
                      ),
                      onLongPress: () =>
                          _showAppSelectionDialog('camera', themeColor),
                      borderRadius: BorderRadius.circular(24),
                      splashColor: themeColor.color.withValues(alpha: 0.15),
                      highlightColor: themeColor.color.withValues(alpha: 0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Icon(
                          Icons.camera_alt,
                          size: 28,
                          color: themeColor.color.withValues(alpha: 0.7),
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

  Widget _buildFavoriteApps(AppThemeColor themeColor) {
    // Get favorites directly from provider - instant, no cache, no API calls
    final favorites = ref.watch(favoriteAppsProvider);
    final apps = favorites.take(10).toList();

    if (apps.isEmpty) return const SizedBox.shrink();

    // ── More than 5 apps: two-column layout (always, prayer widget or not) ──
    if (apps.length > 5) {
      final leftApps = apps.sublist(0, 5);
      final rightApps = apps.sublist(5);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: first 5 apps
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: leftApps
                  .map((app) => _buildFavItem(app, themeColor))
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          // Right: remaining apps (up to 5 more)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: rightApps
                  .map((app) => _buildFavItem(app, themeColor))
                  .toList(),
            ),
          ),
        ],
      );
    }

    // ── 1–5 apps: single column ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: apps.map((app) => _buildFavItem(app, themeColor)).toList(),
    );
  }

  /// Single tappable favorite app row — shared by both column layouts.
  Widget _buildFavItem(dynamic favoriteApp, AppThemeColor themeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _launchApp(favoriteApp.packageName);
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            Navigator.push(
              context,
              _SmoothForwardRoute(child: const FavoritePickerScreen()),
            );
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: themeColor.color.withValues(alpha: 0.1),
          highlightColor: themeColor.color.withValues(alpha: 0.1),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
              child: Text(
                favoriteApp.appName,
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w300,
                  color: themeColor.color.withValues(alpha: 1.0),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesHint(AppThemeColor themeColor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: themeColor.color.withValues(alpha: 0.3),
          width: 1,
          style: BorderStyle.values[1], // solid border
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_rounded,
            size: 20,
            color: themeColor.color.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            'Add your favorite apps',
            style: TextStyle(
              fontSize: 15,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w400,
              color: themeColor.color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFavoritesDialog(AppThemeColor themeColor) {
    Navigator.push(
      context,
      _SmoothForwardRoute(child: const FavoritePickerScreen()),
    );
  }

  Future<void> _handleQuickAction(
    String actionType,
    String? selectedApp,
    AppThemeColor themeColor,
  ) async {
    if (selectedApp != null) {
      // Launch the saved app directly
      _launchApp(selectedApp);
      return;
    }

    // No app saved yet — for camera, use native intent for instant first launch,
    // then auto-detect & persist so the next tap uses the fast _launchApp path.
    if (actionType == 'camera') {
      try {
        await _blockerChannel.invokeMethod('openCamera');
        // Actually trigger auto-detect so next tap will have a saved app
        ref.read(quickActionProvider.notifier).autoDetectCamera();
      } catch (_) {
        // Fallback: show selection dialog
        _showAppSelectionDialog(actionType, themeColor);
      }
    } else {
      // For phone or other — show the selection dialog
      _showAppSelectionDialog(actionType, themeColor);
    }
  }

  Future<void> _showAppSelectionDialog(
    String actionType,
    AppThemeColor themeColor,
  ) async {
    final installedApps = ref.read(installedAppsProvider);

    if (installedApps.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No apps available'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Select ${actionType == 'phone' ? 'Phone' : 'Camera'} App',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: installedApps.length,
            itemBuilder: (context, index) {
              final app = installedApps[index];
              return ListTile(
                title: Text(
                  app.appName,
                  style: TextStyle(
                    color: themeColor.color.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),

                onTap: () async {
                  // Save the selection
                  if (actionType == 'phone') {
                    await ref
                        .read(quickActionProvider.notifier)
                        .setPhoneApp(app.packageName);
                  } else {
                    await ref
                        .read(quickActionProvider.notifier)
                        .setCameraApp(app.packageName);
                  }

                  if (!context.mounted) return;

                  Navigator.pop(context);

                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${app.appName} set for ${actionType == 'phone' ? 'Phone' : 'Camera'}',
                      ),
                      backgroundColor: Colors.green.shade700,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// Blocked app screen now uses shared BlockedAppScreen widget

/// Isolated clock widget — only this small subtree rebuilds every second
/// instead of the entire HomeClockScreen (saves ~200 widget rebuilds/second)
class _ClockTicker extends StatefulWidget {
  final ClockStyle clockStyle;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final double opacityMultiplier;

  const _ClockTicker({
    required this.clockStyle,
    required this.themeColor,
    required this.timeFormat,
    required this.opacityMultiplier,
  });

  @override
  State<_ClockTicker> createState() => _ClockTickerState();
}

class _ClockTickerState extends State<_ClockTicker> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.clockStyle) {
      case ClockStyle.digital:
        return DigitalClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.analog:
        return AnalogClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.minimalist:
        return MinimalistClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.bold:
        return BoldClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.compact:
        return CompactClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.modern:
        return ModernClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.retro:
        return RetroClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.elegant:
        return ElegantClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.binary:
        return BinaryClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.progress:
        return ProgressClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.vertical:
        return VerticalClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.word:
        return WordClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.dotMatrix:
        return DotMatrixClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.zen:
        return ZenClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.typewriter:
        return TypewriterClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
      case ClockStyle.arc:
        return ArcClockWidget(
          time: _currentTime,
          themeColor: widget.themeColor,
          timeFormat: widget.timeFormat,
          opacityMultiplier: widget.opacityMultiplier,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe-down-to-dismiss wrapper for the app list overlay.
// Shows a small drag handle at the top. User can swipe down from the handle
// area OR swipe down when the list is already scrolled to the top.
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM SLIDE-UP ROUTE  –  Samsung One UI / iOS hybrid transition
// ─────────────────────────────────────────────────────────────────────────────
//
// • Bottom-to-top slide with subtle scale-up for depth
// • Scrim fades in behind the sheet
// • easeOutQuart deceleration (Samsung-style long tail)
// • Barrier color animates from transparent → dark

class _SlideUpRoute extends PageRouteBuilder {
  final Widget child;

  _SlideUpRoute({required this.child})
      : super(
          opaque: false,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 420),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (_, _, _) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide from bottom
            final slideUp = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.25, 1.0, 0.25, 1.0), // easeOutQuart
              reverseCurve: const Cubic(0.42, 0.0, 1.0, 1.0),
            ));

            // Subtle scale for depth
            final scale = Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Cubic(0.25, 1.0, 0.25, 1.0),
              ),
            );

            return Stack(
              children: [
                // Sliding content — AppListScreen renders its own wallpaper bg
                SlideTransition(
                  position: slideUp,
                  child: ScaleTransition(
                    scale: scale,
                    alignment: Alignment.bottomCenter,
                    child: child,
                  ),
                ),
              ],
            );
          },
        );
}