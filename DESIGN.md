---
name: Exono
description: A precision lead-capture and relationship-memory CRM for exhibitions and events.
colors:
  background: "#EBF3FF"
  background-alt: "#D6E8FF"
  background-dark: "#000000"
  surface: "#F5F9FF"
  surface-alt: "#E0EEFF"
  surface-elevated: "#D0E4FF"
  surface-dark: "#0B1422"
  surface-alt-dark: "#0F1B2E"
  surface-elevated-dark: "#152538"
  border: "#D4E0F7"
  border-strong: "#B9C9EA"
  border-dark: "#1C2F4A"
  border-strong-dark: "#283F62"
  text-primary: "#18253B"
  text-secondary: "#50627F"
  text-muted: "#526A88"
  text-primary-dark: "#F0F6FF"
  text-secondary-dark: "#B5C6E4"
  text-muted-dark: "#7A90B5"
  accent: "#0672EF"
  accent-strong: "#0559C2"
  accent-soft: "#D6EAFD"
  accent-glow: "#B0D6FB"
  accent-dark: "#2B8BFF"
  accent-glow-dark: "#071C3A"
  destructive: "#DB5B68"
  destructive-dark: "#FF7A8A"
  success: "#3AAE7A"
  success-dark: "#5DC89A"
typography:
  display:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.7px"
  headline:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 700
  body:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "10px"
    fontWeight: 800
    letterSpacing: "0.8px"
rounded:
  input: "16px"
  card: "20px"
  large: "28px"
  button: "999px"
  chip: "4px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "#FFFFFF"
    rounded: "{rounded.button}"
    padding: "16px 24px"
  button-outline:
    backgroundColor: "transparent"
    textColor: "{colors.accent}"
    rounded: "{rounded.button}"
    padding: "16px 24px"
  card-primary:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.card}"
    padding: "16px"
  chip-status:
    textColor: "{colors.surface}"
    rounded: "{rounded.chip}"
    padding: "3px 8px"
---

# Design System: Exono

## 1. Overview

**Creative North Star: "The Glass Cockpit"**

Exono is built for two tempos of the same job: the frantic capture of a name and a face mid-conversation on a loud expo floor, and the calmer, considered review of that relationship weeks later. The Glass Cockpit metaphor holds both — an instrument panel a professional trusts under pressure, where every readout is legible at a glance and nothing is decorative. The cool, saturated blue that anchors the palette isn't a brand flourish; it's the signal color of a tool that works, the way an avionics display uses one disciplined hue for everything that matters.

This system explicitly rejects generic SaaS dashboard cliches (gradient-text metrics, identical icon-card grids, stacked eyebrow labels), Salesforce-style enterprise CRM clutter, and consumer social-app glossiness (heavy gradients, glassmorphism, bouncy motion). Exono is a field instrument, not a back office and not a feed.

**Key Characteristics:**
- One disciplined accent (Trust Blue) carries nearly all color signal; everything else is cool-tinted neutral.
- Flat by default — depth is reserved for surfaces that are genuinely elevated (active cards, sheets), not applied uniformly.
- Pill-shaped, high-confidence buttons; small-caps, bold-weight chip labels — tactile, not timid.
- Rounded-square avatars (not circles) — a deliberate, slightly technical departure from generic CRM/social conventions.

## 2. Colors

A cool, blue-tinted neutral system built around a single committed accent — restrained everywhere except the one place that matters: action and signal.

### Primary
- **Trust Blue** (`#0672EF` light / `#2B8BFF` dark): the only saturated color in the system. Used for primary buttons, active/focused states, links, selected nav items, and the accent gradient inside `AppAvatar`. Calm and dependable rather than alarm-bright — it reads as the color of something you rely on, not a flashing CTA.
- **Trust Blue Strong** (`#0559C2` light / `#0672EF` dark): pressed/hover states and emphasis text on the accent.

