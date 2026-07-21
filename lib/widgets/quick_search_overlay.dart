import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Capsule search bar ───────────────────────────────────
            _buildSearchBar(accent),

            // ── "Search on" action strip — only when typing ──────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: isSearching
                  ? _buildSearchOnStrip(accent)
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 12),

            // ── Search results / recent apps ────────────────────────
            if (apps.isNotEmpty)
              _buildResultsCard(apps, accent, isSearching)
            else if (!isSearching)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  'No recent apps',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.30),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),

            // ── Search elsewhere: web · Play Store · AI ─────────────
            if (isSearching) ...[
              SizedBox(height: apps.isEmpty ? 4 : 16),
              _buildSearchActions(accent),
            ],
          ],
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────

  Widget _buildSearchBar(Color accent) {
    return AnimatedBuilder(
      animation: _searchFocus,
      builder: (_, __) {
        final focused = _searchFocus.hasFocus;
        final hasText = _searchCtrl.text.isNotEmpty;
        return Container(
          margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: hasText
                  ? accent.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: focused ? 0.20 : 0.10),
              width: 1,
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
                    fontWeight: FontWeight.w300,
                    decoration: TextDecoration.none,
                    height: 1.2,
                  ),
                  cursorColor: accent.withValues(alpha: 0.65),
                  cursorWidth: 1.2,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.30),
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    _onSearchChanged('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── "Search on" strip ─────────────────────────────────────────────────────

  Widget _buildSearchOnStrip(Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _searchOnPill(Icons.language_rounded, 'Web', accent, _searchWeb),
              _searchOnPill(Icons.contacts_outlined, 'Contacts', accent, () {
                _dismiss();
                launchUrl(
                  Uri.parse('content://com.android.contacts/contacts'),
                  mode: LaunchMode.externalApplication,
                );
              }),
              _searchOnPill(Icons.map_outlined, 'Map', accent, () {
                _dismiss();
                final q = Uri.encodeComponent(_query);
                launchUrl(
                  Uri.parse('geo:0,0?q=$q'),
                  mode: LaunchMode.externalApplication,
                );
              }),
              _searchOnPill(Icons.call_outlined, 'Call', accent, () {
                _dismiss();
                launchUrl(
                  Uri.parse('tel:$_query'),
                  mode: LaunchMode.externalApplication,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchOnPill(IconData icon, String label, Color accent, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
            Icon(icon, size: 15, color: accent.withValues(alpha: 0.75)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent.withValues(alpha: 0.85),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Vertical results card ─────────────────────────────────────────────────

  Widget _buildResultsCard(List<InstalledApp> apps, Color accent, bool isSearching) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
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
        children: List.generate(apps.length, (i) {
          final app = apps[i];
          final isBlocked = ref.read(appBlockRuleProvider.notifier).isAppBlocked(app.packageName);
          final itemColor = isBlocked
              ? Colors.white.withValues(alpha: 0.15)
              : accent.withValues(alpha: 0.85);

          return Column(
            children: [
              GestureDetector(
                onTap: () => _launchApp(app),
                behavior: HitTestBehavior.opaque,
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
              if (i < apps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    height: 0.5,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  // ── Search-elsewhere actions ────────────────────────────────────────────────
  // Shown while the user is typing: escalate from on-device apps to the web,
  // the Play Store, or an installed AI assistant. Mirrors Spotlight's pattern of
  // listing apps first, then "search elsewhere" at the bottom.

  static const List<_AiAssistant> _aiAssistants = [
    _AiAssistant('ChatGPT', 'com.openai.chatgpt'),
    _AiAssistant('Gemini', 'com.google.android.apps.bard'),
    _AiAssistant('Claude', 'com.anthropic.claude'),
  ];

  Widget _buildSearchActions(Color accent) {
    final allApps = ref.read(installedAppsProvider);
    final installedAi = _aiAssistants
        .where((a) => allApps.any((app) => app.packageName == a.package))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          color: Colors.white.withValues(alpha: 0.06),
        ),
        _searchActionRow(
          icon: Icons.travel_explore_rounded,
          label: 'Search the web',
          onTap: _searchWeb,
        ),
        _searchActionRow(
          icon: Icons.shopping_bag_outlined,
          label: 'Search Play Store',
          onTap: _searchPlayStore,
        ),
        if (installedAi.isNotEmpty) _aiActionRow(installedAi, accent),
      ],
    );
  }

  Widget _searchActionRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        child: Row(
          children: [
            Icon(icon, size: 19, color: Colors.white.withValues(alpha: 0.50)),
            const SizedBox(width: 14),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                  children: [
                    TextSpan(text: '$label  '),
                    TextSpan(
                      text: '“$_query”',
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.40)),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.north_east_rounded,
                size: 15, color: Colors.white.withValues(alpha: 0.28)),
          ],
        ),
      ),
    );
  }

  Widget _aiActionRow(List<_AiAssistant> ai, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: 19, color: accent.withValues(alpha: 0.85)),
          const SizedBox(width: 14),
          Text(
            'Ask',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final a in ai) _aiChip(a, accent)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiChip(_AiAssistant a, Color accent) {
    return GestureDetector(
      onTap: () => _launchPackage(a.package),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.28), width: 0.8),
        ),
        child: Text(
          a.name,
          style: TextStyle(
            color: accent.withValues(alpha: 0.95),
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  // ── Action handlers ─────────────────────────────────────────────────────────

  Future<void> _searchWeb() async {
    final q = _query.trim();
    if (q.isEmpty) return;
    _dismiss();
    try {
      await launchUrl(
        Uri.parse(
            'https://www.google.com/search?q=${Uri.encodeQueryComponent(q)}'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _searchPlayStore() async {
    final q = _query.trim();
    if (q.isEmpty) return;
    _dismiss();
    try {
      final market =
          Uri.parse('market://search?q=${Uri.encodeQueryComponent(q)}&c=apps');
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(
          Uri.parse(
              'https://play.google.com/store/search?q=${Uri.encodeQueryComponent(q)}&c=apps'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {}
  }

  Future<void> _launchPackage(String packageName) async {
    _searchFocus.unfocus();
    _dismiss();
    try {
      await const MethodChannel('com.sukoon.launcher/apps')
          .invokeMethod('launchApp', {'packageName': packageName});
    } catch (_) {}
  }
}

/// One supported AI assistant and the Android package used to detect / launch it.
class _AiAssistant {
  final String name;
  final String package;
  const _AiAssistant(this.name, this.package);
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
