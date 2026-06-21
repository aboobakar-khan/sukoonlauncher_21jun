import 'package:flutter/physics.dart';
import 'package:flutter/animation.dart';

/// ════════════════════════════════════════════════════════════════════════════
/// LAUNCHER PHYSICS ENGINE
/// ════════════════════════════════════════════════════════════════════════════
///
/// Samsung One UI-inspired physics constants, Material Design M3 easing curves,
/// and velocity-based animation utilities.
///
/// Design principles:
///   • Soft, slightly underdamped springs → subtle bounce at rest
///   • Velocity-aware durations → fast swipes = fast completions
///   • M3 easing curves → emphasised decelerate/accelerate for enter/exit
///   • All springs are interruptible (AnimationController.animateWith)

// ──────────────────────────────────────────────────────────────────────────────
//  SPRING DESCRIPTIONS
// ──────────────────────────────────────────────────────────────────────────────

/// Collection of tuned spring configurations for different launcher motions.
class LauncherSpring {
  LauncherSpring._();

  /// Default Samsung-feel spring: soft landing with the tiniest overshoot.
  ///
  /// Used for: app drawer open/close, search panel, page transitions.
  /// Damping ratio ≈ 0.88 → visually smooth, barely-perceptible bounce.
  static const SpringDescription soft = SpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 28.0,
  );

  /// Stiffer spring for snap-backs when user releases below threshold.
  ///
  /// Used for: cancelled drags, quick return to origin.
  /// Damping ratio ≈ 0.93 → faster settle, less bounce.
  static const SpringDescription snapBack = SpringDescription(
    mass: 1.0,
    stiffness: 600.0,
    damping: 35.0,
  );

  /// Very soft spring for gentle, floating transitions.
  ///
  /// Used for: parallax background motion, secondary layer animations.
  /// Damping ratio ≈ 0.85 → clearly elastic but not bouncy.
  static const SpringDescription gentle = SpringDescription(
    mass: 1.0,
    stiffness: 280.0,
    damping: 24.0,
  );

  /// Responsive spring for micro-interactions (icon taps, button presses).
  ///
  /// Used for: scale-on-tap, icon bounce.
  /// High stiffness, low mass → fast and sharp.
  static const SpringDescription tap = SpringDescription(
    mass: 0.6,
    stiffness: 800.0,
    damping: 22.0,
  );

  /// Create a [SpringSimulation] that drives from [current] to [target]
  /// with the given [velocity] using the specified [spring].
  ///
  /// Units:
  ///   • [current] / [target] — normalised 0.0–1.0 progress values
  ///   • [velocity] — pixels/second from gesture, auto-scaled to progress units
  ///   • [pixelRange] — the total pixel range the progress maps to (for velocity scaling)
  static SpringSimulation simulation({
    required SpringDescription spring,
    required double current,
    required double target,
    double velocity = 0.0,
    double pixelRange = 1.0,
  }) {
    // Convert pixel velocity to progress-space velocity
    final progressVelocity = pixelRange > 0 ? velocity / pixelRange : 0.0;
    return SpringSimulation(spring, current, target, progressVelocity);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
//  MATERIAL DESIGN M3 EASING CURVES
// ──────────────────────────────────────────────────────────────────────────────

/// Material Design 3 motion easing curves.
///
/// Reference: https://m3.material.io/styles/motion/easing-and-duration/applying-easing-and-duration
class LauncherEasing {
  LauncherEasing._();

  /// **Emphasized decelerate** — for elements entering the screen.
  ///
  /// Starts fast, decelerates with a long tail. Makes entering content
  /// feel like it's arriving with momentum and gently settling.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// **Emphasized accelerate** — for elements exiting the screen.
  ///
  /// Starts slow, accelerates out. Makes exiting content feel like
  /// it's picking up speed and departing with energy.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// **Emphasized** — for within-screen transitions (shared axis, fade through).
  ///
  /// Combination of accelerate-decelerate for in-place changes.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// **Standard** — for utility animations (color changes, opacity shifts).
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// **Standard decelerate** — for elements entering from off-screen.
  static const Curve standardDecelerate = Cubic(0.0, 0.0, 0.0, 1.0);

  /// **Standard accelerate** — for elements leaving the screen.
  static const Curve standardAccelerate = Cubic(0.3, 0.0, 1.0, 1.0);

  /// Samsung One UI-style easeOutQuart — aggressive decel with long tail.
  static const Curve samsungDecelerate = Cubic(0.25, 1.0, 0.25, 1.0);

  /// Samsung One UI-style easeInQuart — for reverse/dismiss motions.
  static const Curve samsungAccelerate = Cubic(0.42, 0.0, 1.0, 1.0);
}

// ──────────────────────────────────────────────────────────────────────────────
//  VELOCITY → DURATION MAPPING
// ──────────────────────────────────────────────────────────────────────────────

/// Utilities for mapping gesture velocity to animation duration.
class LauncherDuration {
  LauncherDuration._();

  /// Maps swipe velocity (pixels/second) to an appropriate animation duration.
  ///
  /// Fast swipes (>2000 px/s) → 200ms (snappy)
  /// Medium swipes (~1000 px/s) → 300ms
  /// Slow swipes (<500 px/s) → 450ms (deliberate)
  ///
  /// [remainingProgress] — how much animation is left (0.0–1.0).
  /// The duration is scaled by remaining progress so a 90%-complete
  /// animation doesn't take the full duration.
  static Duration fromVelocity(
    double velocityPxPerSec, {
    double remainingProgress = 1.0,
  }) {
    final absVelocity = velocityPxPerSec.abs();

    // Base duration from velocity (linear interpolation between bounds)
    final int baseMs;
    if (absVelocity > 2000) {
      baseMs = 200;
    } else if (absVelocity > 1200) {
      // Lerp 300→200 as velocity goes 1200→2000
      final t = (absVelocity - 1200) / 800;
      baseMs = (300 - (100 * t)).round();
    } else if (absVelocity > 500) {
      // Lerp 400→300 as velocity goes 500→1200
      final t = (absVelocity - 500) / 700;
      baseMs = (400 - (100 * t)).round();
    } else {
      baseMs = 450;
    }

    // Scale by remaining progress — if only 10% left, animation should be fast
    final scaledMs = (baseMs * remainingProgress.clamp(0.15, 1.0)).round();

    return Duration(milliseconds: scaledMs.clamp(120, 500));
  }

  /// Minimum duration for standard transitions.
  static const Duration minimum = Duration(milliseconds: 150);

  /// Standard drawer open/close duration when no velocity info is available.
  static const Duration drawerDefault = Duration(milliseconds: 350);

  /// Quick micro-interaction duration (scale pulse, icon bounce).
  static const Duration micro = Duration(milliseconds: 120);

  /// Return-from-app fade-in.
  static const Duration returnFromApp = Duration(milliseconds: 350);
}

// ──────────────────────────────────────────────────────────────────────────────
//  GESTURE UTILITIES
// ──────────────────────────────────────────────────────────────────────────────

/// Helper methods for gesture-to-animation calculations.
class LauncherGesture {
  LauncherGesture._();

  /// Given a drag delta, overall range, and velocity, determine whether the
  /// gesture should complete (true) or snap back (false).
  ///
  /// [progress] — current progress (0.0–1.0)
  /// [velocity] — pixels/second in the direction of completion (positive = complete)
  /// [threshold] — progress threshold for commit (default 0.35)
  /// [velocityThreshold] — velocity above which always commits (default 800 px/s)
  static bool shouldComplete({
    required double progress,
    required double velocity,
    double threshold = 0.35,
    double velocityThreshold = 800.0,
  }) {
    // High velocity in completion direction → always complete
    if (velocity.abs() > velocityThreshold) {
      return velocity > 0;
    }
    // Otherwise, decide by progress threshold
    return progress > threshold;
  }

  /// Clamp a value between 0.0 and 1.0.
  static double clampProgress(double value) => value.clamp(0.0, 1.0);

  /// Calculate parallax offset for a secondary layer.
  ///
  /// [primaryProgress] — the main layer's progress (0.0–1.0)
  /// [parallaxFactor] — how much slower the secondary layer moves (0.0–1.0)
  ///   0.0 = stationary, 1.0 = moves at same rate as primary
  static double parallax(double primaryProgress, double parallaxFactor) {
    return primaryProgress * parallaxFactor;
  }

  /// Map a progress value to a scale in a given range.
  ///
  /// Example: `mapToScale(0.5, from: 1.0, to: 0.92)` → 0.96
  static double mapToScale(double progress, {required double from, required double to}) {
    return from + (to - from) * progress;
  }

  /// Map a progress value to an opacity in a given range.
  static double mapToOpacity(double progress, {required double from, required double to}) {
    return (from + (to - from) * progress).clamp(0.0, 1.0);
  }
}
