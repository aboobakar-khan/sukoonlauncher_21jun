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
/// Toggle app timer on/off, permission status, per-app limits.
/// Designed for minimal taps: multi-add sheet + inline time-limit picker.
class ScreenTimeSettingsScreen extends ConsumerStatefulWidget {
  const ScreenTimeSettingsScreen({super.key});

  @override
  ConsumerState<ScreenTimeSettingsScreen> createState() =>
      _ScreenTimeSettingsScreenState();
}

class _ScreenTimeSettingsScreenState
    extends ConsumerState<ScreenTimeSettingsScreen> {
  /// Common time-limit presets (minutes) offered in the picker.
  static const _presets = [5, 10, 15, 30, 45, 60, 90];

  @override
  void initState() {
    super.initState();
    // If already enabled, verify permission on open (catches revoked access)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final enabled = ref.read(screenTimeProvider).featureEnabled;
      if (enabled && mounted) {
        _ensureUsagePermission();
      }
    });
  }

  /// Request Usage Access permission — required for app detection
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
    final accent = ref.watch(themeColorProvider).color;
    final state = ref.watch(screenTimeProvider);
    final allApps = ref.watch(installedAppsProvider);

    // Apps that are already configured, sorted by display name
    final configuredApps = state.appConfigs.entries.toList()
      ..sort((a, b) =>
          _nameFor(a.key, allApps).toLowerCase().compareTo(
              _nameFor(b.key, allApps).toLowerCase()));

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
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.white.withValues(alpha: 0.5)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── Analytics card ──────────────────────────────────────
          _AnalyticsCard(accent: accent, onTap: () async {
            final notifier = ref.read(screenTimeProvider.notifier);
            final alreadyHasData =
                ref.read(screenTimeProvider).dailyStats.isNotEmpty;
            if (!alreadyHasData) unawaited(notifier.refreshDailyStats());
            if (!context.mounted) return;
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const AppUsageAnalyticsScreen()),
            );
          }),
          const SizedBox(height: 28),

          // ── Section: Timer toggle + permission ──────────────────
          const _SectionLabel(label: 'Timer'),
          const SizedBox(height: 10),
          _SettingsCard(children: [
            _CardToggleRow(
              title: 'In-app time reminder',
              subtitle: 'Show a gentle overlay when your limit is reached',
              accent: accent,
              value: state.featureEnabled,
              onChanged: (v) {
                ref.read(screenTimeProvider.notifier).setEnabled(v);
                if (v) _ensureUsagePermission();
              },
            ),
            if (state.featureEnabled) ...[
              const _CardDivider(),
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

            // ── Section: Apps ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _SectionLabel(
                    label: 'Monitored apps',
                    trailing: configuredApps.isEmpty
                        ? null
                        : '${configuredApps.length}',
                  ),
                ),
                _AddAppButton(
                  accent: accent,
                  onTap: () => _showAddAppsSheet(accent),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (configuredApps.isEmpty)
              _EmptyAppsState(
                accent: accent,
                onAddTap: () => _showAddAppsSheet(accent),
              )
            else
              _SettingsCard(
                children: [
                  for (int i = 0; i < configuredApps.length; i++) ...[
                    _AppTimerRow(
                      key: ValueKey(configuredApps[i].key),
                      appName: _nameFor(configuredApps[i].key, allApps),
                      config: configuredApps[i].value,
                      accent: accent,
                      onToggle: (v) => ref
                          .read(screenTimeProvider.notifier)
                          .updateAppTimer(configuredApps[i].key, enabled: v),
                      onEditLimit: () => _showLimitSheet(
                          configuredApps[i].key,
                          _nameFor(configuredApps[i].key, allApps),
                          configuredApps[i].value,
                          accent),
                      onRemove: () => ref
                          .read(screenTimeProvider.notifier)
                          .removeAppTimer(configuredApps[i].key),
                    ),
                    if (i < configuredApps.length - 1) const _CardDivider(),
                  ],
                ],
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Tap a limit to change it · swipe a row left to remove',
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.22)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _nameFor(String pkg, List allApps) {
    return allApps
            .where((a) => a.packageName == pkg)
            .map((a) => a.appName)
            .firstOrNull ??
        pkg.split('.').last;
  }

  // ───────────────────────────────────────────────────────────────────────
  // ADD APPS — multi-select sheet (tap to add/remove, stays open)
  // ───────────────────────────────────────────────────────────────────────

  void _showAddAppsSheet(Color accent) {
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              final allApps = ref.read(installedAppsProvider);
              final configured = ref.read(screenTimeProvider).appConfigs;
              final query = searchCtrl.text.toLowerCase().trim();

              final apps = allApps
                  .where((a) =>
                      query.isEmpty ||
                      a.appName.toLowerCase().contains(query))
                  .toList()
                ..sort((a, b) {
                  // Configured apps float to the top for easy review
                  final ca = configured.containsKey(a.packageName) ? 0 : 1;
                  final cb = configured.containsKey(b.packageName) ? 0 : 1;
                  if (ca != cb) return ca - cb;
                  return a.appName
                      .toLowerCase()
                      .compareTo(b.appName.toLowerCase());
                });

              return DraggableScrollableSheet(
                initialChildSize: 0.78,
                maxChildSize: 0.95,
                minChildSize: 0.5,
                expand: false,
                builder: (_, scrollController) {
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Text(
                              'Add apps',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(ctx),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 7),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Done',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Search field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: searchCtrl,
                          autofocus: false,
                          onChanged: (_) => setSheetState(() {}),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search apps…',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            prefixIcon: Icon(Icons.search,
                                size: 19,
                                color: Colors.white.withValues(alpha: 0.3)),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: apps.isEmpty
                            ? Center(
                                child: Text('No apps found',
                                    style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        fontSize: 13)),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: apps.length,
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                                itemBuilder: (_, i) {
                                  final app = apps[i];
                                  final isAdded =
                                      configured.containsKey(app.packageName);
                                  return _AddAppTile(
                                    appName: app.appName,
                                    packageName: app.packageName,
                                    isAdded: isAdded,
                                    accent: accent,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      final notifier = ref
                                          .read(screenTimeProvider.notifier);
                                      if (isAdded) {
                                        notifier.removeAppTimer(app.packageName);
                                      } else {
                                        notifier.addAppTimer(app.packageName,
                                            defaultMinutes: 15,
                                            alwaysAsk: true);
                                      }
                                      setSheetState(() {});
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
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // TIME LIMIT PICKER — compact, 1-tap to choose
  // ───────────────────────────────────────────────────────────────────────

  void _showLimitSheet(
      String pkg, String appName, AppTimerConfig config, Color accent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Time limit',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'for $appName',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 20),
                // "Ask each time" full-width option
                _LimitOption(
                  label: 'Ask each time',
                  hint: 'Choose a fresh limit whenever the app opens',
                  selected: config.alwaysAsk,
                  accent: accent,
                  onTap: () {
                    ref
                        .read(screenTimeProvider.notifier)
                        .updateAppTimer(pkg, alwaysAsk: true);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'OR SET A FIXED LIMIT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _presets.map((min) {
                    final selected =
                        !config.alwaysAsk && config.defaultMinutes == min;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(screenTimeProvider.notifier).updateAppTimer(
                            pkg,
                            alwaysAsk: false,
                            defaultMinutes: min);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        width: 64,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: selected
                              ? accent.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? accent.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                        child: Text(
                          '${min}m',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? accent
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIVATE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Small all-caps section label, with an optional trailing count.
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? trailing;
  const _SectionLabel({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Colors.white.withValues(alpha: 0.32),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Text(
            trailing!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
        ],
      ],
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
        color: Colors.white.withValues(alpha: 0.045),
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
  const _CardDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: Colors.white.withValues(alpha: 0.06),
    );
  }
}

/// A compact, themed, animated toggle — consistent across the screen.
class _AppSwitch extends StatelessWidget {
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const _AppSwitch(
      {required this.value, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 46,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? accent.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Letter-avatar tile for an app — matches the analytics screen style.
class _AppAvatar extends StatelessWidget {
  final String appName;
  final String packageName;
  final double size;
  const _AppAvatar(
      {required this.appName, required this.packageName, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final letter = appName.isNotEmpty ? appName[0].toUpperCase() : '?';
    final hue = (packageName.codeUnits.fold(0, (a, b) => a + b) % 360).toDouble();
    final color = HSLColor.fromAHSL(1.0, hue, 0.45, 0.4).toColor();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            color: color.withValues(alpha: 0.95),
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Toggle row inside a _SettingsCard (master toggle)
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
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _AppSwitch(value: value, accent: accent, onChanged: onChanged),
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
                    ? accent.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
              ),
              child: Icon(
                granted ? Icons.check_rounded : Icons.warning_amber_rounded,
                size: 15,
                color: granted
                    ? accent.withValues(alpha: 0.85)
                    : Colors.orange.withValues(alpha: 0.8),
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    granted
                        ? 'Granted — app detection is active'
                        : 'Tap to grant — required for timer',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: granted
                          ? Colors.white.withValues(alpha: 0.3)
                          : Colors.orange.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (!granted)
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: Colors.white.withValues(alpha: 0.25)),
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
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.16), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.bar_chart_rounded, size: 23, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Timer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daily & per-app usage analytics',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: Colors.white.withValues(alpha: 0.25)),
          ],
        ),
      ),
    );
  }
}

/// "+ Add app" pill button
class _AddAppButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _AddAppButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 16, color: accent),
            const SizedBox(width: 4),
            Text(
              'Add app',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
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
    return GestureDetector(
      onTap: onAddTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 34),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: accent.withValues(alpha: 0.14),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded,
                  size: 24, color: accent.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 14),
            Text(
              'Add your first app',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Pick the apps you want a gentle nudge on',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable option inside the time-limit sheet
class _LimitOption extends StatelessWidget {
  final String label;
  final String hint;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _LimitOption({
    required this.label,
    required this.hint,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded,
                size: 18,
                color: selected ? accent : Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? accent
                          : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 18, color: accent),
          ],
        ),
      ),
    );
  }
}

/// A row in the multi-add sheet — tap to add/remove with instant feedback.
class _AddAppTile extends StatelessWidget {
  final String appName;
  final String packageName;
  final bool isAdded;
  final Color accent;
  final VoidCallback onTap;

  const _AddAppTile({
    required this.appName,
    required this.packageName,
    required this.isAdded,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _AppAvatar(appName: appName, packageName: packageName, size: 38),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                appName,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: isAdded ? 0.9 : 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAdded ? accent : Colors.transparent,
                border: Border.all(
                  color: isAdded
                      ? accent
                      : Colors.white.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: isAdded
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-app row inside the monitored apps card — swipe to remove.
class _AppTimerRow extends StatelessWidget {
  final String appName;
  final AppTimerConfig config;
  final Color accent;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEditLimit;
  final VoidCallback onRemove;

  const _AppTimerRow({
    super.key,
    required this.appName,
    required this.config,
    required this.accent,
    required this.onToggle,
    required this.onEditLimit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final limitLabel =
        config.alwaysAsk ? 'Ask each time' : '${config.defaultMinutes}m';
    final dim = !config.enabled;

    return Dismissible(
      key: ValueKey('dismiss_${config.packageName}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.delete_outline_rounded,
            size: 20, color: Colors.red.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 16, 11),
        child: Row(
          children: [
            Opacity(
              opacity: dim ? 0.4 : 1,
              child: _AppAvatar(
                  appName: appName, packageName: config.packageName, size: 38),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appName,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: dim ? 0.35 : 0.88),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Tappable limit pill
                  GestureDetector(
                    onTap: onEditLimit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: dim ? 0.06 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            config.alwaysAsk
                                ? Icons.help_outline_rounded
                                : Icons.schedule_rounded,
                            size: 12,
                            color: accent.withValues(alpha: dim ? 0.4 : 0.9),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            limitLabel,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: accent.withValues(alpha: dim ? 0.4 : 0.95),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.expand_more_rounded,
                              size: 13,
                              color: accent.withValues(alpha: dim ? 0.4 : 0.7)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _AppSwitch(value: config.enabled, accent: accent, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}
