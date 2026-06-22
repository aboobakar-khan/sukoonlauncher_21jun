import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
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

  void _scrollToLetter(String letter) {
    final targetIndex = _sectionFlatIndex[letter];
    if (targetIndex == null || !_scrollController.hasClients) return;
    _listController.jumpToItem(
      index: targetIndex,
      scrollController: _scrollController,
      alignment: 0.0,
    );
  }



  Widget _buildAlphabetSidebar(List<InstalledApp> filteredApps, AppThemeColor themeColor) {
    return _AlphabetSidebar(
      apps: filteredApps,
      accent: themeColor.color,
      scrollController: _scrollController,
      onScrollToLetter: (letter, apps) {
        _scrollToLetter(letter);
      },
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

                                // Alphabet sidebar — right edge only
                                if (_searchQuery.isEmpty)
                                  _buildAlphabetSidebar(filteredApps, themeColor),

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

    // Normal mode: a clean flat list of apps — no inline letter headers.
    // (Fast scrolling is handled by the A–Z sidebar on the right edge.)
    final flat = <_FlatItem>[];
    for (final sec in _sections) {
      for (final app in sec.apps) {
        flat.add(_FlatItem.app(app));
      }
    }

    // Flat index points to the FIRST app of each letter so the alphabet
    // sidebar's jumpToItem lands on the right section.
    int idx = 0;
    _sectionFlatIndex = {};
    for (final sec in _sections) {
      _sectionFlatIndex[sec.letter] = idx;
      idx += sec.apps.length;
    }

    return SuperSliverList(
      listController: _listController,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return _buildAppItem(flat[index].app!, themeColor);
        },
        childCount: flat.length,
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
        child: _GlassSearchButton(accent: accent, onTap: _showSearch),
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


//  Gaussian wave push: selected letter + neighbours push LEFT with
//  a smooth bell-curve. Dynamic vertical repositioning follows
//  finger if dragged outside boundaries. Circle indicator.
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
    with SingleTickerProviderStateMixin {
  static const _kLetterHeight = 20.0;
  static const _kStripWidth = 42.0;

  static const _allLetters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
    'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
    'U', 'V', 'W', 'X', 'Y', 'Z', '#',
  ];

  late AnimationController _controller;
  late Set<String> _availableLetters;

  final GlobalKey _columnKey = GlobalKey();

  String _selectedLetter = '';
  bool _isDragging = false;
  Offset _dragPosition = Offset.zero;
  int _selectedIndex = -1;


  @override
  void initState() {
    super.initState();
    _buildAvailableLetters();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant _AlphabetSidebar old) {
    super.didUpdateWidget(old);
    if (old.apps != widget.apps) _buildAvailableLetters();
  }

  void _buildAvailableLetters() {
    final set = <String>{};
    for (final app in widget.apps) {
      if (app.appName.isEmpty) continue;
      final first = app.appName[0].toUpperCase();
      if (RegExp(r'[A-Z]').hasMatch(first)) {
        set.add(first);
      }
    }
    _availableLetters = set;
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Resolve to nearest available letter (data-driven) ──
  // Finds the closest letter that actually has apps, walking outward
  // from the selected position in both directions.
  String _resolveNearest(String letter) {
    if (_availableLetters.contains(letter)) return letter;
    if (_availableLetters.isEmpty) return letter;
    final idx = _allLetters.indexOf(letter);
    // Walk outward from idx: check idx-1, idx+1, idx-2, idx+2, ...
    for (int delta = 1; delta < _allLetters.length; delta++) {
      final before = idx - delta;
      final after = idx + delta;
      if (before >= 0 && _availableLetters.contains(_allLetters[before])) {
        return _allLetters[before];
      }
      if (after < _allLetters.length && _availableLetters.contains(_allLetters[after])) {
        return _allLetters[after];
      }
    }
    return letter;
  }

  // ── Drag handlers ──
  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _updateSelectionFromPosition(details.globalPosition);
    });
    HapticFeedback.selectionClick();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _updateSelectionFromPosition(details.globalPosition);
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      _selectedIndex = -1;
      _selectedLetter = '';
    });
    _controller.forward(from: 0.0);
  }

  void _updateSelectionFromPosition(Offset globalPosition) {
    final RenderBox? box =
        _columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final localPos = box.globalToLocal(globalPosition);
    final totalHeight = _kLetterHeight * _allLetters.length;
    final startY = (box.size.height - totalHeight) / 2;

    // Compute which letter index the finger is on — from local position
    int index = ((localPos.dy - startY) / _kLetterHeight).floor();
    index = index.clamp(0, _allLetters.length - 1);

    // Map index → letter, then resolve to nearest letter that has apps
    final rawLetter = _allLetters[index];
    final resolved = _resolveNearest(rawLetter);
    final prevLetter = _selectedLetter;

    setState(() {
      _dragPosition = globalPosition;
      _selectedLetter = resolved;
      _selectedIndex = _allLetters.indexOf(resolved);
    });

    // Only fire scroll + haptic when letter actually changes
    if (resolved != prevLetter) {
      HapticFeedback.selectionClick();
      widget.onScrollToLetter(resolved, widget.apps);
    }
  }

  // ── Gaussian bell-curve offset ──
  double _calculateOffset(int index) {
    if (!_isDragging || _selectedIndex == -1) return 0.0;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final distance = (index - _selectedIndex).abs();

    // Right-aligned: letters push LEFT (negative offset)
    final maxOffset = (screenWidth - _dragPosition.dx + 60).clamp(
      0.0,
      screenWidth - 100,
    );

    // Gaussian bell: divisor controls curve width
    final divisor = ((screenWidth - _dragPosition.dx) / 4.0) + 12.0;
    final gaussian = math.exp(-(math.pow(distance, 2) / divisor));
    final offset = maxOffset * gaussian;

    return -offset; // Negative = push LEFT from right edge
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;

    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: Container(
          width: _kStripWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.transparent),
          ),
          child: Stack(
            alignment: Alignment.centerRight,
            clipBehavior: Clip.none,
            children: [
              // Letter column — AnimatedPositioned for dynamic vertical shift
              AnimatedPositioned(
                duration: const Duration(milliseconds: 50),
                right: 0,
                top: 0,
                bottom: 0,
                child: Column(
                  key: _columnKey,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_allLetters.length, (index) {
                    final letter = _allLetters[index];
                    final isSelected = letter == _selectedLetter && _isDragging;
                    final hasApps = _availableLetters.contains(letter);

                    // Opacity: selected = bright, nearby = moderate, far = dim
                    double alpha;
                    if (isSelected) {
                      alpha = 1.0;
                    } else if (_isDragging) {
                      final dist = (_selectedIndex - index).abs();
                      alpha = (0.15 + 0.40 * math.exp(-dist * 0.4)).clamp(0.0, 1.0);
                    } else {
                      alpha = hasApps ? 0.45 : 0.18;
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 50),
                      width: _kStripWidth,
                      height: _kLetterHeight,
                      padding: const EdgeInsets.only(right: 10),
                      transform: Matrix4.translationValues(
                        _calculateOffset(index),
                        0,
                        0,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: isSelected ? 18 : 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected
                                ? widget.accent
                                : Colors.white.withValues(alpha: alpha),
                            height: 1.0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // ── Floating circle indicator ──
              if (_isDragging && _selectedIndex != -1)
                Positioned(
                  right: 30 + _calculateOffset(_selectedIndex).abs(),
                  top: (_dragPosition.dy - 25 - mq.padding.top - 70)
                      .clamp(0.0, screenH - 100),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.50),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accent.withValues(alpha: 0.10),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _selectedLetter,
                        style: TextStyle(
                          color: widget.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                          decoration: TextDecoration.none,
                        ),
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

// ═══════════════════════════════════════════════════════════════════════
// _GlassSearchButton — frosted-glass FAB with iOS spring-press animation
// ═══════════════════════════════════════════════════════════════════════

class _GlassSearchButton extends StatefulWidget {
  final Color accent;
  final VoidCallback onTap;
  const _GlassSearchButton({required this.accent, required this.onTap});

  @override
  State<_GlassSearchButton> createState() => _GlassSearchButtonState();
}

class _GlassSearchButtonState extends State<_GlassSearchButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    const size = 62.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        // Quick press-in, springy release for that tactile iOS feel.
        scale: _pressed ? 0.88 : 1.0,
        duration: Duration(milliseconds: _pressed ? 90 : 320),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Soft ambient float
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.38),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              // Subtle accent glow so it stays discoverable
              BoxShadow(
                color: accent.withValues(alpha: _pressed ? 0.32 : 0.20),
                blurRadius: 22,
                spreadRadius: -4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Frosted glass: bright top-left highlight fading into an
                  // accent-tinted base.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.24),
                      accent.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.search_rounded,
                    size: 26,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
