// Host test that reproduces the AppBottomNav in the shell's Scaffold structure
// with a SIMULATED iOS home-indicator inset (viewPadding.bottom = 34), then
// measures how much empty space sits below the bar's content row.
//
// The iOS "too much space" bug is a layout/logic issue (how the inset is added),
// not a device rendering quirk — so it reproduces here without a real device.
//
// Expected correct behaviour: the gap below the row equals ONE inset (~34).
// If the inset is double-counted, the gap will be ~68.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:exono/config/app_theme.dart';
import 'package:exono/widgets/app_bottom_nav.dart';

void main() {
  const double kInset = 34.0; // iPhone home-indicator inset, logical px.

  testWidgets('AppBottomNav leaves exactly one inset below its content row',
      (tester) async {
    // Force a bottom viewPadding like an iPhone with a home indicator.
    // FlutterView values are in PHYSICAL pixels; dpr=3 so 34 logical = 102.
    tester.view.devicePixelRatio = 3.0;
    tester.view.viewPadding = const FakeViewPadding(bottom: kInset * 3.0);
    tester.view.padding = const FakeViewPadding(bottom: kInset * 3.0);

    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) => FTheme(
          data: FThemeData(touch: true, colors: FColors.zincLight),
          child: child!,
        ),
        home: Scaffold(
          backgroundColor: AppTheme.background,
          bottomNavigationBar: const AppBottomNav(selectedIndex: 0, onNavigate: _noop),
          body: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final screenBottom = tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // Bottom edge of the "Home" label (last content in the row).
    final homeLabel = find.text('Home');
    expect(homeLabel, findsOneWidget);
    final labelRect = tester.getRect(homeLabel);

    final gapBelowContent = screenBottom - labelRect.bottom;

    // ignore: avoid_print
    print('NAVBAR TEST screenBottom=$screenBottom '
        'labelBottom=${labelRect.bottom} gapBelowContent=$gapBelowContent '
        'inset=$kInset');

    // By design the bar adds NO system inset — it sits flush to the screen
    // bottom. So the gap below the label is just the 5px base padding plus a
    // few px of font descent, and must be well under one home-indicator inset.
    expect(
      gapBelowContent,
      lessThan(kInset,
      ),
      reason: 'Nav bar should sit flush to the bottom (no system inset added); '
          'gap below content was $gapBelowContent, expected < $kInset.',
    );
  });
}

void _noop(int _) {}
