// Renders the screens that only say something interesting once there is data,
// against a real database seeded through the real provider.
//
// Seeding happens in `setUpAll`, not inside the test body on purpose: a
// `testWidgets` body runs in a fake-async zone where sqflite's isolate-backed
// FFI calls never complete, so awaiting a write there hangs until the test
// times out. `setUpAll` runs in the normal async zone and is fine.
//
// This is a separate file from screens_smoke_test.dart because each test file
// gets its own process and therefore its own isolated database.
import 'package:flutter/material.dart';
import 'package:flutter_app_project/models/expense.dart';
import 'package:flutter_app_project/models/income.dart';
import 'package:flutter_app_project/providers/expense_provider.dart';
import 'package:flutter_app_project/screens/budget_screen.dart';
import 'package:flutter_app_project/screens/history_screen.dart';
import 'package:flutter_app_project/screens/home_screen.dart';
import 'package:flutter_app_project/screens/stats_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/screens_test_harness.dart';

void main() {
  late ExpenseProvider provider;

  setUpAll(() async {
    loadRealFonts();
    useIsolatedTestDatabase();

    provider = ExpenseProvider();
    await provider.init();

    // All dated today on purpose. Stats defaults to a "This Week" filter, so a
    // relative date like "two days ago" can fall outside whatever period the
    // app considers current and quietly change the totals these tests assert.
    final now = DateTime.now();
    for (final entry in [
      (title: 'Chicken adobo', amount: 85.0, category: 'Lunch'),
      (title: 'Jeepney fare', amount: 50.0, category: 'Jeepney'),
      (title: 'Cafe latte', amount: 120.0, category: 'Snacks'),
    ]) {
      await provider.addExpense(
        Expense(
          title: entry.title,
          amount: entry.amount,
          category: entry.category,
          date: now,
        ),
      );
    }
    await provider.addIncome(
      Income(amount: 3000, note: 'Allowance from Mom', date: now),
    );
  });

  tearDownAll(disposeTestDatabase);

  testWidgets('the real font is actually in effect', (tester) async {
    await verifyRealFontIsInEffect(tester);
  });

  testWidgets('History lists what was actually saved', (tester) async {
    await showScreen(tester, const HistoryScreen(), expenses: provider);

    expect(find.text('Chicken adobo'), findsOneWidget);
    expect(find.text('Jeepney fare'), findsOneWidget);
    expect(find.text('Cafe latte'), findsOneWidget);
    expect(find.text('No entries yet'), findsNothing);
  });

  testWidgets('History separates "filtered out" from "never logged"', (
    tester,
  ) async {
    await showScreen(tester, const HistoryScreen(), expenses: provider);
    expect(find.text('Chicken adobo'), findsOneWidget);

    // A search that matches nothing is a different situation from an empty
    // database, and gets a different message plus a way back.
    await tester.enterText(find.byType(TextField).first, 'zzzznope');
    await settleBriefly(tester);

    expect(find.text('Nothing matches'), findsOneWidget);
    expect(find.text('Clear search & filters'), findsOneWidget);
    expect(find.text('No entries yet'), findsNothing);

    // And the offered action genuinely clears the search.
    await tester.tap(find.text('Clear search & filters'));
    await settleBriefly(tester);
    expect(find.text('Chicken adobo'), findsOneWidget);
  });

  testWidgets('Stats shows real figures instead of its empty state', (
    tester,
  ) async {
    await showScreen(tester, const StatsScreen(), expenses: provider);

    expect(find.byIcon(Icons.query_stats), findsNothing);
    expect(find.textContaining('No data for'), findsNothing);
    // 85 + 50 + 120, and all three logged today.
    expect(find.textContaining('255'), findsWidgets);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('Budget and Home render against real numbers', (tester) async {
    await showScreen(tester, const BudgetScreen(), expenses: provider);
    expect(tester.takeException(), isNull);

    await showScreen(tester, const HomeScreen(), expenses: provider);
    expect(tester.takeException(), isNull);
  });
}
