import 'package:flutter/material.dart';
import 'package:flutter_app_project/data/tips.dart';
import 'package:flutter_app_project/widgets/tip_card.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the card's RichText actually renders: lead-in, colon, then body.
/// `find.text(..., findRichText: true)` compares the whole plain-text run, not
/// individual spans, so this is what has to be matched.
String plain(Tip tip) => '${tip.title}: ${tip.body}';

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Widget card({
  required DateTime now,
  bool isUrgent = false,
  int offset = 0,
  List<Tip> tips = savingTips,
  List<Tip> urgentTips = savingUrgentTips,
}) {
  return TipCard(
    heading: 'SAVING TIPS',
    emoji: '\u{1F4B0}',
    tips: tips,
    urgentTips: urgentTips,
    isUrgent: isUrgent,
    background: Colors.white,
    borderColor: Colors.grey,
    headingColor: Colors.black,
    offset: offset,
    now: now,
  );
}

Tip tipOn(DateTime now, {bool isUrgent = false, int offset = 0}) {
  return pickTip(
    pool: savingTips,
    urgent: savingUrgentTips,
    now: now,
    isUrgent: isUrgent,
    offset: offset,
  );
}

void main() {
  final day = DateTime(2026, 10, 2);

  testWidgets('shows the heading and the tip for that day', (tester) async {
    await tester.pumpWidget(wrap(card(now: day)));

    expect(find.text('SAVING TIPS'), findsOneWidget);
    expect(find.text(plain(tipOn(day)), findRichText: true), findsOneWidget);
    expect(find.text('TIP OF THE DAY'), findsOneWidget);
  });

  testWidgets('shows a different tip the next day', (tester) async {
    final today = tipOn(day);
    final tomorrow = tipOn(day.add(const Duration(days: 1)));
    expect(today.title, isNot(tomorrow.title));

    await tester.pumpWidget(wrap(card(now: day)));
    expect(find.text(plain(today), findRichText: true), findsOneWidget);

    await tester.pumpWidget(wrap(card(now: day.add(const Duration(days: 1)))));
    expect(find.text(plain(tomorrow), findRichText: true), findsOneWidget);
    expect(find.text(plain(today), findRichText: true), findsNothing);
  });

  testWidgets('swaps to urgent copy and relabels the badge', (tester) async {
    await tester.pumpWidget(wrap(card(now: day, isUrgent: true)));

    expect(
      find.text(plain(tipOn(day, isUrgent: true)), findRichText: true),
      findsOneWidget,
    );
    expect(find.text('HEADS UP'), findsOneWidget);
    expect(find.text('TIP OF THE DAY'), findsNothing);
  });

  testWidgets(
    'stays on the normal tip when urgent is set with no urgent pool',
    (tester) async {
      await tester.pumpWidget(
        wrap(card(now: day, isUrgent: true, urgentTips: const [])),
      );
      expect(find.text('TIP OF THE DAY'), findsOneWidget);
    },
  );

  testWidgets('offset moves the card to a different tip on the same day', (
    tester,
  ) async {
    expect(tipOn(day, offset: 5).title, isNot(tipOn(day).title));

    await tester.pumpWidget(wrap(card(now: day, offset: 5)));
    expect(
      find.text(plain(tipOn(day, offset: 5)), findRichText: true),
      findsOneWidget,
    );
  });

  // The header is emoji + heading + badge in a Wrap. That only works because a
  // Row there overflowed; pumping at 280dp (well under any real phone) fails
  // the test automatically if the header ever goes back to a single row.
  group('fits a narrow phone', () {
    Future<void> pumpAt(WidgetTester tester, double width, Widget child) async {
      tester.view.physicalSize = Size(width, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(child));
    }

    Widget anyCard({
      required String heading,
      required String emoji,
      required List<Tip> tips,
      required List<Tip> urgentTips,
      required bool isUrgent,
      int offset = 0,
    }) {
      return TipCard(
        heading: heading,
        emoji: emoji,
        tips: tips,
        urgentTips: urgentTips,
        isUrgent: isUrgent,
        background: Colors.white,
        borderColor: Colors.grey,
        headingColor: Colors.black,
        offset: offset,
        now: day,
      );
    }

    testWidgets('saving tips card', (tester) async {
      await pumpAt(
        tester,
        280,
        anyCard(
          heading: 'SAVING TIPS',
          emoji: '\u{1F4B0}',
          tips: savingTips,
          urgentTips: savingUrgentTips,
          isUrgent: true,
        ),
      );
      expect(find.text('SAVING TIPS'), findsOneWidget);
    });

    testWidgets('campus tips card, the longer heading, both states', (
      tester,
    ) async {
      for (final urgent in [false, true]) {
        await pumpAt(
          tester,
          280,
          anyCard(
            heading: 'CAMPUS BUDGET TIPS',
            emoji: '\u{1F9E1}',
            tips: campusTips,
            urgentTips: campusUrgentTips,
            isUrgent: urgent,
            offset: 5,
          ),
        );
        expect(find.text('CAMPUS BUDGET TIPS'), findsOneWidget);
      }
    });
  });
}
