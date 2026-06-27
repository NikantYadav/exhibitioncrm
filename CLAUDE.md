# Exono CRM — Claude instructions

Flutter app under `exono/`. UI is being migrated to **forui 0.22.3**.

## ForUI migration — how to migrate a screen

When asked to "migrate `<screen>.dart` to forui", apply the rules below. **Do one pass, then run `flutter analyze <file>` and fix what it flags. Do NOT do a second line-by-line re-read pass** — analyze is the verification.

### Golden rule: use the `App*` wrappers, don't hand-roll forui

The wrappers already exist in `exono/lib/widgets/`. They wrap forui correctly and inherit theme styling. Prefer them over raw forui widgets:

| Need | Use | Replaces |
|------|-----|----------|
| Contact avatar | `AppAvatar` (`lib/widgets/app_avatar.dart`) | `Container`+`BoxDecoration`+initials, `CircleAvatar`, `FAvatar`, hand-rolled rounded-square |
| Button / tap target | `AppButton` (`lib/widgets/app_button.dart`) | `ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextButton`, tappable `InkWell`/`GestureDetector` |
| Card surface | `AppCard` (`lib/widgets/app_card.dart`) | `Container`+`BoxDecoration` used as a card |
| Text input | `AppInput` (`lib/widgets/app_input.dart`) | `TextField`, `TextFormField`. Has `readOnly:` for date/picker fields |
| Dropdown / select | `AppSelect` (`lib/widgets/app_select.dart`) | `DropdownButton`, ad-hoc tap-to-open option sheets. Custom field + option sheet (selected row = white-on-accent); pass `items:` label→value map, `value:`, `onChanged:`, optional `sheetTitle:`. NOT raw `FSelect` — its themed-secondary highlight gave low-contrast dark-on-blue text |
| Chip / status badge | `AppChip` (`lib/widgets/app_chip.dart`) | `Chip`, `FilterChip`, custom badge `Container` |
| Status badge (icon/spinner) | `AppStatusBadge` (`lib/widgets/app_status_badge.dart`) | hand-rolled `Row`+badge for offline/syncing indicators; use `leading:` for icon, `spinner: true` for inline spinner |
| Header / app bar | `AppHeader` (`lib/widgets/app_header.dart`) | `AppBar`, custom header rows |
| Section label | `AppSectionLabel` (`lib/widgets/app_section_label.dart`) | small uppercase label text |
| Stat row (value/label cells) | `AppStatRow` (`lib/widgets/app_stat_row.dart`) | a `Row` of equal `Expanded` value+label cells with dividers (CONTACTS/PENDING/SKIPPED/DONE etc). Pass `stats: [AppStat(value, label, valueColor?)]`. Scales ALL labels by one shared factor so they stay the same size and never wrap on small screens — do NOT per-cell `FittedBox` |
| Checkbox | `AppCheckbox` (`lib/widgets/app_checkbox.dart`) | custom `GestureDetector`+`AnimatedContainer` checkbox |
| Bottom sheet | `showAppSheet(...)` (`lib/widgets/app_feedback.dart`) | `showModalBottomSheet` |
| Snackbar / toast | `showAppToast(context, 'msg')` (`lib/widgets/app_feedback.dart`) | `ScaffoldMessenger.of(context).showSnackBar` |
| Confirm dialog | `showAppConfirmDialog(...)` (`lib/widgets/app_feedback.dart`) | `showDialog` + `AlertDialog` |
| Divider | `FDivider()` | `Divider()`, 1px line `Container` (only when it's a separator) |
| Spinner | `FCircularProgress()` | `CircularProgressIndicator()` |

### Standing rule: grow the wrappers, don't work around them

**The first time a screen hits something a wrapper can't do, fix the wrapper — never drop to raw forui (or raw Material) in the screen to get past it.** This is mandatory, not a suggestion.

- Missing a param (e.g. `maxLength`, `autofocus`, an icon slot)? Add the param to the wrapper, then use it.
- Hit a pattern no wrapper covers yet (e.g. a tab bar, a radio group, a slider)? Create a new `App*` wrapper in `exono/lib/widgets/`, add it to the table above, then use it.

**Why:** every fix is paid once and then every later screen reuses it for free. Working around a gap in the screen instead pays the same cost again on every screen that has the same widget. The wrapper set is the thing that makes migration cheap — investing in it is the whole strategy, so each migration should leave the wrappers at least as capable as it found them.

After changing or adding a wrapper, update the table above and run `flutter analyze` on the wrapper file.

### `AppAvatar` API
```dart
AppAvatar(initials: 'JS')                         // default 44×44, accent gradient
AppAvatar(initials: 'JS', size: 56)               // any size
AppAvatar(initials: 'JS', done: true)             // green check state (follow-up done)
AppAvatar.network(url: avatarUrl, initials: 'JS') // shows image, falls back to initials
```
Style: rounded square (radius 12), blue accent gradient fill, accent border, accent-colored initials. `done: true` switches to green gradient + check icon. `size < 36` uses `xs` typography; `size >= 36` uses `sm`.

### `AppButton` API (note: NOT the raw `FButton`)
```dart
AppButton(
  label: 'SAVE',                       // OR child: <Widget>
  onPressed: _save,                    // NOT onPress
  variant: ButtonVariant.primary,      // primary | secondary | outline | ghost | destructive
  size: ButtonSize.md,                 // sm | md | lg
  fullWidth: true,                     // wraps in SizedBox(width: infinity)
  isLoading: false,                    // shows spinner, disables
  prefixIcon: Icon(Icons.save),        // for icon+label buttons (replaces FilledButton.icon / OutlinedButton.icon)
)
```
Variant mapping: Filled/Elevated → primary · Outlined → outline · Text/cancel → ghost · delete confirm → destructive · "Link X"/secondary → secondary.

### Theme tokens — never hardcode colors/sizes
Access via `context.theme`:
```dart
context.theme.colors.background / .foreground / .primary / .primaryForeground
  / .secondary / .secondaryForeground / .muted / .mutedForeground / .border
  / .error / .errorForeground
context.theme.typography.xs / .sm / .lg / .xl / .xl2   // no .base, no .md
// override: context.theme.typography.sm.copyWith(fontWeight: FontWeight.w700, color: ...)
```
The app also has `ExonoColors` via `AppTheme.colorsOf(context)` (aliased `_c` in screens). **Prefer `context.theme.colors.*`.** Only keep `_c.*` for brand colors with NO forui token: `_c.surfaceElevated`, `_c.accentGlow`, `_c.success`, `_c.accentStrong`, `_c.destructive` (use `context.theme.colors.error` when it reads as an error, `_c.destructive` for the raw brand red).

### Scaffold / layout
- If a screen uses `Scaffold` + `SafeArea` + header `Column`, collapse to `FScaffold(header: AppHeader(...), childPad: false, child: body)`.
- Screens embedded in a tab shell often use `ColoredBox(color: context.theme.colors.background, child: Column([AppHeader(...), Expanded(child: body)]))` — keep that pattern; don't force `FScaffold`.

### Adaptive layout (MANDATORY — every new screen must be responsive across mobile screen sizes)

Every new screen (and every sheet/dialog) must render correctly on **all phone sizes**, from small (~360×640) to large (~430×930) — no overflow, no clipping, no content pinned awkwardly to an edge. This is not optional polish; build it adaptive from the start.

- **Never hardcode a screen-fraction height in logical pixels.** Use `MediaQuery.sizeOf(context)` ratios (e.g. `height: MediaQuery.sizeOf(context).height * 0.4`) or let content size itself. For bottom sheets, the height cap lives in `showAppSheet` (`mainAxisMaxRatio` as a *ratio*, currently 0.92) — don't override it with a fixed pixel height in the sheet content.
- **Make full-screen content scrollable** when it can exceed the viewport on small phones — wrap forms/long columns in `SingleChildScrollView` (with the bottom-inset helper, see below) so nothing overflows on short screens.
- **Don't fix widths in pixels for content that should fill** — use `Expanded`, `Flexible`, `FractionallySizedBox`, or `double.infinity` instead of a hardcoded `width: 320`. Reserve fixed sizes for geometry (avatar size, icon size, divider thickness).
- **Wrap rows that can overflow** (chips, tag lists, button clusters) in `Wrap` rather than a single `Row` that clips on narrow screens.
- **Use the bottom safe-area helpers** (next section) for every screen — they are already adaptive across device insets.
- **Verify with `flutter analyze`**, but for layout also reason about the smallest target: if a `Row` of three fixed-width fields wouldn't fit at 360px wide, it's wrong.

### Bottom safe-area / nav-bar insets (MANDATORY — always use the helpers)

The system reserves space at the bottom of the window (Android nav bar, iOS home indicator). Content that reaches the window bottom must reserve it or it renders **under** the system bar. **Never hardcode a bottom clearance** (`..., 120)`, `SizedBox(height: 40)`) and **never read `MediaQuery.padding.bottom`** — an ancestor `SafeArea` can already have consumed it (0 on Android edge-to-edge). Use the two helpers in [`lib/utils/safe_area_insets.dart`](exono/lib/utils/safe_area_insets.dart):

| Situation | Use |
|-----------|-----|
| Bottom padding of a full-screen **scroll** (`SingleChildScrollView`/`ListView`/`CustomScrollView`) whose last item reaches the window bottom | `padding: EdgeInsets.fromLTRB(16, 20, 16, bottomScrollInset(context))` — add `margin: N` if the scroll must clear a fixed bottom bar (e.g. `margin: 100`) |
| Trailing spacer at the end of a list (`SizedBox(height: …)`) | `SizedBox(height: bottomScrollInset(context))` |
| A widget **pinned** to the bottom (fixed save bar, floating dock, in-screen `Positioned(bottom:0)` overlay sheet) | `padding: EdgeInsets.fromLTRB(.., .., .., bottomBarInset(context, extra: 12))` — `extra` is design padding on top of the inset |
| A `showAppSheet` bottom sheet | nothing — `showAppSheet` already injects the inset; builders keep `SafeArea(top: false)` |
| Keyboard avoidance — **inside a `showAppSheet` builder** | nothing — `showAppSheet` owns the keyboard inset centrally (see next section). NEVER read `viewInsets.bottom` in a sheet builder. |
| Keyboard avoidance — **full-screen pushed screen** (`AppHeader`/back button, not a sheet, e.g. `company_detail`, `target_company_prep`) | keep `MediaQuery.of(context).viewInsets.bottom` in that screen's own scroll padding (that's the keyboard, a different inset) |

