import 'package:flutter/material.dart';
import 'package:flutter_app_project/widgets/empty_state.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('shows the icon, title, and message', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No entries yet',
          message: 'Log something and it shows up here.',
        ),
      ),
    );

    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.text('Log something and it shows up here.'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('fires the action and hides it without a callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      wrap(
        EmptyState(
          icon: Icons.search_off,
          title: 'Nothing matches',
          actionLabel: 'Clear search & filters',
          onAction: () => taps++,
        ),
      ),
    );

    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.text('Clear search & filters'));
    expect(taps, 1);

    // A label with no handler would render a dead button, so it must not show.
    await tester.pumpWidget(
      wrap(const EmptyState(icon: Icons.search_off, title: 'Nothing matches')),
    );
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('compact drops the badge and the message', (tester) async {
    await tester.pumpWidget(
      wrap(
        const EmptyState(
          icon: Icons.bar_chart_outlined,
          title: 'Nothing here for this period',
          message: 'Should not be visible in compact mode.',
          compact: true,
        ),
      ),
    );

    expect(find.text('Nothing here for this period'), findsOneWidget);
    expect(find.text('Should not be visible in compact mode.'), findsNothing);
  });
}
