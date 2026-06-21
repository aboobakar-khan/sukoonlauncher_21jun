import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_filter_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../services/native_app_blocker_service.dart';

/// Notification Filter — two-tab layout:
///   Tab 0: Filtered Notifications (suppressed feed)
///   Tab 1: Settings (master toggle + app allow-list)
class NotificationFilterSettingsScreen extends ConsumerStatefulWidget {
  const NotificationFilterSettingsScreen({super.key});

  @override
  ConsumerState<NotificationFilterSettingsScreen> createState() =>
      _NotificationFilterSettingsScreenState();
}

class _NotificationFilterSettingsScreenState
    extends ConsumerState<NotificationFilterSettingsScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 1);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationFilterProvider.notifier).recheckPermission();
      }
    });
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationFilterProvider.notifier).recheckPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final filterState = ref.watch(notificationFilterProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(accent),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FilteredNotificationsTab(
            filterState: filterState,
            accent: accent,
          ),
          _SettingsTab(
            filterState: filterState,
            accent: accent,
            searchController: _searchController,
            searchQuery: _searchQuery,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color accent) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          size: 18,
          color: Colors.white.withValues(alpha: 0.55),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Notifications',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(49),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.12)),
            TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.35),
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
              ),
              indicatorColor: Colors.white,
              indicatorWeight: 2,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'FILTERED NOTIFICATIONS'),
                Tab(text: 'SETTINGS'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 0 — Filtered Notifications feed
// ═══════════════════════════════════════════════════════════════════

class _FilteredNotificationsTab extends ConsumerWidget {
  final NotificationFilterState filterState;
  final Color accent;

  const _FilteredNotificationsTab({
    required this.filterState,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = filterState.groupedNotifications;

    return Column(
      children: [
        Expanded(
          child: groups.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: groups.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    return _NotificationGroupTile(group: g, accent: accent);
                  },
                ),
        ),
        if (groups.isNotEmpty) ...[
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          _ClearAllBar(
            accent: accent,
            onClear: () {
              ref.read(notificationFilterProvider.notifier).dismissAll();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          'Filtered notifications from apps that are not allowed will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _NotificationGroupTile extends StatelessWidget {
  final NotificationGroup group;
  final Color accent;

  const _NotificationGroupTile({required this.group, required this.accent});

  @override
  Widget build(BuildContext context) {
    final latest = group.notifications.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.appName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (group.count > 1) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${group.count}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                _formatTime(latest.postedAt),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (latest.title.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              latest.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
          ],
          if (latest.text.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              latest.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ClearAllBar extends StatelessWidget {
  final Color accent;
  final VoidCallback onClear;

  const _ClearAllBar({required this.accent, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClear,
      behavior: HitTestBehavior.opaque,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              const Text(
                'Clear all',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.delete_outline_rounded,
                size: 22,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 1 — Settings
// ═══════════════════════════════════════════════════════════════════

class _SettingsTab extends ConsumerWidget {
  final NotificationFilterState filterState;
  final Color accent;
  final TextEditingController searchController;
  final String searchQuery;

  const _SettingsTab({
    required this.filterState,
    required this.accent,
    required this.searchController,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allApps = ref.watch(installedAppsProvider);

    // Allowed apps first (alphabetical), then not-allowed (alphabetical)
    final allowed = allApps
        .where((a) => filterState.allowedPackages.contains(a.packageName))
        .toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    final notAllowed = allApps
        .where((a) => !filterState.allowedPackages.contains(a.packageName))
        .toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

    List<dynamic> items;
    if (searchQuery.isNotEmpty) {
      final matched = allApps
          .where((a) => a.displayName.toLowerCase().contains(searchQuery))
          .toList()
        ..sort((a, b) {
          final aAllowed = filterState.allowedPackages.contains(a.packageName);
          final bAllowed = filterState.allowedPackages.contains(b.packageName);
          if (aAllowed != bAllowed) return aAllowed ? -1 : 1;
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        });
      items = matched;
    } else {
      items = [...allowed, ...notAllowed];
    }

    return Column(
      children: [
        // Master toggle
        _MasterToggleRow(
          enabled: filterState.featureEnabled,
          accent: accent,
          onChanged: (v) {
            ref.read(notificationFilterProvider.notifier).setEnabled(v);
          },
        ),

        // Permission banner (only when no permission)
        if (filterState.featureEnabled && !filterState.hasPermission)
          _PermissionBanner(),

        // "Allow notifications from" header + search
        _AllowFromHeader(
          accent: accent,
          searchController: searchController,
        ),

        Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),

        // App list — allowed first, then rest, both alphabetical
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 40),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final app = items[i];
              final isAllowed = filterState.allowedPackages.contains(app.packageName);
              return _AppToggleRow(
                appName: app.displayName,
                allowed: isAllowed,
                accent: accent,
                onChanged: (_) {
                  ref.read(notificationFilterProvider.notifier).toggleApp(app.packageName);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Master toggle row ────────────────────────────────────────────────────────

class _MasterToggleRow extends StatelessWidget {
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _MasterToggleRow({
    required this.enabled,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification filter active',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ongoing notifications will not be filtered.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.5),
            inactiveThumbColor: Colors.white.withValues(alpha: 0.5),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─── Permission banner ────────────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        NativeAppBlockerService.requestNotificationListenerPermission();
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 18, color: Colors.orange.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap to grant notification access',
                style: TextStyle(
                  color: Colors.orange.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: Colors.orange.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ─── "Allow notifications from" header with inline search ─────────────────────

class _AllowFromHeader extends StatefulWidget {
  final Color accent;
  final TextEditingController searchController;

  const _AllowFromHeader({
    required this.accent,
    required this.searchController,
  });

  @override
  State<_AllowFromHeader> createState() => _AllowFromHeaderState();
}

class _AllowFromHeaderState extends State<_AllowFromHeader> {
  bool _searchVisible = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchVisible
                  ? TextField(
                      key: const ValueKey('search'),
                      controller: widget.searchController,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      cursorColor: Colors.white,
                      cursorWidth: 1.2,
                      decoration: InputDecoration(
                        hintText: 'Search apps...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : const Align(
                      key: ValueKey('title'),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Allow notifications from',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
            ),
          ),
          IconButton(
            icon: Icon(
              _searchVisible ? Icons.close_rounded : Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.6),
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) widget.searchController.clear();
              });
            },
          ),
        ],
      ),
    );
  }
}

// ─── Single app row with minimal pill toggle ──────────────────────────────────

class _AppToggleRow extends StatelessWidget {
  final String appName;
  final bool allowed;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _AppToggleRow({
    required this.appName,
    required this.allowed,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!allowed),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                appName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            _PillToggle(value: allowed),
          ],
        ),
      ),
    );
  }
}

/// Minimal pill toggle matching the image's on/off appearance
class _PillToggle extends StatelessWidget {
  final bool value;
  const _PillToggle({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: 46,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: value
            ? Colors.white.withValues(alpha: 0.75)
            : Colors.white.withValues(alpha: 0.15),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: value ? 22 : 2,
            top: 3,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? Colors.black : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
