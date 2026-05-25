---
name: Natural Hospitality Tech
colors:
  surface: '#fdf9f3'
  surface-dim: '#ddd9d4'
  surface-bright: '#fdf9f3'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f7f3ed'
  surface-container: '#f1ede7'
  surface-container-high: '#ebe8e2'
  surface-container-highest: '#e6e2dc'
  on-surface: '#1c1c18'
  on-surface-variant: '#43474c'
  inverse-surface: '#31302d'
  inverse-on-surface: '#f4f0ea'
  outline: '#73777d'
  outline-variant: '#c3c7cd'
  surface-tint: '#486176'
  primary: '#112c3f'
  on-primary: '#ffffff'
  primary-container: '#294256'
  on-primary-container: '#95aec6'
  inverse-primary: '#b0c9e2'
  secondary: '#35618d'
  on-secondary: '#ffffff'
  secondary-container: '#a2cdff'
  on-secondary-container: '#295782'
  tertiary: '#4f1702'
  on-tertiary: '#ffffff'
  tertiary-container: '#6c2c15'
  on-tertiary-container: '#ef9475'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#cbe6ff'
  primary-fixed-dim: '#b0c9e2'
  on-primary-fixed: '#011e30'
  on-primary-fixed-variant: '#30495e'
  secondary-fixed: '#d0e4ff'
  secondary-fixed-dim: '#9fcafc'
  on-secondary-fixed: '#001d35'
  on-secondary-fixed-variant: '#184974'
  tertiary-fixed: '#ffdbd0'
  tertiary-fixed-dim: '#ffb59c'
  on-tertiary-fixed: '#390c00'
  on-tertiary-fixed-variant: '#75331b'
  background: '#fdf9f3'
  on-background: '#1c1c18'
  surface-variant: '#e6e2dc'
typography:
  display-lg:
    fontFamily: Libre Caslon Text
    fontSize: 48px
    fontWeight: '400'
    lineHeight: 56px
    letterSpacing: -0.02em
  display-lg-mobile:
    fontFamily: Libre Caslon Text
    fontSize: 36px
    fontWeight: '400'
    lineHeight: 44px
  headline-md:
    fontFamily: Libre Caslon Text
    fontSize: 32px
    fontWeight: '400'
    lineHeight: 40px
  headline-sm:
    fontFamily: Libre Caslon Text
    fontSize: 24px
    fontWeight: '400'
    lineHeight: 32px
  body-lg:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Manrope
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-sm:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-md:
    fontFamily: Manrope
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.05em
  label-sm:
    fontFamily: Manrope
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
    letterSpacing: 0.03em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  container-max: 1280px
  gutter: 24px
  margin-mobile: 20px
  margin-desktop: 64px
  section-gap: 80px
---

## Brand & Style

The design system is built for an AI Concierge service that bridges high-touch hospitality with seamless technology. The brand personality is **composed, welcoming, and reliable**, avoiding the cold, "robot-centric" tropes of typical AI products. 

The aesthetic follows a **Natural Minimalism** approach, blending the freshness of coastal retreats with the grounded security of alpine lodges. The UI should evoke a sense of relief and quiet efficiency—mimicking the feeling of a professional concierge who is always present but never intrusive. 

Key visual principles:
- **Quiet Intelligence:** AI is represented through clean, functional dashboards rather than futuristic glow or complex patterns.
- **Organic Professionalism:** Use of high-quality typography and warm neutrals to signal premium service.
- **Breathe:** High reliance on whitespace to prevent cognitive overload for busy hosts.

## Colors

The palette is rooted in natural elements, replacing sterile digital whites with a warm, paper-like background.

