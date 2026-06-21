import 'package:flutter/material.dart';

import '../utils/motion.dart';

/// Reusable bottom swipe-up wrapper for pushed screens.
///
/// Swipe-up from the bottom zone pops back to the launcher root with a
/// smooth reverse slide animation (iOS-style). The CupertinoPageRoute
/// transition keeps the home page fully interactive during the animation.
///
/// Does NOT conflict with vertical scroll inside children because
/// it only captures gestures in a thin bottom zone.
/// Requires a strong deliberate swipe-up (high velocity).
class SwipeBackWrapper extends StatefulWidget {
  final Widget child;

  const SwipeBackWrapper({super.key, required this.child});

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper> {
  bool _isDragging = false;

  /// Pop back to home with the smooth reverse slide animation.
  ///
  /// With CupertinoPageRoute the reverse animation is a smooth right-slide
  /// that keeps the underlying page interactive during the transition —
  /// no more ~300ms input-blocked overlay that MaterialPageRoute had.
  void _popToHome() {
    if (!Navigator.of(context).canPop()) return;
    GestureHaptics.swipeCommit();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Bottom swipe-up zone → pop ALL screens back to launcher home
        // Only triggers on strong deliberate upward swipe (not taps or small drags)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 36, // Reduced zone to avoid accidental captures
          child: GestureDetector(
            onVerticalDragStart: (details) {
              _isDragging = true;
            },
            onVerticalDragEnd: (details) {
              if (!_isDragging) return;
              _isDragging = false;

              final velocity = details.primaryVelocity ?? 0;
              // Require strong upward velocity (more negative = faster upswipe)
              if (velocity < -SwipeTuning.commitVelocity) {
                _popToHome();
              }
            },
            onVerticalDragCancel: () {
              _isDragging = false;
            },
            // translucent so taps pass through to content below
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}
