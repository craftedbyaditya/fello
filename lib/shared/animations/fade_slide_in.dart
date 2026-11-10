import 'package:flutter/material.dart';

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.04),
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration + delay).inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(
              offset.dx * 24 * (1 - value),
              offset.dy * 24 * (1 - value),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
