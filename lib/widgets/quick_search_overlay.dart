import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/installed_app.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/recent_apps_provider.dart';
import '../providers/productivity_provider.dart';
import '../providers/launcher_page_provider.dart';
import '../providers/screen_time_provider.dart';
import '../utils/usage_permission_helper.dart';
import 'blocked_app_screen.dart';
import 'app_session_timer_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Quick Access Overlay
//
// Design language:
//  • Opens fast (280ms) with a subtle scale + fade — feels instant, not sluggish
//  • App rows stagger in with a slow-motion cascade (each 80ms apart, 400ms each)
//  • No icons — clean text-first layout
//  • Max 4 recently opened apps; up to 6 search results
//  • Thin accent bar on each row left edge
//  • Frosted glass panel, dark, minimal chrome
// ─────────────────────────────────────────────────────────────────────────────

class QuickSearchOverlay extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;
  const QuickSearchOverlay({super.key, required this.onDismiss});

  @override
  ConsumerState<QuickSearchOverlay> createState() => _QuickSearchOverlayState();
}

class _QuickSearchOverlayState extends ConsumerState<QuickSearchOverlay>
    with TickerProviderStateMixin {

  // ── Panel: fast open, smooth close ──────────────────────────────────────
  late AnimationController _panelCtrl;
  late Animation<double> _panelFade;
  late Animation<double> _panelScale;
  late Animation<double> _panelSlide; // 0 = 12px above, 1 = final position

  // ── Scrim: fades in slightly after panel ────────────────────────────────
  late AnimationController _scrimCtrl;

  // ── Row stagger: slow-motion cascade ────────────────────────────────────
  late AnimationController _staggerCtrl;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _query = '';
  bool _hasAutoLaunched = false;
  Timer? _autoLaunchTimer;

  // ── Drag-to-dismiss ──────────────────────────────────────────────────────
  double _dragStartY = 0;
  double _progressAtDragStart = 0;

  @override
  void initState() {
    super.initState();

    // Panel: 280ms — fast enough to feel instant, slow enough to feel premium
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _panelFade = CurvedAnimation(
      parent: _panelCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _panelScale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic),
    );

    _panelSlide = Tween<double>(begin: -14.0, end: 0.0).animate(
      CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic),
    );

    // Scrim: starts 60ms after panel, 220ms duration
    _scrimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    // Stagger: slow-motion, starts after panel is fully open
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _panelCtrl.forward();
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _scrimCtrl.forward();
    });
    // Stagger starts as panel finishes opening
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _staggerCtrl.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _autoLaunchTimer?.cancel();
    _panelCtrl.dispose();
    _scrimCtrl.dispose();
    _staggerCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Search ───────────────────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    if (q == _query) return;
    setState(() {
      _query = q;
      _hasAutoLaunched = false;
    });
    _staggerCtrl.reset();
    _staggerCtrl.forward();
    _autoLaunchTimer?.cancel();
    if (q.length >= 2) {
      _autoLaunchTimer = Timer(const Duration(milliseconds: 280), _checkAutoLaunch);
    }
  }

  void _checkAutoLaunch() {
    if (_hasAutoLaunched || _query.length < 2) return;
    final results = ref.read(installedAppsProvider.notifier).filterApps(_query);
    if (results.length == 1) {
      final app = results.first;
      if (ref.read(appBlockRuleProvider.notifier).isAppBlocked(app.packageName)) return;
      _hasAutoLaunched = true;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _launchApp(app);
      });
    }
  }

  // ── Launch ───────────────────────────────────────────────────────────────

  Future<void> _launchApp(InstalledApp app) async {
    _searchFocus.unfocus();
    final blocker = ref.read(appBlockRuleProvider.notifier);
    if (blocker.isAppBlocked(app.packageName)) {
      _dismiss();
      if (mounted) _showBlocked(app.appName);
      return;
    }

    final screenTime = ref.read(screenTimeProvider);
    int? timerMinutes;
    if (screenTime.featureEnabled && screenTime.hasTimerFor(app.packageName)) {
      if (!mounted) return;
      final ok = await UsagePermissionHelper.ensureGranted(context);
      if (!ok) { _dismiss(); return; }
      final config = screenTime.appConfigs[app.packageName];
      if (!mounted) return;
      final chosen = await AppSessionPrompt.show(
        context,
        packageName: app.packageName,
        appName: app.appName,
        defaultMinutes: config?.defaultMinutes ?? 15,
      );
      if (chosen == null || chosen <= 0) { _dismiss(); return; }
      timerMinutes = chosen;
    }

    ref.read(recentAppsProvider.notifier).addRecent(app.packageName);
    _dismiss();

    try {
      await const MethodChannel('com.sukoon.launcher/apps')
          .invokeMethod('launchApp', {'packageName': app.packageName});
    } catch (_) {}

    if (timerMinutes != null) {
      ref.read(screenTimeProvider.notifier).startSession(
        app.packageName, app.appName, timerMinutes,
      );
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final pc = ref.read(launcherPageControllerProvider);
      if (pc != null && pc.hasClients) {
        final cur = pc.page?.round() ?? 2;
        if (cur != 2) pc.jumpToPage(2);
      }
    });
  }

  void _showBlocked(String appName) {
    final overlay = Overlay.of(context);
    late OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => BlockedAppScreen(
        appName: appName,
        autoDismiss: true,
        onDismiss: () => e.remove(),
      ),
    );
    overlay.insert(e);
  }

  // ── Dismiss ──────────────────────────────────────────────────────────────

  void _dismiss({double velocity = 0.0}) {
    _searchFocus.unfocus();
    _scrimCtrl.reverse();
    _panelCtrl.reverse().then((_) {
      HapticFeedback.lightImpact();
      widget.onDismiss();
    });
  }

  void _onDragStart(DragStartDetails d) {
    _dragStartY = d.globalPosition.dy;
    _progressAtDragStart = _panelCtrl.value;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final delta = d.globalPosition.dy - _dragStartY;
    if (delta < 0) {
      final p = _progressAtDragStart + (delta / 400.0);
      _panelCtrl.value = p.clamp(0.0, 1.0);
      _scrimCtrl.value = p.clamp(0.0, 1.0);
    }
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0.0;
    if (v < -500 || _panelCtrl.value < 0.6) {
      _dismiss(velocity: v.abs());
    } else {
      _panelCtrl.forward();
      _scrimCtrl.forward();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final allApps = ref.watch(installedAppsProvider);
    final recentPkgs = ref.watch(recentAppsProvider);

    // Recent apps shown as chips — compact, so a fuller grid reads well.
    final recentApps = <InstalledApp>[];
    for (final pkg in recentPkgs) {
      final app = allApps.where((a) => a.packageName == pkg).firstOrNull;
      if (app != null && recentApps.length < 8) recentApps.add(app);
    }

    // Up to 8 search results
    final searchResults = _query.isEmpty
        ? <InstalledApp>[]
        : ref.read(installedAppsProvider.notifier).filterApps(_query).take(8).toList();

    final isSearching = _query.isNotEmpty;
    final displayApps = isSearching ? searchResults : recentApps;

    return Stack(
      children: [
        // ── Scrim ──────────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _scrimCtrl,
          builder: (_, __) => GestureDetector(
            onTap: _dismiss,
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Container(
              // Fully opaque once open — no home-screen content bleeds through.
              color: Colors.black.withValues(alpha: _scrimCtrl.value),
            ),
          ),
        ),

        // ── Panel ──────────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _panelCtrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _panelSlide.value),
            child: Transform.scale(
              scale: _panelScale.value,
              alignment: Alignment.topCenter,
              child: Opacity(
                opacity: _panelFade.value,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: _buildPanel(accent, displayApps, isSearching),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Panel shell ───────────────────────────────────────────────────────────

  Widget _buildPanel(Color accent, List<InstalledApp> apps, bool isSearching) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 40, 8, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search bar ──────────────────────────────────────────────
          _buildSearchBar(accent),
          const SizedBox(height: 30),

          // ── Recent apps / search results as chips ───────────────────
          if (apps.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 16),
              child: Text(
                isSearching ? 'Results' : 'Recent Apps',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Wrap(
                spacing: 10,
                runSpacing: 12,
                children: [for (final app in apps) _appChip(app, accent)],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text(
                _query.isEmpty ? 'No recent apps' : 'No apps found',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(Color accent) {
    return AnimatedBuilder(
      animation: _searchFocus,
      builder: (_, __) {
        final focused = _searchFocus.hasFocus;
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: focused
                  ? accent.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.55),
              width: focused ? 1.5 : 1.3,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                    height: 1.2,
                  ),
                  cursorColor: accent,
                  cursorWidth: 1.5,
                  cursorRadius: const Radius.circular(1),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.30),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              if (_searchCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── App chip ──────────────────────────────────────────────────────────────

  Widget _appChip(InstalledApp app, Color accent) {
    final isBlocked =
        ref.read(appBlockRuleProvider.notifier).isAppBlocked(app.packageName);

    return GestureDetector(
      onTap: () => _launchApp(app),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        child: Text(
          app.displayName,
          style: TextStyle(
            color: isBlocked
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.92),
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.1,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────

void showQuickSearchOverlay(BuildContext context) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: QuickSearchOverlay(onDismiss: () => entry.remove()),
    ),
  );
  Overlay.of(context).insert(entry);
}