Why one helper works for tab screens AND pushed/detail screens: `bottomScrollInset` returns `viewPadding.bottom + margin`. When a `Scaffold` has a `bottomNavigationBar` (the app shell on tab routes, and `live_*` screens), Flutter strips the body's bottom inset, so `viewPadding.bottom` is ~0 there and the helper yields just the margin — the nav bar covers the system inset. Pushed/detail screens have no nav bar, keep the real inset, and reserve it. So you **don't** need to know which kind of screen you're on — just call `bottomScrollInset(context)`. Tune the app-wide base margin via `kBottomScrollMargin` in the helper file.

### Keyboard inset for bottom sheets (MANDATORY — `showAppSheet` is the single owner)

`showAppSheet` ([`lib/widgets/app_feedback.dart`](exono/lib/widgets/app_feedback.dart)) owns the keyboard inset for **every** bottom sheet. It calls forui's `showFSheet` with `resizeToAvoidBottomInset: false` (so forui does NOT lift the whole sheet) and instead wraps the builder in an `AnimatedPadding(bottom: viewInsets.bottom)`. The sheet stays **bottom-anchored**; the keyboard overlaps the lower portion; content scrolls above it. This behaves identically on every phone size and never rides up into the status bar / time area.

**Why this matters:** previously the keyboard was counted twice — forui lifted the entire sheet AND each sheet builder subtracted `viewInsets.bottom` in its own layout — so the sheet's top edge rode up into the status bar when the keyboard opened (reported on Add Goal / Add Company / Add Contact and other sheets). Removing forui's lift and centralizing the inset in one place is the fix; re-introducing a per-sheet `viewInsets.bottom` re-creates the double-count.

