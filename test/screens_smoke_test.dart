// Renders every screen against a real, empty database so a layout overflow or a
// provider crash fails a test instead of waiting to be noticed by hand on a
// device.
//
// This exists because nothing in this app had ever executed. `flutter analyze`
// cannot see an overflow, and a real provider talking to a real database is a
// different code path from anything the unit tests cover.
//
// Data-backed screens live in screens_seeded_test.dart, which needs its own
// database and so its own process.
import 'package:flutter/material.dart';
import 'package:flutter_app_project/screens/budget_screen.dart';
import 'package:flutter_app_project/screens/history_screen.dart';
import 'package:flutter_app_project/screens/home_screen.dart';
import 'package:flutter_app_project/screens/onboarding_screen.dart';
import 'package:flutter_app_project/screens/recurring_expenses_screen.dart';
import 'package:flutter_app_project/screens/setting_screen.dart';
import 'package:flutter_app_project/screens/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screens_test_harness.dart';

void main() {
  setUpAll(() {
    loadRealFonts();
    useIsolatedTestDatabase();
  });

  tearDownAll(disposeTestDatabase);

  testWidgets('the real font is actually in effect', (tester) async {
    await verifyRealFontIsInEffect(tester);
  });

  final screens = <String, Widget>{
    'Onboarding': const OnboardingScreen(),
    'Home': const HomeScreen(),
    'History': const HistoryScreen(),
    'Stats': const StatsScreen(),
    'Budget': const BudgetScreen(),
    'Settings': const SettingsScreen(),
    'Recurring': const RecurringExpensesScreen(),
  };

  screens.forEach((name, screen) {
    testWidgets('$name renders with an empty database', (tester) async {
      await showScreen(tester, screen);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the new tip cards are actually on the screens', (tester) async {
    await showScreen(tester, const HomeScreen());
    expect(find.text('SAVING TIPS'), findsOneWidget);
    expect(find.text('TIP OF THE DAY'), findsOneWidget);

    await showScreen(tester, const BudgetScreen());
    expect(find.text('CAMPUS BUDGET TIPS'), findsOneWidget);
  });

  testWidgets('History says "never logged" when there is nothing to show', (
    tester,
  ) async {
    await showScreen(tester, const HistoryScreen());
    expect(find.text('No entries yet'), findsOneWidget);
  });

  testWidgets('Stats shows the whole-screen empty state for an empty period', (
    tester,
  ) async {
    await showScreen(tester, const StatsScreen());
    expect(find.byIcon(Icons.query_stats), findsOneWidget);
    expect(find.textContaining('No data for'), findsOneWidget);
  });
}
