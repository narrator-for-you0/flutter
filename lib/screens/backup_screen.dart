import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/expense_provider.dart';
import '../providers/theme_providers.dart';
import '../providers/user_proverder.dart';
import '../services/backup_service.dart';
import '../themes/app_colors.dart';

/// Backup and restore (Phase 5).
///
/// Export writes one JSON file and hands it to the OS share sheet, so it can
/// land in Drive, Drive's backup folder, email, wherever. Import picks a file
/// back and merges it in — see [ExpenseProvider.importBackup] for what "merge"
/// means (nothing is deleted, matches are skipped).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  static const _green = Color(0xFF00C853);

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final provider = context.watch<ExpenseProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          'Backup & restore',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: _green),
                    const SizedBox(width: 8),
                    Text(
                      'Your data stays on this phone',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Nothing is uploaded anywhere. A backup is a file you choose '
                  'where to send it, so if you lose or reset this phone you can '
                  'put everything back.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _stat(
                  'Expenses',
                  '${provider.expenses.length}',
                  Icons.receipt_long_outlined,
                ),
                _divider(),
                _stat(
                  'Income entries',
                  '${provider.income.length}',
                  Icons.savings_outlined,
                ),
                _divider(),
                _stat(
                  'Recurring expenses',
                  '${provider.recurringExpenses.length}',
                  Icons.repeat,
                ),
                _divider(),
                _stat('Budgets & limits', 'Included', Icons.pie_chart_outline),
                const SizedBox(height: 10),
                Text(
                  'Profile photo is not part of the backup — it\'s an image '
                  'file, not part of the data.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.faint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Builder(
            builder: (buttonContext) => _actionButton(
              icon: Icons.ios_share,
              label: 'Export backup',
              color: _green,
              onPressed: _busy ? null : () => _export(buttonContext),
            ),
          ),
          const SizedBox(height: 10),
          _actionButton(
            icon: Icons.file_open_outlined,
            label: 'Import backup',
            color: AppColors.blue,
            onPressed: _busy ? null : _import,
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Exports are also saved inside the app\n(they stay after you share them)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.faint),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _export(BuildContext anchor) async {
    final provider = context.read<ExpenseProvider>();
    final user = context.read<UserProfileProvider>();
    final theme = context.read<ThemeProvider>();

    // iPad anchors the share popover to the tapped button; harmless
    // everywhere else (and required on iPad). Taken before the first await.
    final box = anchor.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final json = BackupService.encode(
        exportedAt: now,
        settings: provider.exportSettings(),
        expenses: provider.expenses,
        income: provider.income,
        recurring: provider.recurringExpenses,
        profile: user.exportProfile(),
        themeMode: theme.mode.name,
      );

      final file = await BackupService.writeToDocuments(json, now);
      if (!mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          fileNameOverrides: [BackupService.fileNameFor(now)],
          subject: 'Food allowance tracker backup',
          sharePositionOrigin: origin,
        ),
      );
    } catch (e) {
      _toast('Could not export: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<void> _import() async {
    PlatformFile? picked;
    try {
      picked = await FilePicker.pickFile(
        dialogTitle: 'Choose a backup file',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (e) {
      _toast('Could not open the file picker: $e');
      return;
    }
    if (picked == null) return; // they cancelled

    final String text;
    try {
      text = utf8.decode(await picked.readAsBytes());
    } catch (e) {
      debugPrint('Could not read ${picked.name}: $e');
      _toast('Could not read ${picked.name}.');
      return;
    }

    final BackupFile backup;
    try {
      backup = BackupService.decode(text);
    } on BackupFormatException catch (e) {
      _toast(e.message);
      return;
    }

    if (backup.totalRows == 0) {
      _toast('That backup has no records in it.');
      return;
    }
    if (!mounted) return;

    final includeSettings = await showDialog<bool>(
      context: context,
      builder: (_) => _ImportConfirmDialog(backup: backup),
    );
    if (includeSettings == null || !mounted) return;

    // Grabbed before the import's awaits so the async gaps below don't read
    // a BuildContext.
    final expenseProvider = context.read<ExpenseProvider>();
    final userProvider = context.read<UserProfileProvider>();
    final themeProvider = context.read<ThemeProvider>();

    setState(() => _busy = true);
    BackupImportSummary? summary;
    var profileRestored = false;
    var themeRestored = false;
    try {
      summary = await expenseProvider.importBackup(
        backup,
        includeSettings: includeSettings,
      );

      // Profile and theme only travel with the "restore settings" opt-in:
      // they're personal preferences, not records.
      if (includeSettings && backup.profile != null) {
        profileRestored = userProvider.applyImportedProfile(backup.profile!);
      }
      if (includeSettings) {
        final mode = switch (backup.themeMode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          'system' => ThemeMode.system,
          _ => null,
        };
        if (mode != null) {
          await themeProvider.setMode(mode);
          themeRestored = true;
        }
      }
    } catch (e) {
      _toast('Could not import: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (summary != null && mounted) {
      await _showSummary(summary, profileRestored, themeRestored);
    }
  }

  Future<void> _showSummary(
    BackupImportSummary s,
    bool profileRestored,
    bool themeRestored,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          s.rowsAdded == 0 ? 'Nothing new to add' : 'Backup imported',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.rowsAdded > 0)
              Text(
                'Added ${s.rowsAdded} '
                '${s.rowsAdded == 1 ? "record" : "records"}.',
                style: TextStyle(fontSize: 13.5, color: AppColors.text2),
              ),
            if (s.rowsSkipped > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Skipped ${s.rowsSkipped} you already had.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ),
            if (s.settingsApplied)
              _resultLine(Icons.pie_chart_outline, 'Budgets & limits restored'),
            if (profileRestored)
              _resultLine(Icons.person_outline, 'Profile restored'),
            if (themeRestored)
              _resultLine(Icons.dark_mode_outlined, 'Theme restored'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done', style: TextStyle(color: _green)),
          ),
        ],
      ),
    );
  }

  Widget _resultLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: AppColors.text2),
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Small builders
  // ---------------------------------------------------------------------------

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _divider() => Divider(height: 1, color: AppColors.border);

  Widget _stat(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13.5, color: AppColors.text2),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 19, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

