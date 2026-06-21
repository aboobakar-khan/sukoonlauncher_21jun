import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/clock_style_provider.dart';
import '../providers/premium_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/time_format_provider.dart';
import '../widgets/clock_variants.dart';
import '../widgets/swipe_back_wrapper.dart';

import 'premium_paywall_screen.dart';

/// Clock Style Picker Screen — live mini-previews for every clock style
class ClockStylePickerScreen extends ConsumerStatefulWidget {
  const ClockStylePickerScreen({super.key});

  // First 3 clock styles are free (digital, analog, minimalist)
  static const int freeClockCount = 3;

  @override
  ConsumerState<ClockStylePickerScreen> createState() =>
      _ClockStylePickerScreenState();
}

class _ClockStylePickerScreenState
    extends ConsumerState<ClockStylePickerScreen> {
  late Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStyle = ref.watch(clockStyleProvider);
    final isPremium = ref.watch(premiumProvider).isPremium;
    final themeColor = ref.watch(themeColorProvider);
    final timeFormat = ref.watch(timeFormatProvider);
    final isLight = themeColor.isLight;
    final bgColor = isLight ? const Color(0xFFF5F5F5) : Colors.black;
    final primaryText = isLight ? const Color(0xFF0D0D0D) : Colors.white;

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, primaryText: primaryText),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
                  itemCount: ClockStyle.values.length,
                  itemBuilder: (context, index) {
                    final style = ClockStyle.values[index];
                    final isSelected = style == currentStyle;
                    final isLocked = !isPremium &&
                        index >= ClockStylePickerScreen.freeClockCount;

                    return _ClockPreviewCard(
                      style: style,
                      isSelected: isSelected,
                      isLocked: isLocked,
                      themeColor: themeColor,
                      timeFormat: timeFormat,
                      time: _now,
                      isLight: isLight,
                      primaryText: primaryText,
                      onTap: () {
                        if (isLocked) {
                          showPremiumPaywall(context,
                              triggerFeature: 'Clock: ${style.name}');
                          return;
                        }
                        ref
                            .read(clockStyleProvider.notifier)
                            .setClockStyle(style);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required Color primaryText}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Icon(
              Icons.arrow_back,
              color: primaryText.withValues(alpha: 0.7),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'CLOCK STYLE',
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 4,
              fontWeight: FontWeight.w300,
              color: primaryText.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single clock preview card with live ticking mini-clock
class _ClockPreviewCard extends StatelessWidget {
  final ClockStyle style;
  final bool isSelected;
  final bool isLocked;
  final AppThemeColor themeColor;
  final TimeFormat timeFormat;
  final DateTime time;
  final bool isLight;
  final Color primaryText;
  final VoidCallback onTap;

  const _ClockPreviewCard({
    required this.style,
    required this.isSelected,
    required this.isLocked,
    required this.themeColor,
    required this.timeFormat,
    required this.time,
    required this.isLight,
    required this.primaryText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = themeColor.color;
    final neutralColor = isLight ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.06)
              : neutralColor.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.4)
                : neutralColor.withValues(alpha: 0.07),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            // ── Live clock preview ──
            Container(
              width: double.infinity,
              height: 150,
              padding: const EdgeInsets.all(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: IgnorePointer(
                  child: _buildMiniClock(),
                ),
              ),
            ),
            // ── Divider ──
            Divider(
              height: 1,
              thickness: 0.5,
              color: isSelected
                  ? accent.withValues(alpha: 0.15)
                  : neutralColor.withValues(alpha: 0.05),
            ),
            // ── Label row ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.name,
                          style: TextStyle(
                            color: isSelected
                                ? accent.withValues(alpha: 0.9)
                                : primaryText.withValues(alpha: 0.75),
                            fontSize: 15,
                            fontWeight:
                                isSelected ? FontWeight.w500 : FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          style.description,
                          style: TextStyle(
                            color: primaryText.withValues(alpha: 0.3),
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      color: accent.withValues(alpha: 0.8),
                      size: 22,
                    )
                  else if (isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFC2A366).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded,
                              color: const Color(0xFFC2A366)
                                  .withValues(alpha: 0.7),
                              size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'PRO',
                            style: TextStyle(
                              color: const Color(0xFFC2A366)
                                  .withValues(alpha: 0.8),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniClock() {
    switch (style) {
      case ClockStyle.digital:
        return DigitalClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.analog:
        return AnalogClockWidget(time: time, themeColor: themeColor);
      case ClockStyle.minimalist:
        return MinimalistClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.bold:
        return BoldClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.compact:
        return CompactClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.modern:
        return ModernClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.retro:
        return RetroClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.elegant:
        return ElegantClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.binary:
        return BinaryClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.progress:
        return ProgressClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.vertical:
        return VerticalClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.word:
        return WordClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.dotMatrix:
        return DotMatrixClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.zen:
        return ZenClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.typewriter:
        return TypewriterClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
      case ClockStyle.arc:
        return ArcClockWidget(
            time: time, themeColor: themeColor, timeFormat: timeFormat);
    }
  }
}