### Neutral
- **Glass Background** (`#EBF3FF` light / `#000000` dark): the cockpit's base surface — barely-there blue tint in light mode, true black in dark mode for an instrument-panel-at-night feel.
- **Panel Surface** (`#F5F9FF` light / `#0B1422` dark): card and input fill, one step lighter (or, in dark mode, one step up) from background.
- **Panel Surface Alt / Elevated** (`#E0EEFF` / `#D0E4FF` light, `#0F1B2E` / `#152538` dark): the gradient steps `cardDecoration` uses to give cards a subtle directional lift without a hard shadow.
- **Readout Ink** (`#18253B` light / `#F0F6FF` dark): primary text — near-navy-black, not a true black, to stay in the cool family.
- **Readout Secondary** (`#50627F` light / `#B5C6E4` dark): secondary text, body copy on muted contexts.
- **Readout Muted** (`#526A88` light / `#7A90B5` dark): placeholders, captions, disabled-adjacent text. Darkened from an earlier `#7E8FAC` to clear WCAG AA's 4.5:1 body-text contrast against both the background and surface tones.
- **Hairline Border** (`#D4E0F7` light / `#1C2F4A` dark): default dividers, card borders, input strokes.
- **Hairline Border Strong** (`#B9C9EA` light / `#283F62` dark): outline-button strokes, emphasis dividers.

### Status
- **Success** (`#3AAE7A` light / `#5DC89A` dark): "met" / followed-up / done states (see `AppAvatar.done`).
- **Destructive** (`#DB5B68` light / `#FF7A8A` dark): delete confirmations, validation errors.

### Named Rules
**The One Signal Rule.** Trust Blue is the only saturated color permitted. Status colors (success, destructive) are functional exceptions, never decorative ones — they appear only to confirm a state change or a destructive action, never as page chrome.

## 3. Typography

**Body & Display Font:** Inter (system-ui, sans-serif fallback)

**Character:** A single geometric-humanist sans carries the entire system, distinguished by weight and size rather than family — instrument-panel discipline: one typeface, calibrated steps, no ornamentation.

### Hierarchy
- **Display** (700, 32px / 28px / 24px, line-height 1.15, letter-spacing −0.5 to −0.7px): screen-level headings, rare — most screens use Headline instead.
- **Headline** (700, 16–20px): section headers, sheet/dialog titles, `AppHeader` titles.
- **Title** (700/600, 12–15px): card titles, list-item primary text.
- **Body** (400, 14px, line-height 1.5, max ~70ch): descriptions, form values, secondary content — always `textSecondary`, never primary ink, to keep primary ink reserved for headings and key labels.
- **Label** (800, 9–10px, letter-spacing 0.8px, uppercase): `AppChip` and `AppSectionLabel` text only — bold-weight small-caps is the system's one deliberate "loud at small size" move.

### Named Rules
**The Calibration Rule.** Every text role maps to an exact `context.theme.typography` step (`xs` / `sm` / `lg` / `xl` / `xl2`). Never hardcode `fontSize` — an uncalibrated size breaks the instrument-panel discipline the same way a mismatched gauge would.

## 4. Elevation

Flat by default. Most surfaces — list rows, inputs, sheets — carry no shadow at all; depth comes from a one-step lighter/darker fill (`surface` → `surfaceAlt` → `surfaceElevated`) and a hairline border. Shadow is reserved for genuinely elevated, attention-bearing surfaces: a card the user is meant to read as "lifted" off the cockpit panel, via `AppTheme.softShadow`.

### Shadow Vocabulary
- **Glow** (`BoxShadow(color: accentGlow @ 18–28% opacity, blurRadius: 40, spreadRadius: -12, offset: (0,14))`): a diffuse, accent-tinted halo under elevated cards — the system's signature depth cue, distinct from a generic gray drop shadow.
- **Ambient** (`BoxShadow(color: black @ 8–24% opacity, blurRadius: 18, spreadRadius: -8, offset: (0,8))`): paired with Glow to ground the lift with a neutral contact shadow.

### Named Rules
**The Flat-Unless-Lifted Rule.** A surface earns a shadow only when it represents something genuinely raised above the panel (a featured card, a modal sheet). Default list rows, inputs, and section containers stay flat with a hairline border — shadows on every card is the Salesforce-clutter failure mode this system rejects.

## 5. Components

Tactile and confident: pill-shaped buttons, bold small-caps chips, assertively bordered cards — built to be operated quickly and with certainty, never timid or over-refined.

