Plan: Adaptive (responsive) styling across the Exono app
Goal
Eliminate congestion/overflow on narrow phones by making typography, spacing, and key layouts adapt to screen width — applied centrally (via theme + App* wrappers) so every screen benefits, plus targeted Flexible/ellipsis fixes on the three known overflow spots.

Guiding principle
Do not sprinkle MediaQuery checks into every screen. Two central levers + three local fixes:

Lever A — responsive typography & text-scale clamp injected once at the MaterialApp builder.
Lever B — a Breakpoints helper + responsive spacing constants the wrappers read.
Local fixes — Flexible/maxLines/ellipsis on the 3 overflowing widgets.
Verified facts (do not re-investigate; use these)
App root: exono/lib/main.dart. The single MaterialApp.router builder is at main.dart:238-243 — this wraps every route in FTheme → FToaster. This is the only global injection point.
forui themes built in _buildForuiDark() / _buildForuiLight() at main.dart:145 and main.dart:174. Both end with return FThemeData(colors: colors, touch: true); — no typography: arg is passed, so forui's default typography is in effect. Adding a typography: argument here is how you scale all context.theme.typography.* at once.
Screens read font sizes via context.theme.typography.{xs,sm,lg,xl,xl2} (no .base/.md). Wrappers do too, e.g. app_button.dart:85, app_section_label.dart:27.
Existing width check precedent: MediaQuery.of(context).size.width < 768 at app_shell.dart:92. Landing screen uses ad-hoc width > 768/900/700 checks (leave those alone — landing is marketing, not the app shell).
Theme/colors live in exono/lib/config/app_theme.dart (552 lines; ExonoColors + AppTheme).
No existing textScaler clamp anywhere (grep confirmed). FittedBox only in auth_screen.dart / home_default_screen.dart.
Step 1 — Create lib/config/responsive.dart (new file)
A single source of truth for breakpoints and scale factors. No dependencies on widgets.


import 'package:flutter/widgets.dart';

/// Width breakpoints (logical px). Narrow ≈ small phones (iPhone SE, etc.).
class Breakpoints {
  static const double narrow = 360; // below this = compact mode
  static const double tablet = 768; // matches app_shell.dart mobile check
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// True on small phones where the default type scale congests.
  bool get isNarrow => screenWidth < Breakpoints.narrow;

  /// Multiplier applied to the forui typography scale.
  /// 1.0 normal, ~0.9 on narrow phones. Tune after visual check.
  double get typeScale => isNarrow ? 0.92 : 1.0;

  /// Standard screen horizontal padding, tightened on narrow phones.
  double get gutter => isNarrow ? 16 : 20;
}
Use MediaQuery.sizeOf (not MediaQuery.of) — it's the modern, rebuild-scoped accessor.

Step 2 — Apply the global text-scale clamp + responsive typography in main.dart
Edit the builder at main.dart:238-243. Two changes:

(a) Clamp the OS accessibility text scaler so large system font settings can't blow up the layout, and (b) feed a width-scaled FTypography into the forui theme.

The builder becomes:


builder: (context, child) {
  final mq = MediaQuery.of(context);
  // Clamp OS font scaling to a layout-safe range.
  final clamped = mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15);
  // Width-based scale on top of the clamp.
  final width = mq.size.width;
  final scale = width < Breakpoints.narrow ? 0.92 : 1.0;
  final scaledTheme = foruiTheme.copyWith(
    typography: foruiTheme.typography.scale(sizeScalar: scale),
  );
  return MediaQuery(
    data: mq.copyWith(textScaler: clamped),
    child: FTheme(
      data: scaledTheme,
      child: FToaster(child: child!),
    ),
  );
},
VERIFICATION STEP (mandatory before relying on the above): the exact forui 0.22.3 API names must be confirmed by grepping the package, not assumed. Run:


