import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A single readout in the telemetry grid. Flat with a hairline border so it
/// stays visually subordinate to the viewfinder hero; the value cross-fades
/// when it changes so updates are noticed without being distracting.
class TelemetryTile extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final IconData icon;
  final Color accentColor;
  final Widget? trailing;

  const TelemetryTile({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    required this.icon,
    this.accentColor = AppColors.brand,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkFaint,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SizeTransition(
                            axis: Axis.vertical,
                            sizeFactor: anim,
                            child: child,
                          ),
                        ),
                        child: Text(
                          value,
                          key: ValueKey(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: kMonoFont,
                            letterSpacing: 0.2,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        unit!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