Rules for any widget rendered as a `showAppSheet` builder:
- **NEVER reference `MediaQuery.viewInsets.bottom` inside a sheet builder** — not in `padding`, not in `maxHeight`/`SizedBox` height calc, not in an inner `AnimatedPadding`. Use a static bottom pad (e.g. `EdgeInsets.fromLTRB(20, 20, 20, 32)`).
- **Make short sheet content a `SingleChildScrollView`** so the centrally-added keyboard padding never overflows on small phones. (`AppSheetContent` and `_LogFollowUpSheet` already do this.)
- This is **sheets-only**. Full-screen *pushed* screens (those with an `AppHeader`/back button, e.g. `company_detail`, `target_company_prep`) are NOT sheets — they keep their own `viewInsets.bottom` for keyboard avoidance.

### Keep as-is (no forui equivalent — do NOT replace)
- Layout: `Row Column Stack Positioned Expanded Spacer Padding SizedBox Center Wrap ConstrainedBox FractionallySizedBox`
- Scroll: `SingleChildScrollView ListView ListView.builder`
- Visual primitives: `ClipRRect`, `ColoredBox`, `Container` ONLY for geometry (circles, 1px lines, gradient overlays, drag-handle pills, progress-bar fills)
- `Image.*`, `Icon` (as child/prefix), `SafeArea` (inside sheets), `AnimationController`/`AnimatedBuilder`/`Transform`, `IgnorePointer`, `Navigator.pop`, `MediaQuery`
- `showDatePicker` is a Material system dialog — keep it; its `Theme(...)` override may use raw `_c.*`.

