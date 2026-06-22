import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════
//  DESIGN TOKENS
// ═══════════════════════════════════════════════════════

const kSwBg = Color(0xFF000000);          // true black (AMOLED / iOS dark)
const kSwCard = Color(0xFF1A1A1C);        // elevated surface (iOS systemGray6-ish)
const kSwCardNext = Color(0xFF112619);    // subtle green wash for the next prayer
const kSwActive = Color(0xFF34C759);      // iOS system green
const kSwTextPrimary = Color(0xFFF2F2F7); // iOS label
const kSwTextSecondary = Color(0xFF9A9AA0);// iOS secondary label
const kSwTextMuted = Color(0xFF5C5C62);   // iOS tertiary label
const kSwDivider = Color(0xFF2A2A2C);
const kSwRadius = 18.0;

// Mode colors: each mode gets its own subtle identity (iOS system palette)
const kModeColors = <String, Color>{
  'off': Color(0xFF636366),
  'notify': Color(0xFF0A84FF),   // iOS blue
  'adhan': Color(0xFF34C759),    // iOS green
};

const kPrayerIcons = <String, IconData>{
  'Fajr': Icons.wb_twilight_rounded,
  'Sunrise': Icons.wb_sunny_outlined,
  'Dhuhr': Icons.wb_sunny_rounded,
  'Asr': Icons.wb_cloudy_rounded,
  'Maghrib': Icons.nights_stay_rounded,
  'Isha': Icons.dark_mode_rounded,
};

String swFmt12h(String t) {
  final parts = t.split(':');
  if (parts.length != 2) return t;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

// ═══════════════════════════════════════════════════════
//  ALARM MODE DATA
// ═══════════════════════════════════════════════════════

class AlarmModeInfo {
  final String key;
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  const AlarmModeInfo(this.key, this.label, this.desc, this.icon, this.color);
}

const kAlarmModes = [
  AlarmModeInfo('off', 'Off', 'No alarm or notification',
    Icons.notifications_off_rounded, Color(0xFF636366)),
  AlarmModeInfo('notify', 'Notify', 'Silent banner notification',
    Icons.notifications_rounded, Color(0xFF0A84FF)),
  AlarmModeInfo('adhan', 'Adhan', 'Notification with Adhan audio',
    Icons.mosque_rounded, Color(0xFF34C759)),
];

const kSunriseModes = [
  AlarmModeInfo('off', 'Off', 'No notification',
    Icons.notifications_off_rounded, Color(0xFF636366)),
  AlarmModeInfo('notify', 'Notify', 'Silent banner notification',
    Icons.notifications_rounded, Color(0xFF0A84FF)),
];

const kFastingModes = [
  AlarmModeInfo('off', 'Off', 'No alarm',
    Icons.notifications_off_rounded, Color(0xFF636366)),
  AlarmModeInfo('notify', 'Notify', 'Silent notification',
    Icons.notifications_rounded, Color(0xFF0A84FF)),
  AlarmModeInfo('adhan', 'Adhan', 'Notification with Adhan',
    Icons.mosque_rounded, Color(0xFF34C759)),
];

// ═══════════════════════════════════════════════════════
//  MODE PICKER BOTTOM SHEET
// ═══════════════════════════════════════════════════════

Future<String?> showModePicker(
  BuildContext context, String current, {
  bool isSunrise = false,
  bool isFasting = false,
  String? title,
}) {
  final modes = isFasting ? kFastingModes : isSunrise ? kSunriseModes : kAlarmModes;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 14),
            child: Container(
              width: 28, height: 3,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.white.withAlpha(18),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                Text(title ?? 'Alarm Mode', style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: kSwTextPrimary, letterSpacing: -0.3,
                )),
                const Spacer(),
                Text('Tap to select', style: TextStyle(
                  fontSize: 10, color: kSwTextMuted,
                )),
              ],
            ),
          ),
          // Mode options
          ...modes.map((m) {
            final sel = m.key == current;
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
              child: GestureDetector(
                // ✅ was missing — tapping a mode option now closes the sheet
                // and returns the selected mode key to the caller
                onTap: () => Navigator.pop(ctx, m.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: sel ? m.color.withAlpha(15) : Colors.transparent,
                    border: Border.all(
                      color: sel ? m.color.withAlpha(50) : Colors.white.withAlpha(6),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icon circle
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: sel ? m.color.withAlpha(25) : Colors.white.withAlpha(6),
                        ),
                        child: Icon(m.icon, size: 16,
                          color: sel ? m.color : kSwTextMuted),
                      ),
                      const SizedBox(width: 14),
                      // Label + desc
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.label, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: sel ? kSwTextPrimary : kSwTextSecondary,
                          )),
                          Text(m.desc, style: TextStyle(
                            fontSize: 10,
                            color: sel ? m.color.withAlpha(160) : kSwTextMuted,
                          )),
                        ],
                      )),
                      // Checkmark
                      if (sel)
                        Icon(Icons.check_circle_rounded, size: 18, color: m.color),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════
