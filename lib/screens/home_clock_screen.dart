import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/launcher_physics.dart';
import '../utils/motion.dart';
import '../widgets/edge_to_edge.dart';
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
import '../widgets/swipe_action_picker.dart';
import 'app_list_screen.dart';
import '../widgets/quick_search_overlay.dart';
import '../providers/quick_action_provider.dart';
import '../widgets/prayer_time_widget.dart';
import '../features/prayer_alarm/widgets/prayer_alarm_dashboard_card.dart';
import '../widgets/app_session_timer_sheet.dart';
import '../providers/screen_time_provider.dart';
import '../providers/app_update_provider.dart';
import '../services/app_update_service.dart';
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
          await const MethodChannel('com.sukoon.launcher/apps')
              .invokeMethod('launchApp', {'packageName': pkg});
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
    // Tactile confirmation the deliberate swipe registered, before the screen
    // changes. Skipped for `none` so a disabled swipe stays completely silent.
    if (action != SwipeAction.none) GestureHaptics.swipeCommit();
    switch (action) {
      case SwipeAction.notifications:
        AppSettingsService.expandNotifications();
        break;
      case SwipeAction.quickAccess:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useSafeArea: false,
          builder: (_) => const AppListScreen(isOverlay: true, autoOpenSearch: true),
        ).then((_) {
          if (mounted) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        });
        break;
      case SwipeAction.openApp:
        if (appPackage != null && appPackage.isNotEmpty) {
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
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          useSafeArea: false,
          builder: (_) => const AppListScreen(isOverlay: true, autoOpenSearch: true),
        ).then((_) {
          if (mounted) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        });
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
        await const MethodChannel('com.sukoon.launcher/apps')
            .invokeMethod('launchApp', {'packageName': packageName});
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

  void _showQuickActionAppPicker(BuildContext context, WidgetRef ref, {required bool isPhone}) {
    final allApps = ref.read(installedAppsProvider);
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final query = searchController.text.toLowerCase();
            final filtered = query.isEmpty
                ? allApps
                : allApps.where((a) => a.appName.toLowerCase().contains(query)).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    Text(
                      isPhone ? 'Choose Phone App' : 'Choose Camera App',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.3), size: 20),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final app = filtered[i];
                          return GestureDetector(
                            onTap: () {
                              if (isPhone) {
                                ref.read(quickActionProvider.notifier).setPhoneApp(app.packageName);
                              } else {
                                ref.read(quickActionProvider.notifier).setCameraApp(app.packageName);
                              }
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.app_shortcut_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      app.appName,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
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
          },
        );
      },
    );
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

    return _SwipeDetector(
      onSwipeUp: () {
        if (!swipeConfig.hasPromptedSwipeUp) {
          showSwipeActionPicker(context, ref, direction: 'Swipe Up', current: swipeConfig.swipeUp, onSelect: (action, {appPackage}) {
            ref.read(swipeGestureProvider.notifier).setSwipeUp(action, appPackage: appPackage);
            ref.read(swipeGestureProvider.notifier).markSwipeUpPrompted();
            _executeSwipeAction(action, appPackage: appPackage);
          });
        } else {
          _executeSwipeAction(swipeConfig.swipeUp, appPackage: swipeConfig.swipeUpApp);
        }
      },
      onSwipeDown: () {
        if (!swipeConfig.hasPromptedSwipeDown) {
          showSwipeActionPicker(context, ref, direction: 'Swipe Down', current: swipeConfig.swipeDown, onSelect: (action, {appPackage}) {
            ref.read(swipeGestureProvider.notifier).setSwipeDown(action, appPackage: appPackage);
            ref.read(swipeGestureProvider.notifier).markSwipeDownPrompted();
            _executeSwipeAction(action, appPackage: appPackage);
          });
        } else {
          _executeSwipeAction(swipeConfig.swipeDown, appPackage: swipeConfig.swipeDownApp);
        }
      },
      child: EdgeToEdge(
        child: SizedBox(
          // viewPadding (NOT padding): the raw safe-area insets, which stay
          // constant when a keyboard appears. Using padding here made this
          // height shrink whenever the swipe-up overlay's keyboard opened
          // (padding.bottom → 0), shifting the bottom-anchored favourite apps
          // up and then back down on dismiss.
          height: MediaQuery.sizeOf(context).height -
              MediaQuery.viewPaddingOf(context).top -
              MediaQuery.viewPaddingOf(context).bottom,
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
                    // NeverScrollableScrollPhysics prevents the Scrollable from
                    // registering a VerticalDragGestureRecognizer in the gesture
                    // arena. With a normal ClampingScrollPhysics the recognizer
                    // would accept the pointer once it crossed the touch slop —
                    // well before the _SwipeDetector's 50px threshold — stealing
                    // the gesture and killing swipe-up/down detection via
                    // onPointerCancel.
                    //
                    // The SingleChildScrollView is kept purely as a layout
                    // safety-net: on very small screens it clips overflow instead
                    // of causing a RenderFlex error, but it no longer competes
                    // for vertical gestures.
                    physics: const NeverScrollableScrollPhysics(),
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
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (displaySettings.showPrayerWidget && displaySettings.homePrayerWidgetType == 'salah_wake')
                                const Padding(
                                  padding: EdgeInsets.only(top: 12, left: 24, right: 24),
                                  child: PrayerAlarmDashboardCard(),
                                ),
                              if ((displaySettings.showPrayerWidget && displaySettings.homePrayerWidgetType != 'salah_wake') || 
                                  (!displaySettings.showPrayerWidget && displaySettings.showFastingWidget) ||
                                  (displaySettings.showPrayerWidget && displaySettings.homePrayerWidgetType == 'salah_wake' && displaySettings.showFastingWidget))
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: PrayerTimeWidget(
                                    forceHidePrayer: displaySettings.showPrayerWidget && displaySettings.homePrayerWidgetType == 'salah_wake',
                                  ),
                                ),
                            ],
                          ),

                        // 📦 Inline update indicator — subtle text, no popup
                        Consumer(builder: (context, ref, _) {
                          final updateState = ref.watch(appUpdateStateProvider);
                          if (!updateState.updateAvailable) return const SizedBox.shrink();
                          return GestureDetector(
                            onTap: () {
                              if (updateState.updateReady) {
                                // Already downloaded — restart to apply
                                AppUpdateService().completeFlexibleUpdate();
                              } else {
                                // Start background download
                                AppUpdateService().startFlexibleUpdate();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    updateState.updateReady
                                        ? Icons.download_done_rounded
                                        : Icons.system_update_rounded,
                                    size: 14,
                                    color: themeColor.color.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    updateState.updateReady
                                        ? 'Tap to install update'
                                        : 'Update available',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.3,
                                      color: themeColor.color.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

                  // Favorite apps at the bottom
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 110,
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

                  // ── Bottom Corner Quick Actions (Phone & Camera) ──
                  Positioned(
                    left: 32,
                    bottom: 32,
                    child: _QuickActionButton(
                      icon: Icons.phone_rounded,
                      onTap: () {
                        final qa = ref.read(quickActionProvider);
                        if (qa.phoneApp != null) {
                          _launchApp(qa.phoneApp!);
                        }
                      },
                      onLongPress: () {
                        // Open app picker to replace phone app
                        _showQuickActionAppPicker(context, ref, isPhone: true);
                      },
                    ),
                  ),
                  Positioned(
                    right: 32,
                    bottom: 32,
                    child: _QuickActionButton(
                      icon: Icons.camera_alt_rounded,
                      onTap: () {
                        final qa = ref.read(quickActionProvider);
                        if (qa.cameraApp != null) {
                          _launchApp(qa.cameraApp!);
                        } else {
                          // Fallback to native intent
                          _blockerChannel.invokeMethod('openCamera');
                        }
                      },
                      onLongPress: () {
                        // Open app picker to replace camera app
                        _showQuickActionAppPicker(context, ref, isPhone: false);
                      },
                    ),
                  ),

                  // SafeArea already removed bottom padding — use fixed 16px offset only
                ],
              ),
            ),
          ),
    );  // _SwipeDetector

  }

  Widget _buildFavoriteApps(AppThemeColor themeColor) {
    // Get favorites directly from provider - instant, no cache, no API calls
    final favorites = ref.watch(favoriteAppsProvider);
    final apps = favorites.take(7).toList();

    if (apps.isEmpty) return const SizedBox.shrink();

    // ── Single column up to 7 apps ──
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: apps.map((app) => _buildFavItem(app, themeColor)).toList(),
    );
  }

  /// Single tappable favorite app row — with scale-on-tap micro-interaction.
  Widget _buildFavItem(dynamic favoriteApp, AppThemeColor themeColor) {
    return _ScaleTapWidget(
      onTap: () {
        _launchApp(favoriteApp.packageName);
      },
      onLongPress: () {
        Navigator.push(
          context,
          _SmoothForwardRoute(child: const FavoritePickerScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
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
// _ScaleTapWidget — Micro-interaction: slight scale-down on press
// ─────────────────────────────────────────────────────────────────────────────

/// A widget that scales down slightly when pressed, providing
/// a premium tactile feel (Samsung One UI / iOS tap style).
class _ScaleTapWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;

  const _ScaleTapWidget({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.97,
  });

  @override
  State<_ScaleTapWidget> createState() => _ScaleTapWidgetState();
}

class _ScaleTapWidgetState extends State<_ScaleTapWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: LauncherEasing.emphasizedDecelerate,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      onLongPress: () {
        _controller.reverse();
        widget.onLongPress?.call();
      },
      // translucent so the outer pan GestureDetector (home screen swipe)
      // can still compete in the gesture arena when the user swipes up/down
      // starting from a favorite app row.
      behavior: HitTestBehavior.translucent,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// _QuickActionButton for Lock Screen style bottom corners
// ───────────────────────────────────────────────────────────────────

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _QuickActionButton({
    required this.icon,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
    HapticFeedback.lightImpact();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  void _handleLongPress() {
    _controller.reverse();
    widget.onLongPress();
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: _handleLongPress,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.35),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.0),
          ),
          child: Icon(
            widget.icon,
            color: Colors.white.withValues(alpha: 0.9),
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ── Swipe Detector ────────────────────────────────────────────────────────────
//
// Uses a raw Listener to detect vertical swipes BEFORE child gesture
// recognizers can claim the gesture arena.
//
// THE PROBLEM:
//   Home screen has competing gesture recognizers:
//     1. PageView → HorizontalDragGestureRecognizer
//     2. Inner SingleChildScrollView → VerticalDragGestureRecognizer (safety-net scroll)
//     3. Outer GestureDetector (if used) → PanGestureRecognizer
//
//   When the user swipes up, the SingleChildScrollView's vertical drag
//   recognizer wins the arena. Flutter then sends onPointerCancel to all
//   raw Listeners — meaning a Listener that waits until onPointerUp will
//   never see it. The swipe is "stolen" by the scroll.
//
// THE SOLUTION:
//   Detect the swipe inside onPointerMove the moment vertical threshold
//   is hit (50+px vertical, low horizontal ratio). Fire the action
//   immediately. This runs before any child recognizer wins the arena,
//   so the swipe always reaches us.
//
//   Listener doesn't compete in the arena — it just observes raw pointer
//   events. Detecting during onPointerMove gives us a guaranteed window
//   before any recognizer claims the gesture.

class _SwipeDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeUp;
  final VoidCallback onSwipeDown;

  const _SwipeDetector({
    required this.child,
    required this.onSwipeUp,
    required this.onSwipeDown,
  });

  @override
  State<_SwipeDetector> createState() => _SwipeDetectorState();
}

class _SwipeDetectorState extends State<_SwipeDetector> {
  double _startY = 0;
  double _startX = 0;
  bool _tracking = false;
  bool _fired = false; // Prevents firing twice in the same gesture

  // Minimum vertical travel to count as a swipe (px) — shared app-wide tuning.
  static const double _minDistance = SwipeTuning.minDistance;
  // Maximum horizontal drift relative to vertical travel — keeps horizontal
  // swipes from triggering. Shared app-wide tuning.
  static const double _maxHorizontalRatio = SwipeTuning.directionRatio;

  void _resetGesture() {
    _tracking = false;
    _fired = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _startY = e.position.dy;
        _startX = e.position.dx;
        _tracking = true;
        _fired = false;
      },
      onPointerMove: (e) {
        if (!_tracking || _fired) return;
        final dy = e.position.dy - _startY;
        final dx = (e.position.dx - _startX).abs();

        // Fire AS SOON AS the vertical threshold is hit during the move.
        // This is critical: if we wait for onPointerUp, the inner
        // SingleChildScrollView can win the gesture arena and Flutter will
        // dispatch onPointerCancel to this Listener instead of onPointerUp,
        // killing the swipe detection.
        if (dy.abs() >= _minDistance && dx < dy.abs() * _maxHorizontalRatio) {
          _fired = true;
          if (dy < 0) {
            widget.onSwipeUp();
          } else {
            widget.onSwipeDown();
          }
        }
      },
      onPointerUp: (_) => _resetGesture(),
      onPointerCancel: (_) => _resetGesture(),
      child: widget.child,
    );
  }
}