### Imports
- Add `import 'package:forui/forui.dart';`
- **Keep** `import 'package:flutter/material.dart';` — still needed for all layout/paint/gesture primitives above.

### Common mistakes
- `AppButton` uses `onPressed:`; raw `FButton` uses `onPress:`. `FHeader` has only `suffixes:`, `FHeader.nested` adds `prefixes:`.
- `showAppSheet` takes named params: `showAppSheet(context: context, builder: (ctx) => Widget)` — NOT positional args.
- `FCheckbox`/`AppCheckbox`: `value:` + `onChange:`/`onChanged:`, not a tappable Container.
- Don't pass `decoration:`/`style:` to `FCard.raw`/`AppCard` unless a custom border/shadow is truly needed.
- `FProgress` is indeterminate-only (no `value:`). For a determinate bar, keep the `ClipRRect`+`FractionallySizedBox` geometry.
- **Never wrap a complex layout child (`Padding+Row`, `AnimatedContainer`, etc.) in `AppButton`.** `FButton` imposes its own internal layout and will throw assertion/null errors at runtime. Use `GestureDetector` for tappable complex layout regions — it is in the "keep as-is" list. Only use `AppButton` when the tap target IS the button (label, icon, short text).
- **`showFDialog` with inline input fields has no wrapper equivalent — keep it raw.** `showAppConfirmDialog` is only for simple title+message confirms. If a dialog contains `TextField`s or other interactive widgets, keep `showFDialog`+`FDialog` but replace its action `FButton`s with `AppButton`.
- **Dead code causes analyzer warnings — remove it.** Unused private methods (`_buildModeSwitch`, etc.) flagged as `unused_element` must be deleted, not just left in place.
- **Replacing `Material` with `ColoredBox` requires an extra `ClipRRect` for rounded corners.** `Material` handles clipping automatically; `ColoredBox` does not. Pattern: `ClipRRect(borderRadius: ..., child: ColoredBox(color: ..., child: ...))` — and count brackets carefully, the extra nesting needs one more closing `)`.
- **`_skeletonItem` and similar ad-hoc card containers (`Container+BoxDecoration` used as a card surface) → `AppCard`.** Only keep raw `Container` for geometry (circles, gradient fills, progress bars) — not for card-shaped surfaces.
- **`showModalBottomSheet` → `showAppSheet`.** Always replace. The inner builder should use `SafeArea(top: false, ...)` (not `top: true`) since forui's `showFSheet` already handles top insets. Drop the `backgroundColor`/`shape` args — the `showAppSheet` wrapper already applies `context.theme.colors.background` internally, so screens must NOT add a manual `ColoredBox` around their sheet content.
- **`StatefulBuilder` inside `showModalBottomSheet` is usually unnecessary.** When the sheet options call `setState` on the parent screen (not local sheet state), remove `StatefulBuilder` entirely and drop the `setSheetState` parameter from option-builder helpers.
- **`if (mounted) setState(...)` without braces triggers `curly_braces_in_flow_control_structures`.** Always wrap as `if (mounted) { setState(() { ... }); }` — the analyzer flags the bare form even though it is technically valid.
- **`AppCard` does not support gradient backgrounds or conditional colors.** If a surface has a `LinearGradient`/`RadialGradient` fill, OR has conditional background color (e.g. `isSelected ? color : _c.surfaceAlt`), keep the raw `Container+BoxDecoration`. `AppCard` uses a fixed theme color — only replace with it when the background is unconditionally the default card color.
- **Unused variables left over from replaced widgets cause analyzer warnings.** After replacing a widget that used a local variable (e.g. `urgencyColor` used only for a `Container` color), delete the variable declaration too — don't just leave it orphaned.
- **`showFToast` → `showAppToast(context, 'message')`.** The forui raw call is `showFToast(context: context, title: Text(...))` which requires a widget; the wrapper takes a plain string. Always use the wrapper and add `app_feedback.dart` to imports.
- **`FilledButton.icon` / `OutlinedButton.icon` → `AppButton(prefixIcon: Icon(...), label: '...')`.** The `prefixIcon` param was added to `AppButton` for icon+label buttons. Do NOT pass a `Row(icon, text)` as `child:` to `AppButton` — `FButton` imposes its own internal layout and will throw. Use `prefixIcon:` instead.
- **`AppButton(child: Icon(...))` for icon-only buttons** — pass only `child:` (not `label:` + `child:`). The assertion requires at least one of `label` or `child`, so an icon-only button must use `child: Icon(...)`.
- **`local variable '_name'` starts with underscore lint.** Local variables (inside methods/builders) must not start with `_`. Rename to `name` (remove the underscore). Only class-level fields use `_` prefix.
- **Screens with `bottomNavigationBar` (i.e., top-level app screens) keep `Scaffold`.** These use Material's `bottomNavigationBar` slot which forui has no equivalent for. Only replace `Scaffold` with `ColoredBox`+`SafeArea`+`Column` when the screen has no `bottomNavigationBar` (e.g. detail/modal screens embedded in a tab shell). Set `backgroundColor: context.theme.colors.background` directly on `Scaffold` in those cases.
- **`showDialog`+`AlertDialog`+`TextButton` for simple confirm → `showAppConfirmDialog`.** Only keep raw `showDialog` when the dialog contains interactive widgets (TextFields, etc.). Simple title+message+confirm/cancel dialogs always use `showAppConfirmDialog(context, title, message, confirmLabel, destructive)`.
- **`_ContactPickerSheet` and similar self-contained sheet widgets:** when they're passed as builder to `showAppSheet`, the `showAppSheet` wrapper already supplies background color. Remove any `Container(color: _c.background, ...)` wrapper from their `build` method — replace with `SizedBox` for sizing. Wrap the whole thing in `SafeArea(top: false)`.
- **`if/else` chains in `try` blocks (timeAgo, status strings) trigger `curly_braces_in_flow_control_structures`.** Always use braces: `if (cond) { x = 'a'; } else if (...) { x = 'b'; } else { x = 'c'; }` — even for single-statement branches.
- **Raw `FButton`/`FButtonVariant` in screens must be replaced with `AppButton`/`ButtonVariant`.** The outline color fix (blue text on white) is applied inside `AppButton` — raw `FButton.outline` bypasses it and renders with white text. Only keep raw `FButton` inside `showFDialog` action arrays (where `AppButton` cannot be used) and for complex layout children (`prefix`+`suffix`+`Expanded` child, `Column` child) where `FButton`'s internal layout is load-bearing.
- **Contact avatars must always use `AppAvatar`.** Never hand-roll a rounded-square or circle container with initials — not `Container`+`BoxDecoration`, not `CircleAvatar`, not `FAvatar`. Every screen that shows a contact's avatar uses `AppAvatar` (or `AppAvatar.network` when an image URL is available). The `done: true` prop handles the green/check state for followed-up contacts.
- **`TextStyle(fontSize: N, ...)` must be replaced with `context.theme.typography.XX.copyWith(...)`.** Never hardcode `fontSize` — use the scale: `xs` (~10–11px), `sm` (~13–14px), `lg` (~16–18px), `xl` (~20–22px), `xl2` (~24–28px). There is no `.base` or `.md`. When in doubt, match the closest size.
- **`_c.textPrimary` → `context.theme.colors.foreground`, `_c.textMuted` → `context.theme.colors.mutedForeground`, `_c.border` → `context.theme.colors.border`, `_c.background` → `context.theme.colors.background`.** These four have direct forui token equivalents — always substitute. Only keep `_c.*` for brand-only colors with no forui token: `_c.accent`, `_c.success`, `_c.destructive`, `_c.isDark`, `_c.surface`, `_c.surfaceElevated`, `_c.surfaceAlt`, `_c.accentGlow`, `_c.accentStrong`.
- **`RefreshIndicator` has no forui equivalent — keep it.** Replace its `color:` with `_c.accent` and `backgroundColor:` with `context.theme.colors.background`. Do not try to wrap or replace it.
- **`LinearProgressIndicator(value: progress)` is a determinate bar — keep the `ClipRRect`+`LinearProgressIndicator` geometry.** Only `FProgress` (indeterminate) should be replaced with `FCircularProgress()`. Never replace a determinate bar.
- **`_c.textPrimary` used as a geometry color (e.g. `BoxDecoration` fill with alpha) → `context.theme.colors.foreground`.** The substitution applies to both text styles and geometry; it is not text-only.
- **`Scaffold(backgroundColor: _c.background)` without `bottomNavigationBar` → remove entirely.** Replace with `ColoredBox(color: context.theme.colors.background, child: SafeArea(bottom: false, child: Column([...])))`. Never keep a bare `Scaffold` just for background color when it has no `bottomNavigationBar`/`floatingActionButton` — it adds unnecessary Material layer overhead.
- **`DecoratedBox(decoration: AppTheme.appBackground(context))` wrapping a `Scaffold` body → remove.** After replacing `Scaffold` with `ColoredBox`, the `DecoratedBox` wrapper is redundant — the `ColoredBox` is the background. Delete the `DecoratedBox` entirely.
- **`_c.textMuted` passed as a `Color` value parameter (not in a `TextStyle`) → `context.theme.colors.mutedForeground`.** This comes up in helper methods like `_summaryCol(value, label, _c.textMuted)` — replace at the call site, not just in `TextStyle`.
- **`AlwaysStoppedAnimation<Color>(...)` inside a determinate `LinearProgressIndicator` → keep as-is.** It is part of the determinate-bar geometry pattern (keep `LinearProgressIndicator`). Do not try to replace it with a forui widget.
- **Sheet drag-handle pill (`Container(width:36, height:4, decoration: BoxDecoration(color: _c.border, ...))`) → replace `_c.border` with `context.theme.colors.border`.** This pill appears at the top of every `showAppSheet` content widget; it is geometry, not a card surface, so `AppCard` does not apply — just fix the color token.
- **`fontSize: 17` maps to `context.theme.typography.lg`.** The typography scale in practice: `xs`≈10–11, `sm`≈13–14, `lg`≈16–17, `xl`≈20–22, `xl2`≈24–28. Use `lg` for modal/sheet titles (~17px) and section headings that fall between `sm` and `xl`.
- **Sheet rounded corners are applied once in `showAppSheet` via `ClipRRect(borderRadius: BorderRadius.vertical(top: Radius.circular(24)))`.** `showFSheet` has no built-in `borderRadius` param — the wrapper already wraps with `ClipRRect` + `ColoredBox`. Do NOT add a `ClipRRect` in individual sheet content builders; it is already handled globally in `app_feedback.dart`.
- **`StatefulBuilder` inside `showAppSheet` IS appropriate when the sheet has local-only state** (e.g. a search field that filters a list within the sheet). The rule against `StatefulBuilder` only applies when the sheet options call `setState` on the parent screen — local sheet state (search query, selected option preview) is fine with `StatefulBuilder`. Dispose any `TextEditingController` created before the `showAppSheet` call; do not create it inside the builder (it would be recreated on every rebuild).

