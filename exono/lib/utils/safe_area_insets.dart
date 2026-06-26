import 'package:flutter/widgets.dart';

/// Bottom inset helpers for full-screen scroll content.
///
/// Background: on Android edge-to-edge (and iOS home-indicator devices) the
/// system reserves space at the bottom of the window. A scroll view whose last
/// item reaches the bottom of the window must reserve that space, otherwise the
/// content renders underneath the system navigation bar / home indicator.
///
/// The single rule for every full-screen scroll in this app:
///
/// ```dart
/// SingleChildScrollView(
///   padding: EdgeInsets.fromLTRB(16, 20, 16, bottomScrollInset(context)),
///   ...
/// )
/// ```
///
/// Why one helper works for both tab screens and pushed screens:
/// - Pushed/detail screens sit directly above the system bar, so they read the
///   real `viewPadding.bottom` here and reserve it.
/// - Tab screens render inside the app shell, whose bottom-nav slot already
///   consumes the system inset AND sits below the body. The shell zeroes the
///   body's bottom `viewPadding` (see `AppShell`), so tab screens read 0 here
///   and reserve only the base margin — the nav bar provides the rest.
///
/// Never hardcode a bottom clearance (`..., 120)` / `SizedBox(height: 40)`).
/// Always go through this helper so the value tracks the real device inset.

/// Base visual margin kept below the last scroll item, on top of the system
/// inset. Tune here once for the whole app.
const double kBottomScrollMargin = 24;

/// The bottom padding a full-screen scroll view should reserve.
///
/// Equals the live system bottom inset plus [kBottomScrollMargin] (override with
/// [margin]). Returns just the margin inside tab screens, where the shell's nav
/// bar already covers the system inset.
double bottomScrollInset(BuildContext context, {double margin = kBottomScrollMargin}) {
  return MediaQuery.viewPaddingOf(context).bottom + margin;
}

/// The bottom padding a widget pinned to the bottom of the screen (a fixed save
/// bar, a floating dock, an in-screen overlay sheet) should add so its tappable
/// content sits above the system bar / home indicator.
///
/// Use this instead of `MediaQuery.padding.bottom`, which an ancestor SafeArea
/// can have already consumed (0 on Android edge-to-edge). Pass [extra] for any
/// design padding the bar wants on top of the system inset.
double bottomBarInset(BuildContext context, {double extra = 0}) {
  return MediaQuery.viewPaddingOf(context).bottom + extra;
}
