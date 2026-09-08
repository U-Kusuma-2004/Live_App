import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A physical-feeling button: pressing it translates the face down and
/// collapses its shadow, like depressing a real console key. Colour comes
/// from the caller so START / STOP / primary actions stay distinct.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final Color pressedColor;
  final Color foreground;
  final EdgeInsets padding;
  final double radius;
  final bool loading;

  const Pressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.color = AppColors.brand,
    this.pressedColor = AppColors.brandPressed,
    this.foreground = Colors.white,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    this.radius = AppRadii.tile,
    this.loading = false,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setDown(bool v) {
    if (!_enabled) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final active = _enabled;
    final pressed = _down && active;

    final bg = !active
        ? AppColors.line
        : pressed
            ? widget.pressedColor
            : widget.color;
    final fg = active ? widget.foreground : AppColors.inkFaint;

    return GestureDetector(
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: active ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, pressed ? 2 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: active && !pressed
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: fg,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          child: IconTheme.merge(
            data: IconThemeData(color: fg, size: 20),
            child: Center(
              child: widget.loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(fg),
                      ),
                    )
                  : widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
