import 'package:flutter/material.dart';
import '../utils/launcher_physics.dart';

/// Lightweight, scroll-safe app drawer overlay.
///
/// Key design:
///  • Scrim is BEHIND the drawer content (not in front)
///  • Dismiss-check only fires when actively animating TO zero (closing)
///  • No outer gesture wrapper — AppList scrolls freely

void showInteractiveAppDrawer({
  required BuildContext context,
  required Widget drawerChild,
  double initialProgress = 0.0,
  double initialVelocity = 0.0,
  VoidCallback? onDismiss,
}) {
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _InteractiveAppDrawerOverlay(
      initialProgress: initialProgress,
      initialVelocity: initialVelocity,
      drawerChild: drawerChild,
      onDismiss: () {
        entry.remove();
        onDismiss?.call();
      },
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
}

class _InteractiveAppDrawerOverlay extends StatefulWidget {
  final double initialProgress;
  final double initialVelocity;
  final Widget drawerChild;
  final VoidCallback onDismiss;

  const _InteractiveAppDrawerOverlay({
    required this.initialProgress,
    required this.initialVelocity,
    required this.drawerChild,
    required this.onDismiss,
  });

  @override
  State<_InteractiveAppDrawerOverlay> createState() =>
      _InteractiveAppDrawerOverlayState();
}

class _InteractiveAppDrawerOverlayState
    extends State<_InteractiveAppDrawerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  double _progress = 0.0;
  bool _isDragging = false;
  double _dragStartY = 0.0;
  double _progressAtDragStart = 0.0;
  double _screenHeight = 800.0;

  // True once the spring-open animation has started.
  // We must NOT auto-dismiss while this is false (progress is still 0 at init).
  bool _hasStartedOpening = false;

  // Guard: ignore scrim drag events until the drawer has visibly opened.
  // Without this, the in-flight pointer from the swipe-up gesture leaks into
  // the scrim's GestureDetector, which sees progress ≈ 0 at drag-end and
  // immediately dismisses the drawer.
  bool _openAnimationSettled = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _controller = AnimationController.unbounded(vsync: this);
    _controller.addListener(_onAnimationTick);

    // Kick off the open animation after first frame so MediaQuery is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _hasStartedOpening = true;
        _springTo(1.0, initialVelocity: widget.initialVelocity);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenHeight = MediaQuery.sizeOf(context).height;
  }

  void _onAnimationTick() {
    if (!mounted) return;
    setState(() {
      _progress = _controller.value.clamp(0.0, 1.0);
    });

    // Mark as settled once the drawer is visibly open (past 50%).
    // After this point, scrim drags are allowed.
    if (!_openAnimationSettled && _progress > 0.5) {
      _openAnimationSettled = true;
    }

    // Only auto-dismiss once we've actually started opening AND
    // the user is not dragging AND progress has reached near-zero (closing).
    if (_hasStartedOpening && _progress <= 0.001 && !_isDragging) {
      _controller.stop();
      widget.onDismiss();
    }
  }

  void _springTo(double target, {double initialVelocity = 0.0}) {
    final spring = target > 0.5 ? LauncherSpring.soft : LauncherSpring.snapBack;
    final simulation = LauncherSpring.simulation(
      spring: spring,
      current: _progress,
      target: target,
      velocity: initialVelocity,
      pixelRange: _screenHeight,
    );
    _controller.animateWith(simulation);
  }

  void _onScrimDragStart(DragStartDetails details) {
    // Block drags until the open animation has visibly settled.
    // This prevents the in-flight swipe-up pointer from hijacking the drawer.
    if (!_openAnimationSettled) return;
    _isDragging = true;
    _dragStartY = details.globalPosition.dy;
    _progressAtDragStart = _progress;
    _controller.stop();
  }

  void _onScrimDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final dragDelta = _dragStartY - details.globalPosition.dy;
    final newProgress = _progressAtDragStart + (dragDelta / _screenHeight);
    setState(() => _progress = newProgress.clamp(0.0, 1.0));
  }

  void _onScrimDragEnd(DragEndDetails details) {
    // If drag was never accepted (blocked by _openAnimationSettled guard),
    // don't interfere with the opening spring animation.
    if (!_isDragging) return;
    _isDragging = false;
    final velocity = details.primaryVelocity ?? 0.0;
    final shouldOpen = LauncherGesture.shouldComplete(
      progress: _progress,
      velocity: -velocity,
      threshold: 0.4,
      velocityThreshold: 700.0,
    );
    _springTo(shouldOpen ? 1.0 : 0.0, initialVelocity: -velocity);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawerTranslateY = (1.0 - _progress) * _screenHeight;
    final scrimOpacity = (_progress * 0.40).clamp(0.0, 0.40);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Scrim behind the drawer ──────────────────────────────────
          // HitTestBehavior.translucent so touches pass through to the drawer
          // content on top. Scrim only captures taps on the area NOT covered
          // by the drawer (when drawer is partially open).
          Positioned.fill(
            child: GestureDetector(
              onTap: _openAnimationSettled ? () => _springTo(0.0) : null,
              onVerticalDragStart: _onScrimDragStart,
              onVerticalDragUpdate: _onScrimDragUpdate,
              onVerticalDragEnd: _onScrimDragEnd,
              behavior: HitTestBehavior.translucent,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: scrimOpacity),
              ),
            ),
          ),

          // ── 2. Drawer content (on top of scrim) ─────────────────────────
          // No GestureDetector wrapping → AppList scroll + taps work freely.
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, drawerTranslateY),
              child: widget.drawerChild,
            ),
          ),

          // ── 3. Drag handle pill ──────────────────────────────────────────
          if (_progress > 0.85)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Opacity(
                    opacity: ((_progress - 0.85) / 0.15).clamp(0.0, 1.0),
                    child: Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
