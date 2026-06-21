import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../providers/theme_provider.dart';
import '../providers/prayer_alarm_provider.dart';
import '../services/aladhan_api_service.dart';
import '../services/location_service.dart';
import '../utils/prayer_time_utils.dart';
import '../widgets/salah_wake_widgets.dart';
import 'prayer_alarm_settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Salah Wake Onboarding — 5 steps, first-launch only
// ─────────────────────────────────────────────────────────────────────────────

class SalahWakeOnboardingScreen extends ConsumerStatefulWidget {
  const SalahWakeOnboardingScreen({super.key});

  @override
  ConsumerState<SalahWakeOnboardingScreen> createState() =>
      _SalahWakeOnboardingState();
}

class _SalahWakeOnboardingState
    extends ConsumerState<SalahWakeOnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  int _step = 0; // 0-4

  // State gathered during onboarding
  bool _locating = false;
  String? _detectedCity;
  double? _lat, _lng;
  int _calcMethod = 3; // ISNA default
  int _asrSchool = 0;  // Shafi'i
  bool _timesLoaded = false;
  Map<String, String>? _previewTimes; // prayer → "HH:mm"
  bool _fetchingTimes = false;

  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _anim.dispose();
    super.dispose();
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  void _next() {
    if (_step < 4) {
      setState(() => _step++);
      _pageController.animateToPage(_step,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
    }
  }

  void _done() {
    final notifier = ref.read(prayerAlarmProvider.notifier);

    // 1. Save location config
    if (_lat != null && _lng != null && _detectedCity != null) {
      notifier.updateConfig(
        latitude: _lat!,
        longitude: _lng!,
        timezone: DateTime.now().timeZoneName,
        locationLabel: _detectedCity!,
      );
    }
    // 2. Save method + school
    notifier.setCalculationMethod(_calcMethod);
    notifier.setAsrCalculationSchool(_asrSchool);

    // 3. Trigger a prayer time fetch so the Salah Wake settings page
    //    shows times immediately after onboarding completes
    notifier.fetchTodayPrayerTimes();

    // 4. Replace onboarding with settings screen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PrayerAlarmSettingsScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Location detection ──────────────────────────────────────────────────

  Future<void> _detectLocation() async {
    // Check if location SERVICE (GPS) is on first
    final serviceEnabled =
        await Permission.location.serviceStatus == ServiceStatus.enabled;
    if (!serviceEnabled) {
      _showLocationServiceDialog();
      return;
    }

    setState(() => _locating = true);
    try {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
      }
      if (status.isPermanentlyDenied) {
        // Can't ask again — open settings
        if (mounted) {
          setState(() => _locating = false);
          _showLocationPermDeniedDialog();
        }
        return;
      }
      if (!status.isGranted) {
        if (mounted) setState(() => _locating = false);
        return;
      }
      final coords = await LocationService.getCurrentLocation();
      final city = await LocationService.getCityName(
          coords['lat']!, coords['lng']!);
      if (!mounted) return;
      setState(() {
        _lat = coords['lat'];
        _lng = coords['lng'];
        _detectedCity = city;
        _locating = false;
      });
    } catch (_) {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationServiceDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0E0E0E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.location_off_rounded,
                    size: 24, color: Colors.orange.withValues(alpha: 0.80)),
              ),
              const SizedBox(height: 18),
              const Text('Location is Off',
                  style: TextStyle(
                    color: Color(0xFFE8E8E8),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 10),
              Text(
                'Please turn on your device location (GPS) so we can detect your city for accurate prayer times.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await openAppSettings();
                    // Re-try after returning from settings
                    await Future.delayed(const Duration(milliseconds: 800));
                    if (mounted) _detectLocation();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.orange.withValues(alpha: 0.12),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Text('Open Location Settings',
                          style: TextStyle(
                            color: Colors.orange.withValues(alpha: 0.90),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationPermDeniedDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E0E0E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Permission Denied',
            style: TextStyle(color: Color(0xFFE8E8E8), fontSize: 16)),
        content: Text(
          'Location permission was permanently denied. Please enable it in app Settings.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.40), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25))),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); openAppSettings(); },
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchPreviewTimes() async {
    if (_lat == null || _lng == null) return;
    setState(() { _fetchingTimes = true; _timesLoaded = false; });
    try {
      final times = await AladhanApiService.fetchPrayerTimes(
        latitude: _lat!,
        longitude: _lng!,
        method: _calcMethod,
        school: _asrSchool,
        date: DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _previewTimes = times;
        _timesLoaded = true;
        _fetchingTimes = false;
      });
      // ✅ DO NOT call _next() here — user must see times and TAP "These look correct"
    } catch (e) {
      if (mounted) setState(() { _fetchingTimes = false; _timesLoaded = false; });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(themeColorProvider).color;

    return Scaffold(
      backgroundColor: kSwBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar
            _ProgressBar(step: _step, total: 5, accent: accent),

            // ── Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StepLocation(
                    locating: _locating,
                    detected: _detectedCity,
                    accent: accent,
                    onDetect: _detectLocation,
                    onNext: _detectedCity != null ? _next : null,
                  ),
                  _StepCalcMethod(
                    selected: _calcMethod,
                    accent: accent,
                    onChanged: (v) => setState(() => _calcMethod = v),
                    onNext: _next,
                  ),
                  _StepAsrSchool(
                    selected: _asrSchool,
                    accent: accent,
                    onChanged: (v) => setState(() => _asrSchool = v),
                    onNext: _next,
                  ),
                  _StepPreview(
                    loading: _fetchingTimes,
                    loaded: _timesLoaded,
                    times: _previewTimes,
                    city: _detectedCity,
                    accent: accent,
                    // ✅ onFetch only fetches — does NOT advance. User taps again.
                    onFetch: _fetchPreviewTimes,
                    onNext: _timesLoaded ? _next : null,
                  ),
                  _StepEnableAlarms(
                    accent: accent,
                    city: _detectedCity ?? '',
                    onDone: _done,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Progress bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  final Color accent;

  const _ProgressBar(
      {required this.step, required this.total, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: List.generate(total, (i) {
          final done = i <= step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                color: done
                    ? accent.withValues(alpha: 0.80)
                    : Colors.white.withValues(alpha: 0.10),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared step scaffold
// ─────────────────────────────────────────────────────────────────────────────

class _StepShell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget content;
  final String buttonLabel;
  final VoidCallback? onButton;
  final bool buttonLoading;

  const _StepShell({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.content,
    required this.buttonLabel,
    this.onButton,
    this.buttonLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.10),
            ),
            child: Icon(icon, size: 22, color: accent.withValues(alpha: 0.80)),
          ),
          const SizedBox(height: 20),
          // Label
          Text(label.toUpperCase(),
              style: TextStyle(
                color: accent.withValues(alpha: 0.55),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              )),
          const SizedBox(height: 8),
          // Title
          Text(title,
              style: const TextStyle(
                color: kSwTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.5,
                height: 1.2,
              )),
          const SizedBox(height: 8),
          // Subtitle
          Text(subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
                height: 1.5,
              )),
          const SizedBox(height: 32),
          // Content
          Expanded(child: content),
          // Button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onButton,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: onButton != null
                      ? accent.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.08),
                ),
                child: Center(
                  child: buttonLoading
                      ? SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: onButton != null
                                  ? Colors.black
                                  : Colors.white54))
                      : Text(buttonLabel,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: onButton != null
                                ? Colors.black.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.25),
                            letterSpacing: -0.2,
                          )),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 1 — Location
// ─────────────────────────────────────────────────────────────────────────────

class _StepLocation extends StatelessWidget {
  final bool locating;
  final String? detected;
  final Color accent;
  final VoidCallback onDetect;
  final VoidCallback? onNext;

  const _StepLocation({
    required this.locating,
    required this.detected,
    required this.accent,
    required this.onDetect,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      icon: Icons.location_on_rounded,
      label: 'Step 1 of 5',
      title: 'Where are\nyou located?',
      subtitle:
          'We need your location to calculate accurate prayer times for your city.',
      accent: accent,
      buttonLabel: detected != null ? 'Continue' : 'Detect My Location',
      onButton: detected != null ? onNext : (locating ? null : onDetect),
      buttonLoading: locating,
      content: Column(
        children: [
          if (detected != null) ...[
            // Detected city card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: accent.withValues(alpha: 0.06),
                border: Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 20, color: accent.withValues(alpha: 0.80)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Auto-detected',
                          style: TextStyle(
                            color: accent.withValues(alpha: 0.55),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          )),
                      const SizedBox(height: 3),
                      Text(detected!,
                          style: const TextStyle(
                            color: kSwTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          )),
                    ],
                  ),
                  const Spacer(),
                  // Re-detect button
                  GestureDetector(
                    onTap: onDetect,
                    child: Icon(Icons.refresh_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Placeholder illustration
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mosque_rounded,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.05)),
                    const SizedBox(height: 16),
                    Text('Tap the button below\nto detect your location',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.20),
                          fontSize: 13,
                          height: 1.6,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 2 — Calculation Method
// ─────────────────────────────────────────────────────────────────────────────

class _StepCalcMethod extends StatelessWidget {
  final int selected;
  final Color accent;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;

  const _StepCalcMethod({
    required this.selected,
    required this.accent,
    required this.onChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final methods = AladhanApiService.calculationMethods;
    return _StepShell(
      icon: Icons.calculate_outlined,
      label: 'Step 2 of 5',
      title: 'Calculation\nMethod',
      subtitle:
          'Choose the authority that matches your region or school of thought.',
      accent: accent,
      buttonLabel: 'Continue',
      onButton: onNext,
      content: Container(
        decoration: BoxDecoration(
          color: kSwCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: DropdownButtonFormField<int>(
          value: selected,
          items: methods
              .map((m) => DropdownMenuItem<int>(
                    value: m['id'] as int,
                    child: Text(m['name'] as String,
                        style:
                            const TextStyle(fontSize: 12, color: kSwTextPrimary),
                        overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
          isExpanded: true,
          dropdownColor: const Color(0xFF161616),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            isDense: true,
          ),
          style: const TextStyle(
              color: kSwTextPrimary, fontSize: 12),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 3 — Asr School
// ─────────────────────────────────────────────────────────────────────────────

class _StepAsrSchool extends StatelessWidget {
  final int selected;
  final Color accent;
  final ValueChanged<int> onChanged;
  final VoidCallback onNext;

  const _StepAsrSchool({
    required this.selected,
    required this.accent,
    required this.onChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      icon: Icons.wb_cloudy_outlined,
      label: 'Step 3 of 5',
      title: 'Asr Prayer\nMethod',
      subtitle:
          'Shafi\'i is the standard opinion. Hanafi is common in Indo-Pak regions.',
      accent: accent,
      buttonLabel: 'Continue',
      onButton: onNext,
      content: Row(
        children: [
          _AsrTile(
            label: "Shafi'i",
            sublabel: 'Standard • Global',
            selected: selected == 0,
            accent: accent,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 10),
          _AsrTile(
            label: 'Hanafi',
            sublabel: 'Indo-Pak • Turkey',
            selected: selected == 1,
            accent: accent,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _AsrTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _AsrTile({
    required this.label,
    required this.sublabel,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? accent.withValues(alpha: 0.08)
                : kSwCard,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.07),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selected)
                Icon(Icons.check_circle_rounded,
                    size: 16, color: accent.withValues(alpha: 0.80)),
              if (!selected)
                Icon(Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.20)),
              const SizedBox(height: 12),
              Text(label,
                  style: TextStyle(
                    color: selected
                        ? kSwTextPrimary
                        : Colors.white.withValues(alpha: 0.55),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 4),
              Text(sublabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 10,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 4 — Preview Times
// ─────────────────────────────────────────────────────────────────────────────

class _StepPreview extends StatelessWidget {
  final bool loading;
  final bool loaded;
  final Map<String, String>? times;
  final String? city;
  final Color accent;
  final VoidCallback onFetch;
  final VoidCallback? onNext;

  const _StepPreview({
    required this.loading,
    required this.loaded,
    required this.times,
    required this.city,
    required this.accent,
    required this.onFetch,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      icon: Icons.access_time_rounded,
      label: 'Step 4 of 5',
      title: 'Your Prayer\nTimes',
      subtitle: city != null
          ? 'Based on your settings — $city'
          : 'Calculating times based on your settings…',
      accent: accent,
      buttonLabel: loaded ? 'These look correct' : 'Calculate Prayer Times',
      onButton: loaded ? onNext : (loading ? null : onFetch),
      buttonLoading: loading,
      content: loaded && times != null
          ? _PreviewList(times: times!, accent: accent)
          : Center(
              child: Icon(Icons.access_time_rounded,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.05)),
            ),
    );
  }
}

class _PreviewList extends StatelessWidget {
  final Map<String, String> times;
  final Color accent;

  const _PreviewList({required this.times, required this.accent});

  @override
  Widget build(BuildContext context) {
    const prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final icons = {
      'Fajr': Icons.wb_twilight_rounded,
      'Sunrise': Icons.wb_sunny_outlined,
      'Dhuhr': Icons.wb_sunny_rounded,
      'Asr': Icons.wb_cloudy_rounded,
      'Maghrib': Icons.nights_stay_rounded,
      'Isha': Icons.dark_mode_rounded,
    };
    return Column(
      children: prayers.map((p) {
        final t = times[p];
        if (t == null || t.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kSwCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(icons[p] ?? Icons.access_time,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.35)),
                const SizedBox(width: 12),
                Text(p,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    )),
                const Spacer(),
                Text(fmt12h(t),
                    style: TextStyle(
                      color: accent.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Step 5 — Enable Alarms
// ─────────────────────────────────────────────────────────────────────────────

class _StepEnableAlarms extends StatelessWidget {
  final Color accent;
  final String city;
  final VoidCallback onDone;

  const _StepEnableAlarms({
    required this.accent,
    required this.city,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      icon: Icons.mosque_rounded,
      label: 'Step 5 of 5',
      title: 'Set Your\nPrayer Alarms',
      subtitle:
          "You're all set! Choose which prayers to get notified for — you can change this anytime.",
      accent: accent,
      buttonLabel: 'Go to Alarm Settings',
      onButton: onDone,
      content: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 72,
              color: accent.withValues(alpha: 0.20)),
          const SizedBox(height: 20),
          Text(
            city.isNotEmpty ? city : 'Location set',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.60),
              fontSize: 15,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prayer times calculated',
            style: TextStyle(
              color: accent.withValues(alpha: 0.50),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
