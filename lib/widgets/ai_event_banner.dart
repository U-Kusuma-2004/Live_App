import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ai_event.dart';
import '../theme/app_theme.dart';

/// Shows AI model status. Quiet and neutral while nothing is wrong; when an
/// event arrives it swaps in with colour and a raised edge so a driver or
/// dispatcher catches it immediately.
class AiEventBanner extends StatelessWidget {
  final AiEvent? event;

  const AiEventBanner({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, -0.06), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: event == null
          ? const _IdleBanner(key: ValueKey('idle'))
          : _AlertBanner(key: ValueKey(event!.timestamp), event: event!),
    );
  }
}

class _IdleBanner extends StatelessWidget {
  const _IdleBanner({super.key});

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
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.go.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.go),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI monitoring',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkFaint,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Model active — no alerts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final AiEvent event;
  const _AlertBanner({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final e = event.event.toUpperCase();
    final severe = e.contains('DROWSINESS') ||
        e.contains('COLLISION') ||
        e.contains('ALERT') ||
        event.confidence > 0.85;
    final color = severe ? AppColors.stop : AppColors.caution;
    final time = DateFormat('HH:mm:ss')
        .format(DateTime.fromMillisecondsSinceEpoch(event.timestamp * 1000));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              severe ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _title(event.event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: kMonoFont,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Confidence ${event.formattedConfidence}  ·  ${event.vehicleId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _title(String raw) {
    final words = raw.replaceAll('_', ' ').trim().toLowerCase().split(RegExp(r'\s+'));
    return words.map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}
