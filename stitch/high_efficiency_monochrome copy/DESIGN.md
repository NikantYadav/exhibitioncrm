---
name: High-Efficiency Monochrome
colors:
  surface: '#141313'
  surface-dim: '#141313'
  surface-bright: '#3a3939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353434'
  on-surface: '#e5e2e1'
  on-surface-variant: '#c4c7c8'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#8e9192'
  outline-variant: '#444748'
  surface-tint: '#c6c6c7'
  primary: '#ffffff'
  on-primary: '#2f3131'
  primary-container: '#e2e2e2'
  on-primary-container: '#636565'
  inverse-primary: '#5d5f5f'
  secondary: '#c6c6cf'
  on-secondary: '#2f3037'
  secondary-container: '#45464e'
  on-secondary-container: '#b4b4bd'
  tertiary: '#ffffff'
  on-tertiary: '#303030'
  tertiary-container: '#e4e2e1'
  on-tertiary-container: '#656464'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e2e2e2'
  primary-fixed-dim: '#c6c6c7'
  on-primary-fixed: '#1a1c1c'
  on-primary-fixed-variant: '#454747'
  secondary-fixed: '#e2e1eb'
  secondary-fixed-dim: '#c6c6cf'
  on-secondary-fixed: '#1a1b22'
  on-secondary-fixed-variant: '#45464e'
  tertiary-fixed: '#e4e2e1'
  tertiary-fixed-dim: '#c8c6c5'
  on-tertiary-fixed: '#1b1c1c'
  on-tertiary-fixed-variant: '#474746'
  background: '#141313'
  on-background: '#e5e2e1'
  surface-variant: '#353434'
typography:
  display-wordmark:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '800'
    lineHeight: 24px
    letterSpacing: -0.05em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Inter
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: '0'
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: '0'
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  label-xs:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.02em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  unit: 4px
  gutter: 16px
  margin-mobile: 16px
  margin-desktop: 32px
  container-max-width: 1280px
---

## Brand & Style
This design system is engineered for high-performance B2B environments where clarity and authority are paramount. It adopts a **Minimalist / Architectural** style, stripping away aesthetic noise to focus on information density and functional precision.

The brand personality is uncompromisingly professional, serious, and premium. It targets senior executives and power users who require a world-class interface that feels like a precision instrument. The emotional response is one of total control and clarity, achieved through a strict monochromatic palette, razor-sharp borders, and a systematic approach to typography.

## Colors
The palette is strictly achromatic, leveraging contrast rather than hue to establish hierarchy.

- **Background (#080808):** A deep, near-black that provides a solid foundation for high-contrast elements.
- **Primary (#FFFFFF):** Reserved for the most important information, wordmarks, and primary interactive states.
- **Secondary / Muted (#A1A1AA):** Used for supporting text, labels, and icons that should not draw immediate attention.
- **Hairline Borders (#262626):** Subtle dividers that define structure without cluttering the visual field. 

No functional or decorative color is permitted. Status is conveyed through iconography and stroke weight variations.

## Typography
The typography system relies exclusively on **Inter** to maintain a clean, neutral, and systematic appearance. 

- **The Wordmark:** Specifically uses `display-wordmark` settings—heavy weight, tight tracking, and uppercase—to create a geometric, "machined" look.
- **Hierarchy:** Headings use semi-bold weights with slight negative letter-spacing to appear more compact and authoritative. 
- **Data Density:** Labels utilize uppercase with increased letter-spacing (`label-sm`) to distinguish metadata from actionable body content.
- **Body Text:** Uses standard weights to ensure maximum legibility against the dark background.

## Layout & Spacing
The system uses a **Fixed Grid** approach for desktop and a **Fluid 4-Column Grid** for mobile.

- **Rhythm:** All spacing is based on a 4px baseline unit. 
- **Grid:** On desktop, a 12-column grid with 16px gutters ensures structured data alignment. 
- **Density:** High information density is prioritized. Vertical spacing between related items is kept tight (8px or 12px), while major sections are separated by 32px or 48px to prevent visual fatigue.
- **Safe Areas:** Generous side margins (32px+) are used on wide screens to maintain focus on the central content area, reinforcing the premium corporate feel.

## Elevation & Depth
In this system, depth is defined by **Low-Contrast Outlines** rather than shadows. 

- **Tiers:** Surfaces do not "float" using traditional shadows. Instead, depth is signaled by shifting background tones or adding hairline borders (#262626).
- **Cards:** Use a slightly lighter background than the base (e.g., #0C0C0C) combined with a 1px border to create a subtle layered effect.
- **Overlays:** Modals and menus use a solid #080808 background with a crisp #FFFFFF 1px border to pop from the background. 
- **Transparency:** Background blurs are used sparingly only for navigation bars to maintain content context without sacrificing the "solid" enterprise aesthetic.

## Shapes
The shape language is predominantly **Soft (0.25rem)** to maintain a disciplined, structural look.

- **Standard Elements:** Buttons, input fields, and cards use a 4px corner radius.
- **The Scan Button:** As a unique focal point, this uses a larger `rounded-lg` (8px) or `rounded-xl` (12px) radius to distinguish itself as the primary action.
- **Pills:** While the general system is soft-square, chips and secondary tags use a fully rounded (pill) shape to clearly differentiate them from primary navigation and input components.

## Components
Consistent execution of these components ensures the system feels like a singular, premium tool.

- **Primary Button:** Solid #FFFFFF background with #080808 text. No shadow, 4px radius.
- **Secondary Button / Chips:** Outlined with a #262626 stroke. Text is #A1A1AA. In active states, the border and text switch to #FFFFFF.
- **The Center Scan Button:** A standout black square with an 8px-12px corner radius, featuring a bold white icon. It sits centered in the bottom navigation, visually "elevated" through its distinct shape and scale.
- **Input Fields:** 1px #262626 border. On focus, the border transitions to #FFFFFF. Labels are always `label-sm` positioned above the field.
- **Cards:** Dark containers (#0C0C0C) with hairline #262626 borders. Headlines inside cards should be `headline-md`.
- **Lists:** Separated by 1px #262626 horizontal rules. High density with 12px vertical padding.
- **Checkboxes/Radios:** Pure #FFFFFF for selected states; 1px #262626 border for unselected states. No gradients or shadows.