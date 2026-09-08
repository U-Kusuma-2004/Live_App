import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Wraps its child in a real perspective transform that tilts toward the
/// pointer as you drag across it, then springs back when released. Used for
/// the live viewfinder so it reads as a physical panel you can handle.
class TiltCard extends StatefulWidget {
  final Widget child;
  final double maxTiltDegrees;

  const TiltCard({
    super.key,
    required this.child,
    this.maxTiltDegrees = 6,
  });

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  // Offset in the range roughly [-1, 1] on each axis.
  Offset _target = Offset.zero;
  Offset _current = Offset.zero;

  @override
  void initState() {
    super.initState();
    _spring.addListener(() {
      setState(() {
        _current = Offset.lerp(_current, _target, Curves.easeOutCubic.transform(_spring.value))!;
      });
    });
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  void _updateFromLocal(Offset local, Size size) {
    final dx = ((local.dx / size.width) * 2 - 1).clamp(-1.0, 1.0);
    final dy = ((local.dy / size.height) * 2 - 1).clamp(-1.0, 1.0);
    setState(() {
      _target = Offset(dx, dy);
      _current = _target;
    });
  }

  void _release() {
    _target = Offset.zero;
    _spring
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final rad = widget.maxTiltDegrees * math.pi / 180;
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateX(-_current.dy * rad)
      ..rotateY(_current.dx * rad);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          onPanStart: (d) => _updateFromLocal(d.localPosition, size),
          onPanUpdate: (d) => _updateFromLocal(d.localPosition, size),
          onPanEnd: (_) => _release(),
          onPanCancel: _release,
          child: Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: widget.child,
          ),
        );
      },
    );
  }
}
