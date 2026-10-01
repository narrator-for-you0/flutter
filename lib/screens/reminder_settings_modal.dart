import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../themes/app_colors.dart';

/// Bottom sheet to switch the end-of-day spending reminder on/off and pick
/// what time it goes off.
class ReminderSettingsModal extends StatefulWidget {
  const ReminderSettingsModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReminderSettingsModal(),
    );
  }

  @override
  State<ReminderSettingsModal> createState() => _ReminderSettingsModalState();
}

class _ReminderSettingsModalState extends State<ReminderSettingsModal> {
  static const _green = Color(0xFF00C853);
  static Color get _dark => AppColors.text;
  static Color get _muted => AppColors.muted;

  bool _permissionDenied = false;

  Future<void> _toggle(ExpenseProvider provider, bool value) async {
    final ok = await provider.setReminder(enabled: value);
    if (!mounted) return;
    setState(() => _permissionDenied = value && !ok);
  }

  Future<void> _pickTime(ExpenseProvider provider) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: provider.reminderTime,
    );
    if (picked != null) {
      await provider.setReminder(
        enabled: provider.reminderEnabled,
        time: picked,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final provider = context.watch<ExpenseProvider>();
    final enabled = provider.reminderEnabled;
    final timeText = provider.reminderTime.format(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: _green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily reminder',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _dark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Get nudged if you forgot to log today's spending",
                        style: TextStyle(fontSize: 12, color: _muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.close, color: _muted, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Remind me each evening',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _dark,
                      ),
                    ),
                  ),
                  Switch(
                    value: enabled,
                    activeThumbColor: _green,
                    onChanged: (v) => _toggle(provider, v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Opacity(
              opacity: enabled ? 1 : 0.5,
              child: GestureDetector(
                onTap: enabled ? () => _pickTime(provider) : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 18, color: _muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Reminder time',
                          style: TextStyle(fontSize: 14, color: _dark),
                        ),
                      ),
                      Text(
                        timeText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_permissionDenied)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Notifications are blocked for this app. Allow them in your device settings, then turn this on again.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                    height: 1.4,
                  ),
                ),
              ),
            Text(
              "Only sent on days you haven't logged an expense. Adding one cancels that day's reminder.",
              style: TextStyle(fontSize: 11, color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
