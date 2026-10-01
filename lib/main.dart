import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/expense_provider.dart';
import 'providers/theme_providers.dart';
import 'providers/user_proverder.dart';
import 'screens/add_expense_modal.dart';
import 'screens/budget_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/stats_screen.dart';
import 'widgets/daily_limit_widgets.dart';
import 'themes/app_colors.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows/Linux have no built-in sqflite engine; use the FFI one there so
  // data is really saved. (Android/iOS keep using regular sqflite.)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

/// Lets mouse / trackpad / stylus drag-scroll like a finger does.
/// (Phones already scroll by touch; this makes Windows/desktop testing behave the same.)
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.trackpad,
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // init() loads saved settings (budgets, daily limit, quick add) + expenses
        ChangeNotifierProvider(create: (_) => ExpenseProvider()..init()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Food Allowance Tracker',
            debugShowCheckedModeBanner: false,
            scrollBehavior: AppScrollBehavior(),
            theme: ThemeProvider.light,
            darkTheme: ThemeProvider.dark,
            themeMode: themeProvider.mode,
            home: const AppGate(),
          );
        },
      ),
    );
  }
}

/// Decides what to show at launch: a splash while the saved profile loads,
/// onboarding on the very first run, otherwise the main app.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    final profile = context.watch<UserProfileProvider>();
    final theme = context.watch<ThemeProvider>();

    final Widget child;
    if (!profile.isLoaded || !theme.isLoaded) {
      child = const _SplashScreen(key: ValueKey('splash'));
    } else if (!profile.hasOnboarded) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else {
      child = const MainNavigationScreen(key: ValueKey('main'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: child,
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: CircularProgressIndicator(color: Color(0xFF00C853))),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _selectedIndex = 0; // default to the first screen (HomeScreen)

  late final List<Widget> _screens = [
    HomeScreen(onViewAll: () => setState(() => _selectedIndex = 1)),
    const HistoryScreen(),
    const StatsScreen(),
    const BudgetScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back to the app (maybe the next day): log due recurring expenses
  // and check whether a budget period just ended.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ExpenseProvider>().onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppColors.sync(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Shows only if you open the app already over today's limit
            const DailyLimitBanner(),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: _screens),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddExpenseModal.show(context),
        backgroundColor: const Color(0xFF00C853),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.bg,
        selectedItemColor: const Color(0xFF00C853),
        unselectedItemColor: AppColors.greyText,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Budget',
          ),
        ],
      ),
    );
  }
}
