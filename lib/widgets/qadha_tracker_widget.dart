import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/qadha_provider.dart';
import '../providers/theme_provider.dart';

/// Qadha Namaz Tracker Widget
///
/// Two states:
/// 1. Setup: User enters estimated missed prayers per type → locks
/// 2. Tracking: Shows remaining per type with +/- buttons
class QadhaTrackerWidget extends ConsumerStatefulWidget {
  const QadhaTrackerWidget({super.key});

  @override
  ConsumerState<QadhaTrackerWidget> createState() => _QadhaTrackerWidgetState();
}

class _QadhaTrackerWidgetState extends ConsumerState<QadhaTrackerWidget> {
  // Design tokens
  static final Color _cardBg = Colors.white.withValues(alpha: 0.03);
  static final Color _borderColor = Colors.white.withValues(alpha: 0.09);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _textMuted = Color(0xFF484F58);

  // Setup state
  bool _isSettingUp = false;
  final _controllers = <String, TextEditingController>{
    'fajr': TextEditingController(text: '0'),
    'dhuhr': TextEditingController(text: '0'),
    'asr': TextEditingController(text: '0'),
    'maghrib': TextEditingController(text: '0'),
    'isha': TextEditingController(text: '0'),
  };

  static const List<Map<String, dynamic>> _prayers = [
    {'name': 'Fajr', 'icon': Icons.wb_twilight_rounded, 'arabicName': 'الفجر'},
    {'name': 'Dhuhr', 'icon': Icons.wb_sunny_rounded, 'arabicName': 'الظهر'},
    {'name': 'Asr', 'icon': Icons.wb_sunny_outlined, 'arabicName': 'العصر'},
    {'name': 'Maghrib', 'icon': Icons.nights_stay_outlined, 'arabicName': 'المغرب'},
    {'name': 'Isha', 'icon': Icons.dark_mode_rounded, 'arabicName': 'العشاء'},
  ];

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qadha = ref.watch(qadhaRecordProvider);
    final themeColor = ref.watch(themeColorProvider);
    final accent = themeColor.color;

    // No record yet or setting up
    if (qadha == null || _isSettingUp) {
      return _buildSetupCard(accent);
    }

    // Not locked yet — show setup
    if (!qadha.isLocked) {
      return _buildSetupCard(accent);
    }

