import 'package:flutter/material.dart';

import '../data/tips.dart';
import '../themes/app_colors.dart';

/// The rotating tip card on Home and on the Budget tab.
///
/// Shows one tip per day, picked from [tips] by the calendar date. When
/// [isUrgent] is set it switches to [urgentTips] instead, so a user who's
/// nearly out of budget isn't handed a cheerful line about meal prep.
///
/// The card itself doesn't know where the tip came from — that decision lives
/// in [pickTip] — so this stays a pure presentational widget and the rotation
/// logic stays testable without pumping a widget.
class TipCard extends StatelessWidget {
  /// Heading shown in the header row, e.g. `SAVING TIPS`.
  final String heading;

  /// Emoji before the heading.
  final String emoji;

  /// The rotating pool.
  final List<Tip> tips;

  /// Substituted for [tips] when [isUrgent] is true.
  final List<Tip> urgentTips;

  final bool isUrgent;

  final Color background;
  final Color borderColor;
  final Color headingColor;

  /// Body text colour. Defaults to `AppColors.black87`, which is what both
  /// cards used before this was extracted.
  final Color? bodyColor;

  /// Colour of the check glyph beside the tip. Defaults to the app's green.
  final Color accent;

  /// Shifts the rotation so this card and another card on a 12-tip rotation
  /// don't show the same tip on the same day.
  final int offset;

  /// The date the tip is chosen for. Injectable so a test (or a preview) can
  /// pin the card to a specific day instead of chasing the clock.
  final DateTime now;

  // Not const: [now] defaults to the real clock, which a const constructor
  // can't call.
  TipCard({
    super.key,
    required this.heading,
    required this.emoji,
    required this.tips,
    this.urgentTips = const [],
    this.isUrgent = false,
    required this.background,
    required this.borderColor,
    required this.headingColor,
    this.bodyColor,
    this.accent = const Color(0xFF00C853),
    this.offset = 0,
    DateTime? now,
  }) : now = now ?? _today();

  static DateTime _today() => DateTime.now();

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);

    final tip = pickTip(
      pool: tips,
      urgent: urgentTips,
      now: now,
      isUrgent: isUrgent,
      offset: offset,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap rather than a Row: on a narrow phone the badge drops to its
          // own line instead of overflowing, and nothing gets ellipsized.
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(
                    heading,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: headingColor,
                    ),
                  ),
                ],
              ),
              _badge(),
            ],
          ),
          const SizedBox(height: 10),
          _TipRow(
            tip: tip,
            color: bodyColor ?? AppColors.black87,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _badge() {
    final urgent = isUrgent && urgentTips.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: headingColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        urgent ? 'HEADS UP' : 'TIP OF THE DAY',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.4,
          color: headingColor,
        ),
      ),
    );
  }
}

/// One tip: bold lead-in, then the sentence, with a check glyph in front.
class _TipRow extends StatelessWidget {
  final Tip tip;
  final Color color;
  final Color accent;

  const _TipRow({required this.tip, required this.color, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✓ ',
          style: TextStyle(
            fontSize: 12,
            color: accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: color, height: 1.4),
              children: [
                // The colon belongs to the layout, not to the stored copy, so
                // tips stay reusable without trailing punctuation.
                TextSpan(
                  text: '${tip.title}: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: tip.body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
