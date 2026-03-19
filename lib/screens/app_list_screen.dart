import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/installed_app.dart';
import '../providers/favorite_apps_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/recent_apps_provider.dart';
import '../providers/productivity_provider.dart';
import '../providers/wallpaper_provider.dart';
import '../providers/amoled_provider.dart';
import '../services/app_settings_service.dart';
import '../widgets/blocked_app_screen.dart';
import '../widgets/app_session_timer_sheet.dart';
import '../providers/screen_time_provider.dart';
import '../providers/launcher_page_provider.dart';
import '../providers/keyboard_auto_open_provider.dart';
import '../utils/usage_permission_helper.dart';
import 'settings_screen.dart';

/// Apple-style page route — full-width iOS slide with interactive swipe-back.
class _SmoothForwardRoute<T> extends CupertinoPageRoute<T> {
  _SmoothForwardRoute({required Widget child})
      : super(builder: (_) => child);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}

/// App List Screen — Premium minimalist launcher
/// Unified surface: no top/bottom division, single scrolling body
/// Swipe-down to dismiss, staggered entry animations, zero lag
class AppListScreen extends ConsumerStatefulWidget {
  /// [isOverlay] = true when pushed as a slide-up route (not in PageView).
  /// Paints a solid black background so the screen behind is hidden.
  final bool isOverlay;
  const AppListScreen({super.key, this.isOverlay = false});

  @override
  ConsumerState<AppListScreen> createState() => _AppListScreenState();
}

