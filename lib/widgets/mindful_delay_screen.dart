import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A premium, behavior-shaping interrupter.
/// Shows a breathing animation for 5 seconds before allowing the user to 
/// enter a timed/blocked application.
class MindfulDelayScreen extends StatefulWidget {
  final String appName;
  final VoidCallback onTimerComplete;
  final VoidCallback onCancel;

  const MindfulDelayScreen({
    super.key,
    required this.appName,
    required this.onTimerComplete,
    required this.onCancel,
  });

  /// Show as a fullscreen dialog
  static Future<void> show(
    BuildContext context, {
    required String appName,
    required VoidCallback onTimerComplete,
    required VoidCallback onCancel,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: MindfulDelayScreen(
            appName: appName,
            onTimerComplete: onTimerComplete,
            onCancel: onCancel,
          ),
        );
      },
    );
  }

  @override
  State<MindfulDelayScreen> createState() => _MindfulDelayScreenState();
}

class _MindfulDelayScreenState extends State<MindfulDelayScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  int _secondsLeft = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _startTimer();
    HapticFeedback.mediumImpact();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 3) HapticFeedback.selectionClick();
      } else {
        _timer?.cancel();
        Navigator.pop(context);
        widget.onTimerComplete();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background "Breathing" Glow
          Center(
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE8915A).withValues(alpha: 0.15),
                      const Color(0xFFE8915A).withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Breathing Circle
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 80 * _pulseAnimation.value,
                        height: 80 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE8915A).withValues(alpha: 0.8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE8915A).withValues(alpha: 0.3),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 60),

              // Encouragement Text
              Text(
                'Breath in...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.2,
                ),
              ),
              
              const SizedBox(height: 12),

              Text(
                'Opening ${widget.appName} in $_secondsLeft...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),

              const Spacer(),

              // Cancel Button
              Padding(
                padding: const EdgeInsets.only(bottom: 50),
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    widget.onCancel();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.5),
                  ),
                  child: const Text('I changed my mind'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