## Working efficiently (token discipline — read this)

These rules exist to keep sessions cheap. Follow them by default.

### Don't re-read large files
- `llm_full_forUI.txt` (~16k lines) and any screen you just edited: **never read top-to-bottom.** `grep`/search for the exact symbol (`### \`FButton`, `showFSheet(`) and read only the matching lines. After an `Edit`, do NOT re-Read the file to "confirm" — the edit already succeeded and analyze will catch breakage.
- Read a file once per session. If you already saw it earlier in the conversation, use that; don't re-open it.

### Verify with the analyzer, not your eyes
- `flutter analyze <file>` from `exono/` is the source of truth. One migration pass → analyze → fix flagged issues → done. No second line-by-line audit pass unless the user explicitly asks.
- Don't run the full app or `flutter test` to check a UI migration; analyze is enough.

### Explore cheaply
- To find where something lives, prefer `grep`/glob over reading whole directories. Read the specific file you need, not its neighbors "for context."
- The wrapper APIs are documented in the table and snippets above — use those instead of opening each `lib/widgets/app_*.dart` to re-learn its signature. Only open a wrapper when you're changing it.

### Keep output tight
- Don't echo migrated file contents back in chat — the diff is visible. Summarize what changed in a few lines.
- Don't narrate options you won't take or re-explain rules already in this file. Act, then give a short summary.

