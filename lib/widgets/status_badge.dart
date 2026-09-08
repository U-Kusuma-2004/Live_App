import 'package:flutter/material.dart';

enum BadgeStatusType {
  active,
  ready,
  pending,
  error,
  inactive,
}

class StatusBadge extends StatefulWidget {
  final String label;
  final String value;
  final BadgeStatusType statusType;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.value,
    required this.statusType,
    this.icon,
  });

  @override
  State<StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.statusType == BadgeStatusType.active ||
        widget.statusType == BadgeStatusType.pending) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant StatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.statusType == BadgeStatusType.active ||
        widget.statusType == BadgeStatusType.pending) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getStatusColor() {
    switch (widget.statusType) {
      case BadgeStatusType.active:
        return const Color(0xFF00F5A0); // Neon Mint Green
      case BadgeStatusType.ready:
        return const Color(0xFF00E5FF); // Cyber Cyan
      case BadgeStatusType.pending:
        return const Color(0xFFFFB703); // Amber Yellow
      case BadgeStatusType.error:
        return const Color(0xFFFF3366); // Warning Red
      case BadgeStatusType.inactive:
        return const Color(0xFF6B7280); // Cool Slate Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(
                    alpha: (widget.statusType == BadgeStatusType.active ||
                            widget.statusType == BadgeStatusType.pending)
                        ? _pulseAnimation.value
                        : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
          ],
          Text(
            '${widget.label}: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.4,
            ),
          ),
          Text(
            widget.value.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