### Buttons (`AppButton`)
- **Shape:** full pill (`999px` radius) for primary/secondary/destructive/outline; no radius for the `branded` variant's `8px`-rounded solid block.
- **Primary:** Trust Blue fill, white text (light mode) or near-black text on white fill (dark mode) — see `branded` variant's inverted treatment. Padding `24px` horizontal / `16px` vertical at `md` size.
- **Outline:** transparent fill, `borderStrong` stroke, Trust Blue text (the wrapper locally overrides forui's `secondaryForeground` so outline text never renders white-on-white).
- **Ghost:** no fill, `mutedForeground` text — used for low-emphasis or cancel actions, rendered manually rather than via raw `FButton.ghost` to guarantee readable text on any background.
- **Destructive:** same pill shape, mapped to the destructive color role.
- **Loading:** label is swapped for a 16px `FCircularProgress`; button is disabled.

### Chips (`AppChip`)
- **Style:** filled rectangle, `4px` radius (deliberately squarer than the button's full pill — chips read as data tags, not actions), `9px` bold (800 weight) uppercase text with `0.8px` tracking.
- **Variants:** `AppChip` (neutral tag, `surfaceElevated` fill + `textMuted` label), `AppChip.label` (same treatment, semantic alias for badge-style use), `AppChip.status` (caller-supplied solid color fill + light text, e.g. green "MET").

### Cards / Containers (`AppCard`)
- **Corner Style:** `16px` default radius (`20px`/`radiusCard` token used directly in `AppTheme.cardDecoration` for hand-rolled cards).
- **Background:** flat `surface` fill by default; `cardDecoration(elevated: true)` steps up through `surfaceAlt`/`surfaceElevated` with a directional gradient for cards that need to read as lifted.
- **Shadow Strategy:** none by default (see Elevation); only hand-rolled "elevated" cards opt into the Glow + Ambient pair.
- **Border:** hairline `border` at 85–90% opacity — present on essentially every card, the primary depth cue in the flat-by-default system.
- **Internal Padding:** `16px` is the standard card padding.

### Inputs / Fields (`AppInput`)
- **Style:** filled `surfaceAlt` background, `16px` radius, `1px` hairline border.
- **Focus:** border shifts to Trust Blue at `1.6px` width — no glow, no color wash, just a crisper stroke.
- **Error:** border shifts to `destructive`, both at rest and on focus.

### Avatars (`AppAvatar`)
- **Shape:** rounded square (`12px` radius) — a deliberate departure from circular avatars used by most CRM/social products, reinforcing the instrument-panel rather than social-feed register.
- **Default:** Trust Blue gradient fill (22%→10% alpha) with a Trust Blue border at 25% alpha; bold initials in Trust Blue.
- **Done state:** swaps to a success-green gradient + centered check icon — the system's clearest "this is handled" signal.

### Navigation (`AppHeader`)
- Transparent background, no elevation; title uses Headline weight/size; icons use `textSecondary`/`textPrimary` per emphasis.

## 6. Do's and Don'ts

### Do:
- **Do** keep Trust Blue (`#0672EF` / `#2B8BFF`) as the only saturated color in any screen — it should read as rare and deliberate, the signal among neutrals.
- **Do** default to flat surfaces with a hairline border; reserve the Glow+Ambient shadow pair for genuinely elevated cards only.
- **Do** use rounded-square `AppAvatar` for every contact representation — never a circle.
- **Do** keep buttons full-pill (`999px`) and chips squared (`4px`) — the shape contrast is intentional: pills act, chips label.
- **Do** route every text size through `context.theme.typography` steps; never hardcode `fontSize`.

### Don't:
- **Don't** introduce a second saturated accent color or a gradient-text treatment — emphasis comes from weight/size, never from color-gradient fills on type.
- **Don't** add shadows to every card uniformly — that is the Salesforce-style enterprise clutter this system explicitly rejects.
- **Don't** use glassmorphism, heavy gradients, or bouncy/elastic motion anywhere — Exono is not a consumer social app.
- **Don't** stack icon+heading+text cards into identical repeating grids — the generic SaaS dashboard cliche PRODUCT.md calls out by name.
- **Don't** use a side-stripe colored border (`border-left`/`border-right` as an accent) on cards, list items, or alerts — use the hairline border + background tint pattern instead.
- **Don't** render contact avatars as circles or hand-rolled containers — always `AppAvatar`.