- **Primary Background (#F7F3ED):** Used for the main canvas to create a calm, non-glare environment.
- **Deep Navy (#294256):** The core of the identity. Used for structural elements, headers, and primary text to establish authority and trust.
- **Sea Blue (#275580):** A lighter, more fluid blue used for interactive elements and platform-specific highlights.
- **Terracotta & Deep Brick (#B7664A, #813F37):** Warm earth tones used sparingly for notification badges, alerts, or specific CTA accents to provide a "human" touch.
- **Surface (#FFFFFF):** Pure white is reserved exclusively for elevated containers (cards, modals) to create clear separation from the warm background.

## Typography

This design system utilizes a high-contrast typographic pairing to signal the "Natural Hospitality Tech" narrative.

- **Headings (Libre Caslon Text):** Chosen as a high-quality alternative to Cormorant Garamond for better screen rendering while maintaining an elegant, editorial feel. It should be used for all marketing headers and significant dashboard titles.
- **Body & UI (Manrope):** A modern, geometric sans-serif that ensures clarity in data-heavy views.
- **Hierarchy:** Maintain generous line-heights to ensure the text feels "airy" and readable. Use the Uppercase Label style for small category markers or metadata to provide a structured, professional rhythm.

## Layout & Spacing

The layout philosophy follows a **Fixed-Fluid Hybrid** model. Content is contained within a 1280px max-width centered grid to ensure readability on wide monitors, while internal dashboard elements use a fluid 12-column system.

- **Rhythm:** An 8px base grid governs all spacing.
- **Margins:** Desktop margins are intentionally wide (64px) to emphasize the "minimalist" and "premium" nature of the service.
- **Sections:** Vertical gaps between major landing page sections should be substantial (80px+) to allow the design to "breathe."
- **Dashboards:** Use a sidebar-based layout for the platform, with a fixed left navigation and a fluid right content area.

## Elevation & Depth

To maintain the "Natural" aesthetic, the design system avoids heavy shadows or aggressive depth.

- **Surface Tiers:** Depth is primarily communicated through color. The Warm White (#F7F3ED) is the base, and Pure White (#FFFFFF) cards sit "on top" of it.
- **Shadows:** When necessary, use a single "Ambient Shadow"—very diffused, low-opacity (4-8%), with a slight Deep Navy tint (#294256) rather than pure black. This keeps the shadows feeling like natural light.
- **Interactions:** Hover states on cards should involve a subtle vertical lift (2-4px) and a slight increase in shadow diffusion, rather than a color change.

## Shapes

The shape language is **Soft and Approachable**. 

Elements should feel like polished stones—smooth and friendly.
- **Standard UI Elements:** Buttons, input fields, and small tags use a 0.5rem (8px) radius.
- **Containers:** Dashboard cards and pricing blocks use the `rounded-xl` setting (1.5rem / 24px) to create a soft, distinctive framing effect.
- **Visual Elements:** Photography and iconography containers should also follow the 24px rounding to maintain a consistent visual language.

## Components

### Buttons
- **Primary:** Deep Navy (#294256) background with Warm White (#F7F3ED) text. 0.5rem rounding.
- **Secondary:** Transparent background with Deep Navy border (1px) and text.
- **Tertiary/Ghost:** Sea Blue (#275580) text with no background, used for low-priority actions.

### Cards
- Always Pure White (#FFFFFF).
- 24px corner radius.
- Minimal 1px border in a slightly darker version of the background (#EBE6DE) for definition without heavy shadows.

### Input Fields
- Background: Warm White (#F7F3ED) or transparent with a thin 1px border.
- Focus state: Sea Blue (#275580) border with a soft blue outer glow.

### Chips & Badges
- Used for status (e.g., "AI Responded," "Pending Host"). 
- Use the Terracotta (#B7664A) for items requiring attention and Sea Blue for neutral system updates.

### Icons
- Use thin-stroke (1.5px) linear icons. 
- Avoid solid/filled icons unless used as a toggle state. Icons should be Deep Navy or Sea Blue.

### Lists
- Clean, generous padding (16px vertical). 
- Use thin dividers (#EBE6DE) and Manrope Medium for list item headers.