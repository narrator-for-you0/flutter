// Shared setup for the screen tests.
//
// Two problems this solves, both of which quietly produce wrong results
// rather than obvious failures:
//
//  1. Flutter's test environment draws every glyph as a full-width box. Real
//     Roboto is roughly half as wide, so ordinary Rows report overflows that
//     no device would ever show. Loading the actual font is what makes an
//     overflow assertion mean something.
//
//  2. `DatabaseHelper` opens a hardcoded 'expenses.db' through sqflite's global
//     factory, and the FFI factory pins that path to <cwd>/.dart_tool. Without
//     redirecting it, tests read and write the developer's real database, and
//     concurrently running test files trample each other.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_app_project/providers/expense_provider.dart';
import 'package:flutter_app_project/providers/theme_providers.dart';
import 'package:flutter_app_project/providers/user_proverder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A small phone, where overflows are most likely. A phone-sized surface also
/// gives an overflow its own line of output instead of scrolling away.
const Size kPhoneSize = Size(390, 844);

/// Roboto, the font Android actually uses for this app, straight from the
/// Flutter SDK's cache so no binary needs committing.
const List<String> _fontPaths = [
  r'C:\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf',
  r'C:\flutter\bin\cache\artifacts\material_fonts\roboto-bold.ttf',
  r'C:\flutter\bin\cache\artifacts\material_fonts\roboto-medium.ttf',
];

Future<void> loadRealFonts() async {
  final loader = FontLoader('Roboto');
  var loaded = 0;
  for (final path in _fontPaths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    loaded++;
  }
  if (loaded == 0) {
    // Better to be loud than to quietly report phantom overflows forever.
    fail(
      'Could not load Roboto from the Flutter SDK at any of:\n$_fontPaths\n'
      'Without a real font every glyph is a full-width box, so every overflow '
      'assertion in these tests is meaningless.',
    );
  }
  await loader.load();
}

/// Points sqflite at a private, empty database for this test process, and
/// deletes it afterwards. Call from `setUpAll`; returns nothing so the
/// directory can be torn down by the companion [disposeTestDatabase].
void useIsolatedTestDatabase() {
  sqfliteFfiInit();
  final dir = Directory.systemTemp.createTempSync('food_allowance_screens');
  final ffi = databaseFactoryFfi;
  // `setDatabasesPathOrNull` lives on sqflite_common's private factory impl,
  // which isn't nameable from outside that package and isn't on the public
  // DatabaseFactory interface either, so this one call goes dynamic. The
  // `databaseFactory` setter only accepts a SqfliteDatabaseFactory, which
  // rules out the sandbox wrapper.
  (ffi as dynamic).setDatabasesPathOrNull(dir.path);
  databaseFactory = ffi;
  _isolatedDbDir = dir;
}

Directory? _isolatedDbDir;

/// Removes the directory created by [useIsolatedTestDatabase]. Call from
/// `tearDownAll`.
///
/// Best effort: `DatabaseHelper` exposes no way to close its connection, so
/// Windows still holds the file open here and deletion can fail. Cleanup is
/// never worth failing a test over — the directory is under the system temp
/// path.
void disposeTestDatabase() {
  final dir = _isolatedDbDir;
  _isolatedDbDir = null;
  try {
    if (dir != null && dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  } on FileSystemException {
    // Left for the OS temp cleaner.
  }
}

/// Renders [child] inside the same provider stack `main.dart` uses.
///
/// Pass [expenses] to drive a screen with state you already loaded, rather
/// than letting the harness build its own. An injected provider is attached
/// with `.value`, so this harness will not dispose it — a `create:` provider is
/// owned by its provider and gets disposed with the tree, which would break the
/// next test that reuses the same instance.
Widget harness(Widget child, {ExpenseProvider? expenses}) {
  return MultiProvider(
    providers: [
      if (expenses != null)
        ChangeNotifierProvider<ExpenseProvider>.value(value: expenses)
      else
        ChangeNotifierProvider(create: (_) => ExpenseProvider()..init()),
      ChangeNotifierProvider(create: (_) => UserProfileProvider()..load()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
    ],
    child: MaterialApp(
      theme: ThemeData(useMaterial3: true),
      // `ThemeData(fontFamily:)` does not reach screens whose Text widgets
      // carry their own TextStyle, which is every screen in this app. Merging
      // above the Navigator does, and `verifyRealFontIsInEffect` keeps it
      // honest.
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Roboto'),
        child: child!,
      ),
      home: child,
    ),
  );
}

/// Pumps [screen] and lets provider I/O settle.
///
/// `pumpAndSettle` is not usable here: it would spin forever on the progress
/// indicators these screens show while loading. This drains a bounded number
/// of frames instead.
Future<void> showScreen(
  WidgetTester tester,
  Widget screen, {
  ExpenseProvider? expenses,
}) async {
  tester.view.physicalSize = kPhoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(harness(screen, expenses: expenses));
  await settleBriefly(tester, frames: 12);
}

/// Advances a few frames after an interaction, such as typing in a search box.
Future<void> settleBriefly(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Guards the guard.
///
/// Every overflow assertion in these tests is only meaningful if the real font
/// is actually in effect. Without this, a regression that dropped the
/// `DefaultTextStyle.merge` above would quietly reintroduce full-width box
/// glyphs and bury the file in phantom overflows.
Future<void> verifyRealFontIsInEffect(WidgetTester tester) async {
  await tester.pumpWidget(
    harness(
      const Center(
        child: Text(
          'Budget Management',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    ),
  );
  final width = tester.getSize(find.byType(Text).first).width;
  expect(
    width,
    lessThan(240),
    reason:
        '"Budget Management" measured ${width}px. Real Roboto is ~206px; '
        '~374px means box glyphs are being used, so overflow results are noise.',
  );
}
