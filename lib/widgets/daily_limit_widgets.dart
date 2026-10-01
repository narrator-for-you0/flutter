import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';

const _red = Color(0xFFDC2626);
Color get _redSoft => AppColors.redSoft;
Color get _redBorder => AppColors.redBorder;
const _green = Color(0xFF00C853);
const _orange = Color(0xFFEA580C);
Color get _dark => AppColors.text;
Color get _muted => AppColors.muted;

// -----------------------------------------------------------------------------
// 1. Banner: shown at the top of the app if you open it already over the limit
// -----------------------------------------------------------------------------
class DailyLimitBanner extends StatelessWidget {
  const DailyLimitBanner({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Consumer<ExpenseProvider>(
      builder: (context, provider, _) {
        final show = provider.showLimitBanner;

        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: show
              ? _buildBanner(provider)
              : const SizedBox(width: double.infinity, height: 0),
        );
      },
    );
  }

  Widget _buildBanner(ExpenseProvider provider) {
    final spent = provider.todaySpent;
    final limit = provider.dailyLimit;
    final over = spent - limit;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: _redSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _redBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _red, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "You're over today's spending limit",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _red,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${spent.toStringAsFixed(0)} spent • ₱${limit.toStringAsFixed(0)} limit • ₱${over.toStringAsFixed(0)} over',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, size: 18, color: _muted),
            onPressed: provider.dismissLimitBanner,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Card: today's spending vs the daily limit (Home + Budget screens)
// -----------------------------------------------------------------------------
class DailyLimitCard extends StatelessWidget {
  final double spent;
  final double limit;

  const DailyLimitCard({super.key, required this.spent, required this.limit});

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final isOver = spent > limit;
    final ratio = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final accent = isOver ? _red : _green;
    final remaining = (limit - spent).abs();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isOver ? _redSoft : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOver ? _redBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isOver ? Icons.warning_amber_rounded : Icons.speed,
                    size: 16,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'DAILY LIMIT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _dark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Text(
                isOver
                    ? '₱${remaining.toStringAsFixed(0)} over'
                    : '₱${remaining.toStringAsFixed(0)} left today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.track,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₱${spent.toStringAsFixed(0)} of ₱${limit.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Pop-up: shown when an expense pushes a day over the limit
// -----------------------------------------------------------------------------
class DailyLimitAlert {
  DailyLimitAlert._();

  /// Call this right after `addExpense`/`updateExpense`. It only shows a
  /// dialog when THIS expense is the one that crossed the daily limit or a
  /// category limit; otherwise it does nothing.
  static Future<void> handle(BuildContext context, LimitCheck check) async {
    if (check.crossed) {
      await showDialog<void>(
        context: context,
        builder: (_) => _DailyLimitDialog(check: check),
      );
    }
    if (check.categoryHits.isNotEmpty && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (_) => _CategoryLimitDialog(hits: check.categoryHits),
      );
    }
  }
}

class _CategoryLimitDialog extends StatelessWidget {
  final List<CategoryLimitHit> hits;

  const _CategoryLimitDialog({required this.hits});

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final plural = hits.length > 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.orangeSoft,
              child: const Icon(Icons.pie_chart_outline, color: _orange, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              plural ? 'Category limits reached' : 'Category limit reached',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _dark),
            ),
            const SizedBox(height: 8),
            Text(
              'That purchase takes you over ${plural ? 'these limits' : 'this limit'} '
              'for the current period.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            ...hits.map(_row),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(CategoryLimitHit h) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(h.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _dark),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${h.total.toStringAsFixed(0)} of ₱${h.limit.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
          ),
          Text(
            '₱${h.overBy.toStringAsFixed(0)} over',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _orange),
          ),
        ],
      ),
    );
  }
}

class _DailyLimitDialog extends StatelessWidget {
  final LimitCheck check;

  const _DailyLimitDialog({required this.check});

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final isToday = DateUtils.isSameDay(check.day, DateTime.now());
    final dayLabel = isToday ? 'today' : DateFormat('MMMM d').format(check.day);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _redSoft,
              child: Icon(Icons.warning_amber_rounded, color: _red, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              'Daily limit exceeded',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'That purchase puts your spending for $dayLabel '
              '₱${check.overBy.toStringAsFixed(0)} over your daily limit.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _statBox('SPENT', '₱${check.dayTotal.toStringAsFixed(0)}', _red),
                const SizedBox(width: 10),
                _statBox('LIMIT', '₱${check.limit.toStringAsFixed(0)}', _dark),
              ],
            ),
            if (isToday) ...[
              const SizedBox(height: 14),
              Text(
                'Try to keep the rest of the day light 💪',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _muted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}