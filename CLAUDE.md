# Exono CRM — Claude instructions

Flutter app under `exono/`. UI is being migrated to **forui 0.22.3**.

## ForUI migration — how to migrate a screen

When asked to "migrate `<screen>.dart` to forui", apply the rules below. **Do one pass, then run `flutter analyze <file>` and fix what it flags. Do NOT do a second line-by-line re-read pass** — analyze is the verification.

### Golden rule: use the `App*` wrappers, don't hand-roll forui

The wrappers already exist in `exono/lib/widgets/`. They wrap forui correctly and inherit theme styling. Prefer them over raw forui widgets:

| Need | Use | Replaces |
|------|-----|----------|
| Button / tap target | `AppButton` (`lib/widgets/app_button.dart`) | `ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextButton`, tappable `InkWell`/`GestureDetector` |
| Card surface | `AppCard` (`lib/widgets/app_card.dart`) | `Container`+`BoxDecoration` used as a card |
| Text input | `AppInput` (`lib/widgets/app_input.dart`) | `TextField`, `TextFormField`. Has `readOnly:` for date/picker fields |
| Chip / status badge | `AppChip` (`lib/widgets/app_chip.dart`) | `Chip`, `FilterChip`, custom badge `Container` |
| Header / app bar | `AppHeader` (`lib/widgets/app_header.dart`) | `AppBar`, custom header rows |
| Section label | `AppSectionLabel` (`lib/widgets/app_section_label.dart`) | small uppercase label text |
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

### `AppButton` API (note: NOT the raw `FButton`)
```dart
AppButton(
  label: 'SAVE',                       // OR child: <Widget>
  onPressed: _save,                    // NOT onPress
  variant: ButtonVariant.primary,      // primary | secondary | outline | ghost | destructive
  size: ButtonSize.md,                 // sm | md | lg
  fullWidth: true,                     // wraps in SizedBox(width: infinity)
  isLoading: false,                    // shows spinner, disables
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