//  PRAYER ROW — with temporal awareness
// ═══════════════════════════════════════════════════════

enum PrayerTimeState { past, current, future }

class PrayerRow extends StatefulWidget {
  final String prayer;
  final String apiTime;
  final String effectiveTime;
  final int adjustment;
  final String mode;
  final PrayerTimeState timeState;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<int> onAdjustmentChanged;

  const PrayerRow({
    super.key,
    required this.prayer,
    required this.apiTime,
    required this.effectiveTime,
    required this.adjustment,
    required this.mode,
    this.timeState = PrayerTimeState.future,
    required this.onModeChanged,
    required this.onAdjustmentChanged,
  });

  @override
  State<PrayerRow> createState() => _PrayerRowState();
}

class _PrayerRowState extends State<PrayerRow> {
  bool _showAdjust = false;

  bool get _isSunrise => widget.prayer == 'Sunrise';
  bool get _isActive => widget.mode != 'off';
  bool get _isCurrent => widget.timeState == PrayerTimeState.current;
  bool get _isPast => widget.timeState == PrayerTimeState.past;

  Color get _modeColor => kModeColors[widget.mode] ?? kSwTextMuted;

  @override
  Widget build(BuildContext context) {
    final icon = kPrayerIcons[widget.prayer] ?? Icons.access_time;
    final hasOffset = widget.adjustment != 0;
    final displayTime = hasOffset
        ? swFmt12h(widget.effectiveTime)
        : swFmt12h(widget.apiTime);

    // Opacity for past prayers — readable but still distinct from future
    final opacity = _isPast ? 0.70 : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _isCurrent ? kSwCardNext : kSwCard,
          borderRadius: BorderRadius.circular(kSwRadius),
          border: Border.all(
            color: _isCurrent ? kSwActive.withAlpha(60) : Colors.white.withAlpha(8),
            width: _isCurrent ? 1.2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kSwRadius - 1),
          child: Column(
            children: [
              // ── Main row ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _isCurrent ? 13 : 16, 13, 12, _showAdjust ? 6 : 13),
                child: Row(
                  children: [
                    // Prayer icon
                    Icon(icon, size: 18,
                      color: _isCurrent
                          ? kSwActive
                          : _isActive
                              ? kSwTextSecondary
                              : const Color(0xFF666666)),
                    const SizedBox(width: 12),

                    // Name + Time column
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Prayer name row — with a "NEXT" badge on the
                        // upcoming prayer so the highlighted card ties back
                        // to the countdown in the date navigator.
                        Row(
                          children: [
                            Flexible(
                              child: Text(widget.prayer, style: TextStyle(
                                fontSize: 15,
                                fontWeight: _isCurrent ? FontWeight.w700 : FontWeight.w600,
                                color: _isCurrent
                                    ? kSwTextPrimary
                                    : _isActive
                                        ? kSwTextPrimary.withAlpha(200)
                                        : const Color(0xFF888888),
                                letterSpacing: -0.3,
                              ), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            if (_isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: kSwActive.withAlpha(28),
                                ),
                                child: const Text('NEXT', style: TextStyle(
                                  fontSize: 8.5, fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8, color: kSwActive,
                                )),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 2),

                        // Time + offset tag
                        GestureDetector(
                          onTap: _isSunrise ? null : () =>
                            setState(() => _showAdjust = !_showAdjust),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Text(displayTime, style: TextStyle(
                                fontSize: 14,
                                fontWeight: _isCurrent ? FontWeight.w600 : FontWeight.w500,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: _isCurrent
                                    ? kSwActive
                                    : hasOffset
                                        ? kSwActive.withAlpha(180)
                                        : const Color(0xFF666666),
                              )),
                              if (hasOffset) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: kSwActive.withAlpha(18),
                                  ),
                                  child: Text(
                                    '${widget.adjustment > 0 ? '+' : ''}${widget.adjustment}m',
                                    style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w700,
                                      color: kSwActive.withAlpha(180),
                                    ),
                                  ),
                                ),
                              ],
                              // Tap hint — subtle pencil
                              if (!_isSunrise) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  _showAdjust
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.edit_rounded,
                                  size: 13,
                                  color: _showAdjust
                                      ? kSwActive.withAlpha(200)
                                      : kSwTextMuted.withAlpha(150),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    )),

                    // Mode chip
                    _ModePill(
                      mode: widget.mode,
                      color: _modeColor,
                      onTap: () async {
                        final picked = await showModePicker(
                          context, widget.mode, isSunrise: _isSunrise);
                        if (picked != null && picked != widget.mode) {
                          widget.onModeChanged(picked);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // ── Adjustment panel ──
              if (_showAdjust && !_isSunrise)
                _AdjustPanel(
                  adjustment: widget.adjustment,
                  apiTime: widget.apiTime,
                  onChanged: widget.onAdjustmentChanged,
                  onClose: () => setState(() => _showAdjust = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  MODE PILL — color-coded by mode
// ═══════════════════════════════════════════════════════

class _ModePill extends StatelessWidget {
  final String mode;
  final Color color;
  final VoidCallback onTap;

  const _ModePill({required this.mode, required this.color, required this.onTap});

  AlarmModeInfo get _info =>
    kAlarmModes.firstWhere((m) => m.key == mode, orElse: () => kAlarmModes[0]);

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final isOff = mode == 'off';
    return GestureDetector(
      onTap: onTap, // ✅ was missing — GestureDetector had no onTap so picker never opened
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isOff ? Colors.white.withAlpha(8) : color.withAlpha(15),
          boxShadow: isOff ? null : [
            BoxShadow(
              color: color.withAlpha(15),
              blurRadius: 8,
              spreadRadius: 0,
            ),
          ],
          border: Border.all(
            color: isOff ? Colors.white.withAlpha(8) : color.withAlpha(40),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(info.icon, size: 12, color: isOff ? kSwTextMuted : color),
            const SizedBox(width: 4),
            Text(info.label, style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: isOff ? kSwTextMuted : color,
              letterSpacing: 0.3,
            )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  ADJUSTMENT PANEL — free ±1min, clean inline
// ═══════════════════════════════════════════════════════

class _AdjustPanel extends StatelessWidget {
  final int adjustment;
  final String apiTime;
  final ValueChanged<int> onChanged;
  final VoidCallback onClose;

  const _AdjustPanel({
    required this.adjustment,
    required this.apiTime,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hasOffset = adjustment != 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withAlpha(5),
        ),
        child: Row(
          children: [
            // −5 button
            _AdjBtn(label: '−5', onTap: () {
              onChanged(adjustment - 5);
            }),
            const SizedBox(width: 4),
            // −1 button
            _AdjBtn(label: '−1', small: true, onTap: () {
              onChanged(adjustment - 1);
            }),

            // Center label
            Expanded(child: Column(
              children: [
                Text(
                  adjustment == 0 ? 'On time'
                      : adjustment < 0 ? '${adjustment.abs()}m early'
                      : '${adjustment}m after',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: hasOffset ? kSwActive : kSwTextSecondary,
                  ),
                ),
                if (hasOffset)
                  GestureDetector(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Reset', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w600,
                        color: kSwTextMuted, decoration: TextDecoration.underline,
                        decorationColor: kSwTextMuted,
                      )),
                    ),
                  ),
              ],
            )),

            // +1 button
            _AdjBtn(label: '+1', small: true, onTap: () {
              onChanged(adjustment + 1);
            }),
            const SizedBox(width: 4),
            // +5 button
            _AdjBtn(label: '+5', onTap: () {
              onChanged(adjustment + 5);
            }),
          ],
        ),
      ),
    );
  }
}

class _AdjBtn extends StatefulWidget {
  final String label;
  final bool small;
  final VoidCallback? onTap;

  const _AdjBtn({required this.label, this.small = false, this.onTap});

  @override
  State<_AdjBtn> createState() => _AdjBtnState();
}

class _AdjBtnState extends State<_AdjBtn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _ctrl.forward() : null,
      onTapUp: enabled ? (_) { _ctrl.reverse(); widget.onTap!(); } : null,
      onTapCancel: enabled ? () => _ctrl.reverse() : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.small ? 32 : 38,
          height: 30,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: enabled ? Colors.white.withAlpha(12) : Colors.transparent,
            border: Border.all(color: enabled ? Colors.white.withAlpha(8) : Colors.transparent),
          ),
          child: Center(child: Text(widget.label, style: TextStyle(
            fontSize: widget.small ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: enabled ? kSwTextPrimary.withAlpha(160) : kSwTextMuted.withAlpha(50),
          ))),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  FASTING ROW — with alarm mode
// ═══════════════════════════════════════════════════════

class FastingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;
  final String mode;
  final ValueChanged<String> onModeChanged;

  const FastingRow({
    super.key,
    required this.icon,
    required this.label,
    required this.time,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final modeColor = kModeColors[mode] ?? kSwTextMuted;
    final isActive = mode != 'off';
    final info = kFastingModes.firstWhere(
      (m) => m.key == mode, orElse: () => kFastingModes[0]);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 10, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kSwRadius),
        color: kSwCard,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16,
            color: isActive ? kSwActive.withAlpha(160) : kSwTextMuted),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: kSwTextMuted,
              )),
              const SizedBox(height: 1),
              Text(time, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: isActive ? kSwTextPrimary : kSwTextSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
            ],
          )),
          GestureDetector(
            onTap: () async {
              final picked = await showModePicker(
                context, mode, isFasting: true, title: '$label Alarm');
              if (picked != null && picked != mode) {
                onModeChanged(picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isActive ? modeColor.withAlpha(15) : Colors.white.withAlpha(8),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: modeColor.withAlpha(15),
                    blurRadius: 8,
                  )
                ] : null,
                border: Border.all(
                  color: isActive ? modeColor.withAlpha(40) : Colors.white.withAlpha(10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(info.icon, size: 12,
                    color: isActive ? modeColor : kSwTextMuted),
                  const SizedBox(width: 4),
                  Text(info.label, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: isActive ? modeColor : kSwTextMuted,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SETTINGS PILL
// ═══════════════════════════════════════════════════════

class SettingsPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const SettingsPill({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final col = iconColor ?? (active ? kSwActive : kSwTextMuted);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? Colors.white.withAlpha(10) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: col),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? kSwTextPrimary : kSwTextSecondary,
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            const SizedBox(width: 2),
            Icon(active ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 12, color: kSwTextMuted),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SETTINGS DIVIDER
// ═══════════════════════════════════════════════════════

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 18, color: kSwDivider);
  }
}

// ═══════════════════════════════════════════════════════
//  ASR OPTION
// ═══════════════════════════════════════════════════════

class AsrOption extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final VoidCallback onTap;

  const AsrOption({
    super.key,
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? kSwActive.withAlpha(14) : Colors.white.withAlpha(4),
            border: Border.all(
              color: selected ? kSwActive.withAlpha(45) : Colors.white.withAlpha(8)),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 14, color: selected ? kSwActive : kSwTextMuted),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: selected ? kSwTextPrimary : kSwTextSecondary,
                  )),
                  Text(sublabel, style: TextStyle(
                    fontSize: 9,
                    color: selected ? kSwActive.withAlpha(120) : kSwTextMuted,
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  DATE NAV ARROW
// ═══════════════════════════════════════════════════════

class NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const NavArrow({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(6),
        ),
        child: Icon(icon, size: 18, color: kSwTextSecondary.withAlpha(160)),
      ),
    );
  }
}