### Batch the work
- When migrating multiple screens, do them in one session so these rules and the wrapper set stay in context. Group similar screens (all list screens, all form screens) together.
- Opus is overkill for mechanical wrapper-swapping — a smaller model is fine once the wrappers exist.

## Conventions
- **No emojis** in code or UI strings, ever.
- Verify with `flutter analyze <file>` (from `exono/`), not by re-reading.
- App entry/structure: `exono/lib/` → `screens/` (35 screens), `widgets/` (the `App*` forui wrappers live here, alongside other shared widgets like `badge.dart`, `skeleton_loader.dart`, `empty_state.dart`), `config/` (`app_theme.dart` = `ExonoColors` + `AppTheme`; also `api_config.dart`, `supabase_config.dart`), `models/`, `services/` (`api_service.dart`, `auth_service.dart`, …), `providers/` (`auth_provider.dart`, `theme_provider.dart`, …), `main.dart`, `router.dart`. Check here before searching for where something lives.

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes` or `query_graph` instead of Grep
- **Understanding impact**: `get_impact_radius` instead of manually tracing imports
- **Code review**: `detect_changes` + `get_review_context` instead of reading entire files
- **Finding relationships**: `query_graph` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview` + `list_communities`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context` | Need source snippets for review — token-efficient |
| `get_impact_radius` | Understanding blast radius of a change |
| `get_affected_flows` | Finding which execution paths are impacted |
| `query_graph` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes` | Finding functions/classes by name or keyword |
| `get_architecture_overview` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes` for code review.
3. Use `get_affected_flows` to understand impact.
4. Use `query_graph` pattern="tests_for" to check coverage.
