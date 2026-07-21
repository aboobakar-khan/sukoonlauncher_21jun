import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Apple-style page route with smooth iOS slide transitions.
///
/// Forward: new page slides in from the right while the old page slides left.
/// Back:    reversed slide — feels identical to iOS native swipe-back.
///
/// Uses [CupertinoPageRoute] under the hood so the interactive
/// edge-swipe-back gesture works automatically on both iOS and Android.
///
/// All navigation in the app should use this instead of [MaterialPageRoute]
/// or raw [PageRouteBuilder] so every transition is consistent and smooth.
class SmoothForwardRoute<T> extends CupertinoPageRoute<T> {
  SmoothForwardRoute({required Widget child, super.settings})
      : super(builder: (_) => child);

  /// True when the OS "reduce motion" accessibility setting is enabled.
  ///
  /// Read from the live navigator context (available once the route is pushed)
  /// so navigation collapses to a near-instant cut for motion-sensitive users
  /// instead of sliding. 1ms (not zero) keeps the route lifecycle intact.
  bool get _reducedMotion {
    final ctx = navigator?.context;
    if (ctx == null) return false;
    return MediaQuery.maybeOf(ctx)?.disableAnimations ?? false;
  }

  // Slightly faster than default Cupertino (400ms) for a snappier feel.
  @override
  Duration get transitionDuration => _reducedMotion
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 350);

  @override
  Duration get reverseTransitionDuration => _reducedMotion
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 300);
}

/// Keeps a push transition buttery when the destination has a heavy first build
/// (large lists, glass blur, JSON-backed providers). During the incoming slide
/// it paints only a cheap [background] placeholder — so the heavy widget tree
/// can't stutter the animation — then fades the real [child] in the moment the
/// slide settles. Wrap a screen's body (not its Scaffold) with this.
class DeferredFade extends StatefulWidget {
  final Widget child;
  final Color background;
  const DeferredFade({
    super.key,
    required this.child,
    this.background = Colors.transparent,
  });

  @override
  State<DeferredFade> createState() => _DeferredFadeState();
}

class _DeferredFadeState extends State<DeferredFade> {
  bool _show = false;
  Animation<double>? _anim;

  void _tick() {
    if (_show) return;
    final a = _anim;
    if (a != null && a.value >= 0.95) {
      a.removeListener(_tick);
      if (mounted) setState(() => _show = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final a = ModalRoute.of(context)?.animation;
    if (!identical(a, _anim)) {
      _anim?.removeListener(_tick);
      _anim = a;
      if (a == null || a.value >= 0.95) {
        _show = true;
      } else {
        a.addListener(_tick);
      }
    }
  }

  @override
  void dispose() {
    _anim?.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return ColoredBox(
          color: widget.background, child: const SizedBox.expand());
    }
    return TweenAnimationBuilder<double>(
      key: const ValueKey('deferred-shown'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      child: widget.child,
    );
  }
}
