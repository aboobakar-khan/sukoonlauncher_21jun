import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/notification_filter_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../services/native_app_blocker_service.dart';

/// Unified Notifications screen — title "Notifications", two tabs:
///  TAB 0 — FILTERED NOTIFICATIONS  (intercepted/blocked apps' notifs)
///  TAB 1 — SETTINGS               (master toggle + per-app allow-list)
class NotificationFeedScreen extends ConsumerStatefulWidget {
  const NotificationFeedScreen({super.key});

  @override
  ConsumerState<NotificationFeedScreen> createState() =>
      _NotificationFeedScreenState();
}

class _NotificationFeedScreenState extends ConsumerState<NotificationFeedScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _recheckPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start on the FILTERED NOTIFICATIONS tab (index 0)
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase().trim());
    });
    // Refresh notifications immediately when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationFilterProvider.notifier).refreshNotifications();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed && _recheckPending) {
      _recheckPending = false;
      ref.read(notificationFilterProvider.notifier).recheckPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            size: 22,
            color: accent.withValues(alpha: 0.7),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: accent,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.10)),
          // ── Tab bar ──
          TabBar(
            controller: _tabController,
            labelColor: accent,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.35),
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
            indicatorColor: accent,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'FILTERED NOTIFICATIONS'),
              Tab(text: 'SETTINGS'),
            ],
          ),
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.10)),
          // ── Tab content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FeedTab(
                  accent: accent,
                            onGoToSettings: () => _tabController.animateTo(1),
                  onRequestAccess: () => setState(() => _recheckPending = true),
                ),
                _SettingsTab(
                  accent: accent,
                            searchController: _searchController,
                  searchQuery: _searchQuery,
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 0 — FILTERED NOTIFICATIONS
// ─────────────────────────────────────────────────────────────────────────────

class _FeedTab extends ConsumerStatefulWidget {
  final Color accent;
  final VoidCallback onGoToSettings;
  final VoidCallback onRequestAccess;

  const _FeedTab({
    required this.accent,
    required this.onGoToSettings,
    required this.onRequestAccess,
  });

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab> {
  // Keeps the current sorted notif list accessible to helper methods.
  List<CapturedNotification> _notifs = [];

  /// Confirmation dialog before clearing all notifications.
  Future<bool?> _confirmClearAll() {
    final count = _notifs.length;
    final accent = widget.accent;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear all notifications?',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Text(
          'All $count filtered notification${count == 1 ? '' : 's'} will be removed.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear all',
              style: TextStyle(color: accent),
            ),
          ),
        ],
      ),
    );
  }

  /// Confirmation dialog before deleting a single notification via swipe.
  Future<bool?> _confirmDeleteOne(CapturedNotification notif) {
    final title = notif.title.isNotEmpty ? notif.title : notif.appName;
    final accent = widget.accent;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove notification?',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Text(
          '"$title" will be removed from your feed.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: TextStyle(color: accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationFilterProvider);
    final accent = widget.accent;

    if (!state.featureEnabled) {
      return _CenteredMessage(
        icon: Icons.notifications_paused_outlined,
        accent: accent,
        title: 'Filter not active',
        subtitle: 'Enable the notification filter\nin the Settings tab.',
        actionLabel: 'Go to Settings',
        onAction: widget.onGoToSettings,
      );
    }

    if (!state.hasPermission) {
      return _CenteredMessage(
        icon: Icons.notifications_off_outlined,
        accent: accent,
        title: 'Notification access needed',
        subtitle: 'Grant access so Sukoon can\nhold selected notifications.',
        actionLabel: 'Grant Access',
        onAction: () {
          HapticFeedback.mediumImpact();
          widget.onRequestAccess();
          NativeAppBlockerService.requestNotificationListenerPermission();
        },
      );
    }

    // Flat list sorted newest-first; keep accessible for confirm dialogs.
    _notifs = [...state.filteredNotifications]
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));

    return Column(
      children: [
        // ── Notification list or empty ──
        Expanded(
          child: _notifs.isEmpty
              ? _CenteredMessage(
                  icon: Icons.inbox_outlined,
                  accent: accent,
                  title: 'No filtered notifications',
                  subtitle: 'Notifications from blocked apps\nwill appear here.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 4, bottom: 20),
                  itemCount: _notifs.length,
                  separatorBuilder: (context, index) => Container(
                    height: 0.5,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (ctx, i) => _NotifTile(
                    notif: _notifs[i],
                    accent: accent,
                    onConfirmDismiss: (notif) => _confirmDeleteOne(notif),
                    onClear: (key) => ref
                        .read(notificationFilterProvider.notifier)
                        .dismissNotification(key),
                    onTapDismiss: (key) => ref
                        .read(notificationFilterProvider.notifier)
                        .dismissNotification(key),
                  ),
                ),
        ),

        // ── Bottom "Clear all" bar ──
        Container(height: 0.5, color: Colors.white.withValues(alpha: 0.10)),
        SafeArea(
          top: false,
          child: GestureDetector(
            onTap: _notifs.isEmpty
                ? null
                : () async {
                    HapticFeedback.mediumImpact();
                    final confirmed = await _confirmClearAll();
                    if (confirmed == true && mounted) {
                      ref
                          .read(notificationFilterProvider.notifier)
                          .dismissAll();
                    }
                  },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _notifs.isEmpty
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 22,
                    color: _notifs.isEmpty
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — SETTINGS
// Master toggle + per-app allow-list with search
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTab extends ConsumerStatefulWidget {
  final Color accent;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onClearSearch;

  const _SettingsTab({
    required this.accent,
    required this.searchController,
    required this.searchQuery,
    required this.onClearSearch,
  });

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  bool _searchVisible = false;
  late final FocusNode _searchFocus;

  @override
  void initState() {
    super.initState();
    _searchFocus = FocusNode();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchVisible = true);
    // Focus after frame so the field is rendered first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    widget.onClearSearch();
    _searchFocus.unfocus();
    setState(() => _searchVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationFilterProvider);
    final allApps = ref.watch(installedAppsProvider);
    final accent = widget.accent;
    final searchQuery = widget.searchQuery;

    final visibleApps = searchQuery.isEmpty
        ? allApps
        : allApps
            .where((a) => a.appName.toLowerCase().contains(searchQuery))
            .toList();

    // Sort: allowed (toggle ON) apps first, then alphabetical within each group
    final sortedApps = [...visibleApps]..sort((a, b) {
      final aAllowed = state.allowedPackages.contains(a.packageName);
      final bAllowed = state.allowedPackages.contains(b.packageName);
      if (aAllowed && !bAllowed) return -1;
      if (!aAllowed && bAllowed) return 1;
      return a.appName.toLowerCase().compareTo(b.appName.toLowerCase());
    });

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // ── Master toggle row ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification filter active',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ongoing notifications will not be filtered.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: state.featureEnabled,
                activeThumbColor: accent,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  ref.read(notificationFilterProvider.notifier).setEnabled(v);
                },
              ),
            ],
          ),
        ),

        // ── Divider ──
        Container(height: 0.5, color: Colors.white.withValues(alpha: 0.08)),

        // ── App list — only shown when filter is ON and permission is granted ──
        if (!state.featureEnabled) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 48),
            child: Column(
              children: [
                Icon(Icons.notifications_paused_outlined,
                    size: 48, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 16),
                Text('Filter is turned off',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.35))),
                const SizedBox(height: 8),
                Text(
                  'Turn on the notification filter above\nto manage per-app notifications.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.20),
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ] else if (!state.hasPermission) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 48),
            child: Column(
              children: [
                Icon(Icons.notifications_off_outlined,
                    size: 48, color: Colors.white.withValues(alpha: 0.08)),
                const SizedBox(height: 16),
                Text('Notification access required',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.35))),
                const SizedBox(height: 8),
                Text(
                  'Grant notification access so Sukoon can\nfilter and manage per-app notifications.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.20),
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    NativeAppBlockerService.requestNotificationListenerPermission();
                    Future.delayed(const Duration(seconds: 2), () {
                      ref.read(notificationFilterProvider.notifier).recheckPermission();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.2), width: 0.5),
                    ),
                    child: Text('Grant Access',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: accent)),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // ── "Allow notifications from" header — full row tappable ──
          GestureDetector(
            onTap: _searchVisible ? _closeSearch : _openSearch,
            behavior: HitTestBehavior.opaque,
            child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Allow notifications from',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ),
                // Icon still animates between search/close
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _searchVisible
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      key: ValueKey(_searchVisible),
                      size: 22,
                      color: _searchVisible
                          ? accent.withValues(alpha: 0.7)
                          : accent.withValues(alpha: 0.50),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'ON = passes through · OFF = held in your feed',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.22),
              ),
            ),
          ),

          // ── Search field — animated in/out ──
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: _searchVisible
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: TextField(
                      controller: widget.searchController,
                      focusNode: _searchFocus,
                      autofocus: false,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search apps…',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  widget.onClearSearch();
                                  _searchFocus.requestFocus();
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.white.withValues(alpha: 0.4),
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: accent.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ── Divider above app list ──
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.08)),

          // ── No results message ──
          if (searchQuery.isNotEmpty && sortedApps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No apps match "$searchQuery"',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
            ),

          // ── App rows ──
          ...sortedApps.map((app) {
            final allowed = state.allowedPackages.contains(app.packageName);
            return _AppRow(
              appName: app.appName,
              allowed: allowed,
              accent: accent,
              onToggle: () {
                HapticFeedback.selectionClick();
                ref
                    .read(notificationFilterProvider.notifier)
                    .toggleApp(app.packageName);
              },
            );
          }),
        ],

        const SizedBox(height: 40),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _CenteredMessage({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.white.withValues(alpha: 0.12)),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.22),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onAction,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.25), width: 0.5),
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  final String appName;
  final bool allowed;
  final Color accent;
  final VoidCallback onToggle;

  const _AppRow({
    required this.appName,
    required this.allowed,
    required this.accent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Text(
                appName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white
                      .withValues(alpha: allowed ? 0.88 : 0.35),
                ),
              ),
            ),
            Switch.adaptive(
              value: allowed,
              activeThumbColor: accent,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final CapturedNotification notif;
  final Color accent;
  /// Called when swipe confirm returns true — parent deletes by key.
  final void Function(String key) onClear;
  /// Called by Dismissible's confirmDismiss to show the delete dialog.
  final Future<bool?> Function(CapturedNotification notif) onConfirmDismiss;
  /// Called after the notification intent is opened so the parent can
  /// remove it from the Riverpod list immediately (optimistic dismiss).
  final void Function(String key) onTapDismiss;

  const _NotifTile({
    required this.notif,
    required this.accent,
    required this.onClear,
    required this.onConfirmDismiss,
    required this.onTapDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notif.key),
      direction: DismissDirection.endToStart,
      // confirmDismiss shows the dialog BEFORE the item is removed.
      // Returning false snaps the tile back; true lets it fly away.
      confirmDismiss: (_) => onConfirmDismiss(notif),
      onDismissed: (_) => onClear(notif.key),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: accent.withValues(alpha: 0.10),
        child: Icon(Icons.delete_outline_rounded,
            size: 20, color: accent.withValues(alpha: 0.60)),
      ),
      // Material gives the tile its own gesture arena entry so taps are
      // never swallowed by the Dismissible's drag recogniser.
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            HapticFeedback.selectionClick();
            // Fire the original notification deep-link / app launcher.
            // We intentionally do NOT remove the notification from the feed
            // after opening — the user may want to re-read or re-open it.
            // Notifications can only be dismissed via swipe or "Clear all".
            await NativeAppBlockerService.openNotificationIntent(notif.key);
          },
          splashColor: Colors.white.withValues(alpha: 0.04),
          highlightColor: Colors.white.withValues(alpha: 0.03),
          child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App name + time ──
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notif.appName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(notif.postedAt),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                ],
              ),
              // ── Title ──
              if (notif.title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  notif.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // ── Body ──
              if (notif.text.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  notif.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.40),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),   // InkWell
    ),     // Material
    );     // Dismissible
  }

  /// HH:mm for today, "Yesterday HH:mm" for yesterday, else "d MMM HH:mm"
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notifDay = DateTime(time.year, time.month, time.day);
    final hhmm = DateFormat('HH:mm');

    if (notifDay == today) {
      return hhmm.format(time);
    } else if (notifDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${hhmm.format(time)}';
    } else {
      return DateFormat('d MMM HH:mm').format(time);
    }
  }
}
