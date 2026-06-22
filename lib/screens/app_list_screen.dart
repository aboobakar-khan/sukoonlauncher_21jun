import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/scheduler.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../utils/launcher_physics.dart';
import '../models/installed_app.dart';
import '../providers/favorite_apps_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/recent_apps_provider.dart';
import '../providers/productivity_provider.dart';
import '../providers/wallpaper_provider.dart';
import '../services/app_settings_service.dart';
import '../services/native_app_blocker_service.dart';
import '../widgets/blocked_app_screen.dart';
import '../widgets/app_session_timer_sheet.dart';
import '../widgets/edge_to_edge.dart';
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
  final ListController _listController = ListController();
  String _searchQuery = '';
  bool _hasAutoLaunched = false;
  Timer? _autoLaunchDebounce;
  bool _recentlyInstalledExpanded = true;

  // Search bar visibility — hidden by default, shown on float button tap
  bool _searchVisible = false;

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

    // Page layout: [Islamic(0), Widget(1), Home(2), Apps(3), Productivity(4)]
    const appListIndex = 3;
    final onAppListPage = (page - appListIndex).abs() < 0.08;

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
        if (_searchVisible) setState(() => _searchVisible = false);
      });
    }
  }

  void _showSearch() {
    setState(() => _searchVisible = true);
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _hideSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchVisible = false;
      _searchQuery = '';
      _hasAutoLaunched = false;
    });
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

    if (timerMinutes != null) {
      if (!mounted) return;
      try {
        if (packageName.contains('paisa') || packageName.contains('googlepay')) {
          await AppSettingsService.launchGooglePay();
        } else {
          await const MethodChannel('com.sukoon.launcher/apps')
              .invokeMethod('launchApp', {'packageName': packageName});
        }
        
        // Start the session on the native side
        ref.read(screenTimeProvider.notifier).startSession(
          packageName,
          timerAppName ?? packageName,
          timerMinutes,
        );

        // Return to home launcher
        if (_pageController != null && _pageController!.hasClients) {
          _pageController!.jumpToPage(3);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('launcher_last_page_index', 3);
      } catch (e) {
        debugPrint('Launch app error: $e');
      }
      return;
    }

    // Default launch logic (non-timed apps)
    try {
      if (packageName.contains('paisa') || packageName.contains('googlepay')) {
        await AppSettingsService.launchGooglePay();
      } else {
        await const MethodChannel('com.sukoon.launcher/apps')
            .invokeMethod('launchApp', {'packageName': packageName});
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

    // Return to home launcher
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.jumpToPage(3);
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

  // ── Section data for super_sliver_list ─────────────────────────────────
  // Built from the sorted app list. Each section = { letter, apps[] }.
  // A flat index map tracks where each letter's first item lives so
  // ListController.jumpToItem can land precisely.
  List<({String letter, List<InstalledApp> apps})> _sections = [];
  Map<String, int> _sectionFlatIndex = {};

  void _buildSections(List<InstalledApp> apps) {
    final grouped = <String, List<InstalledApp>>{};
    for (final app in apps) {
      final first = app.appName.isEmpty ? '' : app.appName[0].toUpperCase();
      final letter = RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
      grouped.putIfAbsent(letter, () => []).add(app);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });
    _sections = sortedKeys
        .map((k) => (letter: k, apps: grouped[k]!))
        .toList();

    // Flat index: header + apps for each section
    int idx = 0;
    _sectionFlatIndex = {};
    for (final sec in _sections) {
      _sectionFlatIndex[sec.letter] = idx; // header row
      idx += 1 + sec.apps.length; // 1 header + N apps
    }
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
    // Directly trigger system uninstall per user request
    ref.read(installedAppsProvider.notifier).removeApp(app.packageName);
    await AppSettingsService.uninstallApp(app.packageName);
    
    // Refresh list after a delay to catch state changes
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _refreshAppList();
    });
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

    // When used as overlay (swipe-up), show the actual wallpaper background
    Widget overlayBg = const SizedBox.shrink();
    if (widget.isOverlay) {
      final wallpaper = ref.watch(wallpaperProvider);
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
            // top/bottom insets are handled manually inside (the search bar
            // adds MediaQuery.padding.top; the list adds a top-inset sliver
            // when the bar is hidden; the float button adds padding.bottom).
            child: EdgeToEdge(
              top: false,
              bottom: false,
              child: Column(
                children: [
                  // ── Top search bar — hidden by default, shown on float tap ──
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _searchVisible
                        ? SlideTransition(
                            position: _searchSlide,
                            child: _buildTopSearchBar(themeColor, mq),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ── App list ──
                  Expanded(
                    child: allApps.isEmpty
                        ? _buildLoadingState(accent)
                        : filteredApps.isEmpty
                            ? _buildEmptyState(accent)
                            : Stack(
                              children: [
                                AnimatedPadding(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOutCubic,
                                  padding: EdgeInsets.only(
                                    bottom: _keyboardHeight > 0 ? _keyboardHeight : 0,
                                  ),
                                  child: Builder(
                                    builder: (_) {
                                      // Rebuild sections whenever the list changes
                                      if (_searchQuery.isEmpty) {
                                        _buildSections(filteredApps);
                                      }
                                      return CustomScrollView(
                                        controller: _scrollController,
                                        physics: const BouncingScrollPhysics(
                                          parent: AlwaysScrollableScrollPhysics(),
                                        ),
                                        slivers: [
                                          // Status-bar inset — only when the
                                          // search bar (which supplies its own
                                          // top padding) is hidden, so the list
                                          // never slides under the status bar.
                                          if (!_searchVisible)
                                            SliverToBoxAdapter(
                                              child: SizedBox(height: mq.padding.top),
                                            ),

                                          // Recently installed
                                          if (_searchQuery.isEmpty)
                                            ..._buildRecentlyInstalledSection(themeColor),

                                          // All apps — super_sliver_list powered
                                          SliverPadding(
                                            padding: const EdgeInsets.only(left: 24, right: 40),
                                            sliver: _buildSuperSliverAppList(filteredApps, themeColor),
                                          ),

                                          // Bottom breathing room
                                          const SliverToBoxAdapter(
                                            child: SizedBox(height: 80),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),

                                // ── Floating search button ──────────────────
                                Positioned(
                                  right: 20,
                                  bottom: 24 + mq.padding.bottom,
                                  child: _buildFloatingSearchButton(accent),
                                ),
                              ],
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
    return [
      SliverToBoxAdapter(
        child: GestureDetector(
          onTap: () => setState(() => _recentlyInstalledExpanded = !_recentlyInstalledExpanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 22, 4),
            child: Row(
              children: [
                Text(
                  'Recently installed',
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
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
                    color: accent.withValues(alpha: 0.25),
                    size: 16,
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
      // Minimal spacing instead of gradient divider
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
  }

  /// Builds the app list using a single SuperSliverList for pixel-perfect
  /// alphabet scrolling via ListController.jumpToItem.
  Widget _buildSuperSliverAppList(List<InstalledApp> apps, AppThemeColor themeColor) {
    // Search mode: simple flat list, no sections
    if (_searchQuery.isNotEmpty) {
      return SuperSliverList(
        listController: _listController,
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildAppItem(apps[index], themeColor),
          childCount: apps.length,
        ),
      );
    }

    // Normal mode: flat list with letter headers interleaved.
    // Build a flat list: [HeaderA, AppA1, AppA2, HeaderB, AppB1, ...]
    final flat = <_FlatItem>[];
    for (final sec in _sections) {
      flat.add(_FlatItem.header(sec.letter));
      for (final app in sec.apps) {
        flat.add(_FlatItem.app(app));
      }
    }

    // Update flat index to point to the HEADER row for each letter
    // so jumpToItem scrolls the header to the top.
    int idx = 0;
    _sectionFlatIndex = {};
    for (final sec in _sections) {
      _sectionFlatIndex[sec.letter] = idx; // index of header
      idx += 1 + sec.apps.length; // header + apps
    }

    return SuperSliverList(
      listController: _listController,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = flat[index];
          if (item.isHeader) {
            return _buildLetterHeader(item.letter!, themeColor);
          }
          return _buildAppItem(item.app!, themeColor);
        },
        childCount: flat.length,
      ),
    );
  }

  Widget _buildLetterHeader(String letter, AppThemeColor themeColor) {
    final accent = themeColor.color;
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 18, 0, 6),
      child: Text(
        letter,
        style: TextStyle(
          color: accent.withValues(alpha: 0.40),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          decoration: TextDecoration.none,
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

  Widget _buildFloatingSearchButton(Color accent) {
    return AnimatedOpacity(
      opacity: _searchVisible ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: _searchVisible,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            _showSearch();
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.16),
              border: Border.all(
                color: accent.withValues(alpha: 0.38),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 20,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.search_rounded,
              size: 27,
              color: accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSearchBar(AppThemeColor themeColor, MediaQueryData mq) {
    final accent = themeColor.color;
    return ListenableBuilder(
      listenable: _searchFocusNode,
      builder: (context, _) {
        final isFocused = _searchFocusNode.hasFocus;
        final hasText = _searchController.text.isNotEmpty;

        return GestureDetector(
          onTap: () {
            if (!_searchFocusNode.hasFocus) {
              _searchFocusNode.requestFocus();
            }
          },
          behavior: HitTestBehavior.translucent,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, mq.padding.top + 16, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Search icon ──
                    Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 12),
                    // ── Text field ──
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontSize: 17,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.3,
                          decoration: TextDecoration.none,
                        ),
                        textInputAction: TextInputAction.search,
                        cursorColor: accent.withValues(alpha: 0.65),
                        cursorWidth: 1.2,
                        decoration: InputDecoration(
                          hintText: 'Search apps...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(
                              alpha: isFocused ? 0.30 : 0.40,
                            ),
                            fontSize: 17,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 0.3,
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
                                    setState(() {
                                      _searchQuery = '';
                                      _hasAutoLaunched = false;
                                    });
                                  },
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: Colors.white.withValues(alpha: 0.40),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _hideSearch,
                                  child: Icon(
                                    Icons.keyboard_arrow_up_rounded,
                                    size: 18,
                                    color: Colors.white.withValues(alpha: 0.30),
                                  ),
                                ),
                          suffixIconConstraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ),
                    ),
                    // ── Settings gear (always visible) ──
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          _SmoothForwardRoute(child: const SettingsScreen()),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Icon(
                          Icons.settings_outlined,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // ── Full-width underline ──
                Container(
                  height: 1.0,
                  color: Colors.white.withValues(alpha: isFocused ? 0.35 : 0.20),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppItem(InstalledApp app, AppThemeColor themeColor) {
    final isBlocked = ref.read(appBlockRuleProvider.notifier).isAppBlocked(app.packageName);
    final itemColor = isBlocked
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.88);

    return RepaintBoundary(
      child: _ScaleTapAppItem(
        onTap: () {
          HapticFeedback.selectionClick();
          _launchApp(app.packageName);
        },
        onLongPress: () => _showAppOptions(context, app, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          child: Text(
            app.displayName,
            style: TextStyle(
              color: itemColor,
              fontSize: 16.5,
              letterSpacing: 0.1,
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

// ───────────────────────────────────────────────────────────────────
// _ScaleTapAppItem — Micro-interaction: scale-on-tap for app items
// ───────────────────────────────────────────────────────────────────

class _ScaleTapAppItem extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ScaleTapAppItem({
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_ScaleTapAppItem> createState() => _ScaleTapAppItemState();
}

class _ScaleTapAppItemState extends State<_ScaleTapAppItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
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
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// _FlatItem — tagged union for letter headers vs app items
// ═══════════════════════════════════════════════════════════════════════

class _FlatItem {
  final bool isHeader;
  final String? letter;
  final InstalledApp? app;

  const _FlatItem._({required this.isHeader, this.letter, this.app});

  factory _FlatItem.header(String letter) =>
      _FlatItem._(isHeader: true, letter: letter);

  factory _FlatItem.app(InstalledApp app) =>
      _FlatItem._(isHeader: false, app: app);
}
