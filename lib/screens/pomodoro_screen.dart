import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/productivity_provider.dart';
import '../providers/ambient_sound_provider.dart';
import '../providers/hub_theme_provider.dart';
import '../models/productivity_models.dart';

// ── palette ─────────────────────────────────────────────────────────────────
const _lGradTop     = Color(0xFFFFC94A);
const _lGradMid     = Color(0xFFFFD97A);
const _lGradBot     = Color(0xFFFFF0C0);
const _lCard        = Color(0xFFFDF5DE);
const _lTxt         = Color(0xFF2E2010);
const _lSub         = Color(0xFF9B7E50);
const _lSlider      = Color(0xFF5B4FCF);
const _dBg          = Color(0xFF000000);
const _dCard        = Color(0xFF1B1E27);
const _dTxt         = Color(0xFFEEEBD8);
const _dSub         = Color(0xFF6B7080);
const _dDivider     = Color(0xFF242830);
const _accentOrange = Color(0xFFE8734A);

// ─────────────────────────────────────────────────────────────────────────────
// TRANSITION INFO
// ─────────────────────────────────────────────────────────────────────────────
class _TransitionInfo {
  final bool isFocusDone;
  final int minutes;
  const _TransitionInfo({required this.isFocusDone, required this.minutes});
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSITION OVERLAY
// ─────────────────────────────────────────────────────────────────────────────
class _TransitionOverlay extends StatefulWidget {
  final _TransitionInfo info;
  final bool light;
  final VoidCallback onDismiss;
  const _TransitionOverlay(
      {required this.info, required this.light, required this.onDismiss});
  @override
  State<_TransitionOverlay> createState() => _TransitionOverlayState();
}

class _TransitionOverlayState extends State<_TransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info   = widget.info;
    final iconData = info.isFocusDone ? Icons.track_changes_rounded : Icons.coffee_rounded;
    final title  = info.isFocusDone ? 'Focus Complete!' : 'Break Done!';
    final sub1   = info.isFocusDone
        ? 'You focused for ${info.minutes} min'
        : 'Break was ${info.minutes} min';
    final next   = info.isFocusDone ? 'Starting short break…' : 'Starting focus…';
    final accent = info.isFocusDone
        ? (widget.light ? _lSlider : _accentOrange)
        : (widget.light ? _lSub : _dSub);
    final txt    = widget.light ? _lTxt : _dTxt;
    final sub    = widget.light ? _lSub : _dSub;

    return Positioned(
      left: 24, right: 24, bottom: 130,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: widget.light ? _lCard : _dCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.28), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 24, offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 22, color: accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              color: txt, fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(sub1,
                          style: TextStyle(color: sub, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(next,
                          style: TextStyle(
                              color: accent, fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Icon(Icons.close_rounded, size: 16, color: sub),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN POMODORO SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class PomodoroScreen extends ConsumerStatefulWidget {
  const PomodoroScreen({super.key});
  @override
  ConsumerState<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends ConsumerState<PomodoroScreen>
    with SingleTickerProviderStateMixin {
  int _prevSessions = 0;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;
  _TransitionInfo? _transition;
  Timer? _transTimer;
  String? _focusTag; // currently selected focus tag

  // ── Immersive mode ────────────────────────────────────────────────────────
  // While a session is active, the UI (controls, top-bar, hint text) is
  // hidden after _kAutoHideMs of inactivity.  A single tap anywhere reveals
  // them again and resets the auto-hide countdown.
  bool _uiVisible = true;
  Timer? _hideTimer;
  static const _kAutoHideMs = 4000; // ms until controls auto-hide

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: _kAutoHideMs), () {
      if (mounted) setState(() => _uiVisible = false);
    });
  }

  void _revealUi() {
    setState(() => _uiVisible = true);
    _scheduleHide();
  }

  // Preset tags
  static const _presetTags = [
    'Study', 'Work', 'Ibadah', 'Workout',
    'Writing', 'Creative', 'Calls', 'Mindfulness',
  ];

  static const _presetTagIcons = <String, IconData>{
    'Study':       Icons.menu_book_rounded,
    'Work':        Icons.laptop_rounded,
    'Ibadah':      Icons.mosque_rounded,
    'Workout':     Icons.fitness_center_rounded,
    'Writing':     Icons.edit_note_rounded,
    'Creative':    Icons.palette_rounded,
    'Calls':       Icons.call_rounded,
    'Mindfulness': Icons.self_improvement_rounded,
  };

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _pulse = Tween(begin: 1.0, end: 1.07)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _transTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  bool get _light => ref.watch(hubThemeLightModeProvider);

  void _showTransition(_TransitionInfo info) {
    setState(() => _transition = info);
    _transTimer?.cancel();
    _transTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _transition = null);
    });
  }

