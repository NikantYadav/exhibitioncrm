// Host test that reproduces AppBottomNav in the shell's Scaffold structure with
// a SIMULATED system bottom inset, then measures the gap below the content row.
//
// The bar's contract:
//   - iPhone home indicator (~34) and Android gesture pill (~16-24) -> FLUSH
//     (no inset reserved; gap below content is just the 5px base pad + descent).
//   - Android 3-button nav (~48) -> RESERVE the inset (row never overlapped).
//
// This is keyed off the inset VALUE, not the screen height, so the behaviour is
// identical on every screen size — which the size sweep below verifies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:exono/config/app_theme.dart';
import 'package:exono/widgets/app_bottom_nav.dart';

void main() {
  // (label, physical screen size) — small to large phones.
  const screens = <(String, Size)>[
    ('small 360x640', Size(360, 640)),
    ('medium 393x852', Size(393, 852)),
    ('large 430x932', Size(430, 932)),
  ];

  // Returns the gap (logical px) between the bottom of the "Home" label and the
  // bottom of the screen, for a given system inset + screen size.
  Future<double> gapFor(WidgetTester tester, double insetLogical, Size physical) async {
    const dpr = 3.0;
    tester.view.devicePixelRatio = dpr;
    tester.view.physicalSize = physical;
    tester.view.viewPadding = FakeViewPadding(bottom: insetLogical * dpr);
    tester.view.padding = FakeViewPadding(bottom: insetLogical * dpr);
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

    final screenBottom = physical.height / dpr;
    final labelRect = tester.getRect(find.text('Home'));
    return screenBottom - labelRect.bottom;
  }

  for (final (name, size) in screens) {
    testWidgets('FLUSH on iPhone home indicator (34) — $name', (tester) async {
      final gap = await gapFor(tester, 34.0, size);
      // ignore: avoid_print
      print('NAVBAR TEST [$name] inset=34 gap=$gap');
      // Flush: only the 5px base pad + a few px font descent. Never the inset.
      expect(gap, lessThan(20),
          reason: 'Expected flush (~10px) on home indicator; got $gap');
    });

    testWidgets('FLUSH on Android gesture pill (20) — $name', (tester) async {
      final gap = await gapFor(tester, 20.0, size);
      // ignore: avoid_print
      print('NAVBAR TEST [$name] inset=20 gap=$gap');
      expect(gap, lessThan(20),
          reason: 'Expected flush (~10px) on gesture pill; got $gap');
    });

    testWidgets('RESERVE on Android 3-button bar (48) — $name', (tester) async {
      final gap = await gapFor(tester, 48.0, size);
      // ignore: avoid_print
      print('NAVBAR TEST [$name] inset=48 gap=$gap');
      // Inset reserved: gap is roughly base pad + the 48px inset.
      expect(gap, greaterThan(48),
          reason: 'Expected the 48px button-bar inset to be reserved; got $gap');
    });
  }
}

void _noop(int _) {}
