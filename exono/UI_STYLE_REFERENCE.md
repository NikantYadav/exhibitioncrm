# Exono Mobile UI Style Reference

This document is a working handoff for humans and AI tools editing `crm/exono`.

## Primary objective

Keep the Flutter UI aligned with the current Exono mobile direction:
- mobile-first layouts
- near-black backgrounds in dark mode with navy gradient card surfaces
- pill buttons and rounded controls
- high-contrast dark navy / vibrant blue styling
- centralized semantic theming
- day/night mode compatibility

Do **not** introduce isolated one-off palettes or screens that deviate from the token system.

---

## Source of truth

### Design reference screen

`lib/screens/offline_mode_screen.dart` is the canonical reference for all UI patterns:
- card style (gradient + border, no shadow)
- filter pills (outline style)
- chips (tag, label, status variants)
- section labels
- bottom nav

When building or reviewing a screen, match what offline_mode_screen produces.

---

### Theme tokens

Use:
- `AppTheme.colorsOf(context)` — all semantic colors
- `AppTheme.appBackground(context)` — page-level scaffold background
- `AppTheme.softShadow(context)` — nav bars and FABs only (never cards)
- `Theme.of(context).textTheme`

Primary token type:
- `ExonoColors` — defined in `lib/config/app_theme.dart`

**Every color in the application flows through this single file.** To retheme the entire app, edit only `AppTheme.lightColors` and `AppTheme.darkColors`. No screen-level changes required.

#### Semantic color tokens

| Token | Light | Dark | Use for |
|---|---|---|---|
| `background` | `#F4F7FF` | `#04060E` | Page/scaffold fill |
| `backgroundAlt` | `#E8F0FF` | `#07091A` | Gradient endpoint |
| `surface` | `#FFFFFF` | `#0B1422` | Card / sheet fill (gradient start) |
| `surfaceAlt` | `#F0F5FF` | `#0F1B2E` | Alternate card, gradient end, input fill |
| `surfaceElevated` | `#E5EEFF` | `#152538` | Elevated chip, progress track |
| `border` | `#D4E0F7` | `#1C2F4A` | 1px card / input borders |
| `borderStrong` | `#B9C9EA` | `#283F62` | Dividers, focus rings |
| `textPrimary` | `#18253B` | `#F0F6FF` | Headlines, values |
| `textSecondary` | `#50627F` | `#B5C6E4` | Subheadings, body copy |
| `textMuted` | `#7E8FAC` | `#7A90B5` | Captions, metadata |
| `accent` | `#4C78E6` | `#4F7BFF` | Filled buttons, active nav, progress fills |
| `accentStrong` | `#2854C1` | `#3360E0` | Pressed state, gradient end |
| `accentSoft` | `#DCE8FF` | `#162E5C` | Chip backgrounds, subtle fills |
| `accentGlow` | `#BFD4FF` | `#0C2048` | Box shadows, halo effects |
| `navBackground` | `#F7FAFF` | `#020408` | Bottom nav / app bar backing |
| `destructive` | `#DB5B68` | `#FF7A8A` | Errors, delete actions |
| `success` | `#3AAE7A` | `#5DC89A` | Positive status indicators |

#### Radius constants

| Constant | Value | Use for |
|---|---|---|
| `radiusCard` | `20` | Cards, panels, sheets |
| `radiusButton` | `999` | Pill buttons |
| `radiusInput` | `16` | Text fields, search bars |
| `radiusLarge` | `28` | Hero cards, large modals |

#### Font

Inter is set globally in `ThemeData`. **Never import `GoogleFonts` in a screen.** Use plain `TextStyle(...)` — Inter applies automatically.

#### How to consume tokens

**StatefulWidget:**
```dart
ExonoColors get _c => AppTheme.colorsOf(context);
```

**StatelessWidget:**
```dart
final _c = AppTheme.colorsOf(context);
```

---

## Component library

All shared UI lives in `lib/widgets/`. Use these everywhere — never rebuild these patterns inline in a screen.

---

### AppCard (`lib/widgets/app_card.dart`)

Single source of truth for all card and panel surfaces. Never write `Container(decoration: BoxDecoration(...))` for a card.

```dart
// Standard card
AppCard(
  padding: const EdgeInsets.all(20),
  child: myContent,
)

// Large hero card
AppCard(
  padding: const EdgeInsets.all(24),
  radius: 28,
  child: myContent,
)

// Elevated inner panel (secondary surface)
AppCard(
  padding: const EdgeInsets.all(16),
  radius: 16,
  elevated: true,
  child: myContent,
)

// VIP card with custom border + glow
AppCard(
  radius: 24,
  borderColor: colors.accent,
  extraShadow: [BoxShadow(color: colors.accentGlow, blurRadius: 12)],
  child: myContent,
)
```

