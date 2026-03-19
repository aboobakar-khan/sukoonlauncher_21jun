import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/swipe_back_wrapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

enum _PermImportance { critical, recommended }

class _PermEntry {
  final String name;
  final String subtitle;
  final String purpose;
  final String feature;
  final IconData icon;
  final Color color;
  final _PermImportance importance;
  final String? concernNote;
  final Permission? permission;
  final bool isSpecial;

  /// Key passed to the native `openPermissionSettings` channel call.
  /// Maps to a specific Android Settings intent in MainActivity.kt.
  final String settingsKey;

  const _PermEntry({
    required this.name,
    required this.subtitle,
    required this.purpose,
    required this.feature,
    required this.icon,
    required this.color,
    required this.importance,
    required this.settingsKey,
    this.concernNote,
    this.permission,
    this.isSpecial = false,
  });
}

// Only the permissions users actually care about.
// Stripped: INTERNET, VIBRATE, BOOT, WAKE_LOCK, FULL_SCREEN_INTENT
// (silently granted by OS, zero user-facing concern)
const List<_PermEntry> _permissions = [
  // ── ESSENTIAL ──────────────────────────────────────────────────────────
  _PermEntry(
    name: 'Location',
    subtitle: 'GPS · Prayer Times',
    purpose:
        'Auto-detects your city to calculate accurate Fajr, Dhuhr, Asr, Maghrib and Isha times. '
        'Without it you must enter your city manually every time.',
    feature: '🕌 Prayer Times',
    icon: Icons.location_on_outlined,
    color: Color(0xFF4CAF50),
    importance: _PermImportance.critical,
    permission: Permission.locationWhenInUse,
    settingsKey: 'location',
  ),
  _PermEntry(
    name: 'Notifications',
    subtitle: 'Alerts · Prayer Reminders',
    purpose:
        'Delivers Adhan reminders at exact prayer times, app-blocker warnings, and '
        'Zen Mode alerts. Disabling this silences all Sukoon notifications.',
    feature: '🔔 Prayer Alarms & Alerts',
    icon: Icons.notifications_outlined,
    color: Color(0xFFFFC107),
    importance: _PermImportance.critical,
    permission: Permission.notification,
    settingsKey: 'notification',
  ),
  _PermEntry(
    name: 'Exact Alarms',
    subtitle: 'Precise scheduling',
    purpose:
        'Fires prayer alarms at the exact second of Adhan, even in low-power mode. '
        'Without this, alarms may be delayed by several minutes.',
    feature: '⏰ Prayer Alarms',
    icon: Icons.alarm_outlined,
    color: Color(0xFFFF9800),
    importance: _PermImportance.critical,
    permission: Permission.scheduleExactAlarm,
    settingsKey: 'exact_alarm',
  ),
  _PermEntry(
    name: 'Draw Over Other Apps',
    subtitle: 'Overlay · Zen / App Blocker',
    purpose:
        'Shows Zen Lock Screen and App Blocker focus overlay on top of other apps. '
        'Only visible when you manually activate Zen Mode or a block rule triggers.',
    feature: '�� Zen Mode / App Blocker',
    icon: Icons.layers_outlined,
    color: Color(0xFF9C27B0),
    importance: _PermImportance.critical,
    concernNote: '⚡ No battery impact — only active when Zen Mode is on.',
    isSpecial: true,
    settingsKey: 'overlay',
  ),
  _PermEntry(
    name: 'Usage Access',
    subtitle: 'Screen Time · App Stats',
    purpose:
        'Reads how long you spend in each app to show daily screen-time stats and '
        'enforce app-blocking time limits. Data stays on-device — never uploaded.',
    feature: '📊 Screen Time Analytics',
    icon: Icons.bar_chart_outlined,
    color: Color(0xFF2196F3),
    importance: _PermImportance.critical,
    concernNote:
        '⚡ Minimal battery use — only reads counters Android already tracks.',
    isSpecial: true,
    settingsKey: 'usage_access',
  ),

  // ── OPTIONAL ───────────────────────────────────────────────────────────
  _PermEntry(
    name: 'Do Not Disturb',
    subtitle: 'Silence during Zen Mode',
    purpose:
        'Mutes all sounds and notifications while a Zen focus session is active. '
        'Has zero effect outside of Zen Mode.',
    feature: '🔕 Zen Mode DND',
    icon: Icons.do_not_disturb_on_outlined,
    color: Color(0xFFFF5722),
    importance: _PermImportance.recommended,
    permission: Permission.accessNotificationPolicy,
    settingsKey: 'dnd',
  ),
  _PermEntry(
    name: 'Ignore Battery Optimisation',
    subtitle: 'Background service reliability',
    purpose:
        'Prevents Android from killing Sukoon\'s background service so prayer alarms '
        'and screen-time tracking stay reliable all day — especially on Samsung/Xiaomi '
        'where aggressive battery management can miss alarms.',
    feature: '🔋 Reliable Alarms',
    icon: Icons.battery_saver_outlined,
    color: Color(0xFF8BC34A),
    importance: _PermImportance.recommended,
    concernNote:
        '💡 Sukoon has no background sync or location polling. '
        'The service only wakes at scheduled alarm times — real-world battery impact is negligible.',
    permission: Permission.ignoreBatteryOptimizations,
    settingsKey: 'battery_optimization',
  ),
  _PermEntry(
    name: 'Audio Files',
    subtitle: 'Custom Adhan ringtone',
    purpose:
        'Lets you pick an audio file from storage as your prayer-time Adhan sound. '
        'Only accessed when you tap "Choose Audio" in prayer settings.',
    feature: '🔊 Custom Adhan Sound',
    icon: Icons.audio_file_outlined,
    color: Color(0xFF00BCD4),
    importance: _PermImportance.recommended,
    permission: Permission.audio,
    settingsKey: 'audio',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AppPermissionsScreen extends StatefulWidget {
  const AppPermissionsScreen({super.key});

  @override
  State<AppPermissionsScreen> createState() => _AppPermissionsScreenState();
}

class _AppPermissionsScreenState extends State<AppPermissionsScreen> {
  final Map<String, PermissionStatus> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatuses();
  }

  Future<void> _fetchStatuses() async {
    final results = <String, PermissionStatus>{};
    for (final p in _permissions) {
      if (p.isSpecial && p.permission == null) {
        // Special permissions that permission_handler cannot check —
        // ask native Android directly via the settings channel.
        try {
          final granted = await _settingsChannel.invokeMethod<bool>(
            'checkSpecialPermission',
            {'type': p.settingsKey},
          );
          results[p.name] =
              (granted == true) ? PermissionStatus.granted : PermissionStatus.denied;
        } catch (_) {
          results[p.name] = PermissionStatus.denied;
        }
      } else if (p.permission != null) {
        try {
          results[p.name] = await p.permission!.status;
        } catch (_) {
          results[p.name] = PermissionStatus.denied;
        }
      }
    }
    if (mounted) {
      setState(() {
        _statuses.addAll(results);
        _loading = false;
      });
    }
  }

  bool _isGranted(_PermEntry p) {
    final s = _statuses[p.name];
    return s == PermissionStatus.granted || s == PermissionStatus.limited;
  }

  int get _criticalGranted => _permissions
      .where((p) => p.importance == _PermImportance.critical && _isGranted(p))
      .length;

  int get _criticalTotal =>
      _permissions.where((p) => p.importance == _PermImportance.critical).length;

  static const _settingsChannel = MethodChannel('app_settings');

  Future<void> _openPermissionSettings(_PermEntry p) async {
    try {
      await _settingsChannel.invokeMethod(
        'openPermissionSettings',
        {'type': p.settingsKey},
      );
    } catch (_) {
      await openAppSettings();
    }
    await Future.delayed(const Duration(milliseconds: 800));
    await _fetchStatuses();
  }

  Future<void> _toggle(_PermEntry p) async {
    HapticFeedback.lightImpact();
    final granted = _isGranted(p);

    // Already granted → go to exact settings page so user can turn it OFF
    if (granted) {
      await _openPermissionSettings(p);
      return;
    }

    // Special permissions (overlay, usage access) always need the settings page
    if (p.isSpecial || p.permission == null) {
      await _openPermissionSettings(p);
      return;
    }

    // Permanently denied → only settings can fix it
    if (_statuses[p.name] == PermissionStatus.permanentlyDenied) {
      await _openPermissionSettings(p);
      return;
    }

    // Not yet granted and not permanently denied → show system dialog
    final result = await p.permission!.request();
    if (mounted) setState(() => _statuses[p.name] = result);

    // If dialog was dismissed without granting, send to exact settings page
    if (mounted && !_isGranted(p)) {
      await _openPermissionSettings(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFC2A366);

    final critical = _permissions
        .where((p) => p.importance == _PermImportance.critical)
        .toList();
    final recommended = _permissions
        .where((p) => p.importance == _PermImportance.recommended)
        .toList();

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _Header(onRefresh: () {
                setState(() => _loading = true);
                _fetchStatuses();
              }),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: accent, strokeWidth: 2))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
                        children: [
                          _SummaryCard(
                            critical: _criticalGranted,
                            criticalTotal: _criticalTotal,
                          ),
                          const SizedBox(height: 24),
                          _SectionLabel(
                            label: 'ESSENTIAL',
                            badge: '$_criticalGranted/$_criticalTotal',
                            badgeColor: _criticalGranted == _criticalTotal
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFF44336),
                          ),
                          const SizedBox(height: 8),
                          ...critical.map((p) => _PermTile(
                                entry: p,
                                granted: _isGranted(p),
                                status: _statuses[p.name],
                                onToggle: () => _toggle(p),
                              )),
                          const SizedBox(height: 20),
                          _SectionLabel(
                            label: 'OPTIONAL',
                            badge: 'Enhances features',
                            badgeColor: const Color(0xFF9E9E9E),
                          ),
                          const SizedBox(height: 8),
                          ...recommended.map((p) => _PermTile(
                                entry: p,
                                granted: _isGranted(p),
                                status: _statuses[p.name],
                                onToggle: () => _toggle(p),
                              )),
                          const SizedBox(height: 20),
                          const _InfoNote(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onRefresh;
  const _Header({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white54, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Permissions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Transparency · You are in control',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded,
                  color: Colors.white38, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary card
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int critical;
  final int criticalTotal;
  const _SummaryCard({required this.critical, required this.criticalTotal});

  @override
  Widget build(BuildContext context) {
    final allGood = critical == criticalTotal;
    final statusColor =
        allGood ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final missing = criticalTotal - critical;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              allGood
                  ? Icons.verified_user_rounded
                  : Icons.shield_outlined,
              color: statusColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allGood
                      ? 'All essential permissions granted'
                      : '$missing essential permission${missing > 1 ? 's' : ''} missing',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  allGood
                      ? 'Sukoon is working at full capability.'
                      : 'Some features like prayer alarms may not work.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                  ),
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
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final String badge;
  final Color badgeColor;
  const _SectionLabel(
      {required this.label, required this.badge, required this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 13,
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.35),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Permission tile with toggle switch
// ─────────────────────────────────────────────────────────────────────────────

class _PermTile extends StatelessWidget {
  final _PermEntry entry;
  final bool granted;
  final PermissionStatus? status;
  final VoidCallback onToggle;

  const _PermTile({
    required this.entry,
    required this.granted,
    required this.status,
    required this.onToggle,
  });

  bool get _isSpecialUnknown =>
      entry.isSpecial && entry.permission == null && !granted;

  String get _statusLabel {
    if (_isSpecialUnknown) return 'Tap to check';
    if (granted) return 'ON';
    if (status == PermissionStatus.permanentlyDenied) return 'Blocked';
    return 'OFF';
  }

  Color get _statusColor {
    if (granted) return const Color(0xFF4CAF50);
    if (_isSpecialUnknown) return const Color(0xFF9E9E9E);
    if (status == PermissionStatus.permanentlyDenied) {
      return const Color(0xFFF44336);
    }
    return const Color(0xFFFFC107);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: granted
            ? entry.color.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: granted
              ? entry.color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.only(left: 14, right: 6, top: 2, bottom: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: Colors.white24,
          collapsedIconColor: Colors.white.withValues(alpha: 0.15),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: entry.color
                      .withValues(alpha: granted ? 0.18 : 0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(entry.icon,
                    color: entry.color
                        .withValues(alpha: granted ? 1.0 : 0.5),
                    size: 20),
              ),
              if (!granted &&
                  entry.importance == _PermImportance.critical)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF44336),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            entry.name,
            style: TextStyle(
              color: Colors.white
                  .withValues(alpha: granted ? 0.95 : 0.65),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              entry.subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 11),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // ON/OFF toggle
              GestureDetector(
                onTap: onToggle,
                child: _ToggleSwitch(
                    value: granted, activeColor: entry.color),
              ),
              const SizedBox(width: 4),
            ],
          ),
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: entry.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(entry.feature,
                      style: TextStyle(
                          color: entry.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    entry.importance == _PermImportance.critical
                        ? '🔴 Essential'
                        : '🟡 Optional',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.purpose,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.5),
            ),
            if (entry.concernNote != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  entry.concernNote!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                      height: 1.45),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: _ActionButton(
                granted: granted,
                isSpecialOrBlocked: _isSpecialUnknown ||
                    status == PermissionStatus.permanentlyDenied,
                color: entry.color,
                onTap: onToggle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated toggle switch
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleSwitch extends StatelessWidget {
  final bool value;
  final Color activeColor;
  const _ToggleSwitch({required this.value, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: 44,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: value
            ? activeColor.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.12),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  value ? Colors.white : Colors.white.withValues(alpha: 0.4),
              boxShadow: value
                  ? [
                      BoxShadow(
                          color: activeColor.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1))
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final bool granted;
  final bool isSpecialOrBlocked;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.granted,
    required this.isSpecialOrBlocked,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = granted
        ? 'Turn Off  (opens Android Settings)'
        : isSpecialOrBlocked
            ? 'Turn On  (opens Android Settings)'
            : 'Turn On';
    final icon = (granted || isSpecialOrBlocked)
        ? Icons.open_in_new_rounded
        : Icons.check_rounded;
    final fg =
        granted ? Colors.white.withValues(alpha: 0.4) : color;
    final bg = granted
        ? Colors.white.withValues(alpha: 0.05)
        : color.withValues(alpha: 0.12);
    final border = granted
        ? Colors.white.withValues(alpha: 0.08)
        : color.withValues(alpha: 0.25);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom transparency note
// ─────────────────────────────────────────────────────────────────────────────

class _InfoNote extends StatelessWidget {
  const _InfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.white38, size: 14),
              const SizedBox(width: 6),
              Text(
                'About battery & background use',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Sukoon does not run constant background sync, track your location '
            'continuously, or upload any data. The background service only wakes '
            'at scheduled alarm times.\n\n'
            'Basic system permissions (VIBRATE, INTERNET, BOOT) are auto-granted '
            'by Android and have zero user impact — they are not shown here.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
                height: 1.6),
          ),
        ],
      ),
    );
  }
}