    // Locked — show tracking view
    return _buildTrackingCard(accent, qadha);
  }

  // ── Setup Card: Enter estimated missed prayers ──
  Widget _buildSetupCard(Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.replay_rounded,
                    size: 18,
                    color: accent.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QADHA NAMAZ',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: accent.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enter your estimated missed prayers',
                        style: TextStyle(
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Info banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: accent.withValues(alpha: 0.5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estimate how many prayers you missed since becoming baligh. Once locked, track your progress.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Prayer input fields
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: _prayers.map((prayer) {
                final name = prayer['name'] as String;
                final key = name.toLowerCase();
                return _buildInputRow(name, prayer['icon'] as IconData, _controllers[key]!, accent);
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Lock button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: GestureDetector(
              onTap: () {
                final fajr = int.tryParse(_controllers['fajr']!.text) ?? 0;
                final dhuhr = int.tryParse(_controllers['dhuhr']!.text) ?? 0;
                final asr = int.tryParse(_controllers['asr']!.text) ?? 0;
                final maghrib = int.tryParse(_controllers['maghrib']!.text) ?? 0;
                final isha = int.tryParse(_controllers['isha']!.text) ?? 0;

                if (fajr + dhuhr + asr + maghrib + isha == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Enter at least one prayer count'),
                      backgroundColor: Colors.red.withValues(alpha: 0.8),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                _showLockConfirmation(context, accent, fajr, dhuhr, asr, maghrib, isha);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'Lock & Start Tracking',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accent,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String name, IconData icon, TextEditingController controller, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _textPrimary.withValues(alpha: 0.8),
              ),
            ),
          ),
          const Spacer(),
          // Minus button
          GestureDetector(
            onTap: () {
              final val = int.tryParse(controller.text) ?? 0;
              if (val > 0) {
                controller.text = '${val - 1}';
                setState(() {});
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: Icon(Icons.remove_rounded, size: 16, color: _textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          // Number input
          SizedBox(
            width: 64,
            height: 32,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: accent.withValues(alpha: 0.5)),
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          // Plus button
          GestureDetector(
            onTap: () {
              final val = int.tryParse(controller.text) ?? 0;
              controller.text = '${val + 1}';
              setState(() {});
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: Icon(Icons.add_rounded, size: 16, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  void _showLockConfirmation(BuildContext ctx, Color accent, int fajr, int dhuhr, int asr, int maghrib, int isha) {
    final total = fajr + dhuhr + asr + maghrib + isha;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.lock_rounded, size: 36, color: accent.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              'Lock $total Qadha Prayers?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fajr: $fajr · Dhuhr: $dhuhr · Asr: $asr\nMaghrib: $maghrib · Isha: $isha',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You can reset this later from settings if needed.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(qadhaRecordProvider.notifier).setTotals(
                        fajr: fajr,
                        dhuhr: dhuhr,
                        asr: asr,
                        maghrib: maghrib,
                        isha: isha,
                      );
                      ref.read(qadhaRecordProvider.notifier).lockTotals();
                      setState(() => _isSettingUp = false);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: Center(
                        child: Text(
                          'Lock',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ── Tracking Card: Show progress with +/- buttons ──
  Widget _buildTrackingCard(Color accent, dynamic qadha) {
    final totalRemaining = qadha.totalRemaining as int;
    final grandTotal = qadha.grandTotal as int;
    final progress = qadha.progress as double;
    final isComplete = totalRemaining == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? accent.withValues(alpha: 0.4)
              : _borderColor,
          width: isComplete ? 1.5 : 1,
        ),
        boxShadow: isComplete
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isComplete ? Icons.check_circle_rounded : Icons.replay_rounded,
                    size: 18,
                    color: accent.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QADHA NAMAZ',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                          color: accent.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isComplete
                            ? 'All qadha prayers completed! ✨'
                            : '$totalRemaining remaining of $grandTotal',
                        style: TextStyle(
                          fontSize: 12,
                          color: isComplete
                              ? accent.withValues(alpha: 0.7)
                              : _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Reset button
                GestureDetector(
                  onTap: () => _showResetConfirmation(context, accent),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: _textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accent.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      '${grandTotal - totalRemaining} prayed',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    valueColor: AlwaysStoppedAnimation(accent.withValues(alpha: 0.7)),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Prayer rows with +/- buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: _prayers.map((prayer) {
                final name = prayer['name'] as String;
                final remaining = qadha.remainingFor(name) as int;
                final total = qadha.totalFor(name) as int;
                if (total == 0) return const SizedBox.shrink();
                return _buildTrackingRow(
                  name: name,
                  icon: prayer['icon'] as IconData,
                  remaining: remaining,
                  total: total,
                  accent: accent,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingRow({
    required String name,
    required IconData icon,
    required int remaining,
    required int total,
    required Color accent,
  }) {
    final completed = total - remaining;
    final isDone = remaining == 0;
    final pct = total > 0 ? completed / total : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDone
              ? accent.withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone
                ? accent.withValues(alpha: 0.20)
                : _borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle_rounded : icon,
              size: 18,
              color: isDone ? accent : _textSecondary,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDone
                      ? accent.withValues(alpha: 0.8)
                      : _textPrimary.withValues(alpha: 0.7),
                ),
              ),
            ),
            // Mini progress
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    valueColor: AlwaysStoppedAnimation(
                      isDone ? accent.withValues(alpha: 0.5) : accent.withValues(alpha: 0.3),
                    ),
                    minHeight: 3,
                  ),
                ),
              ),
            ),
            // Remaining count
            SizedBox(
              width: 32,
              child: Text(
                '$remaining',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDone
                      ? accent.withValues(alpha: 0.5)
                      : _textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Minus button (prayed one)
            GestureDetector(
              onTap: isDone
                  ? null
                  : () {
                      ref.read(qadhaRecordProvider.notifier).prayedOne(name);
                    },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDone
                      ? Colors.white.withValues(alpha: 0.02)
                      : accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDone
                        ? Colors.transparent
                        : accent.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.remove_rounded,
                  size: 14,
                  color: isDone
                      ? _textMuted.withValues(alpha: 0.3)
                      : accent,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Plus button (undo)
            GestureDetector(
              onTap: remaining >= total
                  ? null
                  : () {
                      ref.read(qadhaRecordProvider.notifier).undoOne(name);
                    },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _borderColor),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 14,
                  color: remaining >= total
                      ? _textMuted.withValues(alpha: 0.3)
                      : _textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetConfirmation(BuildContext ctx, Color accent) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF101010),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.warning_amber_rounded, size: 36, color: Colors.orange.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              'Reset Qadha Tracker?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will clear all your Qadha data. You\'ll need to set up again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(qadhaRecordProvider.notifier).reset();
                      setState(() => _isSettingUp = false);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text(
                          'Reset',
                          style: TextStyle(
                            color: Colors.red.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
