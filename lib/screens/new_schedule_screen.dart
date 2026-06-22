import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/screen_time_provider.dart';
import '../providers/installed_apps_provider.dart';
import '../providers/productivity_provider.dart';
import '../models/productivity_models.dart';

// ═══════════════════════════════════════════════════════════════════════
//  NEW SCHEDULE — minimal block-schedule creation screen
//
//  • Tap a Start / End time → standard wheel (Cupertino) time picker.
//  • Toggle the 7 day circles (Mon–Sun) — active filled with warm amber.
//  • Pick distracting apps as chips, sorted by descending 7-day usage.
//  • Save is disabled until ≥1 app AND ≥1 day are selected; it creates a
//    time-based AppBlockRule via [appBlockRuleProvider].
// ═══════════════════════════════════════════════════════════════════════

// ── Design tokens ──
const _bg = Color(0xFF0A0A0A);
const _card = Color(0xFF161616);
const _amber = Color(0xFFF5A623); // warm amber accent
const _amberInk = Color(0xFF1A1206); // near-black ink for text on amber fill
const _text = Color(0xFFEDEDED);
const _textSoft = Color(0xFF9A9A9A);
const _textMute = Color(0xFF5C5C5C);
const _border = Color(0x14FFFFFF); // white @ ~8%

class NewScheduleScreen extends ConsumerStatefulWidget {
  /// When non-null the screen edits an existing schedule instead of creating
  /// a new one (prefills name, times, days and apps; Save calls updateRule).
  final AppBlockRule? existing;

  const NewScheduleScreen({super.key, this.existing});

  @override
  ConsumerState<NewScheduleScreen> createState() => _NewScheduleScreenState();
}

