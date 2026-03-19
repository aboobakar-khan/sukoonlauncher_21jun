import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../providers/prayer_provider.dart';
import '../../../providers/zen_mode_provider.dart';
import '../../../providers/theme_provider.dart';
import '../providers/prayer_alarm_provider.dart';
import '../services/prayer_alarm_service.dart';
import '../../../screens/zen_mode_active_screen.dart';

/// Full-screen prayer alarm screen — appears when user taps notification.
///
/// Design: Minimal, dark, Islamic aesthetic matching Sukoon brand.
/// 3 actions:
///   1. "Alhamdulillah, I prayed" → log prayer + close
///   2. "Not yet, going now"      → snooze N min + close
///   3. "Prayed + Zen Mode"       → pick duration → log + activate Zen Mode + close
/// 
/// Auto-close: Alarm auto-closes after 75 seconds if user doesn't respond
class PrayerAlarmScreen extends ConsumerStatefulWidget {
  final String prayerName;

  const PrayerAlarmScreen({
    super.key,
    required this.prayerName,
  });

  @override
  ConsumerState<PrayerAlarmScreen> createState() => _PrayerAlarmScreenState();
}

class _PrayerAlarmScreenState extends ConsumerState<PrayerAlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _fadeIn;
  AudioPlayer? _alarmPlayer;
  bool _soundEnabled = true;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Register native volume-key stop callback
    PrayerAlarmService.onStopAlarmSoundRequested = () {
      if (mounted) {
        _stopAlarmSound();
        setState(() => _soundEnabled = false);
      }
    };

    // Also register a Flutter-level global key handler as a reliable fallback.
    // HardwareKeyboard.instance.addHandler works regardless of widget focus
    // and fires before the system processes the volume change — it is the
    // most reliable way to intercept volume keys inside a Flutter Activity.
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);

    // Play the adhan sound (plays once, no loop)
    _startAlarmSound();
    
    // Auto-close timer: 228s = full adhan duration (3m48s)
    _startAutoCloseTimer();
  }

  /// Intercepts hardware key events at the Flutter engine level.
  /// Returns true to consume the event (prevent volume change), false to pass through.
  bool _handleHardwareKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
         event.logicalKey == LogicalKeyboardKey.audioVolumeDown)) {
      _stopAlarmSound();
      if (mounted) setState(() => _soundEnabled = false);
      return true; // consume — don't change volume
    }
    return false;
  }

  /// Auto-close alarm after 228 seconds (3m48s = full adhan duration)
  void _startAutoCloseTimer() {
    _autoCloseTimer = Timer(const Duration(seconds: 228), () {
      if (mounted) {
        _autoCloseAlarm();
      }
    });
  }

  /// Auto-close: Stop sound, dismiss notification, close screen
  Future<void> _autoCloseAlarm() async {
    await _stopAlarmSound();
    await PrayerAlarmService.dismissNotification(widget.prayerName);
    await PrayerAlarmService.dismissAlarmWakeFlags();

    // Mark closed BEFORE pop to keep lifecycle guards consistent
    PrayerAlarmService.markAlarmScreenClosed();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _startAlarmSound() async {
    try {
      _alarmPlayer = AudioPlayer();
      
      // Configure to use ALARM audio stream (not media volume)
      await _alarmPlayer!.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      
      // Play adhan once (no loop) — use bundled adhan_madinah.mp3
      await _alarmPlayer!.setReleaseMode(ReleaseMode.release);
      await _alarmPlayer!.setVolume(1.0);
      await _alarmPlayer!.play(AssetSource('sounds/adhan_madinah.mp3'));
    } catch (_) {}
  }

  Future<void> _stopAlarmSound() async {
    try {
      await _alarmPlayer?.stop();
      _alarmPlayer?.dispose();
      _alarmPlayer = null;
    } catch (_) {}
  }

  Future<void> _toggleSound() async {
    HapticFeedback.lightImpact();
    if (_soundEnabled) {
      try {
        await _alarmPlayer?.pause();
      } catch (_) {}
    } else {
      try {
        await _alarmPlayer?.resume();
      } catch (_) {
        await _startAlarmSound();
      }
    }
    setState(() => _soundEnabled = !_soundEnabled);
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    _stopAlarmSound();
    // Unregister hardware key handler and native callback
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    PrayerAlarmService.onStopAlarmSoundRequested = null;
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;
    final alarmState = ref.watch(prayerAlarmProvider);
    final snoozeMins = alarmState.reminderSettings.snoozeDurationMinutes;

    // Volume up/down are handled via native dispatchKeyEvent →
    // MethodChannel → PrayerAlarmService.onStopAlarmSoundRequested.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) await _stopAlarmSound();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Glowing mosque icon ──
              AnimatedBuilder(
                animation: _fadeIn,
                builder: (_, child) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.06 + _fadeIn.value * 0.06),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.08 + _fadeIn.value * 0.08),
                          blurRadius: 40 + _fadeIn.value * 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.mosque_rounded,
                      size: 48,
                      color: accent.withValues(alpha: 0.8),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // ── Title ──
              Text(
                'TIME FOR PRAYER',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 14),

              // ── Prayer name ──
              Text(
                'The ${widget.prayerName} time\nhas just started',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.92),
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 28),

              // ── Quranic verse card ──
              _buildVerseCard(accent),

              const Spacer(flex: 3),

              // ── Sound toggle button (top-right style) ──
              _buildSoundToggle(accent),

              const SizedBox(height: 20),

              // ── 3 Action Buttons ──

              // Button 1: I Prayed
              _buildActionButton(
                label: 'Alhamdulillah, I have prayed',
                icon: Icons.check_circle_outline_rounded,
                isPrimary: true,
                accent: accent,
                onTap: () => _onPrayed(enableZen: false),
              ),

              const SizedBox(height: 14),

              // Button 2: Going Now (snooze)
              _buildActionButton(
                label: 'Not yet, I\'m going now',
                icon: Icons.timer_outlined,
                isPrimary: false,
                accent: accent,
                subtitle: 'Remind in $snoozeMins min',
                onTap: _onSnooze,
              ),

              const SizedBox(height: 14),

              // Button 3: Prayed + Zen Mode (picks duration)
              _buildActionButton(
                label: 'Prayed + Enable Muraqaba',
                icon: Icons.self_improvement_rounded,
                isPrimary: false,
                accent: accent,
                subtitle: 'Choose focus duration after prayer',
                onTap: () => _onZenModePickDuration(accent),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      ), // Scaffold
    ); // PopScope
  }

  // ── Sound toggle row ────────────────────────────────

  Widget _buildSoundToggle(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleSound,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _soundEnabled
                    ? accent.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              color: _soundEnabled
                  ? accent.withValues(alpha: 0.08)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  size: 18,
                  color: _soundEnabled
                      ? accent.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 8),
                Text(
                  _soundEnabled ? 'Sound On' : 'Sound Off',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _soundEnabled
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerseCard(Color accent) {
    final verse = _versesForPrayer[widget.prayerName] ?? _versesForPrayer['Fajr']!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Column(
        children: [
          Text(
            verse['arabic']!,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 20,
              height: 1.9,
              color: Colors.white.withValues(alpha: 0.85),
              fontFamily: 'Amiri',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            verse['translation']!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.4),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            verse['reference']!,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: accent.withValues(alpha: 0.35),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required Color accent,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isPrimary
              ? accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: isPrimary
                ? accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isPrimary
                  ? accent
                  : Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                      color: isPrimary
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ],
        ),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────

  /// Shows Zen Mode duration picker, then enables Zen Mode + logs prayer.
  Future<void> _onZenModePickDuration(Color accent) async {
    HapticFeedback.mediumImpact();

    int selectedMinutes = 30;

    final picked = await showDialog<int>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF0D0D0D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.self_improvement_rounded, size: 36, color: accent),
                const SizedBox(height: 14),
                Text(
                  'Choose Zen Duration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Block distractions after prayer',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                const SizedBox(height: 24),
                // Duration options
                ...([15, 30, 45, 60, 90]).map((mins) {
                  final isSelected = selectedMinutes == mins;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setDialogState(() => selectedMinutes = mins);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? accent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.03),
                        border: Border.all(
                          color: isSelected
                              ? accent.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.07),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            size: 18,
                            color: isSelected
                                ? accent
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$mins minutes',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          const Spacer(),
                          if (mins == 30)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: accent.withValues(alpha: 0.12),
                              ),
                              child: Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: accent.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.of(ctx).pop(selectedMinutes),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: accent.withValues(alpha: 0.2),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.4)),
                          ),
                          child: Center(
                            child: Text(
                              'Start Zen',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (picked == null) return; // User cancelled
    _onPrayed(enableZen: true, zenDuration: picked);
  }

  void _onPrayed({required bool enableZen, int zenDuration = 30}) async {
    // Cancel auto-close timer - user responded
    _autoCloseTimer?.cancel();
    
    // 0. Stop alarm sound immediately
    await _stopAlarmSound();

    // 1. Log prayer in existing PrayerRecord system
    try {
      ref
          .read(prayerRecordListProvider.notifier)
          .togglePrayer(DateTime.now(), widget.prayerName);
    } catch (_) {}

    // 2. Dismiss notification + clear native wake-screen flags
    await PrayerAlarmService.dismissNotification(widget.prayerName);
    await PrayerAlarmService.dismissAlarmWakeFlags();

    // 3. Optionally enable Zen Mode with chosen duration
    if (enableZen) {
      try {
        ref.read(zenModeProvider.notifier).startZenMode(zenDuration);
      } catch (_) {}
    }

    // 4. Close alarm screen and navigate
    if (mounted) {
      if (enableZen) {
        // Mark alarm screen closed BEFORE pushReplacement so that the
        // LauncherShell lifecycle guard won't see it as still showing.
        PrayerAlarmService.markAlarmScreenClosed();

        // Replace alarm screen with Zen Mode screen so the user lands directly in it
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, animation, _) => const ZenModeActiveScreen(),
            transitionsBuilder: (_, animation, _, child) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      } else {
        // 5. Show beautiful centered prayer confirmation overlay BEFORE pop
        // (must be before pop, because after pop the widget is unmounted
        //  and Overlay.of(context) would throw)
        await _showPrayerConfirmation(widget.prayerName);

        // Mark alarm screen closed BEFORE pop so lifecycle guards in
        // LauncherShell see the correct state immediately on resume.
        PrayerAlarmService.markAlarmScreenClosed();

        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  /// Show a beautiful centered overlay confirming the prayer was logged.
  /// Fades in with a scale animation, auto-dismisses after 1.8 seconds.
  Future<void> _showPrayerConfirmation(String prayerName) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final accent = ref.read(themeColorProvider).color;

    final animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    final scaleAnim = CurvedAnimation(parent: animController, curve: Curves.easeOutBack);
    final fadeAnim  = CurvedAnimation(parent: animController, curve: Curves.easeIn);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: animController,
        builder: (_, __) => Opacity(
          opacity: fadeAnim.value,
          child: Center(
            child: ScaleTransition(
              scale: scaleAnim,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 52),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0E0E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.18),
                        blurRadius: 48,
                        spreadRadius: 4,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 34,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Alhamdulillah',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '$prayerName prayer recorded',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.42),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.volunteer_activism_rounded,
                            size: 14,
                            color: accent.withValues(alpha: 0.65),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'May Allah accept it',
                            style: TextStyle(
                              fontSize: 12,
                              color: accent.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await animController.forward();
    await Future.delayed(const Duration(milliseconds: 1500));
    await animController.reverse();
    entry.remove();
    scaleAnim.dispose();
    fadeAnim.dispose();
    animController.dispose();
  }

  void _onSnooze() async {
    // Cancel auto-close timer - user responded
    _autoCloseTimer?.cancel();
    
    // 0. Stop alarm sound immediately
    await _stopAlarmSound();

    final alarmState = ref.read(prayerAlarmProvider);
    final mins = alarmState.reminderSettings.snoozeDurationMinutes;

    // 1. Dismiss current notification FIRST (before scheduling snooze)
    await PrayerAlarmService.dismissNotification(widget.prayerName);
    // Clear native wake-screen flags — screen can lock again during snooze
    await PrayerAlarmService.dismissAlarmWakeFlags();

    // 2. Schedule snooze alarm — fires a new notification after N minutes
    bool snoozeScheduled = false;
    try {
      final snoozeNotifType =
          alarmState.reminderSettings.notifTypeFor(widget.prayerName);
      await PrayerAlarmService.scheduleSnooze(
        prayerName: widget.prayerName,
        minutes: mins,
        notifType: snoozeNotifType,
      );
      snoozeScheduled = true;
    } catch (_) {}

    // 3. Mark alarm screen closed BEFORE pop so lifecycle guards in
    //    LauncherShell see the correct state immediately on resume.
    PrayerAlarmService.markAlarmScreenClosed();

    // 4. Close screen
    if (mounted) {
      Navigator.of(context).pop();

      // 5. Show feedback
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              snoozeScheduled
                  ? '⏰ Reminder set for $mins minutes'
                  : '⏰ Closing — pray when ready',
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // ── Quranic verses per prayer ──────────────────────

  static const Map<String, Map<String, String>> _versesForPrayer = {
    'Fajr': {
      'arabic': 'إِنَّ قُرْآنَ الْفَجْرِ كَانَ مَشْهُودًا',
      'translation':
          '"Indeed, the recitation of dawn is ever witnessed."',
      'reference': 'SURAH AL-ISRA 17:78',
    },
    'Dhuhr': {
      'arabic': 'حَافِظُوا عَلَى الصَّلَوَاتِ وَالصَّلَاةِ الْوُسْطَىٰ',
      'translation':
          '"Guard strictly your prayers, especially the middle prayer."',
      'reference': 'SURAH AL-BAQARAH 2:238',
    },
    'Asr': {
      'arabic': 'وَالْعَصْرِ · إِنَّ الْإِنسَانَ لَفِي خُسْرٍ',
      'translation':
          '"By time, indeed mankind is in loss."',
      'reference': 'SURAH AL-ASR 103:1-2',
    },
    'Maghrib': {
      'arabic': 'وَسَبِّحْ بِحَمْدِ رَبِّكَ قَبْلَ طُلُوعِ الشَّمْسِ وَقَبْلَ غُرُوبِهَا',
      'translation':
          '"Glorify your Lord before sunrise and before sunset."',
      'reference': 'SURAH TA-HA 20:130',
    },
    'Isha': {
      'arabic': 'وَمِنَ اللَّيْلِ فَاسْجُدْ لَهُ وَسَبِّحْهُ لَيْلًا طَوِيلًا',
      'translation':
          '"And prostrate to Him during the night and exalt Him a long night."',
      'reference': 'SURAH AL-INSAN 76:26',
    },
  };
}
