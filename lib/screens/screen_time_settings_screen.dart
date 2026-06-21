import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/screen_time_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/theme_provider.dart';
import '../services/native_app_blocker_service.dart';
import 'app_usage_analytics_screen.dart';

/// In-app time reminder settings — clean, minimal UI.
/// Toggle app timer on/off, precision mode status, per-app search + add.
class ScreenTimeSettingsScreen extends ConsumerStatefulWidget {
  const ScreenTimeSettingsScreen({super.key});

  @override
  ConsumerState<ScreenTimeSettingsScreen> createState() =>
      _ScreenTimeSettingsScreenState();
}

class _ScreenTimeSettingsScreenState
    extends ConsumerState<ScreenTimeSettingsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    // If already enabled, verify permission on open (catches revoked access)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final enabled = ref.read(screenTimeProvider).featureEnabled;
      if (enabled && mounted) {
        _ensureUsagePermission();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Request Usage Access permission — required for precision mode
  Future<void> _ensureUsagePermission() async {
    final has = await NativeAppBlockerService.hasUsageStatsPermission();
    if (has) return;

    if (!mounted) return;
    final accent = ref.read(themeColorProvider).color;
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer_outlined, color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              'Permission Required',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        content: Text(
          'App Timer needs "Usage Access" to detect which app is open and enforce your time limits.\n\nTap "Grant Access" → find Sukoon → turn it on.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.55,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
          ),
          TextButton(
            onPressed: () async {
              await NativeAppBlockerService.requestUsageStatsPermission();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: Text('Grant Access',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    // If user cancelled, turn the feature back OFF
    if (granted != true && mounted) {
      ref.read(screenTimeProvider.notifier).setEnabled(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;
    final state = ref.watch(screenTimeProvider);
    final allApps = ref.watch(installedAppsProvider);

    // Apps that are already configured
    final configuredApps = state.appConfigs.entries.toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'In-app time reminder',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.white.withValues(alpha: 0.5)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          // ── Screen Time Analytics card ──────────────────────────
          const SizedBox(height: 12),
          _AnalyticsCard(accent: accent, onTap: () async {
            final notifier = ref.read(screenTimeProvider.notifier);
            final alreadyHasData = ref.read(screenTimeProvider).dailyStats.isNotEmpty;
            if (!alreadyHasData) unawaited(notifier.refreshDailyStats());
            if (!context.mounted) return;
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const AppUsageAnalyticsScreen()),
            );
          }),
          const SizedBox(height: 28),

          // ── Section: Timer toggle + permission ──────────────────
          _SectionLabel(label: 'Timer'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            // Master toggle
            _CardToggleRow(
              title: 'In-app time reminder',
              subtitle: 'Show overlay when time limit is reached',
              accent: accent,
              value: state.featureEnabled,
              onChanged: (v) {
                ref.read(screenTimeProvider.notifier).setEnabled(v);
                if (v) _ensureUsagePermission();
              },
            ),
            if (state.featureEnabled) ...[
              _CardDivider(),
              // Permission row
              FutureBuilder<bool>(
                future: NativeAppBlockerService.hasUsageStatsPermission(),
                builder: (context, snapshot) {
                  final granted = snapshot.data ?? false;
                  return _CardPermissionRow(
                    granted: granted,
                    accent: accent,
                    onTap: () async {
                      if (!granted) {
                        await _ensureUsagePermission();
                        if (mounted) setState(() {});
                      }
                    },
                  );
                },
              ),
            ],
          ]),

          if (state.featureEnabled) ...[
            const SizedBox(height: 28),

            // ── Section: Apps ────────────────────────────────────
            Row(
              children: [
                Expanded(child: _SectionLabel(label: 'Monitored apps')),
                GestureDetector(
                  onTap: () {
                    _showAppSearchSheet(context, allApps, state, accent);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: accent.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text(
                          'Add app',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accent.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (configuredApps.isEmpty)
              _EmptyAppsState(accent: accent, onAddTap: () {
                _showAppSearchSheet(context, allApps, state, accent);
              })
            else
              _SettingsCard(
                children: [
                  ...List.generate(configuredApps.length, (i) {
                    final entry = configuredApps[i];
                    final appName = allApps
                            .where((a) => a.packageName == entry.key)
                            .map((a) => a.appName)
                            .firstOrNull ??
                        entry.key.split('.').last;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AppTimerRow(
                          appName: appName,
                          enabled: entry.value.enabled,
                          accent: accent,
                          onChanged: (v) {
                            ref.read(screenTimeProvider.notifier).updateAppTimer(
                                  entry.key,
                                  enabled: v,
                                );
                          },
                          onRemove: () {
                            ref.read(screenTimeProvider.notifier).removeAppTimer(entry.key);
                          },
                        ),
                        if (i < configuredApps.length - 1) _CardDivider(),
                      ],
                    );
                  }),
                ],
              ),
          ],
        ],
      ),
    );
  }

  /// Full-screen search sheet to add apps
  void _showAppSearchSheet(
      BuildContext context, List allApps, ScreenTimeState state, Color accent) {
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchCtrl.text.toLowerCase().trim();
            final available = allApps
                .where((a) => !state.appConfigs.containsKey(a.packageName))
                .where((a) =>
                    query.isEmpty || a.appName.toLowerCase().contains(query))
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search field
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchCtrl,
                        autofocus: true,
                        onChanged: (_) => setSheetState(() {}),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search apps…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          prefixIcon: Icon(Icons.search,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.2)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.04),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: available.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (_, i) {
                          final app = available[i];
                          return ListTile(
                            title: Text(
                              app.appName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            dense: true,
                            onTap: () {
                              ref
                                  .read(screenTimeProvider.notifier)
                                  .addAppTimer(
                                    app.packageName,
                                    defaultMinutes: 15,
                                    alwaysAsk: true,
                                  );
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Small all-caps section label
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: Colors.white.withValues(alpha: 0.3),
      ),
    );
  }
}

/// Rounded card that groups rows — single surface, no per-row backgrounds
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// 1px divider inside a card
class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

/// Toggle row inside a _SettingsCard
class _CardToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CardToggleRow({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Permission status row inside a _SettingsCard
class _CardPermissionRow extends StatelessWidget {
  final bool granted;
  final Color accent;
  final VoidCallback onTap;

  const _CardPermissionRow({
    required this.granted,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: granted
                    ? accent.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
              ),
              child: Icon(
                granted ? Icons.check_rounded : Icons.warning_amber_rounded,
                size: 14,
                color: granted
                    ? accent.withValues(alpha: 0.75)
                    : Colors.orange.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usage access',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    granted
                        ? 'Granted — app detection is active'
                        : 'Tap to grant — required for timer',
                    style: TextStyle(
                      fontSize: 11,
                      color: granted
                          ? Colors.white.withValues(alpha: 0.28)
                          : Colors.orange.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            if (!granted)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }
}

/// Analytics entry card — tappable hero row at the top
class _AnalyticsCard extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _AnalyticsCard({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.14), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.bar_chart_rounded, size: 22, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Timer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daily & per-app usage analytics',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.32),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.white.withValues(alpha: 0.2)),
          ],
        ),
      ),
    );
  }
}

/// Empty state when no apps are added
class _EmptyAppsState extends StatelessWidget {
  final Color accent;
  final VoidCallback onAddTap;

  const _EmptyAppsState({required this.accent, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.timer_outlined, size: 36, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 14),
          Text(
            'No apps added',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.28),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Tap "Add app" above to get started',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Per-app row inside the monitored apps card — swipe to remove
class _AppTimerRow extends StatelessWidget {
  final String appName;
  final bool enabled;
  final Color accent;
  final ValueChanged<bool> onChanged;
  final VoidCallback onRemove;

  const _AppTimerRow({
    required this.appName,
    required this.enabled,
    required this.accent,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(appName),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
        ),
        child:
            Icon(Icons.delete_outline, size: 18, color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                appName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: enabled ? 0.82 : 0.3),
                ),
              ),
            ),
            Switch.adaptive(
              value: enabled,
              activeThumbColor: accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