class _NewScheduleScreenState extends ConsumerState<NewScheduleScreen> {
  // Defaults mirror the spec example: 08:00 PM → 11:00 PM.
  TimeOfDay _start = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 23, minute: 0);

  final Set<int> _days = {}; // weekday 1 (Mon) … 7 (Sun)
  final Set<String> _apps = {}; // selected package names
  final _nameController = TextEditingController();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      // Prefill from the rule being edited.
      _nameController.text = e.name;
      _start = TimeOfDay(hour: e.startHour ?? 20, minute: e.startMinute ?? 0);
      _end = TimeOfDay(hour: e.endHour ?? 23, minute: e.endMinute ?? 0);
      _days.addAll(e.activeDays);
      _apps.addAll(e.blockedPackages);
    }
    // Make sure the most-used-apps list is fresh when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(screenTimeProvider.notifier).refreshUsageStats();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave => _apps.isNotEmpty && _days.isNotEmpty;

  /// Falls back to an auto-generated time-based name when left blank.
  String get _effectiveName {
    final typed = _nameController.text.trim();
    if (typed.isNotEmpty) return typed;
    return 'Focus ${_fmtTime(_start)} – ${_fmtTime(_end)}';
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  String _fmtTime(TimeOfDay t) {
    final h = (t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod).toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Duration _span() {
    final s = _start.hour * 60 + _start.minute;
    var e = _end.hour * 60 + _end.minute;
    if (e <= s) e += 24 * 60; // overnight window
    return Duration(minutes: e - s);
  }

  String _fmtSpan() {
    final d = _span();
    final h = d.inHours, m = d.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  String _fmtUsage(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}min';
    if (h > 0) return '${h}h';
    return '${m}min';
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _start : _end;
    final picked = await _showWheelPicker(
      context, initial, isStart ? 'Start time' : 'End time');
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<TimeOfDay?> _showWheelPicker(
      BuildContext context, TimeOfDay initial, String title) {
    final now = DateTime.now();
    var temp = DateTime(now.year, now.month, now.day, initial.hour, initial.minute);
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel',
                        style: TextStyle(color: _textSoft, fontSize: 14)),
                  ),
                  Expanded(
                    child: Text(title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                        ctx, TimeOfDay(hour: temp.hour, minute: temp.minute)),
                    child: const Text('Done',
                        style: TextStyle(
                            color: _amber,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: CupertinoTheme(
                data: const CupertinoThemeData(brightness: Brightness.dark),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: temp,
                  use24hFormat: false,
                  onDateTimeChanged: (d) => temp = d,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(appBlockRuleProvider.notifier);
    try {
      if (_isEdit) {
        await notifier.updateRule(
          widget.existing!.id,
          name: _effectiveName,
          blockedPackages: _apps.toList(),
          isTimeBased: true,
          startHour: _start.hour,
          startMinute: _start.minute,
          endHour: _end.hour,
          endMinute: _end.minute,
          activeDays: _days.toList()..sort(),
        );
      } else {
        await notifier.addRule(
          name: _effectiveName,
          blockedPackages: _apps.toList(),
          isTimeBased: true,
          startHour: _start.hour,
          startMinute: _start.minute,
          endHour: _end.hour,
          endMinute: _end.minute,
          activeDays: _days.toList()..sort(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save schedule'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final week = ref.watch(screenTimeProvider).weekUsage; // sorted desc, >0 min

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                physics: const ClampingScrollPhysics(),
                children: [
                  _nameField(),
                  const SizedBox(height: 22),
                  _timeRangeCard(),
                  const SizedBox(height: 26),
                  _sectionLabel('Repeat'),
                  const SizedBox(height: 12),
                  _daySelector(),
                  const SizedBox(height: 28),
                  _appsHeader(),
                  const SizedBox(height: 14),
                  _appsList(week),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0x14FFFFFF)),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: _text),
            ),
          ),
          const SizedBox(width: 12),
          Text(_isEdit ? 'Edit schedule' : 'New schedule',
              style: const TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
        ],
      ),
    );
  }

  // ── Name ──
  Widget _nameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Name'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: _nameController,
            style: const TextStyle(
                color: _text, fontSize: 16, fontWeight: FontWeight.w600),
            cursorColor: _amber,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            maxLength: 30,
            decoration: const InputDecoration(
              hintText: 'e.g. Mindful morning',
              hintStyle: TextStyle(
                  color: _textMute, fontSize: 16, fontWeight: FontWeight.w500),
              counterText: '',
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              prefixIcon: Icon(Icons.drive_file_rename_outline_rounded,
                  size: 18, color: _textSoft),
              prefixIconConstraints: BoxConstraints(minWidth: 44),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String s) => Text(s.toUpperCase(),
      style: const TextStyle(
          color: _textMute,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4));

  // ── Time range ──
  Widget _timeRangeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(child: _timeBlock('START', _start, true)),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_forward_rounded,
                  size: 18, color: _textMute.withAlpha(200)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _amber.withAlpha(28),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_fmtSpan(),
                    style: const TextStyle(
                        color: _amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          Expanded(child: _timeBlock('END', _end, false)),
        ],
      ),
    );
  }

  Widget _timeBlock(String label, TimeOfDay t, bool isStart) {
    return GestureDetector(
      onTap: () => _pickTime(isStart),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: _textMute,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(_fmtTime(t),
              style: const TextStyle(
                  color: _text,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_rounded, size: 11, color: _amber.withAlpha(180)),
              const SizedBox(width: 4),
              Text('Tap to set',
                  style: TextStyle(color: _amber.withAlpha(180), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Day selector ──
  Widget _daySelector() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final weekday = i + 1; // 1..7
        final active = _days.contains(weekday);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (active) {
                _days.remove(weekday);
              } else {
                _days.add(weekday);
              }
            });
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? _amber : Colors.transparent,
              border: Border.all(
                color: active ? _amber : _border,
                width: 1.4,
              ),
            ),
            child: Text(
              labels[i],
              style: TextStyle(
                color: active ? _amberInk : _textSoft,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ── Apps ──
  Widget _appsHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose apps',
                  style: TextStyle(
                      color: _text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3)),
              const SizedBox(height: 3),
              Text('Screen time · last 7 days',
                  style: TextStyle(color: _textSoft, fontSize: 12)),
            ],
          ),
        ),
        if (_apps.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _amber.withAlpha(28),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_apps.length} selected',
                style: const TextStyle(
                    color: _amber, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _appsList(List<AppUsageEntry> week) {
    if (week.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(Icons.bar_chart_rounded, size: 28, color: _textMute),
            const SizedBox(height: 10),
            Text('No usage data yet',
                style: TextStyle(
                    color: _textSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Grant usage access so your most-used\napps appear here, sorted by time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMute, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      );
    }

    // Nicer names where the native label is missing.
    final installed = ref.watch(installedAppsProvider);
    final nameByPkg = {for (final a in installed) a.packageName: a.displayName};

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: week.map((e) {
        final name = e.appName.isNotEmpty
            ? e.appName
            : (nameByPkg[e.packageName] ?? e.packageName);
        final sel = _apps.contains(e.packageName);
        return _appChip(e.packageName, name, _fmtUsage(e.usageTime), sel);
      }).toList(),
    );
  }

  Widget _appChip(String pkg, String name, String usage, bool sel) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (sel) {
            _apps.remove(pkg);
          } else {
            _apps.add(pkg);
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _amber : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? _amber : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (sel) ...[
              const Icon(Icons.check_rounded, size: 15, color: _amberInk),
              const SizedBox(width: 6),
            ],
            Text(name,
                style: TextStyle(
                    color: sel ? _amberInk : _text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 7),
            Text(usage,
                style: TextStyle(
                    color: sel ? _amberInk.withAlpha(170) : _textSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }

  // ── Sticky bottom bar ──
  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: const BoxDecoration(
        color: _bg,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: _text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _canSave ? _save : null,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _canSave ? _amber : _amber.withAlpha(38),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _amberInk))
                      : Text('Save',
                          style: TextStyle(
                              color: _canSave ? _amberInk : _textMute,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
