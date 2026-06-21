import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/zen_mode_provider.dart';

/// ─────────────────────────────────────────────
/// Zen Mode Active Screen
/// Full-screen lockdown with countdown timer
/// NO EXIT possible — timer must expire
/// ─────────────────────────────────────────────

class ZenModeActiveScreen extends ConsumerStatefulWidget {
  const ZenModeActiveScreen({super.key});

  @override
  ConsumerState<ZenModeActiveScreen> createState() =>
      _ZenModeActiveScreenState();
}

class _ZenModeActiveScreenState extends ConsumerState<ZenModeActiveScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? _immersiveEnforcer;
  late AnimationController _breatheCtrl;
  int _quoteIndex = 0;
  Timer? _quoteTimer;
  
  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMelodyPlaying = false;
  int _selectedSoundIndex = 0;
  
  static const _blockerChannel = MethodChannel('com.sukoon.launcher/app_blocker');

  static const _sounds = [
    {'name': 'Gentle Water', 'file': 'sounds/gentle_water.mp3'},
    {'name': 'Rain', 'file': 'sounds/rain.mp3'},
    {'name': 'Stream', 'file': 'sounds/streamfall.mp3'},
    {'name': 'Waterfall', 'file': 'sounds/waterfall.mp3'},
  ];

  static const _quotes = [
    "Don't give up",
    'Be present',
    'Breathe deeply',
    'Find your calm',
    'This moment matters',
    'Let go of distractions',
    'You are enough',
    'Stay grounded',
    'Embrace the silence',
    'Peace begins within',
    'Rest your mind',
    'You chose this',
  ];

  @override
  void initState() {
    super.initState();

    // NATIVE: Show over lock screen + full immersive mode
    _enableNativeLockdown();

    // FLUTTER: Also set immersive sticky as fallback
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final zen = ref.read(zenModeProvider);
      if (zen.hasExpired) {
        _onTimerComplete();
        return;
      }
      setState(() {});
    });

    // Rotate quotes every 8 seconds
    _quoteTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % _quotes.length;
        });
      }
    });

    _quoteIndex = DateTime.now().second % _quotes.length;
    
    // Re-enforce immersive mode every 10 seconds.
    // Native service re-applies it on each foreground-app check (200ms),
    // so 10s here is a lightweight safety net only.
    _immersiveEnforcer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      _enforceImmersive();
    });
    
    // Start playing gentle melody
    _startMelody();
  }
  
  // ─── Audio Controls ───
  
  Future<void> _startMelody() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.4);
      await _audioPlayer.play(AssetSource(_sounds[_selectedSoundIndex]['file']!));
      if (mounted) setState(() => _isMelodyPlaying = true);
    } catch (e) {
      debugPrint('Melody error: $e');
    }
  }
  
  Future<void> _toggleMelody() async {
    if (_isMelodyPlaying) {
      await _audioPlayer.pause();
      if (mounted) setState(() => _isMelodyPlaying = false);
    } else {
      await _audioPlayer.resume();
      if (mounted) setState(() => _isMelodyPlaying = true);
    }
  }
  
  Future<void> _changeSound(int index) async {
    _selectedSoundIndex = index;
    await _audioPlayer.stop();
    await _audioPlayer.play(AssetSource(_sounds[index]['file']!));
    if (mounted) setState(() => _isMelodyPlaying = true);
  }
  
  // ─── Native Lockdown ───
  
  Future<void> _enableNativeLockdown() async {
    try {
      await _blockerChannel.invokeMethod('enableZenLockScreen');
    } catch (_) {}
    try {
      await _blockerChannel.invokeMethod('enterFullImmersive');
    } catch (_) {}
  }
  
  Future<void> _enforceImmersive() async {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    try {
      await _blockerChannel.invokeMethod('enterFullImmersive');
    } catch (_) {}
  }

  // Track whether audio has already been released to prevent double-dispose crash.
  bool _audioReleased = false;

  void _releaseAudio() {
    if (_audioReleased) return;
    _audioReleased = true;
    _audioPlayer.stop();
    _audioPlayer.dispose();
  }

  void _onTimerComplete() {
    _timer?.cancel();
    _immersiveEnforcer?.cancel();
    _releaseAudio();
    HapticFeedback.heavyImpact();

    // End Zen Mode — calls setZenMode(false) on native side,
    // which also dismisses ZenLockScreenActivity and restores DND.
    ref.read(zenModeProvider.notifier).endZenMode();

    // Disable native lockdown THEN restore UI, then pop.
    // Use then() so native calls are fire-and-forget but ordered.
    _disableNativeLockdown().then((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  Future<void> _disableNativeLockdown() async {
    // Disable lock screen bypass and screen pinning
    try {
      await _blockerChannel.invokeMethod('disableZenLockScreen');
    } catch (_) {}
    // Exit full immersive mode (restore status/nav bars)
    try {
      await _blockerChannel.invokeMethod('exitFullImmersive');
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _quoteTimer?.cancel();
    _immersiveEnforcer?.cancel();
    _breatheCtrl.dispose();
    _releaseAudio(); // safe — guards against double-dispose
    _disableNativeLockdown();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zen = ref.watch(zenModeProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: GestureDetector(
        onVerticalDragStart: (_) {},
        onVerticalDragUpdate: (_) {},
        onVerticalDragEnd: (_) {},
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0D3B27),
                Color(0xFF164A33),
                Color(0xFF1A6B3F),
                Color(0xFF1E7A48),
                Color(0xFF22894F),
              ],
            ),
          ),
          child: Stack(
            children: [
                // Subtle animated wave/gradient overlay
                AnimatedBuilder(
                  animation: _breatheCtrl,
                  builder: (_, _) => CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _WavePainter(
                      progress: _breatheCtrl.value,
                    ),
                  ),
                ),

                // Main content
                SafeArea(
                  child: SizedBox.expand(
                    child: Column(
                      children: [
                        const Spacer(flex: 3),

                        // ─── Countdown Timer ───
                        Text(
                          zen.remainingFormatted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.w200,
                            fontFeatures: [FontFeature.tabularFigures()],
                            letterSpacing: 4,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ─── Motivational quote ───
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 600),
                          child: Text(
                            _quotes[_quoteIndex],
                            key: ValueKey(_quoteIndex),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        const Spacer(flex: 2),

                        // ─── Melody Control ───
                        _buildMelodySection(),

                        const Spacer(flex: 2),

                        // ─── Bottom: Camera ───
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Center(
                            child: _buildBottomButton(
                              icon: Icons.camera_alt_outlined,
                              label: 'Camera',
                              onTap: () => _openCamera(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Melody Section Widget ───
  Widget _buildMelodySection() {
    return Column(
      children: [
        // Play/Pause button with breathing animation
        AnimatedBuilder(
          animation: _breatheCtrl,
          builder: (_, _) {
            final scale = _isMelodyPlaying ? (0.85 + _breatheCtrl.value * 0.3) : 1.0;
            final opacity = _isMelodyPlaying ? (0.2 + _breatheCtrl.value * 0.15) : 0.1;
            return GestureDetector(
              onTap: _toggleMelody,
              child: Container(
                width: 70 * scale,
                height: 70 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: opacity * 0.4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: opacity * 0.8),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _isMelodyPlaying
                      ? Icons.music_note_rounded
                      : Icons.music_off_rounded,
                  color: Colors.white.withValues(
                    alpha: _isMelodyPlaying ? 0.9 : 0.4,
                  ),
                  size: 24,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 10),
        
        // Sound name
        Text(
          _isMelodyPlaying 
              ? _sounds[_selectedSoundIndex]['name']!
              : 'Sound off',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        
        const SizedBox(height: 14),
        
        // Sound selector dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_sounds.length, (i) {
            final isSelected = i == _selectedSoundIndex;
            return GestureDetector(
              onTap: () => _changeSound(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: isSelected ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.white.withValues(alpha: 0.2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ─── Bottom Button Widget ───
  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.7),
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCamera() async {
    try {
      // Use native method that handles unpin + camera launch
      await _blockerChannel.invokeMethod('openCamera');
    } catch (e) {
      debugPrint('Zen camera fallback: $e');
      // The native handler already has a full list of camera packages,
      // so a failure here likely means no camera app at all — nothing to do.
    }
  }
}

/// ─────────────────────────────────────────────
/// Animated wave/hill painter for background
/// ─────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final double progress;

  _WavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    // Gentle rolling hills
    final path = Path();
    path.moveTo(0, size.height * 0.7);

    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height * 0.7 +
          sin((x / size.width) * pi * 2 + progress * pi * 2) * 20 +
          sin((x / size.width) * pi * 3 + progress * pi) * 15;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Second wave
    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.75);

    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height * 0.75 +
          sin((x / size.width) * pi * 2.5 + progress * pi * 1.5 + 1) * 25 +
          cos((x / size.width) * pi * 1.5 + progress * pi * 2) * 10;
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.progress != progress;
}
