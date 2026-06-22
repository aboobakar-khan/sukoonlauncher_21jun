import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../providers/theme_provider.dart';
import '../services/prayer_alarm_service.dart';

// ─── Minimalist Permission Setup ─────────────────────────────────
// Only the two permissions actually needed for prayer alarms:
//   • Notifications — required   (show prayer alerts)
//   • Exact Alarms  — required   (fire at precise time)
// Battery optimization & Display-Over-Apps prompts removed — they are
// intrusive nags that aren't required for the feature to work.

class PermissionSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onAllGranted;
  final VoidCallback? onSkipped;

  const PermissionSetupScreen({
    super.key,
    required this.onAllGranted,
    this.onSkipped,
  });

  @override
  ConsumerState<PermissionSetupScreen> createState() =>
      _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends ConsumerState<PermissionSetupScreen> {
  bool _notif = false;
  bool _alarm = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    final n = await Permission.notification.isGranted;
    final a = await PrayerAlarmService.canScheduleExactAlarms();
    if (!mounted) return;
    setState(() { _notif = n; _alarm = a; });
    // Auto-complete if both permissions are already granted
    if (n && a) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) widget.onAllGranted();
      });
    }
  }

  int get _granted => [_notif, _alarm].where((v) => v).length;
  bool get _criticalGranted => _notif && _alarm;

  Future<void> _request(int step) async {
    if (_busy) return;
    setState(() => _busy = true);

    switch (step) {
      case 0: // Notifications
        final ok = await PrayerAlarmService.requestNotificationPermission();
        if (mounted) setState(() => _notif = ok);
        if (!ok && mounted) {
          _showHelp('Notification access is needed to alert you at prayer times.');
        }
        break;
      case 1: // Exact Alarms
        final ok = await PrayerAlarmService.canScheduleExactAlarms();
        if (!ok) {
          await openAppSettings();
          await Future.delayed(const Duration(milliseconds: 600));
          final re = await PrayerAlarmService.canScheduleExactAlarms();
          if (mounted) setState(() => _alarm = re);
        } else {
          if (mounted) setState(() => _alarm = ok);
        }
        break;
    }

    if (mounted) setState(() => _busy = false);

    // Auto-complete if both permissions are now granted
    if (_notif && _alarm) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) widget.onAllGranted();
    }
  }

  Future<void> _grantAll() async {
    if (_busy) return;
    setState(() => _busy = true);

    // Notifications
    if (!_notif) {
      final ok = await PrayerAlarmService.requestNotificationPermission();
      if (mounted) setState(() => _notif = ok);
      if (!ok) {
        if (mounted) setState(() => _busy = false);
        if (mounted) {
          _showHelp(
              'Notification permission is required. Please enable it in Settings.');
        }
        return;
      }
    }

    // Exact Alarm
    if (!_alarm) {
      final ok = await PrayerAlarmService.canScheduleExactAlarms();
      if (!ok) {
        await openAppSettings();
        await Future.delayed(const Duration(milliseconds: 600));
        final re = await PrayerAlarmService.canScheduleExactAlarms();
        if (mounted) setState(() => _alarm = re);
        if (!re) {
          if (mounted) setState(() => _busy = false);
          return;
        }
      } else {
        if (mounted) setState(() => _alarm = ok);
      }
    }

    if (mounted) setState(() => _busy = false);

    if (_notif && _alarm) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) widget.onAllGranted();
    }
  }

  void _showHelp(String message) {
    final accent = ref.read(themeColorProvider).color;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0C0C10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.info_outline_rounded,
                    size: 22, color: Colors.red.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 18),
              Text('Permission Needed',
                style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.88),
                )),
              const SizedBox(height: 10),
              Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, height: 1.5,
                  color: Colors.white.withValues(alpha: 0.45),
                )),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: () { Navigator.pop(ctx); openAppSettings(); },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: accent.withValues(alpha: 0.1),
                    border: Border.all(color: accent.withValues(alpha: 0.15)),
                  ),
                  child: Center(
                    child: Text('Open Settings',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      )),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () { Navigator.pop(ctx); _checkAll(); },
                child: Text("I've enabled it",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;

    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // Header
              Text('Alarm Permissions',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                  letterSpacing: -0.3,
                )),
              const SizedBox(height: 6),
              Text('These ensure your prayer alarms fire reliably.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.35),
                )),

              // Progress dots (2 permissions)
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(_notif, accent),
                  const SizedBox(width: 4),
                  _dot(_alarm, accent),
                ],
              ),

              const SizedBox(height: 20),

              // Permission cards
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _PermCard(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      desc: 'Show alerts at prayer times',
                      granted: _notif,
                      required_: true,
                      accent: accent,
                      onTap: () => _request(0),
                    ),
                    const SizedBox(height: 8),
                    _PermCard(
                      icon: Icons.alarm_rounded,
                      title: 'Exact Alarms',
                      desc: 'Fire at the precise prayer time',
                      granted: _alarm,
                      required_: true,
                      accent: accent,
                      onTap: () => _request(1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // CTA
              GestureDetector(
                onTap: _busy ? null : _grantAll,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: !_busy
                        ? LinearGradient(colors: [
                            accent.withValues(alpha: 0.30),
                            accent.withValues(alpha: 0.12),
                          ])
                        : null,
                    color: _busy ? Colors.white.withValues(alpha: 0.03) : null,
                    border: Border.all(
                      color: _busy
                          ? Colors.white.withValues(alpha: 0.05)
                          : accent.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Center(
                    child: _busy
                        ? SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: accent))
                        : Text(
                            _criticalGranted
                                ? 'CONTINUE  ($_granted/2 granted)'
                                : 'GRANT PERMISSIONS',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: Colors.white.withValues(alpha: 0.9),
                            )),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Skip / Continue link
              if (_criticalGranted)
                GestureDetector(
                  onTap: widget.onAllGranted,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Continue',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3),
                      )),
                  ),
                )
              else
                GestureDetector(
                  onTap: widget.onSkipped,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Skip for now',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.2),
                      )),
                  ),
                ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(bool granted, Color accent) {
    return Container(
      width: 28, height: 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: granted
            ? accent.withValues(alpha: 0.60)
            : Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}

// ─── Permission Card ─────────────────────────────────────────────────────────

class _PermCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool granted;
  final bool required_;
  final Color accent;
  final VoidCallback onTap;

  const _PermCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.granted,
    required this.required_,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: granted ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: granted
              ? Colors.green.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.02),
          border: Border.all(
            color: granted
                ? Colors.green.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: granted
                    ? Colors.green.withValues(alpha: 0.08)
                    : accent.withValues(alpha: 0.05),
              ),
              child: Icon(icon, size: 18,
                color: granted
                    ? Colors.green.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        )),
                      const SizedBox(width: 8),
                      _StatusChip(granted: granted, required_: required_),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.30),
                    )),
                ],
              ),
            ),
            if (!granted)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: Colors.white.withValues(alpha: 0.15))
            else
              Icon(Icons.check_circle_rounded,
                  size: 18, color: Colors.green.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool granted;
  final bool required_;
  const _StatusChip({required this.granted, required this.required_});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    if (granted) {
      bg = Colors.green.withValues(alpha: 0.08);
      fg = Colors.green.withValues(alpha: 0.7);
      label = 'DONE';
    } else if (required_) {
      bg = Colors.red.withValues(alpha: 0.08);
      fg = Colors.red.withValues(alpha: 0.7);
      label = 'REQUIRED';
    } else {
      bg = Colors.white.withValues(alpha: 0.03);
      fg = Colors.white.withValues(alpha: 0.35);
      label = 'OPTIONAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: bg,
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 8, fontWeight: FontWeight.w700,
          letterSpacing: 0.5, color: fg,
        )),
    );
  }
}
