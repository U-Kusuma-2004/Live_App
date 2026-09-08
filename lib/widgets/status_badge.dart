import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeStatusType {
  active,
  ready,
  pending,
  error,
  inactive,
}

/// A compact status pill: a state dot (pulsing while live or pending), a
/// caption, and the current value. Designed to sit inside an Expanded so the
/// value ellipsizes instead of clipping on narrow screens.
class StatusBadge extends StatefulWidget {
  final String label;
  final String value;
  final BadgeStatusType statusType;
  final IconData? icon;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.label,
    required this.value,
    required this.statusType,
    this.icon,
    this.compact = false,
  });

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _animated =>
      widget.statusType == BadgeStatusType.active ||
      widget.statusType == BadgeStatusType.pending;

  @override
  void initState() {
    super.initState();
    if (_animated) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_animated && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_animated && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _color {
    switch (widget.statusType) {
      case BadgeStatusType.active:
        return AppColors.go;
      case BadgeStatusType.ready:
        return AppColors.brand;
      case BadgeStatusType.pending:
        return AppColors.caution;
      case BadgeStatusType.error:
        return AppColors.stop;
      case BadgeStatusType.inactive:
        return AppColors.inkFaint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 10 : 12,
        vertical: widget.compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = _animated ? _pulse.value : 1.0;
              return Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: _animated
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45 * t),
                            blurRadius: 8,
                            spreadRadius: 2 * t,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkFaint,
                  ),
                ),
                Text(
                  _pretty(widget.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color == AppColors.inkFaint ? AppColors.inkSoft : color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "reconnecting" -> "Reconnecting"
  String _pretty(String raw) =>
      raw.isEmpty ? raw : raw[0].toUpperCase() + raw.substring(1);
}