cd exono && grep -rn "sizeScalar\|FTypography\|TextScaler scale\|scale(" \
  $(flutter pub cache list 2>/dev/null; echo) ~/.pub-cache/hosted/*/forui-0.22.3/lib/ 2>/dev/null | grep -i "typograph\|scale" | head
If FTypography has a .scale(sizeScalar:) method → use it as above.
If it does not, fall back to: build the scaled typography by copyWith-ing each field (xs, sm, lg, xl, xl2, etc.) multiplying fontSize by scale. Grep class FTypography in the forui package to get the exact field list first.
Confirm FThemeData.copyWith(typography:) exists; if not, pass typography: directly into the FThemeData(...) constructors in _buildForuiDark/_buildForuiLight instead, threading scale in as a parameter.
Add import 'config/responsive.dart'; to main.dart.

Do not guess these API signatures — the grep is required. If grep is inconclusive, stop and report rather than inventing method names.

Step 3 — Fix the three known overflow spots (from the screenshots)
These are structural, independent of font scale. Find each, then apply.

3a. Stat row "SCANNED / TARGETS LEFT / GOALS LEFT" (the "BOTTOM OVERFLOWED BY 13 PIXELS").

Locate: grep -rn "GOALS LEFT\|TARGETS LEFT\|SCANNED" lib/screens/ (likely live_home_screen.dart).
Each stat cell must be wrapped in Expanded (equal width share), the label Text given textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis.
The 13px vertical overflow: the Row of cells sits in a fixed-height container — either remove the fixed height, or wrap stat content in Flexible/allow it to size to content. Confirm by reading the actual container.
3b. Contact list row — name collides with "MARK MET" button.

Locate: grep -rn "MARK MET" lib/screens/ (likely live_home_screen.dart).
Wrap the name/role text column in Expanded, give the name maxLines: 1 (or 2) + overflow: TextOverflow.ellipsis. The button keeps its intrinsic width. This stops "Satya Nadella" wrapping into the button.
3c. "+ Add" / "Target Companies" header rows + company name cells.

Locate via the relevant screen (the cards screenshot — likely pre_event_prep_screen.dart given the "Target Contacts / Target Companies" sections; confirm with grep -rn "Target Companies\|Target Contacts" lib/screens/).
Title text in Expanded + maxLines/ellipsis; the AppButton stays trailing. Company name in list cell: Expanded + ellipsis.
For each: after editing, run flutter analyze <file> and fix what it flags. Do not re-read top-to-bottom.

Step 4 — Make screen gutters responsive (optional, low-risk, do last)
Where screens hardcode horizontal padding 20, optionally swap to context.gutter from the helper so narrow phones get 16px gutters. Scope this narrowly: only the top-level scroll/body padding of the 3 screens touched in Step 3, to avoid a huge mechanical sweep. A broader sweep can be a follow-up.

Verification (per CLAUDE.md — analyzer is the source of truth)
After Steps 2–4: cd exono && flutter analyze lib/main.dart lib/config/responsive.dart <each edited screen>.
Fix everything flagged. Do not do a second line-by-line read pass.
Manual visual check is required for this task specifically (the analyzer can't see overflow): the user should run the app on a narrow device/emulator (≤360px wide, e.g. iPhone SE) and confirm the three spots no longer overflow. Tell the user to do this; note the 0.92 / clamp values may need tuning.
Explicitly OUT of scope (do not do)
Do not add per-widget FittedBox everywhere — only consider it if a single stat number still won't fit after Step 3.
Do not rewrite landing_screen.dart's existing width breakpoints.
Do not convert every screen's padding to context.gutter in one pass (Step 4 is scoped to the 3 screens).
Do not change app_shell.dart's 768 check.
Order of operations
Step 1 (new file) → 2. grep-verify forui typography API → 3. Step 2 (main.dart) → flutter analyze → 4. Step 3 a/b/c (find + fix each, analyze each) → 5. Step 4 (scoped) → 6. report + ask user for the narrow-device visual check.
