import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/zen_mode_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/premium_provider.dart';
import '../widgets/swipe_back_wrapper.dart';
import 'zen_mode_active_screen.dart';
import 'zen_mode_permissions_screen.dart';
import 'premium_paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Kahf Mode Entry Screen  (formerly Muraqaba)
// Sacred minimalism: distraction-free deep focus.
// ─────────────────────────────────────────────────────────────────────────────

class ZenModeEntryScreen extends ConsumerStatefulWidget {
  const ZenModeEntryScreen({super.key});

  @override
  ConsumerState<ZenModeEntryScreen> createState() => _ZenModeEntryScreenState();
}

class _ZenModeEntryScreenState extends ConsumerState<ZenModeEntryScreen>
    with TickerProviderStateMixin {
  int _selectedMinutes = 5;

  late AnimationController _breatheCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _breatheAnim;

  // Fresh green leaf light theme
  static const _bg       = Color(0xFFF6FBF5);
  static const _card     = Colors.white;
  static const _border   = Color(0xFFDFEADF);
  static const _text     = Color(0xFF263628);
  static const _textSoft = Color(0xFF748C76);

  Color get _accent      => const Color(0xFF4CAF50);
  Color get _accentSoft  => const Color(0xFF43A047);
  Color get _accentDim   => const Color(0xFF2E7D32);

  static const _presets = [5, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _breatheAnim =
        CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _fmt(int min) {
    if (min < 60) return '${min}m';
    final h = min ~/ 60;
    final m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  void _showCustomPicker() {
    int hours   = _selectedMinutes ~/ 60;
    int minutes = ((_selectedMinutes % 60) / 5).round() * 5;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _text.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                )),
              const SizedBox(height: 24),
              Text('Custom Duration',
                style: const TextStyle(
                  color: _text, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _numPicker(value: hours, min: 0, max: 12, label: 'HR',
                    onChanged: (v) => setModal(() => hours = v)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(':',
                      style: TextStyle(
                        color: _textSoft.withValues(alpha: 0.4),
                        fontSize: 32, fontWeight: FontWeight.w200)),
                  ),
                  _numPicker(value: minutes, min: 0, max: 55, step: 5,
                    label: 'MIN',
                    onChanged: (v) => setModal(() => minutes = v)),
                ],
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () {
                  final total = hours * 60 + minutes;
                  if (total < 5) return;
                  setState(() => _selectedMinutes = total);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.3),
                        blurRadius: 12, offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(child: Text('Confirm',
                    style: TextStyle(
                      color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w700))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numPicker({
    required int value,
    required int min,
    required int max,
    required String label,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Column(children: [
      Text(label,
        style: TextStyle(
          color: _textSoft,
          fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Container(
        width: 90, height: 130,
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1.5),
        ),
        child: ListWheelScrollView.useDelegate(
          itemExtent: 42,
          perspective: 0.003,
          physics: const FixedExtentScrollPhysics(),
          controller: FixedExtentScrollController(
              initialItem: (value - min) ~/ step),
          onSelectedItemChanged: (i) => onChanged(min + i * step),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: ((max - min) ~/ step) + 1,
            builder: (ctx, i) {
              final val = min + i * step;
              final sel = val == value;
              return Center(child: Text(
                val.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: sel ? _text : _textSoft.withValues(alpha: 0.4),
                  fontSize: sel ? 28 : 18,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                )));
            },
          ),
        ),
      ),
    ]);
  }

  void _proceed() {
    final isPremium =
        ref.read(hasFeatureProvider(PremiumFeature.focusModeCustomization));
    if (!isPremium) {
      showPremiumPaywall(context, triggerFeature: 'Kahf Mode Focus');
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, b) =>
            ZenModePermissionsScreen(durationMinutes: _selectedMinutes),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0.05, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        transitionDuration: const Duration(milliseconds: 320),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zen = ref.watch(zenModeProvider);

    if (zen.isActive && !zen.hasExpired) {
      return const ZenModeActiveScreen();
    }

    return SwipeBackWrapper(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: _bg,
          body: FadeTransition(
          opacity: _fadeCtrl,
          child: Stack(
            children: [
              _buildGlow(),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(zen),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            _buildHero(),
                            const SizedBox(height: 36),
                            _buildDuration(),
                            const SizedBox(height: 32),
                            _buildWhatHappens(),
                            const SizedBox(height: 48),
                          ],
                        ),
                      ),
                    ),
                    _buildCTA(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ── Ambient radial glow ──
  Widget _buildGlow() {
    return AnimatedBuilder(
      animation: _breatheAnim,
      builder: (_, _) => CustomPaint(
        painter: _GlowPainter(_breatheAnim.value, _accent),
        size: Size.infinite,
      ),
    );
  }

  // ── Top bar ──
  Widget _buildTopBar(ZenModeState zen) {
    final isPremium =
        ref.watch(hasFeatureProvider(PremiumFeature.focusModeCustomization));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: _textSoft, size: 20),
          ),
        ),
        const Spacer(),
        if (!isPremium)
          GestureDetector(
            onTap: () =>
                showPremiumPaywall(context, triggerFeature: 'Kahf Mode Focus'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFC2A366).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFC2A366).withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_rounded,
                    color: const Color(0xFFC2A366).withValues(alpha: 0.85),
                    size: 11),
                const SizedBox(width: 5),
                Text('PRO',
                  style: TextStyle(
                    color: const Color(0xFFC2A366).withValues(alpha: 0.85),
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  )),
              ]),
            ),
          )
        else if (zen.sessionsCompleted > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withValues(alpha: 0.22)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.local_fire_department_rounded,
                  color: _accentSoft, size: 12),
              const SizedBox(width: 5),
              Text('${zen.sessionsCompleted} sessions',
                style: TextStyle(
                  color: _accentSoft, fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
            ]),
          ),
      ]),
    );
  }

  // ── Hero section ──
  Widget _buildHero() {
    return Column(children: [
      Center(
        child: AnimatedBuilder(
          animation: _breatheAnim,
          builder: (_, _) {
            final scale = 0.93 + (_breatheAnim.value * 0.07);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accent.withValues(alpha: 0.08 + _breatheAnim.value * 0.04),
                      _accent.withValues(alpha: 0.01),
                      Colors.transparent,
                    ],
                    stops: const [0.25, 0.65, 1.0],
                  ),
                  border: Border.all(
                    color: _accent.withValues(alpha: 0.3 + _breatheAnim.value * 0.15),
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.eco_rounded,
                    color: _accent.withValues(
                        alpha: 0.85 + _breatheAnim.value * 0.15),
                    size: 38),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 24),
      // Title
      const Text('Kahf Mode',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _text,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        )),
      const SizedBox(height: 10),
      Text('Blocks all apps. Mutes notifications.\nNo escape until the timer ends.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _textSoft,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          height: 1.4,
        )),
    ]);
  }

  // ── Duration picker ──
  Widget _buildDuration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DURATION',
          style: TextStyle(
            color: _textSoft.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          )),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._presets.map((min) => _DurationChip(
              label: _fmt(min),
              isSelected: _selectedMinutes == min,
              onTap: () => setState(() => _selectedMinutes = min),
              accent: _accent,
              border: _border,
              bg: _card,
              textDark: _text,
              textLight: _textSoft,
            )),
            GestureDetector(
              onTap: _showCustomPicker,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  color: !_presets.contains(_selectedMinutes) ? _accent.withValues(alpha: 0.1) : _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !_presets.contains(_selectedMinutes)
                        ? _accent
                        : _border,
                    width: !_presets.contains(_selectedMinutes) ? 2.0 : 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.tune_rounded,
                    color: !_presets.contains(_selectedMinutes)
                        ? _accentDim
                        : _textSoft,
                    size: 16),
                  const SizedBox(width: 6),
                  Text(
                    !_presets.contains(_selectedMinutes)
                        ? _fmt(_selectedMinutes)
                        : 'Custom',
                    style: TextStyle(
                      color: !_presets.contains(_selectedMinutes)
                          ? _accentDim
                          : _textSoft,
                      fontSize: 14,
                      fontWeight: !_presets.contains(_selectedMinutes)
                          ? FontWeight.w700
                          : FontWeight.w600,
                    )),
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── What happens (clean minimal cards) ──
  Widget _buildWhatHappens() {
    final items = [
      _Item(icon: Icons.grid_view_rounded,
        color: const Color(0xFFD32F2F),
        label: 'All apps blocked'),
      _Item(icon: Icons.notifications_off_rounded,
        color: const Color(0xFFF57C00),
        label: 'Notifications silenced'),
      _Item(icon: Icons.camera_alt_rounded,
        color: const Color(0xFF388E3C),
        label: 'Camera accessible'),
      _Item(icon: Icons.lock_clock_rounded,
        color: const Color(0xFFD81B60),
        label: 'No early exit possible'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RULES OF THE CAVE',
          style: TextStyle(
            color: _textSoft.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
          )),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _text.withValues(alpha: 0.02),
                blurRadius: 10, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final i    = entry.key;
              final item = entry.value;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 16),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.color.withValues(alpha: 0.12),
                      ),
                      child: Icon(item.icon,
                          color: item.color, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Text(item.label,
                      style: TextStyle(
                        color: _text.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      )),
                  ]),
                ),
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    color: _border,
                    indent: 20,
                    endIndent: 20,
                  ),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Bottom CTA ──
  Widget _buildCTA() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
      child: GestureDetector(
        onTap: _proceed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Enter Kahf — ${_fmt(_selectedMinutes)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                )),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duration chip
// ─────────────────────────────────────────────────────────────────────────────

class _DurationChip extends StatelessWidget {
  final String      label;
  final bool        isSelected;
  final VoidCallback onTap;
  final Color        accent;
  final Color        border;
  final Color        bg;
  final Color        textDark;
  final Color        textLight;

  const _DurationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.accent,
    required this.border,
    required this.bg,
    required this.textDark,
    required this.textLight,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.1)
              : bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent : border,
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: Text(label,
          style: TextStyle(
            color: isSelected
                ? Color.lerp(accent, Colors.black, 0.4)
                : textLight,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item model
// ─────────────────────────────────────────────────────────────────────────────

class _Item {
  final IconData icon;
  final Color    color;
  final String   label;
  const _Item({required this.icon, required this.color, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// Glow painter
// ─────────────────────────────────────────────────────────────────────────────

class _GlowPainter extends CustomPainter {
  final double progress;
  final Color  accent;
  const _GlowPainter(this.progress, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final a = (0.035 + progress * 0.025).clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.5),
        radius: 0.75,
        colors: [
          accent.withValues(alpha: (a * 3).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.75))
      ..blendMode = BlendMode.screen;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.65), paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.progress != progress || old.accent != accent;
}