class _AppListScreenState extends ConsumerState<AppListScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin,
         TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _hasAutoLaunched = false;
  Timer? _autoLaunchDebounce;
  bool _recentlyInstalledExpanded = true;

  // Pre-computed pixel offset for every letter that exists in the current
  // filtered list.  Rebuilt in build() whenever the app list changes so the
  // alphabet sidebar always jumps to exactly the right position — works
  // correctly regardless of how many apps the user has installed/removed.
  Map<String, double> _letterOffsets = {};

  // Keyboard height tracked independently via didChangeMetrics —
  // this works even when the parent Scaffold has resizeToAvoidBottomInset:false
  // which would otherwise keep viewInsets.bottom always at 0.
  double _keyboardHeight = 0;

  // Throttle refresh — max once per 10 min
  DateTime? _lastRefreshTime;

  @override
  bool get wantKeepAlive => true;

  PageController? _pageController;
  bool _wasOnAppListPage = false;
  Timer? _pageScrollDebounce;

  // ── Premium entry animation ──
  late AnimationController _entryController;
  late Animation<double> _contentFade;
  late Animation<Offset> _searchSlide;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(_onSearchChanged);

    // Entry animation — staggered fade+slide for premium feel
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _contentFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _searchSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.2, 1.0, curve: Cubic(0.25, 1.0, 0.25, 1.0)),
    ));

    // Start entry animation after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entryController.forward();

      _pageController = ref.read(launcherPageControllerProvider);
      _pageController?.addListener(_onPageScroll);

      // Auto-focus if standalone route
      if (_pageController == null || !_pageController!.hasClients) {
        final autoOpen = ref.read(keyboardAutoOpenProvider);
        if (autoOpen && mounted && !_searchFocusNode.hasFocus) {
          Future.delayed(const Duration(milliseconds: 350), () {
            if (mounted && !_searchFocusNode.hasFocus) {
              _searchFocusNode.requestFocus();
            }
          });
        }
      }
    });
  }

  void _onPageScroll() {
    final page = _pageController?.page;
    if (page == null) return;

    final onAppListPage = (page - 4).abs() < 0.08;

    if (onAppListPage && !_wasOnAppListPage) {
      _wasOnAppListPage = true;
      _pageScrollDebounce?.cancel();
      final autoOpen = ref.read(keyboardAutoOpenProvider);
      if (autoOpen && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_searchFocusNode.hasFocus) {
            _searchFocusNode.requestFocus();
          }
        });
      }
    } else if (!onAppListPage && _wasOnAppListPage) {
      _wasOnAppListPage = false;
      _pageScrollDebounce?.cancel();
      _pageScrollDebounce = Timer(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        if (_searchFocusNode.hasFocus) _searchFocusNode.unfocus();
        if (_searchController.text.isNotEmpty) _searchController.clear();
      });
    }
  }

  void _onSearchChanged() {
    final newQuery = _searchController.text;
    if (newQuery != _searchQuery) {
      setState(() {
        _searchQuery = newQuery;
        _hasAutoLaunched = false;
      });
      _autoLaunchDebounce?.cancel();
      if (newQuery.length >= 2) {
        _autoLaunchDebounce = Timer(const Duration(milliseconds: 300), () {
          _checkAutoLaunch();
        });
      }
    }
  }

  void _checkAutoLaunch() {
    if (_hasAutoLaunched || _searchQuery.length < 2) return;
    final notifier = ref.read(installedAppsProvider.notifier);
    final app = notifier.bestAutoLaunchMatch(_searchQuery);
    if (app != null) {
      _hasAutoLaunched = true;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) {
          _launchApp(app.packageName);
          _searchController.clear();
        }
      });
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // PlatformDispatcher gives us the raw keyboard inset even when the
    // parent Scaffold has resizeToAvoidBottomInset:false (which freezes
    // MediaQuery.viewInsets at 0 for PageView children).
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final insets = view.viewInsets;
    final pixelRatio = view.devicePixelRatio;
    final kbPx = insets.bottom;
    final kbDp = kbPx / pixelRatio;
    if (mounted && kbDp != _keyboardHeight) {
      setState(() => _keyboardHeight = kbDp);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final shouldRefresh = _lastRefreshTime == null ||
          now.difference(_lastRefreshTime!).inMinutes >= 10;
      if (shouldRefresh) {
        _lastRefreshTime = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refreshAppList();
        });
      }
    }
  }

  Future<void> _refreshAppList() async {
    await ref.read(installedAppsProvider.notifier).refreshApps();
  }

  @override
  void dispose() {
    _searchFocusNode.unfocus();
    _entryController.dispose();
    _pageScrollDebounce?.cancel();
    _autoLaunchDebounce?.cancel();
    _pageController?.removeListener(_onPageScroll);
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _launchApp(String packageName) async {
    _searchFocusNode.unfocus();

    // Check app blocker
    final blocker = ref.read(appBlockRuleProvider.notifier);
    if (blocker.isAppBlocked(packageName)) {
      if (mounted) _showBlockedAppScreen(packageName);
      return;
    }

    // App Time Intent
    final screenTime = ref.read(screenTimeProvider);
    int? timerMinutes;
    String? timerAppName;
    if (screenTime.featureEnabled && screenTime.hasTimerFor(packageName)) {
      if (!mounted) return;
      final hasPermission = await UsagePermissionHelper.ensureGranted(context);
      if (!hasPermission) return;

      final allApps = ref.read(installedAppsProvider);
      timerAppName = allApps
          .where((a) => a.packageName == packageName)
          .map((a) => a.appName)
          .firstOrNull ?? packageName.split('.').last;
      final config = screenTime.appConfigs[packageName];
      final defaultMins = config?.defaultMinutes ?? 15;

      if (!mounted) return;
      final chosenMinutes = await AppSessionPrompt.show(
        context,
        packageName: packageName,
        appName: timerAppName,
        defaultMinutes: defaultMins,
      );
      if (chosenMinutes == null || chosenMinutes <= 0) return;
      timerMinutes = chosenMinutes;
    }

    ref.read(recentAppsProvider.notifier).addRecent(packageName);

    try {
      if (packageName.contains('paisa') || packageName.contains('googlepay')) {
        await AppSettingsService.launchGooglePay();
      } else if (packageName == 'net.one97.paytm') {
        await InstalledApps.startApp(packageName);
      } else {
        await InstalledApps.startApp(packageName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open app: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (timerMinutes != null) {
      ref.read(screenTimeProvider.notifier).startSession(
        packageName, timerAppName ?? packageName, timerMinutes,
      );
    }

    // Navigate to Home immediately after launching an app so that when the
    // user swipes up / presses back from the launched app they land on the
    // home page — not on the App List.
    // We also persist the home-page index so that _restoreLastPage (called on
    // every screen-off/on cycle) also puts them back on home, not app list.
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.jumpToPage(3); // 3 = Home page
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('launcher_last_page_index', 3);
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

  // ── Compute letter → scroll offset map ──────────────────────────────────
  // Heights that make up the scroll content above each letter group:
  //   • Status-bar top padding  (mq.padding.top + 8)  – dynamic, passed in
  //   • Recently-installed section (header 38 + apps×46 + divider 13)
  //   • For each letter group: header 36 + apps×46
  //
  // Using fixed heights avoids the RenderBox/GlobalKey race that caused the
  // sidebar to silently do nothing when the layout hadn't settled yet.
  // This is rebuilt in build() so it always reflects the current app list,
  // including after installs or uninstalls.
  static const double _kAppRowHeight    = 46.0; // vertical:11×2 + fontSize:20 line
  static const double _kLetterHdrHeight = 36.0; // SizedBox height in _buildLetterHeader
  static const double _kRecentHdrHeight = 38.0; // padding(14+6) + text(~18)
  static const double _kDividerHeight   = 13.0; // padding(4+8) + container(0.5)

  Map<String, double> _computeLetterOffsets(
    List<InstalledApp> filteredApps,
    double topPadding,
  ) {
    final offsets = <String, double>{};
    double y = topPadding; // SliverToBoxAdapter(height: mq.padding.top + 8)

    // ── Recently-installed section (only shown when search is empty) ──────
    if (_searchQuery.isEmpty) {
      final recentApps =
          ref.read(installedAppsProvider.notifier).recentlyInstalled;
      if (recentApps.isNotEmpty) {
        y += _kRecentHdrHeight; // collapsible header row
        if (_recentlyInstalledExpanded) {
          y += recentApps.length * _kAppRowHeight;
        }
        y += _kDividerHeight; // hairline divider below section
      }
    }

    // ── SliverPadding top (left:24, right:40 — no vertical padding) ──────
    // (no extra y offset needed)

    // ── Letter groups ─────────────────────────────────────────────────────
    String? lastLetter;
    for (final app in filteredApps) {
      final firstChar =
          app.appName.isEmpty ? '' : app.appName[0].toUpperCase();
      final letter =
          RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';

      if (letter != lastLetter) {
        // Record where this letter header starts
        offsets[letter] = y;
        y += _kLetterHdrHeight;
        lastLetter = letter;
      }
      y += _kAppRowHeight;
    }

    return offsets;
  }

  void _scrollToLetter(String letter, List<InstalledApp> apps) {
    if (!_scrollController.hasClients) return;

    final offset = _letterOffsets[letter];
    if (offset == null) return; // letter doesn't exist in current list

    final maxExtent = _scrollController.position.maxScrollExtent;
    final target = offset.clamp(0.0, maxExtent);

    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildAlphabetSidebar(List<InstalledApp> filteredApps, AppThemeColor themeColor) {
    return _AlphabetSidebar(
      apps: filteredApps,
      accent: themeColor.color,
      scrollController: _scrollController,
      onScrollToLetter: _scrollToLetter,
    );
  }

  void _showRenameDialog(BuildContext context, InstalledApp app, WidgetRef ref, AppThemeColor themeColor) {
    final controller = TextEditingController(text: app.customName ?? app.appName);
    final accent = themeColor.color;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        title: Text(
          'Rename App',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original name: ${app.appName}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Enter new name',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: accent, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (app.customName != null)
            TextButton(
              onPressed: () async {
                await ref.read(installedAppsProvider.notifier).renameApp(app.packageName, '');
                if (context.mounted) {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                }
              },
              child: Text('Reset', style: TextStyle(color: Colors.white.withValues(alpha: 0.45))),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != app.appName) {
                await ref.read(installedAppsProvider.notifier).renameApp(app.packageName, newName);
              } else {
                await ref.read(installedAppsProvider.notifier).renameApp(app.packageName, '');
              }
              if (context.mounted) {
                Navigator.pop(context);
                HapticFeedback.lightImpact();
              }
            },
            child: Text('Save', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }

  void _showAppOptions(BuildContext context, InstalledApp app, WidgetRef ref) {
    final themeColor = ref.read(themeColorProvider);
    final isFav = ref.read(favoriteAppsProvider.notifier).isFavorite(app.packageName);
    final accent = themeColor.color;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                app.displayName,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 24),

            // Rename
            _optionTile(
              icon: Icons.edit_outlined,
              label: 'Rename app',
              color: accent,
              subtitle: app.customName != null ? 'Original: ${app.appName}' : null,
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, app, ref, themeColor);
              },
            ),

            // Favorite toggle
            _optionTile(
              icon: isFav ? Icons.star : Icons.star_outline,
              label: isFav ? 'Remove from Favorites' : 'Add to Favorites',
              color: accent,
              subtitle: !isFav ? 'Max 7 apps' : null,
              onTap: () async {
                final success = await ref
                    .read(favoriteAppsProvider.notifier)
                    .toggleFavorite(app.packageName, app.appName);
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Max 7 favorites reached'),
                      backgroundColor: Color(0xFFE8915A),
                    ),
                  );
                } else {
                  HapticFeedback.lightImpact();
                }
              },
            ),

            // Uninstall
            _optionTile(
              icon: Icons.delete_outline,
              label: 'Uninstall app',
              color: const Color(0xFFEF5350),
              onTap: () async {
                Navigator.pop(context);
                await _confirmUninstall(app);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String label,
    required Color color,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color.withValues(alpha: 0.65), size: 22),
      title: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11))
          : null,
      onTap: onTap,
    );
  }

  Future<void> _confirmUninstall(InstalledApp app) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
        ),
        title: Text('Uninstall ${app.appName}?', style: const TextStyle(color: Colors.white)),
        content: const Text('This will uninstall the app from your device.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(false);
              ref.read(installedAppsProvider.notifier).removeApp(app.packageName);
              await AppSettingsService.uninstallApp(app.packageName);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _refreshAppList();
              });
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF5350)),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD — unified single-surface layout
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final allApps = ref.watch(installedAppsProvider);
    final installedAppsNotifier = ref.read(installedAppsProvider.notifier);
    final filteredApps = installedAppsNotifier.filterApps(_searchQuery);
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;
    final mq = MediaQuery.of(context);

    // Recompute letter offsets every build so installs/uninstalls are always
    // reflected. This is O(n) and very cheap — safe to call here.
    if (_searchQuery.isEmpty) {
      _letterOffsets = _computeLetterOffsets(
        filteredApps,
        mq.padding.top + 8,
      );
    }

    // When used as overlay (swipe-up), show the actual wallpaper background
    Widget overlayBg = const SizedBox.shrink();
    if (widget.isOverlay) {
      final isAmoled = ref.watch(amoledProvider);
      final wallpaper = isAmoled ? WallpaperType.black : ref.watch(wallpaperProvider);
      overlayBg = _buildOverlayBackground(wallpaper);
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        _searchFocusNode.unfocus();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Wallpaper background (only for overlay mode)
          if (widget.isOverlay) overlayBg,
          FadeTransition(
            opacity: _contentFade,
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  // ── App list ──
                  Expanded(
                    child: allApps.isEmpty
                        ? _buildLoadingState(accent)
                        : filteredApps.isEmpty
                            ? _buildEmptyState(accent)
                            : Stack(
                              children: [
                                CustomScrollView(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  slivers: [
                                    // Status bar breathing room (replaces SafeArea top)
                                    SliverToBoxAdapter(
                                      child: SizedBox(height: mq.padding.top + 8),
                                    ),

                                    // Recently installed
                                    if (_searchQuery.isEmpty)
                                      ..._buildRecentlyInstalledSection(themeColor),

                                    // All apps with sticky letter headers
                                    SliverPadding(
                                      padding: const EdgeInsets.only(left: 24, right: 40),
                                      sliver: _buildAlphaGroupedList(filteredApps, themeColor),
                                    ),

                                    // Bottom breathing room so last app isn't
                                    // hidden under the search bar
                                    const SliverToBoxAdapter(
                                      child: SizedBox(height: 80),
                                    ),
                                  ],
                                ),

                                // Alphabet sidebar — right edge only
                                if (_searchQuery.isEmpty)
                                  _buildAlphabetSidebar(filteredApps, themeColor),

                                // Top fade for clean scroll edge
                                Positioned(
                                  top: 0, left: 0, right: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 20,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.5),
                                            Colors.black.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                  ),

                  // ── Minimalist bottom search bar ──
                  // _keyboardHeight is tracked via didChangeMetrics so it
                  // updates even when the parent Scaffold has
                  // resizeToAvoidBottomInset:false (PageView context).
                  // AnimatedPadding smooths the transition so there is no
                  // hard jump that causes the PageView to bounce sideways.
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(
                      bottom: _keyboardHeight > 0 ? _keyboardHeight : 0,
                    ),
                    child: SlideTransition(
                      position: _searchSlide,
                      child: _buildBottomSearchBar(themeColor, mq),
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

  Widget _buildLoadingState(Color accent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
              color: accent.withValues(alpha: 0.4),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading apps...',
            style: TextStyle(
              color: accent.withValues(alpha: 0.4),
              fontSize: 14,
              fontWeight: FontWeight.w300,
              letterSpacing: 0.5,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color accent) {
    return SizedBox.expand(
      child: Center(
        child: Text(
          'No apps found',
          style: TextStyle(
            color: accent.withValues(alpha: 0.3),
            fontSize: 16,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRecentlyInstalledSection(AppThemeColor themeColor) {
    final recentApps = ref.read(installedAppsProvider.notifier).recentlyInstalled;
    if (recentApps.isEmpty) return [];

    final accent = themeColor.color;
    const dividerColor = Colors.white;
    return [
      SliverToBoxAdapter(
        child: GestureDetector(
          onTap: () => setState(() => _recentlyInstalledExpanded = !_recentlyInstalledExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 22, 6),
            child: Row(
              children: [
                Text(
                  'Recently installed',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _recentlyInstalledExpanded ? 0.0 : 0.5,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: accent.withValues(alpha: 0.35),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_recentlyInstalledExpanded)
        SliverPadding(
          padding: const EdgeInsets.only(left: 24, right: 22),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildAppItem(recentApps[index], themeColor),
              childCount: recentApps.length,
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 40, 8),
          child: Container(
            height: 0.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  dividerColor.withValues(alpha: 0.0),
                  dividerColor.withValues(alpha: 0.06),
                  dividerColor.withValues(alpha: 0.06),
                  dividerColor.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildAlphaGroupedList(List<InstalledApp> apps, AppThemeColor themeColor) {
    if (_searchQuery.isNotEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildAppItem(apps[index], themeColor),
          childCount: apps.length,
        ),
      );
    }

    final rows = <({bool isHeader, String? letter, InstalledApp? app})>[];
    String? lastLetter;
    for (final app in apps) {
      final firstChar = app.appName.isEmpty ? '' : app.appName[0].toUpperCase();
      final letter = RegExp(r'[A-Z]').hasMatch(firstChar) ? firstChar : '#';
      if (letter != lastLetter) {
        rows.add((isHeader: true, letter: letter, app: null));
        lastLetter = letter;
      }
      rows.add((isHeader: false, letter: null, app: app));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final row = rows[index];
          if (row.isHeader) return _buildLetterHeader(row.letter!, themeColor);
          return _buildAppItem(row.app!, themeColor);
        },
        childCount: rows.length,
      ),
    );
  }

  Widget _buildLetterHeader(String letter, AppThemeColor themeColor) {
    final letterColor = themeColor.color.withValues(alpha: 0.3);
    return SizedBox(
      height: _kLetterHdrHeight,
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            letter,
            style: TextStyle(
              color: letterColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  /// Renders the wallpaper background when AppListScreen is used as an overlay
  /// route (swipe-up from home). Mirrors launcher_shell's _buildBackground.
  Widget _buildOverlayBackground(WallpaperType wallpaper) {
    if (wallpaper == WallpaperType.black) {
      return const Positioned.fill(child: ColoredBox(color: Colors.black));
    }
    final assetPath = wallpaperAssetPath(wallpaper);
    if (assetPath != null) {
      return Positioned.fill(
        child: Image.asset(assetPath, fit: BoxFit.cover),
      );
    }
    if (wallpaper == WallpaperType.customImage) {
      final imagePath = ref.read(wallpaperProvider.notifier).customImagePath;
      if (imagePath != null && File(imagePath).existsSync()) {
        return Positioned.fill(
          child: Image.file(File(imagePath), fit: BoxFit.cover),
        );
      }
    }
    // All gradient wallpapers → show their dominant dark color as solid bg
    final bgColor = _wallpaperDominantColor(wallpaper);
    return Positioned.fill(child: ColoredBox(color: bgColor));
  }

  Color _wallpaperDominantColor(WallpaperType wallpaper) {
    switch (wallpaper) {
      case WallpaperType.desertGradient:   return const Color(0xFF1A150D);
      case WallpaperType.blueGradient:     return const Color(0xFF0d1b2a);
      case WallpaperType.purpleGradient:   return const Color(0xFF1a0a2e);
      case WallpaperType.redGradient:      return const Color(0xFF1a0a0a);
      case WallpaperType.greenGradient:    return const Color(0xFF0a1a0f);
      case WallpaperType.darkGradient:     return const Color(0xFF0a0a0a);
      case WallpaperType.leafGreenGradient:return const Color(0xFF0d1a0d);
      case WallpaperType.beigeGradient:    return const Color(0xFF1a1610);
      case WallpaperType.roseGoldGradient: return const Color(0xFF1a0f0f);
      case WallpaperType.lavenderGradient: return const Color(0xFF110d1a);
      case WallpaperType.oceanTealGradient:return const Color(0xFF0a1515);
      case WallpaperType.sunsetPeachGradient: return const Color(0xFF1a0f08);
      case WallpaperType.mintGradient:     return const Color(0xFF0a1510);
      case WallpaperType.dustyRoseGradient:return const Color(0xFF150d0f);
      default:                             return Colors.black;
    }
  }

  Widget _buildBottomSearchBar(AppThemeColor themeColor, MediaQueryData mq) {
    final accent = themeColor.color;
    return ListenableBuilder(
      listenable: _searchFocusNode,
      builder: (context, _) {
        final isFocused = _searchFocusNode.hasFocus;
        final hasText = _searchController.text.isNotEmpty;

        // ── Background: gradient that dissolves upward into the list ──────
        // No hard edge — the bar feels like it grows out of the wallpaper.
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.28, 1.0],
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.82),
              ],
            ),
          ),
          child: Padding(
            // Extra top space so the gradient feather is visible
            padding: EdgeInsets.fromLTRB(16, 22, 14, 16 + mq.padding.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Text field ────────────────────────────────────────
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: TextStyle(
                          color: accent.withValues(alpha: 0.90),
                          fontSize: 17,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.4,
                          decoration: TextDecoration.none,
                        ),
                        textInputAction: TextInputAction.search,
                        cursorColor: accent.withValues(alpha: 0.65),
                        cursorWidth: 1.2,
                        decoration: InputDecoration(
                          hintText: 'Search apps',
                          hintStyle: TextStyle(
                            color: accent.withValues(
                              alpha: isFocused ? 0.28 : 0.42,
                            ),
                            fontSize: 17,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.4,
                          ),
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          suffixIcon: hasText
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _searchFocusNode.unfocus();
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: accent.withValues(alpha: 0.40),
                                  ),
                                )
                              : null,
                          suffixIconConstraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ── Search icon ───────────────────────────────────────
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isFocused ? 0.75 : 0.50,
                      child: Icon(
                        Icons.search_rounded,
                        size: 24,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // ── Settings gear ─────────────────────────────────────
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          _SmoothForwardRoute(child: const SettingsScreen()),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.settings_outlined,
                        size: 22,
                        color: accent.withValues(alpha: 0.40),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Full-width accent underline ───────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: isFocused ? 1.2 : 0.7,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        accent.withValues(alpha: isFocused ? 0.65 : 0.30),
                        accent.withValues(alpha: isFocused ? 0.65 : 0.30),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.15, 0.85, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppItem(InstalledApp app, AppThemeColor themeColor) {
    final isBlocked = ref.read(appBlockRuleProvider.notifier).isAppBlocked(app.packageName);
    final accent = themeColor.color;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _launchApp(app.packageName),
        onLongPress: () => _showAppOptions(context, app, ref),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // vertical: 11 → ~22px gap between apps, matching the screenshot
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Text(
            app.displayName,
            style: TextStyle(
              color: isBlocked
                  ? accent.withValues(alpha: 0.12)
                  : accent.withValues(alpha: 0.88),
              fontSize: 20,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w300,
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  PREMIUM ALPHABET SIDEBAR
//  Zero-jank, 60fps, isolated repaints, haptic drag
// ═══════════════════════════════════════════════════════════════════

class _AlphabetSidebar extends StatefulWidget {
  final List<InstalledApp> apps;
  final Color accent;
  final ScrollController scrollController;
  final void Function(String letter, List<InstalledApp> apps) onScrollToLetter;

  const _AlphabetSidebar({
    required this.apps,
    required this.accent,
    required this.scrollController,
    required this.onScrollToLetter,
  });

  @override
  State<_AlphabetSidebar> createState() => _AlphabetSidebarState();
}

class _AlphabetSidebarState extends State<_AlphabetSidebar>
    with TickerProviderStateMixin {
  static const _allLetters = [
    '#',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  final ValueNotifier<String?> _activeLetter = ValueNotifier(null);
  final ValueNotifier<bool> _isDragging = ValueNotifier(false);
  final ValueNotifier<double?> _dragY = ValueNotifier(null);
  // Smoothly spring-animated drag Y — drives the snake curve
  final ValueNotifier<double?> _animatedDragY = ValueNotifier(null);
  final GlobalKey _columnKey = GlobalKey();
  late Set<String> _availableLetters;
  late AnimationController _bubbleAnim;

  // Spring release: custom ticker drives fade-to-rest
  Ticker? _springTicker;
  double _springPos = 0.0;
  double _springTarget = 0.0;

  @override
  void initState() {
    super.initState();
    _buildAvailableLetters();
    _bubbleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void didUpdateWidget(covariant _AlphabetSidebar old) {
    super.didUpdateWidget(old);
    if (old.apps != widget.apps) _buildAvailableLetters();
  }

  void _buildAvailableLetters() {
    final set = <String>{};
    bool hasNonAlpha = false;
    for (final app in widget.apps) {
      if (app.appName.isEmpty) continue;
      final first = app.appName[0].toUpperCase();
      if (RegExp(r'[A-Z]').hasMatch(first)) {
        set.add(first);
      } else {
        hasNonAlpha = true;
      }
    }
    if (hasNonAlpha) set.add('#');
    _availableLetters = set;
  }

  @override
  void dispose() {
    _activeLetter.dispose();
    _isDragging.dispose();
    _dragY.dispose();
    _animatedDragY.dispose();
    _bubbleAnim.dispose();
    _springTicker?.dispose();
    super.dispose();
  }

  // ── Spring release ──────────────────────────────────────────────
  // Simple easeOut fade: the wave dissolves away cleanly on release,
  // no bounce, no overshoot — just a smooth melt back to flat.
  void _startSpringRelease(double fromY) {
    _springTicker?.stop();
    _springTicker?.dispose();
    // Drive animatedDragY toward null over ~350ms with easeOutCubic feel.
    // We do this by incrementally blending fromY → centerY each tick.
    final rb = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    final centerY = rb != null ? rb.size.height / 2.0 : fromY;
    _springPos = fromY;
    _springTarget = centerY;
    final startTime = DateTime.now();
    const durationMs = 320;

    _springTicker = createTicker((_) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      final raw = (elapsed / durationMs).clamp(0.0, 1.0);
      // easeOutCubic: fast start, gentle finish — no overshoot
      final t = 1.0 - math.pow(1.0 - raw, 3).toDouble();
      if (raw >= 1.0) {
        _animatedDragY.value = null;
        _springTicker?.stop();
      } else {
        _animatedDragY.value = _springPos + (_springTarget - _springPos) * t;
      }
    })
      ..start();
  }

  // ── Helpers ─────────────────────────────────────────────────────
  String? _letterFromDy(double localY) {
    final rb = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return null;
    final height = rb.size.height;
    if (height <= 0) return null;
    final fraction = (localY / height).clamp(0.0, 0.999);
    final index = (fraction * _allLetters.length).floor();
    return _allLetters[index];
  }

  // ── Drag handlers ────────────────────────────────────────────────
  void _onDragStart(DragStartDetails d) {
    _springTicker?.stop();
    _isDragging.value = true;
    _dragY.value = d.localPosition.dy;
    _animatedDragY.value = d.localPosition.dy;
    _bubbleAnim.forward();
    _handleDrag(d.localPosition.dy);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    // Only the vertical component moves the snake — ignore any horizontal drift
    // (user's finger may wander left, we only care about Y within the strip)
    final y = d.localPosition.dy;
    _dragY.value = y;
    _animatedDragY.value = y;
    _handleDrag(y);
  }

  void _onDragEnd(DragEndDetails details) {
    final lastY = _dragY.value;

    // Bubble fades after a short hold so user can see the last letter
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _bubbleAnim.reverse();
    });

    // Clear active letter after bubble is gone
    Future.delayed(const Duration(milliseconds: 380), () {
      if (mounted) {
        _isDragging.value = false;
        _activeLetter.value = null;
        _dragY.value = null;
      }
    });

    // Kick off spring release — this drives _animatedDragY back to center
    if (lastY != null) _startSpringRelease(lastY);
  }

  void _handleDrag(double localY) {
    final letter = _letterFromDy(localY);
    if (letter == null) return;

    String finalLetter = letter;
    if (!_availableLetters.contains(letter)) {
      final idx = _allLetters.indexOf(letter);
      int closestDist = 999;
      String closest = letter;
      for (final l in _availableLetters) {
        final availIdx = _allLetters.indexOf(l);
        final dist = (availIdx - idx).abs();
        if (dist < closestDist) {
          closestDist = dist;
          closest = l;
        }
      }
      finalLetter = closest;
    }

    if (finalLetter == _activeLetter.value) return;
    _activeLetter.value = finalLetter;
    HapticFeedback.selectionClick();
    widget.onScrollToLetter(finalLetter, widget.apps);
  }

  void _onTapLetter(String letter) {
    HapticFeedback.selectionClick();

    // Resolve to nearest available letter if this one has no apps —
    // consistent with drag behaviour so every tap does something useful.
    String target = letter;
    if (!_availableLetters.contains(letter) && _availableLetters.isNotEmpty) {
      final idx = _allLetters.indexOf(letter);
      int closestDist = 999;
      for (final l in _availableLetters) {
        final dist = (_allLetters.indexOf(l) - idx).abs();
        if (dist < closestDist) {
          closestDist = dist;
          target = l;
        }
      }
    }

    _activeLetter.value = target;
    _bubbleAnim.forward();
    if (_availableLetters.contains(target)) {
      widget.onScrollToLetter(target, widget.apps);
    }
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _bubbleAnim.reverse();
        _activeLetter.value = null;
      }
    });
  }

  static const double _stripWidth = 36.0;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: _stripWidth,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Align(
          alignment: Alignment.centerRight,
          child: RepaintBoundary(
            child: SizedBox(
              width: _stripWidth,
              child: Stack(
                alignment: Alignment.centerRight,
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Column(
                      key: _columnKey,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: _allLetters.map((letter) {
                        final hasApps = _availableLetters.contains(letter);
                        return _LetterTile(
                          letter: letter,
                          hasApps: hasApps,
                          accent: widget.accent,
                          activeLetter: _activeLetter,
                          dragY: _animatedDragY,
                          columnKey: _columnKey,
                          totalLetters: _allLetters.length,
                          index: _allLetters.indexOf(letter),
                          // All letters respond to tap; sidebar scrolls to nearest
                          // available letter automatically via _handleDrag logic.
                          onTap: () => _onTapLetter(letter),
                        );
                      }).toList(),
                    ),
                  ),

                  ValueListenableBuilder<String?>(
                    valueListenable: _activeLetter,
                    builder: (_, active, _) {
                      if (active == null) return const SizedBox.shrink();
                      final idx = _allLetters.indexOf(active);
                      if (idx < 0) return const SizedBox.shrink();
                      return _BubbleIndicator(
                        letter: active,
                        index: idx,
                        totalLetters: _allLetters.length,
                        accent: widget.accent,
                        animation: _bubbleAnim,
                        columnKey: _columnKey,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LETTER TILE — isolated repaint per letter
// ═══════════════════════════════════════════════════════════════════

class _LetterTile extends StatelessWidget {
  final String letter;
  final bool hasApps;
  final Color accent;
  final ValueNotifier<String?> activeLetter;
  final ValueNotifier<double?> dragY;
  final GlobalKey columnKey;
  final int totalLetters;
  final int index;
  final VoidCallback? onTap;

  const _LetterTile({
    required this.letter,
    required this.hasApps,
    required this.accent,
    required this.activeLetter,
    required this.dragY,
    required this.columnKey,
    required this.totalLetters,
    required this.index,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: dragY,
      builder: (_, currentDragY, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: activeLetter,
          builder: (_, active, _) {
            final isActive = active == letter;

            // Natural forward-bulge curve:
            // Letters near the touch point slide LEFT (toward the content area =
            // "forward" since the sidebar is pinned to the RIGHT edge).
            // The peak letter moves most, neighbours taper off with cosine falloff.
            // On release, _animatedDragY snaps back via easeOutQuart → curve
            // melts back to rest naturally without any snap/pop.
            double targetXOffset = 0.0;
            double targetScale = 1.0;

            if (currentDragY != null) {
              final rb = columnKey.currentContext?.findRenderObject() as RenderBox?;
              if (rb != null) {
                final columnHeight = rb.size.height;
                final letterH = columnHeight / totalLetters;
                final centerY = (index + 0.5) * letterH;
                final distance = (currentDragY - centerY).abs();

                // Wide radius: ~8 letters above & below the touch point
                // feel the pull — gives a long, flowing wave across the column
                final radius = letterH * 12.0;

                if (distance < radius) {
                  final normalizedDist = distance / radius;
                  // Cosine bell: 1.0 at touch point, smoothly → 0 at radius edge
                  final bell = (math.cos(normalizedDist * math.pi) + 1.0) / 2.0;
                  // Quintic ease for a sharper peak / softer tail
                  final t = bell;
                  final stretch = t * t * t * (t * (t * 6.0 - 15.0) + 10.0);

                  // Sidebar is on the RIGHT edge, so "forward" = toward the
                  // content area = negative X (shift left).
                  // 28 px max keeps the sidebar readable without going off-screen.
                  targetXOffset = -42.0 * stretch;
                  // Scale only the nearest ~3 letters subtly
                  targetScale = 1.0 + (0.28 * stretch);
                }
              }
            }

            return GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                // Snap-back driver (_animatedDragY) already handles the slow
                // ease; this duration just smooths per-frame micro-jumps.
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOutCubic,
                transform: Matrix4.diagonal3Values(targetScale, targetScale, 1.0)
                  ..setTranslationRaw(targetXOffset, 0.0, 0.0),
                child: SizedBox(
                  width: 28,
                  height: 22,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        // All letters same contrast — active letter gets accent,
                        // every other letter uses the same visible alpha
                        // regardless of whether apps exist under that letter.
                        color: isActive
                            ? accent
                            : Colors.white.withValues(alpha: 0.55),
                        fontSize: isActive ? 13 : 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.0,
                        decoration: TextDecoration.none,
                      ),
                      child: Text(letter),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  BUBBLE INDICATOR — floating letter during sidebar drag
// ═══════════════════════════════════════════════════════════════════

class _BubbleIndicator extends StatelessWidget {
  final String letter;
  final int index;
  final int totalLetters;
  final Color accent;
  final Animation<double> animation;
  final GlobalKey columnKey;

  const _BubbleIndicator({
    required this.letter,
    required this.index,
    required this.totalLetters,
    required this.accent,
    required this.animation,
    required this.columnKey,
  });

  @override
  Widget build(BuildContext context) {
    final rb = columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return const SizedBox.shrink();
    final columnHeight = rb.size.height;
    final letterH = columnHeight / totalLetters;
    final centerY = (index + 0.5) * letterH;
    final halfColumn = columnHeight / 2;
    final offsetFromCenter = centerY - halfColumn;

    // Fixed X offset — bubble sits cleanly to the left of the sidebar strip
    const double xOffset = -62.0;

    return AnimatedBuilder(
      animation: animation,
      builder: (_, _) {
        final opacity = animation.value;
        if (opacity < 0.01) return const SizedBox.shrink();
        final scaleCurve = Curves.easeOutBack.transform(animation.value);

        return Transform.translate(
          offset: Offset(xOffset, offsetFromCenter),
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scaleCurve,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.4),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.08),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.95),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
