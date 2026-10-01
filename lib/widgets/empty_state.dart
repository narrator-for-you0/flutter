import 'package:flutter/material.dart';

import '../themes/app_colors.dart';

/// The "there's nothing here" block.
///
/// Every list in the app needs one of these and they all used to be invented
/// per screen — a bare `Text('Nothing found')` in History, a sentence buried
/// inside a card in Stats. This gives them one shape: a tinted icon badge, a
/// short title, a sentence explaining what to do next, and optionally a button
/// that does the thing.
///
/// Call [AppColors.sync] is already handled by the caller; this reads the
/// palette as-is like every other widget.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  /// Optional call to action, e.g. "Log an expense" when nothing is logged.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Badge tint and icon colour. Defaults to a neutral grey so an empty state
  /// never implies success or failure.
  final Color? accent;
  final Color? badgeColor;

  /// A single line for places without vertical room to breathe, such as the
  /// category ranking card inside Stats.
  final bool compact;

  final EdgeInsetsGeometry padding;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.accent,
    this.badgeColor,
    this.compact = false,
    this.padding = const EdgeInsets.all(32),
  });

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.muted;

    if (compact) {
      return Padding(
        padding: padding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.faint),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: badgeColor ?? AppColors.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: tint),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: tint,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
