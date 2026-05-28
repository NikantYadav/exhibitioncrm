# CRM Frontend Design System

**Version:** 2.0  
**Last Updated:** February 2026  
**Purpose:** Comprehensive UI styling guide for maintaining visual consistency across the CRM platform

---

## Table of Contents

1. [Design Philosophy](#design-philosophy)
2. [Color System](#color-system)
3. [Typography](#typography)
4. [Spacing & Layout](#spacing--layout)
5. [Components](#components)
6. [Patterns & Compositions](#patterns--compositions)
7. [Animations & Transitions](#animations--transitions)
8. [Accessibility](#accessibility)
9. [Implementation Guidelines](#implementation-guidelines)
10. [Code Examples](#code-examples)

---

## Design Philosophy

### Core Principles

**Calm, Near-Monochrome Aesthetic**
- Restrained color palette dominated by stone grays (neutral tones)
- Single accent color (indigo #4F46E5) used sparingly for primary actions
- Emphasis on whitespace, subtle shadows, and refined typography
- Premium feel through attention to detail and craftsmanship
- Soft gradient background wash for depth without distraction
- Faint noise texture overlay (1.5% opacity) for tactile quality

**Visual Hierarchy**
- Typography weight and size create clear information hierarchy
- Generous spacing prevents visual clutter (16px base, 48px+ sections)
- Soft shadows and borders define surfaces without harsh lines
- Consistent use of rounded corners (24px for cards, 12px for buttons)
- Inset highlights on cards for premium glass-like effect

**Interaction Design**
- Smooth, subtle transitions (150ms ease-out for all interactions)
- Hover states provide gentle feedback (-2px lift, border color change)
- Active states use scale (0.98) for tactile feel
- Loading states use skeleton loaders with shimmer animation
- Focus rings use calm indigo with 30% opacity
- Touch targets minimum 44x44px on mobile devices

**Mobile-First Responsive**
- Touch targets minimum 44x44px
- Generous padding on mobile (20px)
- Responsive grid layouts (1/2/3/4 columns)
- Collapsible navigation and adaptive components
- Swipe gestures for mobile interactions

**Performance & Accessibility**
- System fonts for optimal performance
- WCAG AA contrast minimum (AAA preferred)
- Semantic HTML structure
- Keyboard navigation support
- Screen reader friendly markup

---

## Color System

### Primary Palette

```css
/* CSS Variables (defined in globals.css) */
--background: 210 20% 98%;        /* #F8FAFB - Page background */
--foreground: 222 47% 11%;        /* #1C1917 - Primary text */
--card: 0 0% 100%;                /* #FFFFFF - Card surfaces */
--primary: 239 84% 67%;           /* #6366F1 - Indigo accent (HSL) */
--primary-foreground: 0 0% 100%;  /* #FFFFFF - Text on primary */
--border: 214 32% 91%;            /* Border color */
--input: 214 32% 91%;             /* Input border */
--ring: 239 84% 67%;              /* Focus ring color */
--radius: 1.5rem;                 /* 24px - Base border radius */
```

### Indigo Accent (Primary)

```typescript
// Primary indigo - use sparingly
primary: #4F46E5           // Indigo-600 (main)
primary-hover: #4338CA     // Indigo-700 (hover state)
primary-light: #6366F1     // Indigo-500 (lighter variant)
primary-foreground: #FFFFFF // Text on primary

// Gradient variant for premium buttons
gradient: linear-gradient(to right, #4F46E5, #4338CA)
```

### Stone Palette (Neutral Scale)

The stone palette is the foundation of the design system. Use these values consistently:

```typescript
// Tailwind stone colors - PRIMARY NEUTRAL PALETTE
stone-50:  #FAFAF9  // Lightest backgrounds, subtle fills, journey stages
stone-100: #F5F5F4  // Secondary backgrounds, hover states, empty state icons
stone-200: #E7E5E4  // Borders, dividers, disabled states, skeleton base
stone-300: #D6D3D1  // Hover borders, inactive elements, timeline dots
stone-400: #A8A29E  // Placeholder text, secondary icons
stone-500: #78716C  // Secondary text, captions, timestamps
stone-600: #57534E  // Body text, labels, descriptions
stone-700: #44403C  // Emphasis text, headings, navigation text
stone-800: #292524  // Strong emphasis, important labels
stone-900: #1C1917  // Primary headings, high contrast text, active nav
```

### Semantic Colors

```typescript
// Success (Green)
success: #10B981           // Green-500 - success actions, positive states
success-bg: #D1FAE5        // Green-100 - success backgrounds
success-text: #065F46      // Green-800 - text on success backgrounds
success-border: #6EE7B7    // Green-300 - success borders

// Warning (Amber)
warning: #F59E0B           // Amber-500 - warning actions, caution states
warning-bg: #FEF3C7        // Amber-100 - warning backgrounds
warning-text: #92400E      // Amber-800 - text on warning backgrounds
warning-border: #FCD34D    // Amber-300 - warning borders

// Error/Destructive (Red)
destructive: #EF4444       // Red-500 - error states, delete actions
destructive-bg: #FEE2E2    // Red-100 - error backgrounds
destructive-text: #991B1B  // Red-800 - text on error backgrounds
destructive-border: #FCA5A5 // Red-300 - error borders

// Info (Blue)
info: #3B82F6              // Blue-500 - informational states
info-bg: #DBEAFE           // Blue-100 - info backgrounds
info-text: #1E40AF         // Blue-800 - text on info backgrounds
info-border: #93C5FD       // Blue-300 - info borders
```

### Background System

```css
/* Page background - soft gradient wash */
body {
  background: linear-gradient(180deg,
    rgb(248, 250, 252) 0%,    /* stone-50 tint */
    rgb(252, 252, 253) 50%,   /* near white */
    rgb(248, 250, 252) 100%   /* stone-50 tint */
  );
  background-attachment: fixed;
}

/* Faint noise texture overlay */
body::before {
  opacity: 0.015;
  background-image: url("data:image/svg+xml,..."); /* SVG noise filter */
}
```

### Usage Guidelines

**Primary Color (Indigo) - Use Sparingly**
- Primary CTAs and main action buttons ONLY
- Active navigation states
- Focus rings and keyboard navigation indicators
- Progress indicators and loading states
- Links in body text (use stone-700 for navigation)
- NEVER use for decorative purposes or backgrounds

**Stone Palette - Primary Workhorse**
- stone-50/100: Backgrounds, subtle fills, hover states
- stone-200/300: Borders, dividers, disabled states
- stone-400/500: Secondary text, placeholders, captions
- stone-600/700: Body text, labels, navigation
- stone-800/900: Headings, emphasis, active states

**Semantic Colors - Consistent Meaning**
- Use consistently for their intended purpose only
- Always pair with appropriate background tints
- Ensure sufficient contrast (WCAG AA minimum: 4.5:1)
- Use border variants for subtle emphasis

**Color Contrast Requirements**
- Body text (stone-600): 7:1 contrast ratio (AAA)
- Headings (stone-900): 12:1 contrast ratio
- Secondary text (stone-500): 4.5:1 contrast ratio (AA)
- Interactive elements: 3:1 contrast ratio minimum

---

## Typography

### Font Stack

```css
font-family: -apple-system, BlinkMacSystemFont, 'Inter', 'Segoe UI', system-ui, sans-serif;
```

System fonts provide native feel, optimal performance, and excellent readability. No web fonts required.

### Type Scale & Hierarchy


Use these predefined text classes consistently throughout the application:

```css
/* Display - Page titles, hero headings */
.text-display {
  font-size: 1.875rem;      /* 30px */
  font-weight: 600;         /* Semibold */
  color: #1C1917;          /* stone-900 */
  line-height: 1.2;
  letter-spacing: -0.025em; /* Tight tracking */
}

/* Section Header - Major section titles */
.text-section-header {
  font-size: 1.125rem;      /* 18px */
  font-weight: 600;         /* Semibold */
  color: #1C1917;          /* stone-900 */
  line-height: 1.3;
  letter-spacing: -0.015em;
}

/* Card Title - Card and component titles */
.text-card-title {
  font-size: 0.875rem;      /* 14px */
  font-weight: 600;         /* Semibold */
  color: #1C1917;          /* stone-900 */
  line-height: 1.4;
  letter-spacing: -0.01em;
}

/* Body - Default body text */
.text-body {
  font-size: 0.875rem;      /* 14px */
  font-weight: 400;         /* Normal */
  color: #57534E;          /* stone-600 */
  line-height: 1.6;         /* Relaxed */
}

/* Caption - Small text, timestamps, metadata */
.text-caption {
  font-size: 0.75rem;       /* 12px */
  font-weight: 400;         /* Normal */
  color: #78716C;          /* stone-500 */
  line-height: 1.5;
}
```

### Font Weight Guidelines

```typescript
// Use only these weights for consistency
font-normal: 400   // Body text, descriptions
font-medium: 500   // Subtle emphasis (use sparingly)
font-semibold: 600 // Headings, labels, buttons
font-bold: 700     // Strong emphasis (rarely used)
```

### Typography Rules

1. **Hierarchy through size and weight**: Use larger sizes and semibold weight for headings
2. **Limited weights**: Stick to normal (400) and semibold (600) for 90% of text
3. **Generous line height**: Use 1.5-1.6 for body text for readability
4. **Tight tracking on headings**: Negative letter-spacing (-0.025em) for display text
5. **Color for hierarchy**: stone-900 for headings, stone-600 for body, stone-500 for captions


---

## Spacing & Layout

### Spacing Scale

Use Tailwind's spacing scale consistently. Key values:

```typescript
// Tailwind spacing (1 unit = 0.25rem = 4px)
0:   0px      // No spacing
1:   4px      // Minimal spacing
2:   8px      // Tight spacing
3:   12px     // Small spacing
4:   16px     // Base spacing (default)
6:   24px     // Medium spacing
8:   32px     // Large spacing
12:  48px     // Section spacing
16:  64px     // Major section spacing
20:  80px     // Page section spacing
24:  96px     // Hero spacing
```

### Layout Patterns

**Container Widths**
```css
max-w-7xl: 1280px  /* Main content container */
max-w-4xl: 896px   /* Narrow content (forms, articles) */
max-w-2xl: 672px   /* Very narrow (modals, dialogs) */
```

**Grid Layouts**
```css
/* Responsive grid - cards, items */
grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6

/* Two-column layout - detail pages */
grid grid-cols-1 lg:grid-cols-3 gap-8
/* Main content: col-span-2, Sidebar: col-span-1 */
```

**Padding Standards**
```css
/* Cards */
p-6: 24px padding (default card padding)
p-8: 32px padding (large cards)

/* Page containers */
px-4 py-6: Mobile (16px horizontal, 24px vertical)
px-6 py-8: Tablet (24px horizontal, 32px vertical)
px-8 py-12: Desktop (32px horizontal, 48px vertical)

/* Sections */
mb-12: 48px (module gap between related sections)
mb-16: 64px (section gap between major sections)
```

### Responsive Breakpoints

```typescript
// Tailwind breakpoints
sm:  640px   // Small tablets
md:  768px   // Tablets
lg:  1024px  // Small laptops
xl:  1280px  // Desktops
2xl: 1536px  // Large desktops
```

### Layout Rules

1. **Generous whitespace**: Never crowd elements, use minimum 16px spacing
2. **Consistent padding**: Use p-6 (24px) for cards, p-4 (16px) for mobile
3. **Section gaps**: Use mb-12 (48px) between modules, mb-16 (64px) between sections
4. **Grid gaps**: Use gap-6 (24px) for card grids, gap-4 (16px) for tight lists
5. **Max widths**: Constrain content to max-w-7xl for readability


---

## Components

### Buttons

**Variants**

```typescript
// Primary - Main CTAs only
variant="primary"
className="bg-gradient-to-r from-indigo-600 to-indigo-700 text-white shadow-md hover:shadow-lg"

// Secondary - Alternative actions
variant="secondary"
className="bg-white text-stone-700 border border-stone-300 hover:bg-stone-50"

// Ghost - Tertiary actions, icon buttons
variant="ghost"
className="text-stone-600 hover:bg-stone-100"

// Destructive - Delete, remove actions
variant="destructive"
className="bg-red-600 text-white shadow-md hover:bg-red-700"
```

**Sizes**

```typescript
size="sm"   // h-9 px-3 text-xs (36px height)
size="md"   // h-10 px-4 py-2 (40px height) - DEFAULT
size="lg"   // h-11 px-8 (44px height)
size="icon" // h-10 w-10 (40x40px square)
```

**States**

```typescript
// Loading state
<Button loading={true}>Save Changes</Button>
// Shows spinner + text, disabled automatically

// Disabled state
<Button disabled={true}>Submit</Button>
// opacity-50, pointer-events-none

// Active state (automatic)
active:scale-[0.98] // Slight scale down on click
```

**Usage Rules**
- Use PRIMARY variant sparingly (1-2 per page maximum)
- Secondary for alternative actions
- Ghost for tertiary actions and icon buttons
- Destructive ONLY for delete/remove actions
- Minimum 44x44px touch target on mobile
- Always include loading state for async actions


### Cards

**Base Card Styling**

```css
.premium-card {
  border-radius: 24px;           /* rounded-3xl */
  background: white;
  border: 1px solid rgba(231, 229, 228, 0.4); /* stone-200/40 */
  box-shadow: 
    inset 0 1px 0 rgba(255, 255, 255, 0.7),  /* Inner highlight */
    0 1px 2px rgba(0, 0, 0, 0.04),            /* Subtle shadow */
    0 12px 30px -4px rgba(0, 0, 0, 0.06);     /* Soft depth */
}

.premium-card:hover {
  transform: translateY(-2px);   /* Gentle lift */
  border-color: rgba(214, 211, 209, 0.5); /* stone-300/50 */
  box-shadow: 
    inset 0 1px 0 rgba(255, 255, 255, 0.7),
    0 4px 6px -1px rgba(0, 0, 0, 0.05),
    0 20px 40px -8px rgba(0, 0, 0, 0.08);
}
```

**Card Structure**

```tsx
<Card hoverable>
  <CardHeader>
    <CardTitle>Card Title</CardTitle>
    <CardDescription>Optional description</CardDescription>
  </CardHeader>
  <CardContent>
    {/* Main content */}
  </CardContent>
  <CardFooter>
    {/* Actions or metadata */}
  </CardFooter>
</Card>
```

**Card Variants**

```typescript
// Standard card (default)
<Card className="p-6">

// Hoverable card (interactive)
<Card hoverable className="cursor-pointer">

// Compact card
<Card className="p-4">

// Large card
<Card className="p-8">
```

**Usage Rules**
- Always use rounded-3xl (24px) border radius
- Default padding: p-6 (24px)
- Add hoverable prop for interactive cards
- Use CardHeader for titles and descriptions
- CardFooter for actions or metadata
- Maintain consistent spacing: mb-6 between header and content


### Inputs & Forms

**Input Styling**

```tsx
<Input
  label="Email Address"
  type="email"
  placeholder="you@example.com"
  error="Invalid email address"
/>
```

**Input States**

```css
/* Default */
border: 1px solid hsl(var(--input));  /* stone-200 */
background: white;
height: 40px;
padding: 8px 12px;
border-radius: 6px;

/* Focus */
outline: none;
ring: 2px solid rgba(99, 102, 241, 0.3);  /* indigo with opacity */
border-color: #6366F1;  /* indigo */

/* Error */
border-color: #EF4444;  /* red-500 */
ring: 2px solid rgba(239, 68, 68, 0.2);

/* Disabled */
opacity: 0.5;
cursor: not-allowed;
background: #F5F5F4;  /* stone-100 */
```

**Form Layout**

```tsx
<div className="space-y-4">
  <Input label="First Name" />
  <Input label="Last Name" />
  <Input label="Email" type="email" />
</div>
```

**Form Rules**
- Always include labels for accessibility
- Use space-y-4 (16px) between form fields
- Show error messages below inputs
- Disable submit button during loading
- Use placeholder text sparingly (not a replacement for labels)
- Minimum 40px height for touch targets


### Modals

**Modal Structure**

```tsx
<Modal
  isOpen={isOpen}
  onClose={onClose}
  title="Modal Title"
  size="md"  // sm | md | lg | xl
  headerActions={<Button variant="ghost">Action</Button>}
>
  {/* Modal content */}
</Modal>
```

**Modal Sizes**

```typescript
sm: max-w-md   (448px)  // Small dialogs, confirmations
md: max-w-lg   (512px)  // Default, forms
lg: max-w-2xl  (672px)  // Large forms, content
xl: max-w-4xl  (896px)  // Full-featured modals
```

**Modal Styling**

```css
/* Backdrop */
background: rgba(0, 0, 0, 0.4);
backdrop-filter: blur(4px);

/* Modal container */
border-radius: 16px;  /* rounded-2xl */
background: white;
box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
ring: 1px solid rgba(28, 25, 23, 0.05);
max-height: 90vh;

/* Header */
border-bottom: 1px solid #F5F5F4;  /* stone-100 */
padding: 16px 24px;

/* Content */
padding: 24px;
overflow-y: auto;
```

**Modal Rules**
- Always provide onClose handler
- Lock body scroll when modal is open
- Use backdrop blur for depth
- Animate entry with fade-in-up
- Close on backdrop click
- Include close button (X) in header
- Max height 90vh with scrollable content


### Badges

**Badge Variants**

```tsx
<Badge variant="default">Default</Badge>
<Badge variant="success">Success</Badge>
<Badge variant="warning">Warning</Badge>
<Badge variant="error">Error</Badge>
<Badge variant="info">Info</Badge>
<Badge variant="outline">Outline</Badge>
```

**Badge Styling**

```css
/* Base */
display: inline-flex;
align-items: center;
border-radius: 9999px;  /* fully rounded */
padding: 2px 10px;
font-size: 12px;
font-weight: 600;

/* Success */
background: #D1FAE5;  /* green-100 */
color: #065F46;       /* green-800 */

/* Warning */
background: #FEF3C7;  /* amber-100 */
color: #92400E;       /* amber-800 */

/* Error */
background: #FEE2E2;  /* red-100 */
color: #991B1B;       /* red-800 */

/* Info */
background: #DBEAFE;  /* blue-100 */
color: #1E40AF;       /* blue-800 */
```

**Badge Rules**
- Use semantic variants consistently
- Keep text short (1-2 words)
- Use for status indicators, counts, labels
- Pair with icons when appropriate
- Ensure sufficient contrast (WCAG AA)


### Empty States

**Empty State Structure**

```tsx
<EmptyState
  icon={<Icon className="h-12 w-12" />}
  title="No contacts yet"
  description="Get started by adding your first contact"
  action={<Button>Add Contact</Button>}
/>
```

**Empty State Styling**

```css
/* Container */
display: flex;
flex-direction: column;
align-items: center;
text-align: center;
padding: 48px 16px;

/* Icon container */
width: 96px;
height: 96px;
border-radius: 50%;
background: #F5F5F4;  /* stone-100 */
color: #D6D3D1;       /* stone-300 */
display: flex;
align-items: center;
justify-content: center;

/* Title */
font-size: 18px;
font-weight: 600;
color: #1C1917;  /* stone-900 */
margin-top: 16px;

/* Description */
font-size: 14px;
color: #78716C;  /* stone-500 */
max-width: 448px;
margin-top: 4px;

/* Action */
margin-top: 24px;
```

**Empty State Rules**
- Use for zero states, no results, errors
- Include relevant icon (24x24px in 96x96px circle)
- Clear, actionable title
- Brief, helpful description
- Optional CTA button
- Center align all content


### Loading States

**Skeleton Loader**

```css
.skeleton {
  background: linear-gradient(
    to right,
    #E7E5E4 0%,    /* stone-200 */
    #F5F5F4 50%,   /* stone-100 */
    #E7E5E4 100%   /* stone-200 */
  );
  background-size: 200% 100%;
  animation: shimmer 2s ease-in-out infinite;
  border-radius: 12px;
}

@keyframes shimmer {
  0% { background-position: -200% 0; }
  100% { background-position: 200% 0; }
}
```

**Skeleton Usage**

```tsx
// Card skeleton
<div className="premium-card p-6">
  <div className="skeleton h-6 w-32 mb-4" />
  <div className="skeleton h-4 w-full mb-2" />
  <div className="skeleton h-4 w-3/4" />
</div>

// List skeleton
<div className="space-y-3">
  {[1, 2, 3].map(i => (
    <div key={i} className="skeleton h-16 w-full" />
  ))}
</div>
```

**Spinner (Button Loading)**

```tsx
<svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
  <circle className="opacity-25" cx="12" cy="12" r="10" 
    stroke="currentColor" strokeWidth="4" />
  <path className="opacity-75" fill="currentColor" 
    d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
</svg>
```

**Loading Rules**
- Use skeleton loaders for initial page loads
- Use spinners for button actions
- Match skeleton shapes to actual content
- Animate with shimmer effect (2s duration)
- Never show blank screens - always show loading state


---

## Patterns & Compositions

### Navigation

**Sidebar Navigation**

```css
/* Sidebar container */
width: 256px;  /* w-64 */
background: white;
border-right: 1px solid #E7E5E4;  /* stone-200 */
padding: 24px 16px;

/* Nav item - inactive */
.sidebar-inactive {
  color: #78716C;  /* stone-500 */
  padding: 8px 12px;
  border-radius: 8px;
  transition: all 150ms ease-out;
}

.sidebar-inactive:hover {
  background: #F5F5F4;  /* stone-100 */
  color: #1C1917;       /* stone-900 */
}

/* Nav item - active */
.sidebar-active {
  background: #1C1917;  /* stone-900 */
  color: white;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}
```

**Pill Navigation (Tabs)**

```css
/* Pill container */
.nav-pill {
  padding: 6px 16px;
  border-radius: 9999px;
  font-size: 14px;
  font-weight: 500;
  transition: all 150ms ease-out;
  cursor: pointer;
}

/* Active pill */
.nav-pill-active {
  background: #1C1917;  /* stone-900 */
  color: white;
}

/* Inactive pill */
.nav-pill-inactive {
  color: #57534E;  /* stone-600 */
}

.nav-pill-inactive:hover {
  color: #1C1917;      /* stone-900 */
  background: #F5F5F4; /* stone-100 */
}
```


### Lists & Tables

**List Item Pattern**

```tsx
<div className="space-y-2">
  {items.map(item => (
    <div key={item.id} className="lead-card">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Avatar />
          <div>
            <h4 className="text-sm font-semibold text-stone-900">
              {item.name}
            </h4>
            <p className="text-xs text-stone-500">
              {item.subtitle}
            </p>
          </div>
        </div>
        <Badge variant="success">Active</Badge>
      </div>
    </div>
  ))}
</div>
```

**Lead Card Styling**

```css
.lead-card {
  border-radius: 8px;
  background: white;
  border: 1px solid rgba(231, 229, 228, 0.4);
  padding: 12px;
  margin-bottom: 8px;
  transition: all 150ms ease-out;
  cursor: pointer;
}

.lead-card:hover {
  transform: translateY(-1px);
  border-color: #D6D3D1;  /* stone-300 */
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.04);
}
```

**Table Pattern**

```tsx
<div className="overflow-x-auto">
  <table className="w-full">
    <thead className="border-b border-stone-200">
      <tr>
        <th className="text-left text-xs font-semibold text-stone-700 pb-3">
          Name
        </th>
        <th className="text-left text-xs font-semibold text-stone-700 pb-3">
          Status
        </th>
      </tr>
    </thead>
    <tbody className="divide-y divide-stone-100">
      <tr className="hover:bg-stone-50">
        <td className="py-3 text-sm text-stone-900">John Doe</td>
        <td className="py-3"><Badge variant="success">Active</Badge></td>
      </tr>
    </tbody>
  </table>
</div>
```


### Timeline & Activity

**Timeline Item**

```tsx
<div className="timeline-item">
  <div className="timeline-dot" />
  <div className="flex-1">
    <p className="text-sm text-stone-900">
      <span className="font-semibold">John Doe</span> added a note
    </p>
    <p className="text-xs text-stone-500 mt-1">2 hours ago</p>
  </div>
</div>
```

**Timeline Styling**

```css
.timeline-item {
  display: flex;
  gap: 12px;
  padding: 12px;
  border-radius: 8px;
  transition: all 150ms ease-out;
  cursor: pointer;
}

.timeline-item:hover {
  background: #FAFAF9;  /* stone-50 */
}

.timeline-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #D6D3D1;  /* stone-300 */
  margin-top: 8px;
  flex-shrink: 0;
}
```

**Activity Feed Pattern**

```tsx
<div className="space-y-1">
  {activities.map(activity => (
    <div key={activity.id} className="timeline-item">
      <div className="timeline-dot" />
      <div className="flex-1">
        <p className="text-sm text-stone-900">
          {activity.description}
        </p>
        <p className="text-xs text-stone-500 mt-1">
          {activity.timestamp}
        </p>
      </div>
    </div>
  ))}
</div>
```


### Avatars & User Display

**Avatar Sizes**

```tsx
// Small - 32px
<div className="h-8 w-8 rounded-full bg-stone-200" />

// Medium - 40px (default)
<div className="h-10 w-10 rounded-full bg-stone-200" />

// Large - 48px
<div className="h-12 w-12 rounded-full bg-stone-200" />

// Extra Large - 64px
<div className="h-16 w-16 rounded-full bg-stone-200" />
```

**Avatar with Status**

```tsx
<div className="relative">
  <img className="h-10 w-10 rounded-full" src={avatar} alt={name} />
  <span className="avatar-status-dot bg-green-500" />
</div>
```

**Avatar Group (Overlapping)**

```tsx
<div className="flex -space-x-2">
  {users.map((user, i) => (
    <img
      key={user.id}
      className="h-8 w-8 rounded-full ring-2 ring-white"
      src={user.avatar}
      alt={user.name}
      style={{ zIndex: users.length - i }}
    />
  ))}
</div>
```

**Avatar Styling**

```css
/* Status dot */
.avatar-status-dot {
  position: absolute;
  bottom: 0;
  right: 0;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  border: 2px solid white;
}

/* Overlapping avatars */
.avatar-overlap {
  margin-left: -8px;
}

.avatar-overlap:first-child {
  margin-left: 0;
}
```


### Stats & Metrics

**Stat Card Pattern**

```tsx
<Card className="p-6">
  <div className="flex items-center justify-between">
    <div>
      <p className="text-caption">Total Contacts</p>
      <p className="text-3xl font-semibold text-stone-900 mt-2">
        1,234
      </p>
      <p className="text-xs text-green-600 mt-2">
        +12% from last month
      </p>
    </div>
    <div className="h-12 w-12 rounded-full bg-indigo-100 flex items-center justify-center">
      <Icon className="h-6 w-6 text-indigo-600" />
    </div>
  </div>
</Card>
```

**Metric Display**

```tsx
<div className="grid grid-cols-1 md:grid-cols-3 gap-6">
  <div className="text-center">
    <p className="text-4xl font-semibold text-stone-900">1.2K</p>
    <p className="text-sm text-stone-500 mt-1">Total Leads</p>
  </div>
  <div className="text-center">
    <p className="text-4xl font-semibold text-stone-900">87%</p>
    <p className="text-sm text-stone-500 mt-1">Conversion Rate</p>
  </div>
  <div className="text-center">
    <p className="text-4xl font-semibold text-stone-900">$45K</p>
    <p className="text-sm text-stone-500 mt-1">Revenue</p>
  </div>
</div>
```

**Progress Indicator**

```tsx
<div>
  <div className="flex justify-between text-sm mb-2">
    <span className="text-stone-600">Progress</span>
    <span className="font-semibold text-stone-900">75%</span>
  </div>
  <div className="h-2 bg-stone-100 rounded-full overflow-hidden">
    <div 
      className="h-full bg-indigo-600 rounded-full transition-all duration-500"
      style={{ width: '75%' }}
    />
  </div>
</div>
```


---

## Animations & Transitions

### Transition Standards

**Base Transition**

```css
.transition-smooth {
  transition: all 150ms ease-out;
}
```

Use this class for all interactive elements (buttons, cards, links).

### Animation Keyframes

**Fade In Up**

```css
@keyframes fade-in-up {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-fade-in-up {
  animation: fade-in-up 400ms ease-out forwards;
}
```

**Shimmer (Loading)**

```css
@keyframes shimmer {
  0% {
    background-position: -200% 0;
  }
  100% {
    background-position: 200% 0;
  }
}

.animate-shimmer {
  animation: shimmer 2s ease-in-out infinite;
}
```

**Spin (Loading)**

```css
@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.animate-spin {
  animation: spin 1s linear infinite;
}
```

**Count Up (Numbers)**

```css
@keyframes count-up {
  from {
    opacity: 0;
    transform: translateY(5px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-count-up {
  animation: count-up 600ms ease-out;
}
```


### Interaction States

**Hover States**

```css
/* Cards */
hover:transform hover:translateY(-2px)
hover:border-stone-300/50
hover:shadow-card-hover

/* Buttons */
hover:shadow-lg  /* Primary buttons */
hover:bg-stone-50  /* Secondary buttons */
hover:bg-stone-100  /* Ghost buttons */

/* Links */
hover:text-stone-900
hover:underline
```

**Active States**

```css
/* All interactive elements */
active:scale-[0.98]

/* Buttons get automatic scale down on click */
```

**Focus States**

```css
.focus-ring {
  focus-visible:outline-none
  focus-visible:ring-2
  focus-visible:ring-indigo-400/30
  focus-visible:border-indigo-400
}
```

**Disabled States**

```css
disabled:opacity-50
disabled:pointer-events-none
disabled:cursor-not-allowed
```

### Animation Rules

1. **Duration**: 150ms for micro-interactions, 400ms for page transitions
2. **Easing**: Use ease-out for natural deceleration
3. **Hover lift**: -2px translateY for cards, -1px for list items
4. **Scale**: 0.98 for active/pressed states
5. **Loading**: 2s shimmer animation, infinite loop
6. **Entrance**: fade-in-up for modals and new content
7. **Performance**: Use transform and opacity (GPU accelerated)


---

## Accessibility

### WCAG Compliance

**Contrast Requirements**

```typescript
// Minimum contrast ratios (WCAG AA)
Body text (14px+): 4.5:1
Large text (18px+): 3:1
UI components: 3:1

// Our implementation
stone-900 on white: 12:1 (AAA) - Headings
stone-600 on white: 7:1 (AAA) - Body text
stone-500 on white: 4.5:1 (AA) - Secondary text
indigo-600 on white: 4.5:1 (AA) - Primary buttons
```

**Color Usage**

- Never rely on color alone to convey information
- Use icons, labels, or text alongside color
- Provide text alternatives for visual content
- Test with color blindness simulators

### Keyboard Navigation

**Focus Management**

```tsx
// All interactive elements must be keyboard accessible
<button className="focus-ring">Click me</button>
<a href="#" className="focus-ring">Link</a>
<input className="focus-ring" />

// Modal focus trap
useEffect(() => {
  if (isOpen) {
    // Focus first interactive element
    modalRef.current?.querySelector('button')?.focus();
  }
}, [isOpen]);
```

**Tab Order**

- Maintain logical tab order (top to bottom, left to right)
- Use tabIndex={-1} to remove from tab order
- Use tabIndex={0} to add to natural tab order
- Never use positive tabIndex values

**Keyboard Shortcuts**

```typescript
// Common patterns
Escape: Close modals, cancel actions
Enter: Submit forms, confirm actions
Space: Toggle checkboxes, activate buttons
Arrow keys: Navigate lists, tabs
Tab: Move forward through interactive elements
Shift+Tab: Move backward through interactive elements
```


### Semantic HTML

**Use Proper Elements**

```tsx
// Good - semantic HTML
<button onClick={handleClick}>Click me</button>
<a href="/page">Link</a>
<nav>Navigation</nav>
<main>Main content</main>
<article>Article content</article>

// Bad - non-semantic
<div onClick={handleClick}>Click me</div>
<div onClick={navigate}>Link</div>
```

**ARIA Labels**

```tsx
// Icon buttons need labels
<button aria-label="Close modal">
  <X className="h-5 w-5" />
</button>

// Images need alt text
<img src={avatar} alt={`${user.name}'s avatar`} />

// Loading states
<div role="status" aria-live="polite">
  Loading...
</div>

// Form inputs need labels
<label htmlFor="email">Email</label>
<input id="email" type="email" />
```

**Screen Reader Support**

```tsx
// Hide decorative elements
<div aria-hidden="true">
  <Icon />
</div>

// Announce dynamic content
<div role="alert" aria-live="assertive">
  Error: Please fill in all fields
</div>

// Describe complex interactions
<button
  aria-expanded={isOpen}
  aria-controls="dropdown-menu"
>
  Menu
</button>
```

### Touch Targets

**Minimum Sizes**

```css
/* Mobile touch targets */
@media (hover: none) and (pointer: coarse) {
  button, a, [role="button"] {
    min-height: 44px;
    min-width: 44px;
  }
}
```

**Spacing**

- Minimum 8px spacing between touch targets
- Increase padding on mobile for easier tapping
- Use larger buttons on mobile (size="lg")


---

## Implementation Guidelines

### Component Development

**File Structure**

```
src/components/
├── ui/                    # Base components
│   ├── Button.tsx
│   ├── Card.tsx
│   ├── Input.tsx
│   └── Modal.tsx
├── contacts/              # Feature components
│   ├── ContactCard.tsx
│   └── ContactList.tsx
└── layout/                # Layout components
    ├── Sidebar.tsx
    └── Header.tsx
```

**Component Template**

```tsx
import * as React from "react"
import { cn } from "@/lib/utils"

interface ComponentProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: "default" | "secondary"
  size?: "sm" | "md" | "lg"
}

export function Component({ 
  variant = "default",
  size = "md",
  className,
  children,
  ...props 
}: ComponentProps) {
  return (
    <div
      className={cn(
        "base-classes",
        variant === "secondary" && "variant-classes",
        size === "lg" && "size-classes",
        className
      )}
      {...props}
    >
      {children}
    </div>
  )
}
```

### Styling Approach

**Utility-First with Tailwind**

```tsx
// Good - utility classes
<div className="flex items-center gap-4 p-6 rounded-xl bg-white">

// Good - custom utility classes (globals.css)
<div className="premium-card">

// Avoid - inline styles (use only for dynamic values)
<div style={{ width: `${progress}%` }}>
```

**Class Composition**

```tsx
import { cn } from "@/lib/utils"

// Merge classes safely
<div className={cn(
  "base-classes",
  isActive && "active-classes",
  className  // Allow override
)} />
```


### Responsive Design

**Mobile-First Approach**

```tsx
// Start with mobile, add breakpoints for larger screens
<div className="
  px-4 py-6           // Mobile
  md:px-6 md:py-8     // Tablet
  lg:px-8 lg:py-12    // Desktop
">
```

**Responsive Patterns**

```tsx
// Grid - responsive columns
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">

// Flex - stack on mobile, row on desktop
<div className="flex flex-col lg:flex-row gap-4">

// Hide on mobile
<div className="hidden md:block">

// Show only on mobile
<div className="block md:hidden">

// Responsive text sizes
<h1 className="text-2xl md:text-3xl lg:text-4xl">
```

### Performance

**Optimization Rules**

1. **Images**: Use Next.js Image component with proper sizing
2. **Lazy loading**: Load components below fold lazily
3. **Animations**: Use transform and opacity (GPU accelerated)
4. **Bundle size**: Import only what you need from libraries
5. **Fonts**: Use system fonts (no web font loading)

**Code Splitting**

```tsx
// Lazy load heavy components
const HeavyComponent = dynamic(() => import('./HeavyComponent'), {
  loading: () => <Skeleton />
})
```

### Testing

**Visual Testing Checklist**

- [ ] Component renders correctly in all variants
- [ ] Responsive behavior works on mobile, tablet, desktop
- [ ] Hover states work correctly
- [ ] Focus states are visible
- [ ] Loading states display properly
- [ ] Error states are clear
- [ ] Empty states are helpful
- [ ] Animations are smooth (60fps)
- [ ] Colors meet contrast requirements
- [ ] Touch targets are 44x44px minimum


---

## Code Examples

### Complete Page Layout

```tsx
export default function ContactsPage() {
  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-stone-200 bg-white">
        <div className="max-w-7xl mx-auto px-4 py-6 md:px-6 lg:px-8">
          <div className="flex items-center justify-between">
            <h1 className="text-display">Contacts</h1>
            <Button variant="primary">
              <Plus className="h-4 w-4" />
              Add Contact
            </Button>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 py-8 md:px-6 lg:px-8">
        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-12">
          <Card className="p-6">
            <p className="text-caption">Total Contacts</p>
            <p className="text-3xl font-semibold text-stone-900 mt-2">
              1,234
            </p>
          </Card>
          {/* More stat cards */}
        </div>

        {/* Contact List */}
        <Card className="p-6">
          <CardHeader>
            <CardTitle>All Contacts</CardTitle>
            <CardDescription>
              Manage your contact database
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-2">
              {contacts.map(contact => (
                <ContactCard key={contact.id} contact={contact} />
              ))}
            </div>
          </CardContent>
        </Card>
      </main>
    </div>
  )
}
```


### Form with Validation

```tsx
export function ContactForm() {
  const [loading, setLoading] = useState(false)
  const [errors, setErrors] = useState<Record<string, string>>({})

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    // Submit logic
    setLoading(false)
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <Input
        label="First Name"
        name="firstName"
        required
        error={errors.firstName}
      />
      
      <Input
        label="Last Name"
        name="lastName"
        required
        error={errors.lastName}
      />
      
      <Input
        label="Email"
        name="email"
        type="email"
        required
        error={errors.email}
      />
      
      <Input
        label="Phone"
        name="phone"
        type="tel"
        placeholder="+1 (555) 000-0000"
      />

      <div className="flex gap-3 pt-4">
        <Button
          type="submit"
          variant="primary"
          loading={loading}
          className="flex-1"
        >
          Save Contact
        </Button>
        <Button
          type="button"
          variant="secondary"
          onClick={onCancel}
        >
          Cancel
        </Button>
      </div>
    </form>
  )
}
```


### Modal with Form

```tsx
export function AddContactModal({ isOpen, onClose }: ModalProps) {
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (data: ContactData) => {
    setLoading(true)
    try {
      await createContact(data)
      onClose()
    } catch (error) {
      console.error(error)
    } finally {
      setLoading(false)
    }
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title="Add New Contact"
      size="md"
    >
      <ContactForm
        onSubmit={handleSubmit}
        onCancel={onClose}
        loading={loading}
      />
    </Modal>
  )
}
```

### List with Empty State

```tsx
export function ContactList({ contacts }: ContactListProps) {
  if (contacts.length === 0) {
    return (
      <EmptyState
        icon={<Users className="h-12 w-12" />}
        title="No contacts yet"
        description="Get started by adding your first contact to build your network"
        action={
          <Button variant="primary" onClick={onAddContact}>
            <Plus className="h-4 w-4" />
            Add Contact
          </Button>
        }
      />
    )
  }

  return (
    <div className="space-y-2">
      {contacts.map(contact => (
        <div key={contact.id} className="lead-card">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <img
                src={contact.avatar}
                alt={contact.name}
                className="h-10 w-10 rounded-full"
              />
              <div>
                <h4 className="text-sm font-semibold text-stone-900">
                  {contact.name}
                </h4>
                <p className="text-xs text-stone-500">
                  {contact.company}
                </p>
              </div>
            </div>
            <Badge variant="success">Active</Badge>
          </div>
        </div>
      ))}
    </div>
  )
}
```


### Loading States

```tsx
export function ContactListSkeleton() {
  return (
    <div className="space-y-3">
      {[1, 2, 3, 4, 5].map(i => (
        <div key={i} className="premium-card p-4">
          <div className="flex items-center gap-3">
            <div className="skeleton h-10 w-10 rounded-full" />
            <div className="flex-1">
              <div className="skeleton h-4 w-32 mb-2" />
              <div className="skeleton h-3 w-24" />
            </div>
          </div>
        </div>
      ))}
    </div>
  )
}

// Usage
export function ContactsPage() {
  const { data: contacts, isLoading } = useContacts()

  if (isLoading) {
    return <ContactListSkeleton />
  }

  return <ContactList contacts={contacts} />
}
```

### Dashboard Stats

```tsx
export function DashboardStats() {
  const stats = [
    {
      label: "Total Contacts",
      value: "1,234",
      change: "+12%",
      trend: "up",
      icon: Users,
    },
    {
      label: "Active Deals",
      value: "56",
      change: "+8%",
      trend: "up",
      icon: TrendingUp,
    },
    {
      label: "Revenue",
      value: "$45K",
      change: "-3%",
      trend: "down",
      icon: DollarSign,
    },
  ]

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
      {stats.map(stat => (
        <Card key={stat.label} className="p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-caption">{stat.label}</p>
              <p className="text-3xl font-semibold text-stone-900 mt-2 animate-count-up">
                {stat.value}
              </p>
              <p className={cn(
                "text-xs mt-2",
                stat.trend === "up" ? "text-green-600" : "text-red-600"
              )}>
                {stat.change} from last month
              </p>
            </div>
            <div className="h-12 w-12 rounded-full bg-indigo-100 flex items-center justify-center">
              <stat.icon className="h-6 w-6 text-indigo-600" />
            </div>
          </div>
        </Card>
      ))}
    </div>
  )
}
```


---

## Design Tokens Reference

### Quick Reference Table

| Token | Value | Usage |
|-------|-------|-------|
| **Border Radius** | | |
| rounded-3xl | 24px | Cards, major containers |
| rounded-2xl | 16px | Modals, dialogs |
| rounded-xl | 12px | Buttons, inputs |
| rounded-lg | 8px | Small cards, list items |
| rounded-full | 9999px | Badges, avatars, pills |
| **Shadows** | | |
| shadow-soft | Custom | Cards default |
| shadow-card-hover | Custom | Cards on hover |
| shadow-glow | Custom | Primary buttons |
| **Spacing** | | |
| p-6 | 24px | Card padding (default) |
| gap-6 | 24px | Grid gap (default) |
| mb-12 | 48px | Module spacing |
| mb-16 | 64px | Section spacing |
| **Typography** | | |
| text-display | 30px/600 | Page titles |
| text-section-header | 18px/600 | Section headers |
| text-card-title | 14px/600 | Card titles |
| text-body | 14px/400 | Body text |
| text-caption | 12px/400 | Captions, metadata |
| **Colors** | | |
| stone-900 | #1C1917 | Headings, emphasis |
| stone-600 | #57534E | Body text |
| stone-500 | #78716C | Secondary text |
| stone-200 | #E7E5E4 | Borders |
| stone-100 | #F5F5F4 | Backgrounds |
| indigo-600 | #4F46E5 | Primary actions |
| **Transitions** | | |
| transition-smooth | 150ms ease-out | All interactions |


---

## Common Patterns Checklist

### When Creating a New Page

- [ ] Use `min-h-screen bg-background` on root container
- [ ] Wrap content in `max-w-7xl mx-auto px-4 md:px-6 lg:px-8`
- [ ] Add page title with `text-display` class
- [ ] Include primary action button in header
- [ ] Use `mb-12` or `mb-16` between major sections
- [ ] Implement loading states with skeletons
- [ ] Add empty states for zero data
- [ ] Ensure mobile responsiveness

### When Creating a New Component

- [ ] Use TypeScript with proper prop types
- [ ] Extend appropriate HTML element props
- [ ] Use `cn()` utility for class merging
- [ ] Support `className` prop for customization
- [ ] Add proper ARIA labels and roles
- [ ] Include focus states with `focus-ring`
- [ ] Add hover states with `transition-smooth`
- [ ] Test keyboard navigation
- [ ] Verify color contrast (WCAG AA minimum)
- [ ] Test on mobile devices

### When Adding Interactions

- [ ] Use `transition-smooth` for all transitions
- [ ] Add hover state (lift, color change, or background)
- [ ] Add active state (`active:scale-[0.98]`)
- [ ] Add focus state with `focus-ring`
- [ ] Include loading state for async actions
- [ ] Add disabled state styling
- [ ] Ensure 44x44px minimum touch target
- [ ] Test keyboard accessibility

### When Using Colors

- [ ] Use stone palette for 90% of UI
- [ ] Reserve indigo for primary actions only
- [ ] Use semantic colors (success, warning, error) consistently
- [ ] Pair semantic colors with appropriate backgrounds
- [ ] Verify contrast ratios (4.5:1 minimum)
- [ ] Never rely on color alone for meaning
- [ ] Test with color blindness simulator


---

## Troubleshooting

### Common Issues

**Issue: Colors look different than expected**
- Verify you're using HSL format for CSS variables
- Check if Tailwind is processing the classes correctly
- Ensure globals.css is imported in layout.tsx

**Issue: Hover states not working**
- Add `transition-smooth` class
- Verify parent doesn't have `pointer-events-none`
- Check z-index stacking context

**Issue: Focus rings not visible**
- Use `focus-ring` utility class
- Ensure `focus-visible:` prefix is used (not just `focus:`)
- Check if outline is being overridden

**Issue: Animations janky or slow**
- Use `transform` and `opacity` only (GPU accelerated)
- Avoid animating `width`, `height`, `top`, `left`
- Check for layout thrashing (forced reflows)
- Reduce animation complexity

**Issue: Text not readable**
- Verify color contrast (use browser DevTools)
- Check font weight (use 600 for headings, 400 for body)
- Ensure proper line-height (1.5-1.6 for body text)
- Increase font size if needed

**Issue: Layout breaking on mobile**
- Use mobile-first approach (base styles for mobile)
- Test at 375px width (iPhone SE)
- Check for fixed widths (use max-w-* instead)
- Verify touch targets are 44x44px minimum

**Issue: Components not aligning**
- Use flexbox or grid for layout
- Check for inconsistent padding/margin
- Verify parent container has proper width
- Use gap-* utilities instead of margin for spacing


---

## Version History

### Version 2.0 (February 2026)
- Comprehensive expansion of all sections
- Added detailed component specifications
- Included complete code examples
- Added accessibility guidelines
- Expanded color system documentation
- Added implementation guidelines
- Included troubleshooting section
- Added design tokens reference table
- Included common patterns checklist

### Version 1.0 (January 2026)
- Initial design system documentation
- Core principles established
- Basic color palette defined
- Typography scale created
- Component foundations laid

---

## Contributing

When updating this design system:

1. **Document changes**: Update version history with date and changes
2. **Provide examples**: Include code examples for new patterns
3. **Test thoroughly**: Verify changes work across browsers and devices
4. **Update components**: Ensure existing components follow new guidelines
5. **Communicate**: Share updates with the team

---

## Resources

### Tools
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [WAVE Accessibility Tool](https://wave.webaim.org/)
- [Figma](https://figma.com) - Design mockups

### References
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Inclusive Components](https://inclusive-components.design/)
- [Material Design](https://material.io/design) - Inspiration
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

---

**End of Design System Documentation**

For questions or suggestions, contact the design team or open an issue in the repository.

