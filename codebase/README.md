# CNC Design System

A mobile-first responsive design system for Thai landing pages.

Apply ALL rules in `styles.css` when generating new designs.
Reference `index.html` for layout patterns and component examples.

## Hard Constraints

### Output Format
- PLAIN HTML + CSS only
- Single `index.html` with inline `<style>` block
- NO React Vue Angular Svelte or any framework
- NO JSX TypeScript Babel transpilation
- NO Tailwind CDN
- Reason audience is absolute beginners with no Node.js no npm

### Mobile-First Responsive
- Base CSS (no media query) = mobile experience 320-767px
- Media queries enhance for LARGER screens using `min-width` ONLY
- NEVER use `@media (max-width: ...)` desktop-first queries
- NEVER use `clamp()` with `vw` on display headlines
- Display headline base 28-36px tablet 48-56 desktop 64-80 large 80-112 max

### Thai Punctuation (NON-NEGOTIABLE)
- NEVER use em dash (—) between Thai clauses
- NEVER use English-style comma (,) between Thai clauses
- Use SPACE as ONLY separator
- En dash (–) for numeric ranges OK (30 – 45 ปี)

### Brand Placeholders
- Keep `[ชื่อร้าน]` `[LOGO]` `[เบอร์โทร]` etc as-is
- NEVER invent brand names or handles

## Aesthetic Direction

### Typography (pick ONE display + ONE body)
- Display: IBM Plex Sans Thai / Anuphan / Trirong / Bai Jamjuree
- Body: Sarabun / Bai Jamjuree / IBM Plex Sans Thai
- Mono (optional): JetBrains Mono / IBM Plex Mono / Space Mono
- BANNED: Inter Roboto Arial Open Sans system-ui Space Grotesk

### Color
- 60-30-10 ratio with DOMINANT + SHARP ACCENTS
- NOT timid even-distribution palettes
- BANNED: purple/indigo gradients soft pastels

### Image Aspect Ratios (STRICT 3 only)
- Landscape 16/9 (นอน) — use class `.ratio-landscape`
- Square 1/1 (จัตุรัส) — use class `.ratio-square`
- Portrait 9/16 (ตั้ง) — use class `.ratio-portrait`
- Logo independent (no ratio constraint)
- BANNED any other ratio (4/5 3/4 4/3 3/2 5/7 7/10 etc)
- Reason students take photos with 1 of 3 simple shapes, web-images skill matches against these 3 only

## Anti-Slop Catalog (12 patterns to NEVER use)

1. Purple/indigo gradient backgrounds
2. Generic fonts (Inter Roboto Arial Open Sans Space Grotesk)
3. Glassmorphism translucent cards with backdrop-filter blur
4. Centered hero with image floating right (default split-hero)
5. Grid of 3-4 feature cards with icon heading paragraph
6. Glowing orb or blob backgrounds
7. Gradient text on headlines (background-clip text)
8. Floating geometric shapes random positioned
9. Card hover scale(1.05) transform
10. "Get Started" or "Learn More" CTA copy
11. Stock photo of diverse smiling team
12. Soft pastel palettes (pink purple blue)

## Motion Strategy

- ONE orchestrated page load (staggered hero fade-in)
- Counter animation on stats > 1
- Scroll-triggered reveals
- Smooth anchor scroll
- Sticky mobile CTA after 200px scroll
- Hover transitions on interactive elements
- LIMIT 3 idle motions when not scrolling
- Respect `prefers-reduced-motion`

## Structural Distinctiveness

DO NOT default to vertical-scroll-stacked-sections.

Before building propose 3 structurally different approaches from DIFFERENT
categories below then pick the most distinctive that serves the content.
Each generation should explore different categories so two runs of the same
brief produce genuinely different layouts.

Structural pattern library (pick from different categories each time)

LAYOUT ARCHITECTURE
1. Vertical scroll stacked sections (classic default avoid unless best)
2. Horizontal scroll panels (installation gallery feel)
3. Single screen with tabbed or accordion content
4. Magazine spread with sidebar or persistent navigation
5. Asymmetric editorial grid with non-linear reading flow
6. Split-screen persistent dual columns
7. Diptych two-panel before-after as artwork

NARRATIVE STYLE
8. Narrative scrolltelling with parallax layers
9. Long-form editorial NYT-style with pull quotes
10. Manifesto single-page with anchor jumps
11. Timeline or progression scrub (numbers tick as you scroll)
12. Index or table-of-contents driven navigation

AESTHETIC FRAME
13. Spec-sheet or data-driven clinical layout
14. Terminal or console aesthetic with monospace
15. Poster or editorial-cover hero dominant
16. Zine or cut-paste collage energy

For each proposed direction state
- Structural pattern (from list above)
- Why it fits THIS brand context
- Mobile adaptation strategy
- One-line rationale

Reject any proposal set where all 3 gravitate to vertical-scroll-stacked.
Pick structure that BEST serves the content NOT the safest pattern.

## Component Requirements (CREATE YOUR OWN do not copy)

IMPORTANT styles.css contains ONLY foundation (tokens reset type scale container).
It does NOT contain button form card counter or animation styles on purpose.

You MUST create your own implementations for these components.
Two different briefs should produce VISUALLY DIFFERENT components.
Do NOT reuse identical counter form or button code across designs.

Each component below lists REQUIREMENTS (behavior) not code.
Invent the visual treatment and interaction style for THIS brand.

### Buttons
- min-height 44px (tap target)
- border-radius 0-4px max
- NO scale(1.05) hover (use directional shift color invert or shadow instead)
- Width 100% on mobile auto on desktop
- YOUR own visual style hover effect matching the brand archetype

### Forms
- Input width 100% on mobile
- Input font-size 16px minimum (iOS zoom prevention)
- Label above input not beside (mobile-friendly)
- YOUR own border focus and field style matching the brand

### Cards
- Sharp corners or radius 2-4px max
- NO glassmorphism backdrop-filter blur
- YOUR own border background elevation treatment

### Counter Animation (REQUIRED for stats greater than 1)
- Animate numbers counting up when scrolled into view
- YOUR own easing timing and trigger style
- Do NOT reuse a fixed counter implementation across designs

### Scroll Reveal (REQUIRED)
- Elements reveal on scroll into view
- YOUR own easing distance and direction

### Sticky Mobile CTA (REQUIRED after 200px scroll)
- Appears on mobile only
- YOUR own style and entrance animation

### Hero Entrance (REQUIRED one orchestrated load)
- Staggered reveal on page load
- YOUR own timing and motion character matching the brand

## Smell Test Before Finalizing

TECHNICAL
- Mobile-first only `min-width` queries
- Base styles work at 320px iPhone SE
- Display headline base 28-36px
- No clamp() with vw on display headlines
- Single column in base
- Image aspect-ratio from STRICT 3 (16/9 1/1 9/16) using utility classes
- Viewport meta in head
- Font 100px+ only at viewport 1024px+
- Zero em dashes in Thai text including title meta
- Brand placeholders kept as-is
- Output is PLAIN HTML/CSS

ANTI-SLOP
- No purple/indigo gradients
- No banned fonts
- No glassmorphism cards
- No glowing orbs
- No "Get Started" or "Learn More" CTAs
- No card hover scale(1.05)

STRUCTURAL
- Not generic landing page template
- Could identify brand from layout alone