**Parameters:**

| Parameter | Type | Default | Description |
|---|---|---|---|
| `child` | `Widget` | required | Card body |
| `padding` | `EdgeInsetsGeometry?` | `null` | Internal padding |
| `radius` | `double` | `20` | Corner radius |
| `elevated` | `bool` | `false` | Uses `surfaceAlt → surfaceElevated` gradient |
| `borderColor` | `Color?` | `null` | Override border color |
| `extraShadow` | `List<BoxShadow>?` | `null` | Add glow/shadow (use sparingly) |

**Rules:**
- Cards never have a box shadow by default — the gradient provides depth
- `softShadow` is reserved for nav bars and FABs only
- Do not call `AppTheme.cardDecoration()` directly in screens — use `AppCard`

---

### AppChip (`lib/widgets/app_chip.dart`)

Three variants sourced from offline_mode_screen. Never build chip containers inline.

```dart
// Tag — outlined pill (AI & Robotics, Deep Tech)
AppChip('AI & Robotics')
AppChip('Deep Tech', color: colors.accent, textColor: colors.accent)

// Label badge — filled rect (BOOTH B-04, HALL 2)
AppChip.label('BOOTH B-04')
AppChip.label('HALL 2', color: colors.surfaceElevated)

// Status badge — filled rect with required color (MET, VIP, URGENT)
AppChip.status('MET', color: colors.textSecondary)
AppChip.status('VIP', color: colors.accent)
AppChip.status('URGENT', color: colors.destructive)
AppChip.status('DONE', color: colors.success)
```

**When to use which:**

| Pattern | Use |
|---|---|
| Industry / category tag | `AppChip(label)` |
| Booth / location / tier identifier | `AppChip.label(label)` |
| Met / Pending / VIP / lifecycle state | `AppChip.status(label, color: ...)` |

**Visual spec:**
- `AppChip` — rounded pill (radius 999), border outline, uppercase 10px w500
- `AppChip.label` — rect badge (radius 4), filled `surfaceElevated`, uppercase 9px w700
- `AppChip.status` — rect badge (radius 4), filled with `color`, uppercase 9px w800

---

### AppSectionLabel (`lib/widgets/app_section_label.dart`)

Uppercase muted section header. Sourced from "PREPARED NOTES" in offline_mode_screen.

```dart
// Default — textMuted, letterSpacing 1.6
const AppSectionLabel('Prepared Notes')

// Accent colored (e.g. dashboard "AI Prep Notes")
AppSectionLabel('AI Prep Notes', color: colors.accent, letterSpacing: 0.7)
```

**Parameters:**

| Parameter | Type | Default |
|---|---|---|
| `label` | `String` | required — auto-uppercased |
| `color` | `Color?` | `textMuted` |
| `letterSpacing` | `double` | `1.6` |

Replace any `Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, ...))` with this.

---

### AppFilterRow (`lib/widgets/app_filter_row.dart`)

Horizontal scrollable pill-filter row. Two visual styles.

```dart
// Outline style (reference / default) — from offline_mode_screen
AppFilterRow(
  filters: const ['All', 'Priority', 'Met', 'Pending'],
  selected: _activeFilter,
  onSelect: (f) => setState(() => _activeFilter = f),
)

// Filled style — from dashboard_screen
AppFilterRow(
  filters: const ['Today', 'Week', 'Month'],
  selected: _period,
  onSelect: (p) => setState(() => _period = p),
  style: AppFilterRowStyle.filled,
  padding: const EdgeInsets.symmetric(horizontal: 12),
)
```

**Parameters:**

| Parameter | Type | Default |
|---|---|---|
| `filters` | `List<String>` | required |
| `selected` | `String` | required |
| `onSelect` | `ValueChanged<String>` | required |
| `style` | `AppFilterRowStyle` | `.outline` |
| `padding` | `EdgeInsetsGeometry?` | `null` |

**Styles:**
- `AppFilterRowStyle.outline` — inactive: dim border + muted text; active: accent border + accent text
- `AppFilterRowStyle.filled` — inactive: `surfaceElevated` fill + muted text; active: accent fill + white text

Filter chips have no box shadow.

---

### AppBottomNav (`lib/widgets/app_bottom_nav.dart`)

Single source of truth for bottom navigation. Never build a `_buildBottomNav()` method in a screen.

```dart
// Main tab screen (one tab is active)
AppBottomNav(
  selectedIndex: 0,
  onNavigate: _navigate,
)

// Pushed screen (no tab active)
AppBottomNav(
  selectedIndex: 4,  // sentinel value
  onNavigate: _navigate,
)
```

