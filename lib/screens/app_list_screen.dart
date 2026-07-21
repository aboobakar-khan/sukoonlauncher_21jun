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
import 'package:url_launcher/url_launcher.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import '../widgets/pre_review_dialog.dart';
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
import '../utils/review_helper.dart';
import 'settings_screen.dart';
import 'donation_screen.dart';
import '../providers/app_folder_provider.dart';

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

  /// When true, auto-opens the search bar as soon as the screen mounts.
  /// Used when swipe-down/up from home navigates here instead of the overlay.
  final bool autoOpenSearch;

  const AppListScreen({
    super.key,
    this.isOverlay = false,
    this.autoOpenSearch = false,
  });

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

    // Auto-open search when launched from swipe gesture on home screen
    if (widget.autoOpenSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSearch();
      });
    }

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
    final onAppListPage = (page - appListIndex).abs() < 0.4;

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
            top: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
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

            // Hide app
            _optionTile(
              icon: Icons.visibility_off_outlined,
              label: 'Hide app',
              color: accent,
              subtitle: 'Remove from app list',
              onTap: () async {
                Navigator.pop(context);
                await ref.read(installedAppsProvider.notifier).hideApp(app.packageName);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${app.displayName} hidden — unhide in Settings'),
                    backgroundColor: const Color(0xFF2A2A2A),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
            ),

            // Move to folder
            if (ref.read(appFolderProvider).enabled)
              _optionTile(
                icon: Icons.folder_outlined,
                label: 'Move to folder',
                color: accent,
                subtitle: ref.read(appFolderProvider.notifier).getCategoryFor(app.packageName) ?? 'Uncategorized',
                onTap: () {
                  Navigator.pop(context);
                  _showMoveToFolderSheet(context, app, ref);
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
    // Open the system uninstall dialog — do NOT remove the app from the list
    // prematurely. The user may cancel the uninstall.
    await AppSettingsService.uninstallApp(app.packageName);
    
    // Refresh list after a delay to catch the actual uninstall result.
    // The system dialog runs in a separate activity; when the user returns
    // (whether they confirmed or cancelled), this refresh picks up the truth.
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
    final searchFilteredApps = installedAppsNotifier.filterApps(_searchQuery);
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;
    final mq = MediaQuery.of(context);

    // Folder filtering
    final folderState = ref.watch(appFolderProvider);
    final folderNotifier = ref.read(appFolderProvider.notifier);
    final filteredApps = folderNotifier.filterByActiveFolder(searchFilteredApps);

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
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Wallpaper background (only for overlay mode)
            if (widget.isOverlay) overlayBg,

            // ── Tap-anywhere-to-dismiss (overlay mode only) ──────────────
            // Full-screen transparent detector sits behind all content.
            // Tapping empty space pops the route back to home.
            if (widget.isOverlay)
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _searchFocusNode.unfocus();
                  Navigator.of(context).maybePop();
                },
              ),

            FadeTransition(
              opacity: _contentFade,
              child: EdgeToEdge(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                  // ── Status bar spacer ──
                  SizedBox(height: math.max(mq.padding.top, 32.0)),

                  // ── Folder category pills (Top of the app list, above search) ──
                  if (folderState.enabled && _searchQuery.isEmpty && allApps.isNotEmpty)
                    _buildFolderStrip(
                      themeColor,
                      folderState,
                      folderNotifier,
                      searchFilteredApps,
                      mq,
                    ),

                  // ── Top search bar — hidden by default, shown on float tap ──
                  AnimatedSize(
                    key: const ValueKey('searchBarContainer'),
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
                    key: const ValueKey('appListExpanded'),
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
                                          // Recently installed
                                          if (_searchQuery.isEmpty)
                                            ..._buildRecentlyInstalledSection(themeColor),

                                          // All apps — super_sliver_list powered
                                          SliverPadding(
                                            padding: const EdgeInsets.only(left: 24, right: 40),
                                            sliver: _buildSuperSliverAppList(filteredApps, themeColor),
                                          ),
                                          
                                          // ── App Settings & Support Links ──
                                          if (_searchQuery.isEmpty)
                                            SliverPadding(
                                              padding: const EdgeInsets.only(left: 24, right: 40, top: 16, bottom: 20),
                                              sliver: SliverToBoxAdapter(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _buildFooterButton(
                                                      context: context,
                                                      icon: Icons.groups_rounded,
                                                      label: 'Community',
                                                      onTap: () {
                                                        launchUrl(Uri.parse('https://chat.whatsapp.com/FY0RsAPri7sENTWFtxC1GK'), mode: LaunchMode.externalApplication);
                                                      },
                                                      accent: accent,
                                                    ),
                                                    _buildFooterButton(
                                                      context: context,
                                                      icon: Icons.settings_rounded,
                                                      label: 'Settings',
                                                      onTap: () => Navigator.push(context, _SmoothForwardRoute(child: const SettingsScreen())),
                                                      accent: accent,
                                                    ),
                                                    _buildFooterButton(
                                                      context: context,
                                                      icon: Icons.favorite_rounded,
                                                      label: 'Donate',
                                                      onTap: () => showDonationScreen(context),
                                                      accent: accent,
                                                    ),
                                                    _buildFooterButton(
                                                      context: context,
                                                      icon: Icons.star_rate_rounded,
                                                      label: 'Rate',
                                                      onTap: () async => await showPreReviewDialog(context, accent),
                                                      accent: accent,
                                                    ),
                                                  ],
                                                ),
                                              ),
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
    // Search mode: results in a rounded card container with dividers
    if (_searchQuery.isNotEmpty) {
      final accent = themeColor.color;
      return SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              apps.length > 8 ? 8 : apps.length, // Cap visible results
              (index) {
                final app = apps[index];
                final isBlocked = ref.read(appBlockRuleProvider.notifier).isAppBlocked(app.packageName);
                final itemColor = isBlocked
                    ? Colors.white.withValues(alpha: 0.10)
                    : accent.withValues(alpha: 0.85);
                return Column(
                  children: [
                    _ScaleTapAppItem(
                      onTap: () => _launchApp(app.packageName),
                      onLongPress: () => _showAppOptions(context, app, ref),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 15,
                        ),
                        child: Text(
                          app.displayName,
                          style: TextStyle(
                            color: itemColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.1,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Divider between items (not after last)
                    if (index < (apps.length > 8 ? 7 : apps.length - 1))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          height: 0.5,
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Capsule search bar ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: hasText
                          ? accent.withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: isFocused ? 0.15 : 0.08),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: 16,
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
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.3,
                            ),
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (val) {
                            // Update search query without removing focus
                            if (val != _searchQuery) {
                              setState(() {
                                _searchQuery = val;
                                _hasAutoLaunched = false;
                              });
                              _autoLaunchDebounce?.cancel();
                              if (val.length >= 2) {
                                _autoLaunchDebounce = Timer(
                                    const Duration(milliseconds: 300), () {
                                  _checkAutoLaunch();
                                });
                              }
                            }
                           },
                        ),
                      ),
                      if (hasText)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _hasAutoLaunched = false;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.40),
                            ),
                          ),
                        )
                      else ...[
                        GestureDetector(
                          onTap: _hideSearch,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.30),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // ── Settings gear ──
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              _SmoothForwardRoute(child: const SettingsScreen()),
                            );
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.settings_outlined,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.30),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── "Search on" action strip — animated appearance ──
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: hasText
                      ? _SearchOnStrip(
                          query: _searchQuery,
                          accent: accent,
                        )
                      : const SizedBox.shrink(),
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

  // ── Folder pill strip ────────────────────────────────────────────
  Widget _buildFolderStrip(
    AppThemeColor themeColor,
    AppFolderState folderState,
    AppFolderNotifier folderNotifier,
    List<InstalledApp> apps,
    MediaQueryData mq,
  ) {
    final accent = themeColor.color;
    final folders = folderNotifier.getActiveFolders(apps);

    // Count apps per folder for badge
    final counts = <String, int>{};
    for (final app in apps) {
      final cat = folderNotifier.getCategoryFor(app.packageName);
      if (cat != null) {
        counts[cat] = (counts[cat] ?? 0) + 1;
      }
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        height: 64, // taller strip — easier finger reach
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.fromLTRB(
            24,
            14, // extra top padding pushes pills lower in strip
            56, // leave space for alphabet sidebar
            8,
          ),
          itemCount: folders.length + 1, // +1 for "All" pill
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            // First pill is always "All"
            if (index == 0) {
              final isActive = folderState.activeFolder == null;
              return _FolderPill(
                label: 'All',
                isActive: isActive,
                accent: accent,
                onTap: () => folderNotifier.selectFolder(null),
              );
            }

            final folderName = folders[index - 1];
            final isActive = folderState.activeFolder == folderName;
            final count = counts[folderName] ?? 0;
            final isCustom = !folderNotifier.isDefaultFolder(folderName);

            return _FolderPill(
              label: folderName,
              isActive: isActive,
              accent: accent,
              count: count,
              onTap: () {
                folderNotifier.selectFolder(isActive ? null : folderName);
              },
              onLongPress: isCustom
                  ? () => _showFolderOptions(context, folderName, folderNotifier, accent)
                  : null,
            );
          },
        ),
      ),
    );
  }

  /// Long-press menu for custom (user-created) folders
  void _showFolderOptions(
    BuildContext context,
    String folderName,
    AppFolderNotifier notifier,
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                folderName,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.9),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.06), height: 24),
            _optionTile(
              icon: Icons.edit_outlined,
              label: 'Rename folder',
              color: accent,
              onTap: () {
                Navigator.pop(ctx);
                _showRenameFolderDialog(context, folderName, notifier, accent);
              },
            ),
            _optionTile(
              icon: Icons.delete_outline,
              label: 'Delete folder',
              color: const Color(0xFFEF5350),
              subtitle: 'Apps revert to auto-category',
              onTap: () async {
                Navigator.pop(ctx);
                await notifier.deleteFolder(folderName);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Rename dialog for custom folders
  void _showRenameFolderDialog(
    BuildContext context,
    String folderName,
    AppFolderNotifier notifier,
    Color accent,
  ) {
    final controller = TextEditingController(text: folderName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Rename Folder',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await notifier.renameFolder(folderName, newName);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Save', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet for choosing which folder to move an app into
  void _showMoveToFolderSheet(BuildContext context, InstalledApp app, WidgetRef ref) {
    final notifier = ref.read(appFolderProvider.notifier);
    final themeColor = ref.read(themeColorProvider);
    final accent = themeColor.color;
    final currentFolder = notifier.getCategoryFor(app.packageName);
    final allFolders = notifier.getAllFolderNames();

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Move "${app.displayName}" to…',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    // Create new folder button
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCreateFolderDialog(context, app, ref);
                      },
                      child: Icon(Icons.add, color: accent.withValues(alpha: 0.7), size: 22),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 20),
              // "None / Auto" option
              ListTile(
                leading: Icon(
                  Icons.auto_awesome_outlined,
                  color: currentFolder == null
                      ? accent
                      : Colors.white.withValues(alpha: 0.3),
                  size: 20,
                ),
                title: Text(
                  'Auto (no override)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                trailing: currentFolder == null
                    ? Icon(Icons.check_rounded, color: accent, size: 18)
                    : null,
                onTap: () async {
                  await notifier.removeAppFromFolder(app.packageName);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              // All available folders
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allFolders.length,
                  itemBuilder: (_, i) {
                    final folder = allFolders[i];
                    final isSelected = currentFolder == folder;
                    return ListTile(
                      leading: Icon(
                        Icons.folder_outlined,
                        color: isSelected
                            ? accent
                            : Colors.white.withValues(alpha: 0.3),
                        size: 20,
                      ),
                      title: Text(
                        folder,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: accent, size: 18)
                          : null,
                      onTap: () async {
                        await notifier.moveAppToFolder(app.packageName, folder);
                        if (ctx.mounted) Navigator.pop(ctx);
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

  /// Create a brand-new custom folder and immediately assign this app to it
  void _showCreateFolderDialog(BuildContext context, InstalledApp app, WidgetRef ref) {
    final notifier = ref.read(appFolderProvider.notifier);
    final themeColor = ref.read(themeColorProvider);
    final accent = themeColor.color;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'New Folder',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'e.g. Work, Studies, Fun…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent.withValues(alpha: 0.25)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await notifier.createFolder(name);
                await notifier.moveAppToFolder(app.packageName, name);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('Create', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return _ScaleTapAppItem(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.88)),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 16.5,
                letterSpacing: 0.1,
                fontWeight: FontWeight.w300,
                decoration: TextDecoration.none,
              ),
            ),
          ],
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
// _GlassSearchButton — flat minimalist FAB, no glow, no gradient
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
    const size = 56.0; // bigger tap target

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: Duration(milliseconds: _pressed ? 80 : 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: _pressed ? 0.12 : 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.search_rounded,
              size: 28, // larger icon
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// _FolderPill — Minimalist pill chip for the folder category strip
// ═══════════════════════════════════════════════════════════════════════

class _FolderPill extends StatefulWidget {
  final String label;
  final bool isActive;
  final Color accent;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FolderPill({
    required this.label,
    required this.isActive,
    required this.accent,
    required this.onTap,
    this.count = 0,
    this.onLongPress,
  });

  @override
  State<_FolderPill> createState() => _FolderPillState();
}

class _FolderPillState extends State<_FolderPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.isActive;
    final accent = widget.accent;

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            // Active: soft accent fill; Inactive: very subtle frosted
            color: isActive
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.45),
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w300,
                letterSpacing: 0.3,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// _SearchOnStrip — "Search on" action pills (Web, Contacts, Map, Call)
// Appears below the search bar when the user types a query.
// Staggered scale+fade animation for each pill.
// ═══════════════════════════════════════════════════════════════════════

class _SearchOnStrip extends StatefulWidget {
  final String query;
  final Color accent;

  const _SearchOnStrip({required this.query, required this.accent});

  @override
  State<_SearchOnStrip> createState() => _SearchOnStripState();
}

class _SearchOnStripState extends State<_SearchOnStrip>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerCtrl;

  static const _actions = [
    (icon: Icons.language_rounded, label: 'Web'),
    (icon: Icons.contacts_outlined, label: 'Contacts'),
    (icon: Icons.map_outlined, label: 'Map'),
    (icon: Icons.call_outlined, label: 'Call'),
  ];

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  void _handleAction(String label) {
    final q = Uri.encodeComponent(widget.query);
    switch (label) {
      case 'Web':
        launchUrl(
          Uri.parse('https://www.google.com/search?q=$q'),
          mode: LaunchMode.externalApplication,
        );
        break;
      case 'Contacts':
        launchUrl(
          Uri.parse('content://com.android.contacts/contacts'),
          mode: LaunchMode.externalApplication,
        );
        break;
      case 'Map':
        launchUrl(
          Uri.parse('geo:0,0?q=$q'),
          mode: LaunchMode.externalApplication,
        );
        break;
      case 'Call':
        launchUrl(
          Uri.parse('tel:${widget.query}'),
          mode: LaunchMode.externalApplication,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "✦ Search on" label
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: accent.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                Text(
                  'Search on',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Action pills row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_actions.length, (i) {
              final action = _actions[i];
              // Stagger: each pill starts after 50ms × index
              final begin = (i * 0.15).clamp(0.0, 0.6);
              final end = (begin + 0.5).clamp(0.0, 1.0);
              final animation = CurvedAnimation(
                parent: _staggerCtrl,
                curve: Interval(begin, end, curve: Curves.easeOutBack),
              );

              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.scale(
                  scale: 0.6 + (0.4 * animation.value),
                  child: Opacity(
                    opacity: animation.value,
                    child: child,
                  ),
                ),
                child: _SearchActionPill(
                  icon: action.icon,
                  label: action.label,
                  accent: accent,
                  onTap: () => _handleAction(action.label),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// _SearchActionPill — Individual action pill with scale-on-tap
// ═══════════════════════════════════════════════════════════════════════

class _SearchActionPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _SearchActionPill({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_SearchActionPill> createState() => _SearchActionPillState();
}

class _SearchActionPillState extends State<_SearchActionPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _tapCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    return GestureDetector(
      onTapDown: (_) => _tapCtrl.forward(),
      onTapUp: (_) {
        _tapCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: accent.withValues(alpha: 0.10),
            border: Border.all(
              color: accent.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: accent.withValues(alpha: 0.75)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: accent.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