  /// Shows the focus tag picker bottom sheet.
  /// Returns the chosen tag string or null if dismissed.
  Future<void> _showTagPicker() async {
    final accent  = _light ? _lSlider : _accentOrange;
    final bgColor = _light ? _lCard   : _dCard;
    final txt     = _light ? _lTxt    : _dTxt;
    final sub     = _light ? _lSub    : _dSub;

    final customCtrl = TextEditingController();
    String? chosen;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: sub.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text('What are you focusing on?',
                    style: TextStyle(
                        color: txt, fontSize: 17,
                        fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                const SizedBox(height: 4),
                Text('Pick a tag or write your own',
                    style: TextStyle(color: sub, fontSize: 13)),
                const SizedBox(height: 16),
                // Preset chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetTags.map((tag) {
                    final isSelected = chosen == tag;
                    return GestureDetector(
                      onTap: () {
                        setLocal(() => chosen = isSelected ? null : tag);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accent.withValues(alpha: 0.18)
                              : sub.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? accent.withValues(alpha: 0.55)
                                : sub.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _presetTagIcons[tag] ?? Icons.label_outline_rounded,
                              size: 14,
                              color: isSelected
                                  ? accent
                                  : sub.withValues(alpha: 0.65),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tag,
                              style: TextStyle(
                                color: isSelected ? accent : sub,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                // Custom tag input
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: customCtrl,
                      style: TextStyle(color: txt, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Or type your own…',
                        hintStyle:
                            TextStyle(color: sub.withValues(alpha: 0.5), fontSize: 14),
                        filled: true,
                        fillColor: sub.withValues(alpha: 0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        isDense: true,
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                  ),
                  if (customCtrl.text.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setLocal(() => chosen = customCtrl.text.trim());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Use',
                            style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 20),
                // Start button
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      // Use custom text if typed but not yet "used"
                      final finalTag = chosen ??
                          (customCtrl.text.trim().isNotEmpty
                              ? customCtrl.text.trim()
                              : null);
                      Navigator.pop(ctx);
                      setState(() => _focusTag = finalTag);
                      ref
                          .read(pomodoroProvider.notifier)
                          .startFocus(todoId: ref.read(pomodoroProvider).activeTodoId);
                    },
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        chosen != null ||
                                customCtrl.text.trim().isNotEmpty
                            ? 'Start  —  ${chosen ?? customCtrl.text.trim()}'
                            : 'Start Focus',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
    customCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pomo  = ref.watch(pomodoroProvider);
    final sound = ref.watch(ambientSoundProvider);

    if (pomo.completedSessions > _prevSessions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(focusStreakProvider.notifier).recordSession();
        _pulseCtrl.forward(from: 0);
        _showTransition(_TransitionInfo(
          isFocusDone: true,
          minutes: pomo.settings.focusMinutes,
        ));
        setState(() => _prevSessions = pomo.completedSessions);
      });
    }

    final isFocusing = pomo.state == PomodoroState.focusing;
    final isShort    = pomo.state == PomodoroState.shortBreak;
    final isPaused   = pomo.state == PomodoroState.paused;
    final isActive   = isFocusing || isShort || isPaused;

    // When session just became active, kick off auto-hide.
    // When session ends, cancel timer and restore full UI.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isActive && _hideTimer == null) {
        _scheduleHide();
      } else if (!isActive) {
        _hideTimer?.cancel();
        _hideTimer = null;
        if (!_uiVisible) setState(() => _uiVisible = true);
      }
    });

    final stateLabel = isFocusing ? 'Focus'
        : isShort   ? 'Short Break'
        : isPaused  ? 'Paused'
        : 'Ready';

    final txt    = _light ? _lTxt    : _dTxt;
    final sub    = _light ? _lSub    : _dSub;
    final accent = _light ? _lSlider : _accentOrange;

    return Scaffold(
      backgroundColor: _light ? _lGradBot : _dBg,
      body: Container(
        decoration: _light
            ? const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.4, 1.0],
                  colors: [_lGradTop, _lGradMid, _lGradBot],
                ),
              )
            : const BoxDecoration(color: _dBg),
        child: SafeArea(
          child: GestureDetector(
            // During active session: tap anywhere to toggle UI visibility
            onTap: isActive ? _revealUi : null,
            behavior: HitTestBehavior.translucent,
            child: Stack(
            children: [
              Column(children: [
                // ── TOP BAR ────────────────────────────────────────
                AnimatedOpacity(
                  opacity: (!isActive || _uiVisible) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: IgnorePointer(
                    ignoring: isActive && !_uiVisible,
                    child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: sub),
                    ),
                    const Spacer(),
                    Text(stateLabel,
                        style: TextStyle(
                            color: sub, fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    if (!isActive) ...[
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                              _slideRoute(_StatsPage(light: _light)));
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: Icon(Icons.bar_chart_rounded,
                              size: 24, color: sub),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(context,
                              _slideRoute(const _SettingsPage()));
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Icon(Icons.settings_rounded,
                            size: 24, color: sub),
                      ),
                    ] else ...[
                      GestureDetector(
                        onTap: () {
                          if (sound.isPlaying) {
                            ref.read(ambientSoundProvider.notifier).stop();
                          } else {
                            ref.read(ambientSoundProvider.notifier)
                                .selectAndPlay(sound.currentSoundId ?? 'rain');
                          }
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          sound.isPlaying
                              ? Icons.music_note_rounded
                              : Icons.music_off_rounded,
                          size: 22, color: sub,
                        ),
                      ),
                    ],
                  ]),
                ),
                  ),
                ),

                // ── TIMER CENTER ───────────────────────────────────
                Expanded(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) => Transform.scale(
                          scale: _pulse.value,
                          child: Text(
                            pomo.timeDisplay,
                            style: TextStyle(
                              fontSize: 90,
                              fontWeight: FontWeight.w600,
                              color: txt,
                              letterSpacing: 2,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),

                      if (isActive) ...[
                        const SizedBox(height: 12),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: isFocusing
                                ? accent.withValues(alpha: 0.12)
                                : sub.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isFocusing
                                    ? Icons.track_changes_rounded
                                    : isPaused
                                        ? Icons.pause_circle_outline_rounded
                                        : Icons.coffee_rounded,
                                size: 14,
                                color: isFocusing ? accent : sub,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isFocusing
                                    ? (_focusTag ?? 'Focusing')
                                    : isPaused
                                        ? 'Paused'
                                        : 'Short Break',
                                style: TextStyle(
                                  color: isFocusing ? accent : sub,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(
                              pomo.settings.sessionsBeforeLongBreak, (i) {
                            final cyclePos = pomo.completedSessions %
                                pomo.settings.sessionsBeforeLongBreak;
                            // During break/paused-from-break, the focus dot
                            // is done — reflect that visually.
                            final effectiveDone = (isShort || (isPaused && pomo.previousState == PomodoroState.shortBreak))
                                ? cyclePos  // break means last focus is done
                                : cyclePos;
                            final done = i < effectiveDone;
                            final cur  = i == effectiveDone && (isFocusing || (isPaused && pomo.previousState == PomodoroState.focusing));
                            final isBreakDot = i == cyclePos && isShort;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: (cur || isBreakDot) ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: done || isBreakDot
                                    ? accent
                                    : cur
                                        ? accent.withValues(alpha: 0.45)
                                        : sub.withValues(alpha: 0.2),
                              ),
                            );
                          }),
                        ),
                      ],

                      if (!isActive) ...[
                        const SizedBox(height: 14),
                        // ── Focus tag display / picker trigger ──
                        GestureDetector(
                          onTap: () {
                            _showTagPicker();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: _focusTag != null
                                  ? accent.withValues(alpha: 0.12)
                                  : sub.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _focusTag != null
                                    ? accent.withValues(alpha: 0.35)
                                    : sub.withValues(alpha: 0.18),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _focusTag ?? 'Focus',
                                  style: TextStyle(
                                    color: _focusTag != null ? accent : sub,
                                    fontSize: 14,
                                    fontWeight: _focusTag != null
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Icon(
                                  _focusTag != null
                                      ? Icons.edit_rounded
                                      : Icons.expand_more_rounded,
                                  size: 15,
                                  color: _focusTag != null
                                      ? accent.withValues(alpha: 0.7)
                                      : sub.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        GestureDetector(
                          onTap: () {
                            _showTagPicker();
                          },
                          child: Container(
                            width: 180, height: 54,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(27),
                            ),
                            alignment: Alignment.center,
                            child: const Text('Start',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4)),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),

                // ── BOTTOM CONTROLS ────────────────────────────────
                if (isActive)
                  AnimatedOpacity(
                    opacity: _uiVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: IgnorePointer(
                      ignoring: !_uiVisible,
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 44),
                    child: Column(children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _circleBtn(
                            icon: Icons.skip_previous_rounded,
                            color: sub, size: 50,
                            onTap: () {
                              ref.read(pomodoroProvider.notifier).skipBackward();
                            },
                          ),
                          const SizedBox(width: 20),
                          _circleBtn(
                            icon: Icons.stop_rounded,
                            color: sub, size: 50,
                            onTap: () {
                              ref.read(pomodoroProvider.notifier).reset();
                              setState(() => _focusTag = null);
                            },
                          ),
                          const SizedBox(width: 20),
                          _circleBtn(
                            icon: isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: accent, size: 64, filled: true,
                            onTap: () {
                              if (isPaused) {
                                ref.read(pomodoroProvider.notifier).resume();
                              } else {
                                ref.read(pomodoroProvider.notifier).pause();
                              }
                              // Tapping a control resets auto-hide countdown
                              _revealUi();
                            },
                          ),
                          const SizedBox(width: 20),
                          _circleBtn(
                            icon: Icons.skip_next_rounded,
                            color: sub, size: 50,
                            onTap: () {
                              final wasBreak =
                                  pomo.state == PomodoroState.shortBreak;
                              final totalMins = wasBreak
                                  ? pomo.settings.shortBreakMinutes
                                  : pomo.settings.focusMinutes;
                              final elapsed = totalMins -
                                  (pomo.remainingSeconds ~/ 60);
                              ref.read(pomodoroProvider.notifier).skipForward();
                              _showTransition(_TransitionInfo(
                                isFocusDone: !wasBreak,
                                minutes: elapsed.clamp(0, totalMins),
                              ));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isFocusing
                            ? '⏭  next → short break'
                            : isShort
                                ? '⏭  next → focus'
                                : '',
                        style: TextStyle(
                            color: sub.withValues(alpha: 0.50),
                            fontSize: 11),
                      ),
                    ]),
                  ),
                    ),
                  ),
              ]),

              // ── TAP HINT — visible only when controls are hidden ──
              if (isActive)
                Positioned(
                  bottom: 20,
                  left: 0, right: 0,
                  child: AnimatedOpacity(
                    opacity: _uiVisible ? 0.0 : 0.30,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: Center(
                      child: Text(
                        'tap to show controls',
                        style: TextStyle(
                          color: sub,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),

              // ── TRANSITION OVERLAY ─────────────────────────────
              if (_transition != null)
                _TransitionOverlay(
                  info: _transition!,
                  light: _light,
                  onDismiss: () => setState(() => _transition = null),
                ),
            ],
          ),        // Stack
          ),        // GestureDetector
        ),          // SafeArea
      ),            // Container
    );             // Scaffold
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required double size,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? color
              : color.withValues(alpha: 0.10),
          border: filled
              ? null
              : Border.all(color: color.withValues(alpha: 0.22), width: 1.2),
          boxShadow: filled
              ? [BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 14, offset: const Offset(0, 4))]
              : null,
        ),
        child: Icon(icon, size: size * 0.44,
            color: filled ? Colors.white : color),
      ),
    );
  }

  static Route _slideRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (ctx, a1, a2) => page,
      transitionsBuilder: (ctx2, anim, a3, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 260),
    );
  }
}