/// "Here's what's in the file — do you want it?" Confirmation before an
/// import, with the one real decision it can't make on its own: whether to
/// replace the budgets/limits you've got now.
class _ImportConfirmDialog extends StatefulWidget {
  const _ImportConfirmDialog({required this.backup});

  final BackupFile backup;

  @override
  State<_ImportConfirmDialog> createState() => _ImportConfirmDialogState();
}

class _ImportConfirmDialogState extends State<_ImportConfirmDialog> {
  static const _green = Color(0xFF00C853);

  bool _includeSettings = true;

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final backup = widget.backup;
    final when = backup.exportedAt;
    final hasExtras = backup.hasSettings || backup.profile != null;

    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Import this backup?',
        style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (when != null) ...[
            Text(
              'Taken ${DateFormat('MMM d, yyyy • h:mm a').format(when)}',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
          ],
          _count(
            Icons.receipt_long_outlined,
            'Expenses',
            backup.expenses.length,
          ),
          _count(
            Icons.savings_outlined,
            'Income entries',
            backup.income.length,
          ),
          _count(Icons.repeat, 'Recurring', backup.recurring.length),
          const SizedBox(height: 14),
          Text(
            'Anything you already have that matches will be skipped, so it\'s '
            'safe to import the same file twice. Nothing gets deleted.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.muted,
            ),
          ),
          if (hasExtras) ...[
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _includeSettings,
              onChanged: (v) => setState(() => _includeSettings = v ?? true),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: _green,
              title: Text(
                "Also replace my budgets, limits and profile",
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text2,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_includeSettings),
          child: const Text('Import', style: TextStyle(color: _green)),
        ),
      ],
    );
  }

  Widget _count(IconData icon, String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.text2),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
