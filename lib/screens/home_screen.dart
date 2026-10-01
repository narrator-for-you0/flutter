import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../data/tips.dart';
import '../models/expense_category.dart';
import '../models/income.dart';
import '../widgets/daily_limit_widgets.dart';
import '../widgets/tip_card.dart';
import '../providers/expense_provider.dart';
import '../providers/user_proverder.dart';
import 'manange_quick_modal.dart';
import 'setting_screen.dart';
import '../themes/app_colors.dart';
import '../utils/format.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onViewAll});

  /// Called by "View All →" (main.dart switches to the History tab).
  final VoidCallback? onViewAll;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _getGreeting(DateTime time) {
    final hour = time.hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getEmojiForExpense(Expense item) =>
      CategoryData.emojiFor(item.category);

  // Ask which payment method was used, then log the Quick Add expense with it
  void _showPaymentPicker(
    BuildContext context,
    String title,
    double amount,
    String category,
  ) {
    final methods = ['Cash', 'GCash', 'Card'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paid with?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$title • ${formatPeso(amount, decimals: 0)}',
                style: TextStyle(fontSize: 12, color: AppColors.faint),
              ),
              const SizedBox(height: 16),
              Row(
                children: methods.map((method) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final newExpense = Expense(
                          title: title,
                          amount: amount,
                          category: category,
                          date: DateTime.now(),
                          paymentMethod: method,
                        );

                        final provider = Provider.of<ExpenseProvider>(
                          context,
                          listen: false,
                        );
                        final messenger = ScaffoldMessenger.of(context);

                        // Close the picker, then log the expense
                        Navigator.pop(ctx);
                        final check = await provider.addExpense(newExpense);
                        if (!context.mounted) return;

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '$title added (+${formatPeso(amount, decimals: 0)} • $method)',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );

                        // Pop-up if this quick-add pushed today over the limit
                        await DailyLimitAlert.handle(context, check);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          method,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text2,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Edit Profile Dialog
  void _showEditProfileDialog(BuildContext context) {
    final profileProvider = Provider.of<UserProfileProvider>(
      context,
      listen: false,
    );
    final user = profileProvider.user;

    final nameController = TextEditingController(text: user.name);
    final infoController = TextEditingController(text: user.studentInfo);
    String selectedEmoji = user.avatarEmoji;

    // Photo shown in the dialog. Starts as the saved photo (if any); a newly
    // picked image is only copied into the app's storage when Save is tapped.
    String? photoPath = user.avatarImagePath;
    bool photoChanged = false;

    /// Opens a square crop screen. Returns the cropped file's path, or null
    /// if the user backed out. On platforms without a cropper (Windows /
    /// desktop testing) the image is returned uncropped.
    Future<String?> cropPhoto(String sourcePath) async {
      if (!(Platform.isAndroid || Platform.isIOS)) return sourcePath;
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: sourcePath,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          maxWidth: 512,
          maxHeight: 512,
          compressQuality: 85,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop photo',
              toolbarColor: const Color(0xFF00C853),
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: const Color(0xFF00C853),
              cropStyle: CropStyle.circle,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Crop photo',
              cropStyle: CropStyle.circle,
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              aspectRatioPickerButtonHidden: true,
            ),
          ],
        );
        return cropped?.path;
      } catch (e) {
        debugPrint('Could not crop image: $e');
        return null;
      }
    }

    Future<void> pickPhoto(StateSetter setModalState) async {
      try {
        // No maxWidth/maxHeight here: crop the full-size photo, and the
        // cropper shrinks the result to 512x512.
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (picked == null) return;
        final cropped = await cropPhoto(picked.path);
        if (cropped == null) return; // cancelled: keep the current photo
        setModalState(() {
          photoPath = cropped;
          photoChanged = true;
        });
      } catch (e) {
        debugPrint('Could not pick image: $e');
      }
    }

    Future<void> recropPhoto(StateSetter setModalState) async {
      final current = photoPath;
      if (current == null) return;
      final cropped = await cropPhoto(current);
      if (cropped == null) return;
      setModalState(() {
        photoPath = cropped;
        photoChanged = true;
      });
    }

    void showPhotoOptions(
      BuildContext sheetContext,
      StateSetter setModalState,
    ) {
      showModalBottomSheet(
        context: sheetContext,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (optionsCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF00C853),
                ),
                title: const Text('Choose photo'),
                onTap: () {
                  Navigator.pop(optionsCtx);
                  pickPhoto(setModalState);
                },
              ),
              if (photoPath != null && (Platform.isAndroid || Platform.isIOS))
                ListTile(
                  leading: const Icon(Icons.crop, color: Color(0xFF00C853)),
                  title: const Text('Adjust crop'),
                  onTap: () {
                    Navigator.pop(optionsCtx);
                    recropPhoto(setModalState);
                  },
                ),
              if (photoPath != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC2626),
                  ),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.pop(optionsCtx);
                    setModalState(() {
                      photoPath = null;
                      photoChanged = true;
                    });
                  },
                ),
            ],
          ),
        ),
      );
    }

    final List<String> avatarOptions = [
      '👨‍💻',
      '👩‍💻',
      '🎓',
      '📚',
      '⚡',
      '💻',
      '🎒',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: () => showPhotoOptions(ctx, setModalState),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.greenSoft,
                              backgroundImage: photoPath != null
                                  ? FileImage(File(photoPath!))
                                  : null,
                              child: photoPath == null
                                  ? Text(
                                      selectedEmoji,
                                      style: const TextStyle(fontSize: 34),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00C853),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Select Avatar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: avatarOptions.map((emoji) {
                        final isSelected =
                            photoPath == null && emoji == selectedEmoji;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedEmoji = emoji;
                              // choosing an emoji switches back from a photo
                              if (photoPath != null) {
                                photoPath = null;
                                photoChanged = true;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.greenSoft
                                  : AppColors.card,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF00C853)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: infoController,
                      decoration: InputDecoration(
                        labelText: 'Course / Info',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          final newInfo = infoController.text.trim();
                          final navigator = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(context);

                          profileProvider.updateProfile(
                            name: newName.isNotEmpty ? newName : user.name,
                            studentInfo: newInfo.isNotEmpty
                                ? newInfo
                                : user.studentInfo,
                            avatarEmoji: selectedEmoji,
                          );

                          var photoFailed = false;
                          if (photoChanged) {
                            if (photoPath == null) {
                              await profileProvider.removeAvatarPhoto();
                            } else {
                              photoFailed = !await profileProvider
                                  .setAvatarPhoto(photoPath!);
                            }
                          }

                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                photoFailed
                                    ? 'Profile saved, but the photo could not be saved.'
                                    : 'Profile updated successfully!',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Save Profile',
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Consumer2<ExpenseProvider, UserProfileProvider>(
      builder: (context, expenseProvider, userProvider, child) {
        final expenses = expenseProvider.expenses;
        final user = userProvider.user;

        final totalSpent = expenseProvider.totalSpent;
        final monthlyBudget = expenseProvider.monthlyBudget;
        final remaining = monthlyBudget - totalSpent;
        final budgetPercentage = monthlyBudget > 0
            ? (totalSpent / monthlyBudget)
            : 0.0;
        final percentageInt = (budgetPercentage * 100).toInt();
        final budgetCardTitle = switch (expenseProvider.cycleType) {
          AllowanceCycleType.monthly => 'Monthly Budget',
          AllowanceCycleType.weekly => 'Weekly Budget',
          AllowanceCycleType.biweekly => 'Biweekly Budget',
        };

        final now = DateTime.now();
        final todayExpenses = expenses.where((item) {
          return item.date.year == now.year &&
              item.date.month == now.month &&
              item.date.day == now.day;
        }).toList();

        final todayTotal = todayExpenses
            .where((item) => !item.fromSavings)
            .fold(0.0, (sum, item) => sum + item.amount);

        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayExpenses = expenses.where((item) {
          return item.date.year == yesterday.year &&
              item.date.month == yesterday.month &&
              item.date.day == yesterday.day;
        }).toList();

        final yesterdayTotal = yesterdayExpenses
            .where((item) => !item.fromSavings)
            .fold(0.0, (sum, item) => sum + item.amount);
        final diffFromYesterday = todayTotal - yesterdayTotal;

        // Safe-to-spend hero + balance line (Round 7)
        final safeToday = expenseProvider.dailyLimitFor(now) - todayTotal;
        final balance = expenseProvider.currentBalance;

        String? cycleCountdownText;
        if (expenseProvider.cycleType != AllowanceCycleType.monthly) {
          final today = DateTime(now.year, now.month, now.day);
          final nextPeriodStart = expenseProvider
              .currentCycleEnd(now)
              .add(const Duration(days: 1));
          final daysUntilNext = nextPeriodStart.difference(today).inDays;
          cycleCountdownText = daysUntilNext <= 1
              ? 'New allowance period starts tomorrow'
              : '$daysUntilNext days until your next allowance period';
        }

        // Today's activity: expenses + income, newest first (Round 7)
        final todayIncome = expenseProvider.getIncomeOn(now);
        final todayActivity = <dynamic>[...todayExpenses, ...todayIncome]
          ..sort((a, b) {
            final dateA = a is Expense ? a.date : (a as Income).date;
            final dateB = b is Expense ? b.date : (b as Income).date;
            return dateB.compareTo(dateA);
          });

        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Section with Dynamic User Data & Profile Action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('MMMM d, yyyy').format(now),
                              style: TextStyle(
                                color: AppColors.greyText,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    '${_getGreeting(now)}, ${user.name}!',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '👋',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                            Text(
                              user.studentInfo,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                        icon: Icon(
                          Icons.settings_outlined,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _showEditProfileDialog(context),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.greenSoft,
                          backgroundImage: user.avatarImagePath != null
                              ? FileImage(File(user.avatarImagePath!))
                              : null,
                          child: user.avatarImagePath == null
                              ? Text(
                                  user.avatarEmoji,
                                  style: const TextStyle(fontSize: 20),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Safe-to-spend today + balance + cycle countdown
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: safeToday < 0
                          ? AppColors.redSoft
                          : AppColors.greenFaint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: safeToday < 0
                            ? AppColors.redBorder
                            : AppColors.greenSoft,
                      ),
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
                                  Icons.bolt,
                                  size: 15,
                                  color: safeToday < 0
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF00C853),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'SAFE TO SPEND TODAY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.muted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Balance: ${formatPeso(balance, decimals: 0)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          safeToday < 0
                              ? '${formatPeso(safeToday.abs(), decimals: 0)} over'
                              : formatPeso(safeToday, decimals: 0),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: safeToday < 0
                                ? const Color(0xFFDC2626)
                                : AppColors.text,
                          ),
                        ),
                        if (cycleCountdownText != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            cycleCountdownText,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Today's Spending Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C853)
                              .withValues(alpha: 0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Today's Spending",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${todayExpenses.length} items',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatPeso(todayTotal, decimals: 2),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    diffFromYesterday >= 0
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    diffFromYesterday >= 0
                                        ? '${formatPeso(diffFromYesterday, decimals: 0)} more than yesterday'
                                        : '${formatPeso(diffFromYesterday.abs(), decimals: 0)} less than yesterday',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '(Yesterday: ${formatPeso(yesterdayTotal, decimals: 0)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Today vs. daily limit
                  DailyLimitCard(
                    spent: todayTotal,
                    limit: expenseProvider.dailyLimit,
                  ),
                  const SizedBox(height: 24),

                  // 3. Quick Add Horizontal Bar with Customize Option
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✨ QUICK ADD',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.muted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ManageQuickAddModal.show(context),
                        child: const Text(
                          '+ Customize',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00C853),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        ...expenseProvider.quickAddItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: _buildQuickAddChip(
                              context,
                              item.emoji,
                              item.title,
                              item.amount,
                              item.category,
                              item.id,
                            ),
                          );
                        }),
                        InkWell(
                          onTap: () => ManageQuickAddModal.show(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.greenBorder),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 14,
                                  color: AppColors.greenDark,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Add Custom',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.greenDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Today's Expenses Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Today's Expenses",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${todayExpenses.length}',
                              style: const TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: widget.onViewAll,
                        child: const Text(
                          'View All →',
                          style: TextStyle(
                            color: Color(0xFF00C853),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (todayActivity.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      child: Text(
                        'No expenses added today.',
                        style: TextStyle(
                          color: AppColors.greyText,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    ...todayActivity.map((item) {
                      if (item is Expense) return _buildExpenseCard(item);
                      return _buildIncomeChip(item as Income);
                    }),

                  const SizedBox(height: 16),

                  // 5. Budget Overview Card (current cycle: monthly / weekly / biweekly)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 16,
                                  color: Color(0xFF00C853),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  budgetCardTitle,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.text2,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$percentageInt%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.text2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: budgetPercentage.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: AppColors.track,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              budgetPercentage > 0.9
                                  ? Colors.redAccent
                                  : const Color(0xFF00C853),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SPENT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.greyText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formatPeso(totalSpent, decimals: 0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'LEFT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.greyText,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  formatPeso(remaining, decimals: 0),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: remaining < 0
                                        ? Colors.redAccent
                                        : const Color(0xFF00C853),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Saving Tips Card (one tip per day; urgent advice when the budget is tight)
                  TipCard(
                    heading: 'SAVING TIPS',
                    emoji: '💰',
                    tips: savingTips,
                    urgentTips: savingUrgentTips,
                    isUrgent: isBudgetUrgent(
                      spent: totalSpent,
                      budget: monthlyBudget,
                    ),
                    background: AppColors.greenFaint,
                    borderColor: AppColors.greenSoft,
                    headingColor: AppColors.greenDark,
                    bodyColor: AppColors.greenDeep,
                    accent: const Color(0xFF22C55E),
                    offset: 0,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAddChip(
    BuildContext context,
    String emoji,
    String title,
    double amount,
    String category, // 1. Added category parameter
    String id,
  ) {
    return InkWell(
      onTap: () => _showPaymentPicker(context, title, amount, category),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove Shortcut?'),
            content: Text('Do you want to remove "$title" from Quick Add?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Provider.of<ExpenseProvider>(
                    context,
                    listen: false,
                  ).removeQuickAddItem(id);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"$title" removed from Quick Add')),
                  );
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.text2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.greenSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                formatPeso(amount, decimals: 0),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.greenDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeChip(Income income) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greenBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.add_card, size: 16, color: AppColors.greenDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  income.note.isEmpty ? 'Income received' : income.note,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.greenDeep,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('h:mm a').format(income.date),
                  style: TextStyle(fontSize: 11, color: AppColors.greenDark),
                ),
              ],
            ),
          ),
          Text(
            '+${formatPeso(income.amount, decimals: 2)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.greenDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(Expense item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getEmojiForExpense(item),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('h:mm a').format(item.date)} • ${item.paymentMethod}'
                  '${item.fromSavings ? ' • From savings' : ''}',
                  style: TextStyle(fontSize: 11, color: AppColors.greyText),
                ),
              ],
            ),
          ),
          Text(
            formatPeso(item.amount, decimals: 2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
