import 'package:flutter/material.dart';

import '../utils/motion.dart';

/// Edge Swipe Wrapper - Enables right edge swipe to navigate to dashboard
/// 
/// Wraps screens in Islamic Hub (Quran, Hadith, Dua) to enable
/// swipe-to-dashboard gesture from right edge
class EdgeSwipeWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSwipeRight;

  const EdgeSwipeWrapper({
    super.key,
    required this.child,
    this.onSwipeRight,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        child,
        
        // Right edge swipe detector
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 50, // Wider edge for easier swipe
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -SwipeTuning.quickVelocity) {
                // Fast swipe left from right edge
                if (onSwipeRight != null) {
                  GestureHaptics.swipeCommit();
                  onSwipeRight!();
                }
              }
            },
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}
