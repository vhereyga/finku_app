---
name: Finku Budget System
projectId: 3996423772759417908
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#3e4a3d'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#6e7b6c'
  outline-variant: '#bdcaba'
  surface-tint: '#006e2d'
  primary: '#006b2c'
  primary-brand: '#16a34a'
  on-primary: '#ffffff'
  primary-container: '#00873a'
  on-primary-container: '#f7fff2'
  inverse-primary: '#62df7d'
  secondary: '#0051d5'
  secondary-brand: '#2563eb'
  on-secondary: '#ffffff'
  secondary-container: '#316bf3'
  on-secondary-container: '#fefcff'
  tertiary: '#545c72'
  neutral-slate: '#64748b'
  on-tertiary: '#ffffff'
  tertiary-container: '#6c748b'
  on-tertiary-container: '#fefcff'
  error: '#ba1a1a'
  danger-alert: '#dc2626'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  warning: '#d97706'
  warning-container: '#fef3c7'
  primary-fixed: '#7ffc97'
  primary-fixed-dim: '#62df7d'
  on-primary-fixed: '#002109'
  on-primary-fixed-variant: '#005320'
  secondary-fixed: '#dbe1ff'
  secondary-fixed-dim: '#b4c5ff'
  on-secondary-fixed: '#00174b'
  on-secondary-fixed-variant: '#003ea8'
  tertiary-fixed: '#dae2fd'
  tertiary-fixed-dim: '#bec6e0'
  on-tertiary-fixed: '#131b2e'
  on-tertiary-fixed-variant: '#3f465c'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-currency:
    fontFamily: Plus Jakarta Sans
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.01em
  headline-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.02em
  currency-prefix:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

The design system is crafted for a communal, transparent personal finance and collaborative budgeting experience. The aesthetic balances bank-grade financial credibility with the approachable warmth required for social and household expense sharing.

### Visual Style
- **Modern Fintech Humanism:** Replaces rigid corporate banking austerity with clean, welcoming geometric surfaces, airy whitespace, and legible typographic tiers.
- **Tactile Clarity:** Prioritizes high legibility of currency amounts, state indicators, and multi-user split metrics through precise information hierarchy rather than decorative flourishes.
- **Confidence & Transparency:** Establishes trust via calm off-white foundations, crisp bordered white cards, and distinct semantic signals for surplus, threshold warnings, and deficit alerts.

## Colors

The color palette centers on financial vitality, legibility, and unmistakable feedback.

### Core Roles
- **Primary Accent (`#16A34A` / `#006B2C`):** The primary brand driver and positive financial indicator (savings, safe balances, income). Used on key conversion buttons, positive balance readouts, and success states. Paired with `#DCFCE7` for low-intensity badges and progress bar tracks.
- **Secondary Accent (`#2563EB` / `#0051D5`):** Applied for interactive informational nodes, system links, collaborative budget role assignments (e.g., "Editor", "Co-owner"), and multi-wallet selection. Paired with `#DBEAFE`.
- **Tertiary / Base (`#0F172A` / `#0B1C30`):** Deep navy ink delivering contrast for primary financial numbers, merchant headers, and main CTAs.
- **Neutral (`#64748B` / `#545C72`):** Cool slate used for field descriptors, transaction timestamps, category subtitles, and currency prefixes.

### Semantic Tones
- **Warning (`#D97706`):** Highlights 75%+–90% budget consumption alerts, upcoming bill milestones, and pending reconciliation. Paired with `#FEF3C7`.
- **Danger / Alert (`#DC2626` / `#BA1A1A`):** Reserved for over-budget (>90%) warnings, recurring overdraft indicators, and destructive account actions. Paired with `#FEE2E2`.
- **Canvas & Surface:** `#F8F9FF` / `#F8FAFC` provides a resting backdrop that isolates pure white (`#FFFFFF`) card containers, outlined by `#E2E8F0` / `#BDCABA`.

## Typography

The type system is powered by **Plus Jakarta Sans**, offering geometric clarity and high legibility at micro-scales on high-density mobile screens.

### Indonesian Rupiah (IDR) Formatting Rules
- **Structure:** Always prefix numeric totals with `Rp ` (with an unbroken space), using periods as thousand separators (e.g., `Rp 1.500.000`).
- **Hierarchy Pairing:** In master account headers and summary cards, the `currency-prefix` sits in a muted slate (`#64748B`) alongside the bold navy balance values rendered via `display-currency`.
- **Negative Balances:** Represent negative or over-budget amounts as `-Rp 250.000` in alert coral red, never with parentheses.

## Layout & Spacing

The layout is built for single-hand mobile interactions within standard portrait viewports (390px baseline).

### Grid & Edge Insets
- **Mobile Margins:** Standard horizontal screen margin is set to `1rem` (16px), giving maximum surface area to financial figures while keeping interactive targets away from hardware edges.
- **Card Padding:** Primary interactive modules and budget wrappers use an internal padding of `space-xl` (24px) for prominent balance summaries and `space-lg` (16px) for itemized transaction lists.
- **Vertical Rhythm:** A base 4px system dictates list gap intervals (`space-sm` for related transaction meta, `space-lg` between distinct grouped categories).
- **Safe Area Adaptations:** Bottom sticky navigation and drawer sheets respect the device native home indicator zone with an added minimum clearance of `1.25rem`.

## Elevation & Depth

Visual hierarchy uses a dual-layer strategy pairing subtle containment lines with softly diffused ambient drops.

### Elevation Levels
- **Canvas Base (Level 0):** Hex `#F8F9FF`, flat, hosting scrollable feeds and modular screens.
- **Standard Card (Level 1):** Hex `#FFFFFF` with a crisp `1px solid #E2E8F0` border. Shadow is rendered as an ambient drop: `0px 1px 3px rgba(15, 23, 42, 0.04), 0px 4px 8px rgba(15, 23, 42, 0.02)`.
- **Floating Modals / Action Drawers (Level 2):** Sheet modals, shared budget member selectors, and floating category pills use `0px 12px 24px -4px rgba(15, 23, 42, 0.08), 0px 4px 8px -2px rgba(15, 23, 42, 0.04)`.

## Shapes

- **Main Cards & Containers (`rounded-xl`):** `1.5rem` (24px) for outer budgeting cards, account overview summaries, and bottom sheets.
- **Inputs & Standard Buttons (`rounded-lg`):** `0.75rem` (12px).
- **Badges, Filter Chips & Avatars (`pill`):** Completely rounded (9999px).