// =============================================================================
// SETTINGS PAGE
// =============================================================================
class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final light    = ref.watch(hubThemeLightModeProvider);
    final settings = ref.watch(pomodoroProvider).settings;

    final bg      = light ? _lGradMid : _dBg;
    final card    = light ? _lCard    : _dCard;
    final txt     = light ? _lTxt     : _dTxt;
    final sub     = light ? _lSub     : _dSub;
    final slider  = light ? _lSlider  : _accentOrange;
    final divider = light ? Colors.transparent : _dDivider;

    PomodoroSettings s({
      int? f, int? sb, int? cycles,
      bool? autoBreak, bool? snd, bool? autoFocus,
    }) =>
        PomodoroSettings(
          focusMinutes:            f         ?? settings.focusMinutes,
          shortBreakMinutes:       sb        ?? settings.shortBreakMinutes,
          longBreakMinutes:        settings.longBreakMinutes,
          sessionsBeforeLongBreak: cycles    ?? settings.sessionsBeforeLongBreak,
          autoStartBreaks:         autoBreak ?? settings.autoStartBreaks,
          autoStartFocus:          autoFocus ?? settings.autoStartFocus,
          soundEnabled:            snd       ?? settings.soundEnabled,
        );

    Widget sliderCard({
      required IconData icon,
      required String label,
      required int value,
      required String suffix,
      required double min,
      required double max,
      required int divisions,
      required ValueChanged<double> onChanged,
    }) =>
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: light ? null : Border.all(color: divider),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 22, color: sub),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      color: txt, fontSize: 17,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(suffix.isEmpty ? '$value' : '$value $suffix',
                  style: TextStyle(color: sub, fontSize: 13)),
            ),
            SliderTheme(
              data: SliderThemeData(
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 18),
                trackHeight: 3,
                activeTrackColor: slider,
                inactiveTrackColor: sub.withValues(alpha: 0.18),
                thumbColor: slider,
                overlayColor: slider.withValues(alpha: 0.08),
              ),
              child: Slider(
                value: value.toDouble(),
                min: min, max: max, divisions: divisions,
                onChanged: (v) {
                  onChanged(v);
                },
              ),
            ),
          ]),
        );

    Widget toggleCard({
      required IconData icon,
      required String label,
      required String hint,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) =>
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: light ? null : Border.all(color: divider),
          ),
          child: Row(children: [
            Icon(icon, size: 22, color: sub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: txt, fontSize: 16,
                            fontWeight: FontWeight.w500)),
                    if (hint.isNotEmpty)
                      Text(hint, style: TextStyle(color: sub, fontSize: 11)),
                  ]),
            ),
            Switch.adaptive(
              value: value,
              onChanged: (v) {
                onChanged(v);
              },
              activeThumbColor: Colors.white,
              activeTrackColor: slider,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: sub.withValues(alpha: 0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: sub),
              ),
              const Spacer(),
              Text('Settings',
                  style: TextStyle(
                      color: txt, fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  ref.read(hubThemeLightModeProvider.notifier).toggle();
                },
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  light ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  size: 22, color: sub,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Timer',
                        style: TextStyle(
                            color: sub, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    sliderCard(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Focus', value: settings.focusMinutes,
                      suffix: 'minutes', min: 5, max: 120, divisions: 23,
                      onChanged: (v) => ref
                          .read(pomodoroProvider.notifier)
                          .updateSettings(s(f: v.round())),
                    ),
                    sliderCard(
                      icon: Icons.free_breakfast_outlined,
                      label: 'Short Break',
                      value: settings.shortBreakMinutes,
                      suffix: 'minutes', min: 1, max: 30, divisions: 29,
                      onChanged: (v) => ref
                          .read(pomodoroProvider.notifier)
                          .updateSettings(s(sb: v.round())),
                    ),
                    sliderCard(
                      icon: Icons.sync_rounded,
                      label: 'Cycles', value: settings.sessionsBeforeLongBreak,
                      suffix: '', min: 2, max: 8, divisions: 6,
                      onChanged: (v) => ref
                          .read(pomodoroProvider.notifier)
                          .updateSettings(s(cycles: v.round())),
                    ),
                    const SizedBox(height: 8),
                    Text('Automation',
                        style: TextStyle(
                            color: sub, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    toggleCard(
                      icon: Icons.play_circle_outline_rounded,
                      label: 'Auto-start Breaks',
                      hint: 'Short break starts after focus ends',
                      value: settings.autoStartBreaks,
                      onChanged: (v) => ref
                          .read(pomodoroProvider.notifier)
                          .updateSettings(s(autoBreak: v)),
                    ),
                    toggleCard(
                      icon: Icons.replay_circle_filled_outlined,
                      label: 'Auto-start Focus',
                      hint: 'Focus restarts after break ends',
                      value: settings.autoStartFocus,
                      onChanged: (v) => ref
                          .read(pomodoroProvider.notifier)
                          .updateSettings(s(autoFocus: v)),
                    ),
                    const SizedBox(height: 8),
                    Text('Preferences',
                        style: TextStyle(
                            color: sub, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    toggleCard(
                      icon: Icons.volume_off_outlined,
                      label: 'Timer Sound', hint: '',
                      value: settings.soundEnabled,
                      onChanged: (v) => ref
                          .read(pomodoroProvider.notifier)
                          .updateSettings(s(snd: v)),
                    ),
                    toggleCard(
                      icon: Icons.dark_mode_outlined,
                      label: 'Dark Mode', hint: '',
                      value: !light,
                      onChanged: (_) {
                        ref.read(hubThemeLightModeProvider.notifier).toggle();
                      },
                    ),
                    const SizedBox(height: 8),
                    Text('Ambient Sound',
                        style: TextStyle(
                            color: sub, fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _AmbientCard(
                        card: card, txt: txt, sub: sub,
                        slider: slider, divider: divider, light: light),
                    const SizedBox(height: 36),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// =============================================================================
// STATS PAGE
// =============================================================================
class _StatsPage extends ConsumerStatefulWidget {
  final bool light;
  const _StatsPage({required this.light});
  @override
  ConsumerState<_StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<_StatsPage> {
  int _weekOffset = 0;
  DateTime? _selectedDate;
  List<FocusSessionLog>? _selectedDayLogs;
  bool _loadingDay = false;
  late final ScrollController _dayScroll;

  @override
  void initState() {
    super.initState();
    _dayScroll = ScrollController();
    _selectedDate = DateTime.now();
    _loadDayLogs(_selectedDate!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_dayScroll.hasClients) {
        _dayScroll.animateTo(
          _dayScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _dayScroll.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadDayLogs(DateTime date) async {
    setState(() => _loadingDay = true);
    final now     = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    if (isToday) {
      final pomo = ref.read(pomodoroProvider);
      if (mounted) {
        setState(() {
          _selectedDayLogs = pomo.todayLogs;
          _loadingDay      = false;
        });
      }
    } else {
      final logs =
          await ref.read(pomodoroProvider.notifier).logsForDate(_dateKey(date));
      if (mounted) {
        setState(() {
          _selectedDayLogs = logs;
          _loadingDay      = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = ref.watch(hubThemeLightModeProvider);
    final pomo    = ref.watch(pomodoroProvider);
    final streak  = ref.watch(focusStreakProvider);

    final bg      = isLight ? _lGradMid  : _dBg;
    final card    = isLight ? _lCard     : _dCard;
    final txt     = isLight ? _lTxt      : _dTxt;
    final sub     = isLight ? _lSub      : _dSub;
    final accent  = isLight ? _lSlider   : _accentOrange;
    final dayBg   = isLight ? _lCard     : const Color(0xFF252830);
    final divider = isLight ? Colors.transparent : _dDivider;

    final now      = DateTime.now();
    final todayMon = now.subtract(Duration(days: now.weekday - 1));
    final weekMon  = todayMon.add(Duration(days: _weekOffset * 7));
    final wEnd     = weekMon.add(const Duration(days: 6));
    const months   = ['Jan','Feb','Mar','Apr','May','Jun',
                       'Jul','Aug','Sep','Oct','Nov','Dec'];
    const dNames   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

    final totalFocus = pomo.totalFocusMinutesToday;
    final timeStr = totalFocus >= 60
        ? '${totalFocus ~/ 60}h ${totalFocus % 60}m'
        : '${totalFocus}m';

    final weekLabel = _weekOffset == 0
        ? 'This week'
        : '${months[weekMon.month - 1]} ${weekMon.day} – '
          '${months[wEnd.month - 1]} ${wEnd.day}';

    final selDate = _selectedDate;
    String selLabel = '';
    if (selDate != null) {
      final isToday = selDate.day == now.day &&
          selDate.month == now.month && selDate.year == now.year;
      selLabel = isToday
          ? 'Today'
          : '${dNames[selDate.weekday - 1]}, '
            '${months[selDate.month - 1]} ${selDate.day}';
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 20, color: sub),
              ),
              const Spacer(),
              Text('Statistics',
                  style: TextStyle(
                      color: txt, fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.calendar_month_outlined, size: 22, color: sub),
            ]),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                // Week nav + day pills
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(22),
                    border: isLight ? null : Border.all(color: divider),
                  ),
                  child: Column(children: [
                    Row(children: [
                      GestureDetector(
                        onTap: () => setState(() => _weekOffset--),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.chevron_left_rounded,
                              size: 22, color: sub),
                        ),
                      ),
                      Expanded(
                        child: Text(weekLabel,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: txt, fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                      GestureDetector(
                        onTap: _weekOffset < 0
                            ? () => setState(() => _weekOffset++)
                            : null,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.chevron_right_rounded,
                              size: 22,
                              color: _weekOffset < 0
                                  ? sub
                                  : sub.withValues(alpha: 0.2)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 68,
                      child: ListView.builder(
                        controller: _dayScroll,
                        scrollDirection: Axis.horizontal,
                        itemCount: 7,
                        itemBuilder: (context, i) {
                          final date    = weekMon.add(Duration(days: i));
                          final isToday = _weekOffset == 0 &&
                              date.day == now.day &&
                              date.month == now.month;
                          final isSel   = selDate != null &&
                              date.day == selDate.day &&
                              date.month == selDate.month &&
                              date.year == selDate.year;
                          final isFuture = date.isAfter(now);
                          return GestureDetector(
                            onTap: isFuture
                                ? null
                                : () {
                                    setState(() => _selectedDate = date);
                                    _loadDayLogs(date);
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 46,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? accent
                                    : isToday
                                        ? accent.withValues(alpha: 0.14)
                                        : dayBg,
                                borderRadius: BorderRadius.circular(14),
                                border: isSel
                                    ? null
                                    : isToday
                                        ? Border.all(
                                            color: accent.withValues(
                                                alpha: 0.38),
                                            width: 1.2)
                                        : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(dNames[i],
                                      style: TextStyle(
                                          color: isSel
                                              ? Colors.white
                                              : isFuture
                                                  ? sub.withValues(alpha: 0.3)
                                                  : sub,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 4),
                                  Text('${date.day}',
                                      style: TextStyle(
                                          color: isSel
                                              ? Colors.white
                                              : isFuture
                                                  ? txt.withValues(alpha: 0.25)
                                                  : txt,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // Stat pills
                Row(children: [
                  _MiniStat(
                    icon: Icons.local_fire_department_rounded,
                    value: '$streak',
                    label: streak == 1 ? 'day streak' : 'days streak',
                    color: _accentOrange,
                    card: card, txt: txt, sub: sub,
                    divider: divider, light: isLight,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.check_circle_outline_rounded,
                    value: '${pomo.completedSessions}',
                    label: 'sessions',
                    color: accent,
                    card: card, txt: txt, sub: sub,
                    divider: divider, light: isLight,
                  ),
                  const SizedBox(width: 10),
                  _MiniStat(
                    icon: Icons.schedule_rounded,
                    value: timeStr,
                    label: 'focused',
                    color: accent,
                    card: card, txt: txt, sub: sub,
                    divider: divider, light: isLight,
                  ),
                ]),
                const SizedBox(height: 18),

                // Selected day header
                if (selDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Text(selLabel,
                          style: TextStyle(
                              color: txt, fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      if (_loadingDay)
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: accent),
                        ),
                    ]),
                  ),

                // Day logs
                if (_loadingDay)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(
                          color: accent, strokeWidth: 2),
                    ),
                  )
                else if (_selectedDayLogs != null &&
                    _selectedDayLogs!.isNotEmpty)
                  ..._selectedDayLogs!.reversed.map((log) {
                    final isFocusLog = log.type == 'focus';
                    final label      = isFocusLog ? 'Focus' : 'Short Break';
                    final h          = log.startTime.hour;
                    final m          = log.startTime.minute
                        .toString().padLeft(2, '0');
                    final ampm       = h >= 12 ? 'PM' : 'AM';
                    final h12        = h == 0 ? 12 : h > 12 ? h - 12 : h;
                    final logColor   = isFocusLog ? accent : sub;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: card,
                        borderRadius: BorderRadius.circular(18),
                        border:
                            isLight ? null : Border.all(color: divider),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: logColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFocusLog
                                ? Icons.self_improvement_rounded
                                : Icons.free_breakfast_outlined,
                            size: 18, color: logColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label,
                                  style: TextStyle(
                                      color: txt, fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('Started $h12:$m $ampm',
                                  style: TextStyle(
                                      color: sub, fontSize: 12)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${log.durationMinutes} min',
                                style: TextStyle(
                                    color: logColor, fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            Text('duration',
                                style:
                                    TextStyle(color: sub, fontSize: 10)),
                          ],
                        ),
                      ]),
                    );
                  })
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(children: [
                      Icon(Icons.self_improvement_rounded,
                          size: 52,
                          color: sub.withValues(alpha: 0.25)),
                      const SizedBox(height: 14),
                      Text('No sessions',
                          style: TextStyle(color: sub, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text(
                        'No focus sessions recorded for this day',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: sub.withValues(alpha: 0.55),
                            fontSize: 12),
                      ),
                    ]),
                  ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// =============================================================================
// AMBIENT CARD
// =============================================================================
class _AmbientCard extends ConsumerWidget {
  final Color card, txt, sub, slider, divider;
  final bool light;
  const _AmbientCard({
    required this.card, required this.txt, required this.sub,
    required this.slider, required this.divider, required this.light,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sound  = ref.watch(ambientSoundProvider);
    const ids    = ['rain', 'waterfall', 'stream', 'gentle_water'];
    const labels = ['Rain', 'Waterfall', 'Stream', 'Waves'];
    const icons  = [
      Icons.water_drop_rounded, Icons.waves_rounded,
      Icons.water_rounded,      Icons.air_rounded,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: light ? null : Border.all(color: divider),
      ),
      child: Column(children: [
        Row(
          children: [
            _Chip(
              icon: Icons.volume_off_rounded, label: 'Off',
              selected: !sound.isPlaying, accent: slider, sub: sub,
              onTap: () {
                ref.read(ambientSoundProvider.notifier).stop();
              },
            ),
            ...List.generate(ids.length, (i) {
              final sel = sound.isPlaying && sound.currentSoundId == ids[i];
              return _Chip(
                icon: icons[i], label: labels[i],
                selected: sel, accent: slider, sub: sub,
                onTap: () {
                  ref.read(ambientSoundProvider.notifier).selectAndPlay(ids[i]);
                },
              );
            }),
          ],
        ),
        if (sound.isPlaying) ...[
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderThemeData(
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape:
                  const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 2,
              activeTrackColor: slider,
              inactiveTrackColor: sub.withValues(alpha: 0.15),
              thumbColor: slider,
              overlayColor: slider.withValues(alpha: 0.08),
            ),
            child: Slider(
              value: sound.volume,
              onChanged: (v) =>
                  ref.read(ambientSoundProvider.notifier).setVolume(v),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accent, sub;
  final VoidCallback onTap;
  const _Chip({
    required this.icon, required this.label, required this.selected,
    required this.accent, required this.sub, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : sub.withValues(alpha: 0.18),
              ),
            ),
            child: Icon(icon, size: 16,
                color: selected ? accent : sub),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: selected ? accent : sub,
                  fontSize: 9,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color, card, txt, sub, divider;
  final bool light;
  const _MiniStat({
    required this.icon, required this.value, required this.label,
    required this.color, required this.card, required this.txt,
    required this.sub, required this.divider, required this.light,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: light ? null : Border.all(color: divider),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: txt, fontSize: 17,
                  fontWeight: FontWeight.w700, height: 1.0)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: sub, fontSize: 9, letterSpacing: 0.2),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
