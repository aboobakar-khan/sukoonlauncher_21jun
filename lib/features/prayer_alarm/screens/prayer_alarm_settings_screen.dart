import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/fasting_provider.dart';
import '../../../providers/display_settings_provider.dart';
import '../../../widgets/swipe_back_wrapper.dart';
import '../providers/prayer_alarm_provider.dart';
import '../models/prayer_alarm_config.dart';
import '../services/aladhan_api_service.dart';
import '../services/prayer_alarm_service.dart';
import '../services/location_service.dart';
import '../utils/prayer_time_utils.dart';
import '../widgets/salah_wake_widgets.dart';
import 'permission_setup_screen.dart';

// ═══════════════════════════════════════════════════════════════════
//  Salah Wake — Unified single-page redesign
//  No tabs, no bottom activate button, everything on one screen.
//  Alarm modes: off / notify / adhan
//  Saves instantly on interaction.
// ═══════════════════════════════════════════════════════════════════

class PrayerAlarmSettingsScreen extends ConsumerStatefulWidget {
  const PrayerAlarmSettingsScreen({super.key});

  @override
  ConsumerState<PrayerAlarmSettingsScreen> createState() =>
      _PrayerAlarmSettingsScreenState();
}

class _PrayerAlarmSettingsScreenState
    extends ConsumerState<PrayerAlarmSettingsScreen> {
  final _cityController = TextEditingController();
  bool _isLocating = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  DateTime? _lastSearchTime;
  bool _showLocationSearch = false;
  bool _showCalcMethod = false;
  bool _showAsrSchool = false;
  String? _autoDetectedCity;
  bool? _hasNotifPermission;
  bool? _hasExactAlarmPermission;

  // Date navigation
  DateTime _viewDate = DateTime.now();
  DailyPrayerTimes? _viewTimes;
  bool _viewLoading = false;

  // Countdown timer
  Timer? _countdownTimer;
  Duration _timeUntilNext = Duration.zero;
  String _nextPrayerName = '';

  // Fasting alarm modes — persisted via SharedPreferences
  String _suhoorMode = 'off';
  String _iftarMode  = 'off';
  static const _kSuhoorModeKey = 'fasting_suhoor_alarm_mode';
  static const _kIftarModeKey  = 'fasting_iftar_alarm_mode';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadFastingModes(); // load persisted Suhoor/Iftar alarm modes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = ref.read(prayerAlarmProvider).config;
      if (config.locationLabel.isNotEmpty) {
        _cityController.text = config.locationLabel;
      }
      _loadViewDate(DateTime.now());
      _startCountdown();
    });
  }

  Future<void> _checkPermissions() async {
    final notif = await Permission.notification.isGranted;
    final exact = await PrayerAlarmService.canScheduleExactAlarms();
    if (mounted) {
      setState(() {
        _hasNotifPermission = notif;
        _hasExactAlarmPermission = exact;
      });
    }
  }

  // ── FASTING ALARM MODE PERSISTENCE ──

  Future<void> _loadFastingModes() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _suhoorMode = prefs.getString(_kSuhoorModeKey) ?? 'off';
        _iftarMode  = prefs.getString(_kIftarModeKey)  ?? 'off';
      });
    }
  }

  Future<void> _saveSuhoorMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSuhoorModeKey, mode);
    if (mounted) setState(() => _suhoorMode = mode);
    // Reschedule with updated mode
    final times = ref.read(fastingProvider).times;
    if (times != null && mode != 'off') {
      _scheduleFastingAlarm('Suhoor', times.sahur);
    }
  }

  Future<void> _saveIftarMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIftarModeKey, mode);
    if (mounted) setState(() => _iftarMode = mode);
    final times = ref.read(fastingProvider).times;
    if (times != null && mode != 'off') {
      _scheduleFastingAlarm('Iftar', times.iftar);
    }
  }

  // ── DATE NAVIGATION ──

  Future<void> _loadViewDate(DateTime d) async {
    if (!mounted) return;
    setState(() { _viewDate = d; _viewLoading = true; });
    final stateNow = ref.read(prayerAlarmProvider);
    final key = dateKeyFor(d);
    final todayKey = todayDateKey();
    DailyPrayerTimes? times;
    if (key == todayKey && stateNow.todayTimes != null) {
      times = stateNow.todayTimes;
    } else {
      times = await ref.read(prayerAlarmProvider.notifier).fetchTimesForDate(d);
    }
    if (mounted) setState(() { _viewTimes = times; _viewLoading = false; });
  }

  // ── COUNTDOWN ──

  void _startCountdown() {
    _tickCountdown();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1), (_) => _tickCountdown());
  }

  void _tickCountdown() {
    if (!mounted) return;
    final now = DateTime.now();
    final todayPrayers = ref.read(prayerAlarmProvider).todayTimes;
    if (todayPrayers == null) return;
    const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final p in prayers) {
      final t = todayPrayers.timeFor(p);
      if (t.isEmpty) continue;
      final parts = t.split(':');
      if (parts.length != 2) continue;
      final prayerDt = DateTime(now.year, now.month, now.day,
        int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
      if (prayerDt.isAfter(now)) {
        if (mounted) {
          setState(() { _nextPrayerName = p; _timeUntilNext = prayerDt.difference(now); });
        }
        return;
      }
    }
    if (mounted) setState(() { _nextPrayerName = ''; _timeUntilNext = Duration.zero; });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cityController.dispose();
    super.dispose();
  }

  // Uses fmt12h from salah_wake_widgets.dart

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prayerAlarmProvider);
    final s = state.reminderSettings;

    return SwipeBackWrapper(
      child: Scaffold(
        backgroundColor: kSwBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSettingsBar(state),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  physics: const ClampingScrollPhysics(),
                  children: [
                    _buildPermissionBanner(),
                    _buildDateNavigator(),
                    const SizedBox(height: 10),
                    ..._buildPrayerRows(state, s),
                    const SizedBox(height: 16),
                    _buildWidgetToggle(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 4),
      child: Row(
        children: [
          // Circular back button — larger, clearer tap target.
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38, height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withAlpha(8),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: kSwTextPrimary.withAlpha(165)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Salah Wake', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: kSwTextPrimary.withAlpha(235), letterSpacing: -0.4,
                )),
                const SizedBox(height: 1),
                Text('Prayer times & alarms', style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w500,
                  color: kSwTextSecondary.withAlpha(155),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  SETTINGS BAR (Location · Source · Madhab)
  // ══════════════════════════════════════════════════════

  Widget _buildSettingsBar(PrayerAlarmState state) {
    final hasLoc = state.config.locationLabel.isNotEmpty;
    final locLabel = hasLoc ? state.config.locationLabel : 'Set location';
    final calcName = _calcMethodName(state.config.calculationMethod);
    final asrName = state.config.asrCalculationSchool == 1 ? 'Hanafi' : "Shafi'i";

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: kSwCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(13)),
            ),
            child: Row(
              children: [
                Expanded(flex: 5, child: SettingsPill(
                  icon: hasLoc ? Icons.location_on_rounded : Icons.location_off_rounded,
                  label: locLabel,
                  active: _showLocationSearch,
                  iconColor: hasLoc ? kSwActive.withAlpha(180) : kSwTextMuted,
                  trailing: _isLocating
                      ? SizedBox(width: 10, height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.2, color: kSwActive.withAlpha(100)))
                      : GestureDetector(
                          onTap: _detectLocation,
                          child: Icon(Icons.my_location_rounded,
                              size: 12, color: kSwTextMuted.withAlpha(80)),
                        ),
                  onTap: () async {
                    // If device location (GPS) is off, prompt to turn it on
                    final serviceEnabled = await _isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      await _showLocationServiceDialog();
                      return;
                    }
                    setState(() {
                      _showLocationSearch = !_showLocationSearch;
                      if (_showLocationSearch) { _showCalcMethod = false; _showAsrSchool = false; }
                    });
                  },
                )),
                const SettingsDivider(),
                Expanded(flex: 4, child: SettingsPill(
                  icon: Icons.calculate_outlined,
                  label: calcName,
                  active: _showCalcMethod,
                  onTap: () {
                    setState(() {
                      _showCalcMethod = !_showCalcMethod;
                      if (_showCalcMethod) { _showLocationSearch = false; _showAsrSchool = false; }
                    });
                  },
                )),
                const SettingsDivider(),
                Expanded(flex: 3, child: SettingsPill(
                  icon: Icons.wb_cloudy_outlined,
                  label: asrName,
                  active: _showAsrSchool,
                  onTap: () {
                    setState(() {
                      _showAsrSchool = !_showAsrSchool;
                      if (_showAsrSchool) { _showLocationSearch = false; _showCalcMethod = false; }
                    });
                  },
                )),
              ],
            ),
          ),
        ),
        // Expandable panels
        _animatedPanel(_showLocationSearch, _buildLocationExpanded(state)),
        _animatedPanel(_showCalcMethod, _buildCalcMethodPanel(state)),
        _animatedPanel(_showAsrSchool, _buildAsrSchoolPanel(state)),
      ],
    );
  }

  Widget _animatedPanel(bool show, Widget child) {
    return AnimatedCrossFade(
      firstChild: const SizedBox(height: 0),
      secondChild: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 0), child: child),
      crossFadeState: show ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 220),
      sizeCurve: Curves.easeOut,
    );
  }

  // ══════════════════════════════════════════════════════
  //  DATE NAVIGATOR
  // ══════════════════════════════════════════════════════

  Widget _buildDateNavigator() {
    final isToday = dateKeyFor(_viewDate) == todayDateKey();
    final dateStr = DateFormat('EEEE d MMMM').format(_viewDate);

    // Countdown
    String? countdownLabel;
    if (isToday && _nextPrayerName.isNotEmpty) {
      final h = _timeUntilNext.inHours;
      final m = _timeUntilNext.inMinutes.remainder(60);
      countdownLabel = h > 0 ? '$_nextPrayerName in ${h}h ${m}m'
          : '$_nextPrayerName in ${m}m';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
      decoration: BoxDecoration(
        color: kSwCard,
        borderRadius: BorderRadius.circular(kSwRadius),
      ),
      child: Column(
        children: [
          Row(
            children: [
              NavArrow(
                icon: Icons.chevron_left_rounded,
                onTap: () {
                  _loadViewDate(_viewDate.subtract(const Duration(days: 1)));
                },
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(dateStr, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: kSwTextPrimary.withAlpha(200),
                    )),
                    if (isToday) ...[
                      const SizedBox(height: 2),
                      Text('TODAY', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        letterSpacing: 1.5, color: kSwActive,
                      )),
                    ],
                  ],
                ),
              ),
              NavArrow(
                icon: Icons.chevron_right_rounded,
                onTap: () {
                  _loadViewDate(_viewDate.add(const Duration(days: 1)));
                },
              ),
            ],
          ),
          if (countdownLabel != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: kSwActive.withAlpha(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: kSwActive),
                  const SizedBox(width: 6),
                  Text(countdownLabel, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: kSwActive,
                  )),
                ],
              ),
            ),
          ],
          if (_viewLoading) ...[
            const SizedBox(height: 8),
            SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: kSwActive)),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  PRAYER ROWS
  // ══════════════════════════════════════════════════════


  // Determine the time state of each prayer
  PrayerTimeState _prayerTimeState(String prayer, DailyPrayerTimes times) {
    final isToday = dateKeyFor(_viewDate) == todayDateKey();
    if (!isToday) return PrayerTimeState.future;

    final now = DateTime.now();
    const ordered = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final idx = ordered.indexOf(prayer);
    if (idx < 0) return PrayerTimeState.future;

    // Parse this prayer time
    final t = times.timeFor(prayer);
    if (t.isEmpty) return PrayerTimeState.future;
    final parts = t.split(':');
    if (parts.length != 2) return PrayerTimeState.future;
    final prayerDt = DateTime(now.year, now.month, now.day,
      int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);

    if (prayerDt.isAfter(now)) {
      // This prayer is in the future
      // Check if it's the NEXT upcoming one
      for (int i = 0; i < idx; i++) {
        final prevT = times.timeFor(ordered[i]);
        if (prevT.isEmpty) continue;
        final prevParts = prevT.split(':');
        if (prevParts.length != 2) continue;
        final prevDt = DateTime(now.year, now.month, now.day,
          int.tryParse(prevParts[0]) ?? 0, int.tryParse(prevParts[1]) ?? 0);
        if (prevDt.isAfter(now)) return PrayerTimeState.future; // earlier prayer also future
      }
      return PrayerTimeState.current; // This is the next upcoming prayer
    }
    return PrayerTimeState.past;
  }

  List<Widget> _buildPrayerRows(PrayerAlarmState state, PrayerReminderSettings s) {
    final times = _viewTimes ?? state.todayTimes;
    if (times == null) {
      return [Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text(
          'Set location to load prayer times',
          style: TextStyle(fontSize: 13, color: kSwTextMuted),
        )),
      )];
    }

    const prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    return prayers.map((prayer) {
      final apiTime = times.timeFor(prayer);
      if (apiTime.isEmpty) return const SizedBox.shrink();

      final mode = s.notifTypeFor(prayer);
      final adj = s.adjustmentFor(prayer);
      final effectiveTime = state.effectiveTimeFor(prayer, _viewDate) ?? apiTime;
      final timeState = _prayerTimeState(prayer, times);

      return PrayerRow(
        prayer: prayer,
        apiTime: apiTime,
        effectiveTime: effectiveTime,
        adjustment: adj,
        mode: mode,
        timeState: timeState,
        onModeChanged: (newMode) async {
          // Check required permissions for the selected mode before saving
          final ok = await _checkPermissionsForMode(newMode);
          if (!ok) return; // user was prompted — don't save until they grant
          ref.read(prayerAlarmProvider.notifier).setPrayerNotifType(prayer, newMode);
        },
        onAdjustmentChanged: (newAdj) {
          ref.read(prayerAlarmProvider.notifier).setPrayerAdjustment(prayer, newAdj);
        },
      );
    }).toList();
  }

  // ══════════════════════════════════════════════════════
  //  PER-MODE PERMISSION CHECK
  // ══════════════════════════════════════════════════════

  /// Returns true if all required permissions for [mode] are granted.
  /// If anything is missing, shows a compact in-context dialog and returns false.
  Future<bool> _checkPermissionsForMode(String mode) async {
    if (mode == 'off') return true;

    // Required permissions per mode:
    //  notify     → Notifications
    //  adhan      → Notifications + Exact Alarms
    final needNotif      = mode == 'notify' || mode == 'adhan';
    final needExact      = mode == 'adhan';

    final notifOk      = needNotif      ? await Permission.notification.isGranted : true;
    final exactOk      = needExact      ? await PrayerAlarmService.canScheduleExactAlarms() : true;

    if (notifOk && exactOk) return true;

    // Build missing list
    final missing = <String>[];
    if (!notifOk)      missing.add('Notifications');
    if (!exactOk)      missing.add('Exact Alarms');

    final modeLabel = {
      'notify'    : 'Notify',
      'adhan'     : 'Adhan',
    }[mode] ?? mode;

    if (!mounted) return false;
    final grant = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text('"$modeLabel" needs permissions',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: Color(0xFFE8E8E8))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This alarm type requires:', style: TextStyle(
              fontSize: 12, color: Colors.white.withAlpha(120))),
            const SizedBox(height: 8),
            ...missing.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.circle, size: 5, color: Colors.amber.withAlpha(180)),
                const SizedBox(width: 8),
                Text(p, style: const TextStyle(fontSize: 12,
                  color: Color(0xFFE8E8E8), fontWeight: FontWeight.w500)),
              ]),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(
              color: Colors.white.withAlpha(80), fontSize: 12)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx, true); },
            style: TextButton.styleFrom(foregroundColor: Colors.amber),
            child: const Text('Grant Permissions', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (grant != true) return false;
    // Open permission setup screen
    _openPermissionSetup();
    return false; // don't save mode until permissions granted
  }



  Widget _buildPermissionBanner() {
    final notifOk = _hasNotifPermission ?? true;
    final exactOk = _hasExactAlarmPermission ?? true;
    if (notifOk && exactOk) return const SizedBox.shrink();

    final missing = <String>[];
    if (!notifOk) missing.add('Notifications');
    if (!exactOk) missing.add('Exact Alarms');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: _openPermissionSetup,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.amber.withAlpha(15),
            border: Border.all(color: Colors.amber.withAlpha(40)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.amber.withAlpha(25),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.amber.withAlpha(180)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Permissions Required', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.amber.withAlpha(220),
                    )),
                    const SizedBox(height: 2),
                    Text('${missing.join(' & ')} not granted. Tap to fix.',
                      style: TextStyle(fontSize: 10, color: Colors.amber.withAlpha(120))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: Colors.amber.withAlpha(100)),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  FASTING FOOTER
  // ══════════════════════════════════════════════════════



  // ══════════════════════════════════════════════════════
  //  LOCATION EXPANDED PANEL
  // ══════════════════════════════════════════════════════

  Widget _buildLocationExpanded(PrayerAlarmState state) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: kSwCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLocating) ...[
            Row(children: [
              SizedBox(width: 11, height: 11,
                child: CircularProgressIndicator(strokeWidth: 1.3, color: kSwActive.withAlpha(130))),
              const SizedBox(width: 8),
              Text('Detecting your location…',
                style: TextStyle(fontSize: 11, color: kSwTextMuted)),
            ]),
            const SizedBox(height: 8),
          ] else if (_autoDetectedCity != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: kSwActive.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kSwActive.withAlpha(40)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.my_location_rounded, size: 12, color: kSwActive.withAlpha(150)),
                const SizedBox(width: 6),
                Text('Auto-detected: $_autoDetectedCity',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                    color: kSwActive.withAlpha(190))),
                const SizedBox(width: 8),
                Icon(Icons.check_circle_outline_rounded, size: 12, color: kSwActive.withAlpha(130)),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: _cityController,
            style: TextStyle(color: kSwTextPrimary.withAlpha(220), fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search city...',
              hintStyle: TextStyle(color: kSwTextMuted.withAlpha(80), fontSize: 13),
              prefixIcon: Icon(Icons.search_rounded, size: 15, color: kSwTextMuted.withAlpha(60)),
              suffixIcon: _isLocating || _isSearching
                  ? const Padding(padding: EdgeInsets.all(12),
                      child: SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5)))
                  : _cityController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, size: 14, color: kSwTextMuted),
                          onPressed: () {
                            _cityController.clear();
                            setState(() { _searchResults = []; _autoDetectedCity = null; });
                          },
                        )
                      : IconButton(
                          icon: Icon(Icons.my_location_rounded, size: 16, color: kSwTextMuted),
                          tooltip: 'Auto-detect location',
                          onPressed: _detectLocation,
                        ),
              filled: true,
              fillColor: Colors.white.withAlpha(6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            onChanged: (v) {
              if (_autoDetectedCity != null && v != _autoDetectedCity) {
                setState(() => _autoDetectedCity = null);
              }
              _onCitySearch(v);
            },
          ),
          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _searchResults.length,
                itemBuilder: (_, i) {
                  final r = _searchResults[i];
                  return InkWell(
                    onTap: () => _selectSearchResult(r),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(r['name'] as String,
                        style: TextStyle(fontSize: 12, color: kSwTextPrimary.withAlpha(170)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  CALC METHOD PANEL
  // ══════════════════════════════════════════════════════

  Widget _buildCalcMethodPanel(PrayerAlarmState state) {
    final selectedId = state.config.calculationMethod;
    final methods = AladhanApiService.calculationMethods;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: kSwCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('CALCULATION METHOD', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 1.0, color: kSwTextMuted)),
          ),
          // On-theme scrollable selection list — replaces the stock
          // DropdownButtonFormField (whose Material popup clashed with the
          // card design). Selected method is highlighted in the accent color.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 244),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: methods.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final m = methods[i];
                final id = m['id'] as int;
                final name = m['name'] as String;
                final sel = id == selectedId;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ref.read(prayerAlarmProvider.notifier).setCalculationMethod(id);
                    setState(() => _showCalcMethod = false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: sel ? kSwActive.withAlpha(18) : Colors.white.withAlpha(4),
                      border: Border.all(
                        color: sel ? kSwActive.withAlpha(50) : Colors.white.withAlpha(8)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 15, color: sel ? kSwActive : kSwTextMuted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(name,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                              color: sel ? kSwTextPrimary : kSwTextSecondary,
                            )),
                        ),
                        if (sel)
                          Icon(Icons.check_rounded, size: 14, color: kSwActive),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  ASR SCHOOL PANEL
  // ══════════════════════════════════════════════════════

  Widget _buildAsrSchoolPanel(PrayerAlarmState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: kSwCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Asr Calculation School', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            letterSpacing: 0.6, color: kSwTextMuted)),
          const SizedBox(height: 10),
          Row(children: [
            AsrOption(label: "Shafi'i", sublabel: 'Standard',
              selected: state.config.asrCalculationSchool == 0,
              onTap: () {
                ref.read(prayerAlarmProvider.notifier).setAsrCalculationSchool(0);
                setState(() => _showAsrSchool = false);
              }),
            const SizedBox(width: 8),
            AsrOption(label: 'Hanafi', sublabel: 'Indo-Pak',
              selected: state.config.asrCalculationSchool == 1,
              onTap: () {
                ref.read(prayerAlarmProvider.notifier).setAsrCalculationSchool(1);
                setState(() => _showAsrSchool = false);
              }),
          ]),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════

  String _calcMethodName(int id) {
    for (final m in AladhanApiService.calculationMethods) {
      if (m['id'] == id) {
        final name = m['name'] as String;
        return name.length > 25 ? '${name.substring(0, 25)}…' : name;
      }
    }
    return 'Default';
  }

  void _openPermissionSetup() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PermissionSetupScreen(
          onAllGranted: () async {
            await ref.read(prayerAlarmProvider.notifier).rescheduleAllAlarms();
            if (!mounted) return;
            Navigator.of(context).pop(true);
          },
          onSkipped: () => Navigator.of(context).pop(false),
        ),
        fullscreenDialog: true,
      ),
    );
    _checkPermissions();
  }

  Future<bool> _isLocationServiceEnabled() async {
    try {
      return await Permission.location.serviceStatus == ServiceStatus.enabled;
    } catch (_) {
      return true; // assume enabled if can't check
    }
  }

  Future<void> _showLocationServiceDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.location_off_rounded, color: kSwActive, size: 20),
          const SizedBox(width: 8),
          const Text('Location is Off', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE8E8E8))),
        ]),
        content: Text(
          'Turn on device location to auto-detect your city for accurate prayer times.',
          style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(120)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not Now', style: TextStyle(
              color: Colors.white.withAlpha(80), fontSize: 12)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Open system Location Settings directly
              await openAppSettings();
            },
            style: TextButton.styleFrom(foregroundColor: kSwActive),
            child: const Text('Open Settings', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _detectLocation() async {
    var locationStatus = await Permission.location.status;
    if (locationStatus.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Location permission is permanently denied. Enable it in Settings.'),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'OPEN SETTINGS', textColor: Colors.white,
          onPressed: () => openAppSettings()),
      ));
      return;
    }
    if (locationStatus.isDenied) {
      locationStatus = await Permission.location.request();
      if (!locationStatus.isGranted) return;
    }
    setState(() {
      _isLocating = true;
      _showLocationSearch = true;
      _showCalcMethod = false;
      _showAsrSchool = false;
      _autoDetectedCity = null;
    });
    try {
      await PrayerAlarmService.requestNotificationPermission();
      final coords = await LocationService.getCurrentLocation();
      final lat = coords['lat']!;
      final lng = coords['lng']!;
      final cityName = await LocationService.getCityName(lat, lng);
      if (!mounted) return;
      _cityController.text = cityName;
      setState(() { _searchResults = []; _isLocating = false; _autoDetectedCity = cityName; });
      ref.read(prayerAlarmProvider.notifier).updateConfig(
        latitude: lat, longitude: lng,
        timezone: DateTime.now().timeZoneName, locationLabel: cityName);
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() { _isLocating = false; _autoDetectedCity = null; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message), backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'SETTINGS', textColor: Colors.white,
          onPressed: () => openAppSettings()),
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() { _isLocating = false; _autoDetectedCity = null; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not detect location.'),
        backgroundColor: Colors.black54, behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _onCitySearch(String query) async {
    if (query.trim().length < 2) { setState(() => _searchResults = []); return; }
    _lastSearchTime = DateTime.now();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    if (DateTime.now().difference(_lastSearchTime!).inMilliseconds < 450) return;
    setState(() => _isSearching = true);
    try {
      final results = await LocationService.searchCity(query);
      if (!mounted) return;
      setState(() { _searchResults = results; _isSearching = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) async {
    final lat = result['lat'] as double;
    final lng = result['lng'] as double;
    final name = result['name'] as String;
    _cityController.text = name;
    setState(() => _searchResults = []);
    FocusScope.of(context).unfocus();
    await PrayerAlarmService.requestNotificationPermission();
    ref.read(prayerAlarmProvider.notifier).updateConfig(
      latitude: lat, longitude: lng,
      timezone: DateTime.now().timeZoneName, locationLabel: name);
  }

  Future<void> _scheduleFastingAlarm(String label, String timeStr) async {
    try {
      DateTime? parsed;
      final str = timeStr.trim();
      final parts24 = str.split(':');
      if (parts24.length == 2 && !str.contains(' ')) {
        parsed = DateTime(0, 1, 1, int.parse(parts24[0]), int.parse(parts24[1]));
      } else {
        parsed = DateFormat('h:mm a').parse(str);
      }
      final now = DateTime.now();
      var target = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
      if (target.isBefore(now)) target = target.add(const Duration(days: 1));

      final displayTime = DateFormat('h:mm a').format(target);
      final alarmId = label == 'Suhoor' ? 1010 : 1011;

      await PrayerAlarmService.storeFastingAlarm(alarmId, label, target);
      await PrayerAlarmService.scheduleFastingAlarm(
          label: label, alarmTime: target, alarmId: alarmId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$label alarm set for $displayTime'),
          backgroundColor: kSwCard,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not set alarm: $e'),
          backgroundColor: Colors.red.shade900,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
  // ══════════════════════════════════════════════════════
  //  HOME WIDGET TOGGLE
  // ══════════════════════════════════════════════════════

  Widget _buildWidgetToggle() {
    final displaySettings = ref.watch(displaySettingsProvider);
    final isEnabled = displaySettings.showPrayerWidget;

    return Container(
      decoration: BoxDecoration(
        color: kSwCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        children: [
          // Main toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kSwActive.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.widgets_rounded, size: 18, color: kSwActive.withAlpha(200)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Home Screen Widget', style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: kSwTextPrimary.withAlpha(230),
                      )),
                      const SizedBox(height: 2),
                      Text('Display next prayer card on home', style: TextStyle(
                        fontSize: 11, color: kSwTextMuted.withAlpha(150),
                      )),
                    ],
                  ),
                ),
                CupertinoSwitch(
                  value: isEnabled,
                  activeTrackColor: kSwActive,
                  inactiveTrackColor: Colors.white.withAlpha(20),
                  onChanged: (val) {
                    ref.read(displaySettingsProvider.notifier).setShowPrayerWidget(val);
                  },
                ),
              ],
            ),
          ),
          
          // Expanded options
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: [
                Divider(height: 1, color: Colors.white.withAlpha(10)),
                // Style Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      const SizedBox(width: 44),
                      Expanded(
                        child: Text('Widget Style', style: TextStyle(
                          fontSize: 13, color: kSwTextPrimary.withAlpha(200),
                        )),
                      ),
                      Container(
                        padding: const EdgeInsets.only(left: 10, right: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: displaySettings.homePrayerWidgetType,
                            icon: Icon(Icons.arrow_drop_down, color: Colors.white.withAlpha(150), size: 16),
                            isDense: true,
                            dropdownColor: const Color(0xFF141418),
                            style: TextStyle(fontSize: 12, color: Colors.white.withAlpha(200)),
                            items: const [
                              DropdownMenuItem(value: 'prayer_time', child: Text('Standard')),
                              DropdownMenuItem(value: 'salah_wake', child: Text('Salah Wake')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(displaySettingsProvider.notifier).setHomePrayerWidgetType(val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: isEnabled ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }



}
