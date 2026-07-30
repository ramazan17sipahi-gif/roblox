```markdown
# Design System: The Editorial Studio

## 1. Overview & Creative North Star
**Creative North Star: "The Curated Canvas"**
This design system moves beyond the utility of a standard "tool" and into the realm of a premium "studio." It is designed to feel like a high-end physical workspace: expansive, sun-drenched, and meticulously organized. 

To achieve a "Signature" look, we reject the rigid, boxed-in layouts of traditional apps. Instead, we utilize **Intentional Asymmetry** and **Tonal Depth**. The UI should feel like an editorial spread—using dramatic typography scales and overlapping elements to create a sense of motion. By prioritizing breathing room (negative space) over structural lines, we place the creator’s content on a pedestal, making the interface feel invisible yet authoritative.

---

## 2. Colors & Surface Philosophy
The palette is rooted in a soft, warm "Paper" base, punctuated by a high-energy "Ignition Orange."

### The "No-Line" Rule
**Strict Prohibition:** Do not use 1px solid borders to define sections.
Boundaries are created exclusively through background shifts. A `surface-container-lowest` card (#FFFFFF) must sit on a `surface` background (#F7F7F4). To separate logic blocks, use a vertical jump in the Spacing Scale (e.g., `8` or `10`) rather than a divider line.

### Surface Hierarchy & Nesting
Treat the UI as layered sheets of premium stock.
*   **Base Layer:** `surface` (#F7F7F4) — The "Desk" surface.
*   **Secondary Layer:** `surface-container-low` (#F0F1EE) — Subtle inset areas for secondary utilities.
*   **Content Layer:** `surface-container-lowest` (#FFFFFF) — Primary cards and interaction zones.
*   **Floating Layer:** `surface-bright` (#F7F7F4) with 80% opacity and 20px backdrop blur for navigation bars and modals.

### Signature Textures & Gradients
To avoid a flat "Bootstrap" feel, apply a subtle linear gradient to `primary` actions:
*   **Action Gradient:** From `primary_fixed` (#FF793A) to `primary` (#9F3B00) at a 135° angle. This adds a "tangible" weight to buttons that flat hex codes cannot achieve.

---

## 3. Typography
We use a dual-typeface system to balance editorial authority with functional clarity.

*   **Display & Headlines (Plus Jakarta Sans):** These are the "Voice." Use `display-lg` for empty states and `headline-md` for dashboard summaries. The generous x-height of Plus Jakarta Sans provides a modern, tech-forward energy.
*   **Body & Labels (Manrope):** The "Workhorse." Manrope is chosen for its geometric precision and readability at small scales. Use `body-md` for creator descriptions and `label-md` (All Caps, +5% tracking) for category tags.

**Hierarchy Tip:** Always skip a weight or size in the scale to create high contrast. For example, pair a `headline-lg` title directly with a `body-sm` metadata tag for a sophisticated editorial look.

---

## 4. Elevation & Depth
In this system, elevation is a product of **light and layering**, not drop shadows.

*   **Tonal Layering:** Achieve "lift" by nesting. A `surface-container-lowest` (#FFFFFF) card on a `surface-container-high` (#E2E3DF) background creates a crisp, clear hierarchy without a single shadow pixel.
*   **Ambient Shadows:** For floating elements (e.g., a "Create" FAB), use:
    *   `Y: 12px, Blur: 24px, Color: rgba(159, 59, 0, 0.08)` (A tinted shadow using the `primary` hue).
*   **The "Ghost Border" Fallback:** If a layout requires a boundary for accessibility, use `outline-variant` at 15% opacity. It should be felt, not seen.
*   **Glassmorphism:** Navigation headers should use `surface-container-lowest` at 85% opacity with a `32px` backdrop blur. This allows content to bleed through as the user scrolls, creating a sense of infinite depth.

---

## 5. Components

### Buttons
*   **Primary:** High-pill shape (`full` rounding). Uses the Action Gradient. Text is `on_primary_fixed` (#000000) for maximum "pop" against the orange.
*   **Secondary:** Ghost style. No background. `outline-variant` 20% border. Use `primary` (#9F3B00) for text.
*   **States:** On press, scale the component down to `0.96` to provide haptic-like visual feedback.

### Creator Cards
*   **Rules:** No borders. Corner radius `lg` (2rem). 
*   **Layout:** Use asymmetrical padding—`top: 6, left: 5, right: 5, bottom: 8`. This "bottom-heavy" spacing gives cards a grounded, professional feel.

### Input Fields
*   **Styling:** Soft `surface-container-low` fill. No border. On focus, the background shifts to `surface-container-lowest` with a subtle 2px `primary` bottom-bar only.

### Analytics Charts
*   **Visual Language:** Use "Soft Pastel" tokens. Lines should be `2px` thick with `round` caps. 
*   **The "Glow" Rule:** Data lines in a chart should have a subtle drop-shadow in their own color (e.g., a success-green line with a 4% green shadow) to make data feel illuminated.

---

## 6. Do's and Don'ts

### Do
*   **Use Whitespace as a Tool:** If two elements feel cluttered, add `spacing-8` instead of a divider.
*   **Embrace Large Radii:** Stick to `1.5rem` to `2rem` for containers to maintain the "Soft Modern" aesthetic.
*   **Nesting Surfaces:** Place white cards on a soft grey background to define the workspace.

### Don't
*   **Don't use Pure Black:** Never use #000000. Use `on_background` (#2D2F2D) for softness.
*   **No Sharp Corners:** Avoid `none` or `sm` rounding unless it's for a tiny badge. It breaks the "Creative Studio" flow.
*   **Avoid Over-Shadowing:** If you can see the shadow clearly, it’s too dark. It should feel like "ambient occlusion" in a bright room.
*   **No Standard Grids:** Occasionally break the vertical rhythm. Let an image "bleed" off the edge of a card to suggest a larger world of content.