**selectedIndex mapping:**

| Value | Tab |
|---|---|
| `0` | Targets |
| `1` | Events |
| `2` | QR / Capture (center elevated) |
| `3` | Contacts |
| `5` | Profile |
| `4` | Sentinel — pushed screen, no tab highlighted |

When `selectedIndex == 2`, shows a 4-item scanner variant.

**Scaffold integration:**
```dart
Scaffold(
  bottomNavigationBar: AppBottomNav(
    selectedIndex: _selectedTab,
    onNavigate: _navigate,
  ),
  body: SafeArea(bottom: false, child: ...),
)
```

Always pair with `SafeArea(bottom: false)` on the body.

---

### Entry flow components (`lib/widgets/entry_flow_components.dart`)

For onboarding, auth, and splash screens only. `EntryPanel` and `EntrySoftTile` use `AppCard` internally.

| Widget | Description |
|---|---|
| `EntryFlowScaffold` | Full-screen scaffold with grid/glow background |
| `EntryFlowTopBar` | Top bar for entry screens |
| `EntryPanel` | Card panel (`AppCard`) |
| `EntrySoftTile` | Elevated tile (`AppCard(elevated: true)`) |
| `EntryEyebrow` | Small muted header label |
| `EntryChip` | Entry-specific chip |
| `EntryMetricCard` | Metric display card |
| `EntryPrimaryButton` | Pill gradient CTA button |
| `EntryTextField` | Styled text input |
| `EntryBullet` | Bullet-point list item |

---

## Mobile styling rules

### Cards
- Use `AppCard` always — never `Container + BoxDecoration`
- No box shadow on cards; gradient provides depth
- Radius: `20` standard · `28` hero · `16` compact · `12` small list rows
- `elevated: true` for inner panels or secondary rows

### Color — dark mode
- Background: near-black `#04060E`
- Cards: navy gradient `#0B1422 → #0F1B2E`
- Accent: vibrant blue `#4F7BFF`
- Avoid flat solid cards, light-navy backgrounds that blend with cards, and purple neon styling

### Buttons
- Filled/CTA: pill (radius 999), accent gradient, white text, uppercase
- Outlined/secondary: pill, `borderStrong` border, transparent fill
- Filter pills: always via `AppFilterRow`
- Min tap target: 44px height

### Typography
- Section labels: `AppSectionLabel` (10px uppercase muted)
- Headings: bold, compact, slightly negative letter spacing
- Inter applies globally — never call `GoogleFonts` in screens

### Spacing
- Outer page padding: `16`
- Card internal padding: `16–20`
- Section gaps: `12–18`
- Bottom scroll padding: `24` (nav bar handled by `Scaffold.bottomNavigationBar`)

---

## If an AI tool is editing a new screen

1. Use `AppCard` for every card/panel surface
2. Use `AppChip`, `AppSectionLabel`, `AppFilterRow` for their patterns
3. Add `AppBottomNav` to `Scaffold.bottomNavigationBar`
4. Pair with `SafeArea(bottom: false)` on body
5. Use `AppTheme.colorsOf(context)` for all colors — no hardcoded `Color(...)` values
6. Reference `offline_mode_screen.dart` if uncertain
7. Run `flutter analyze` — zero new warnings

---

## Do / Don't

### Do
- `AppCard` for every card surface
- `AppChip` / `AppSectionLabel` / `AppFilterRow` / `AppBottomNav` for their patterns
- Semantic tokens for all colors
- `SafeArea(bottom: false)` with `Scaffold.bottomNavigationBar`

### Don't
- `Container(decoration: BoxDecoration(...))` for cards
- Inline filter rows, chip containers, section labels, or nav bars
- `boxShadow` on cards
- Hardcoded `Color(...)` in screens
- `GoogleFonts` imports in screen files
- Per-screen `_buildBottomNav()` methods

---

## Migration status (June 2026)

- `AppCard` replaces all inline `Container + BoxDecoration` card patterns
- `AppChip` replaces all inline tag / label / status chip containers
- `AppSectionLabel` replaces all inline uppercase muted `Text` widgets
- `AppFilterRow` replaces all inline filter pill `ListView` patterns
- `AppBottomNav` replaces all per-screen `_buildBottomNav()` methods
- No `static const Color` fields in any screen file
- No `GoogleFonts` imports in any screen file

Pre-existing analyzer issues (unrelated — do not fix):
- `lib/widgets/premium_card.dart` — references `AppTheme.cardHoverShadow` / `AppTheme.cardShadow`
- `test/widget_test.dart` — missing `themeProvider` argument
