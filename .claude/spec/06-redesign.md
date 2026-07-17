# UI Redesign (v2) — Fable-led, after Phase 6

Goofer's directive (2026-07-17): redefine the UI. Implemented by Fable directly, not delegated. Amends `05-design-system.md` — update it as changes land.

## Direction

1. **Darker + more minimal.** Base palette: dark gray/navy (darker than current bg0 #0A0E14 family), white primary text. Less glow, fewer tints — restraint.
2. **Changeable accent.** Accent color is a user setting (stored in `.dash/settings.yaml` → travels with vault). Default cyan; picker with a small curated set (cyan, violet, green, amber, red, white). Everything currently hardcoding accent goes through theme lookup.
3. **Smaller text, better typography.** Tighter type scale (body ~13-14, labels 11-12, titles down accordingly); refine weights/tracking/line-heights; Inter stays.
4. **Bigger neural network** — the brain is the hero of the home page: larger canvas share, possibly full-bleed behind the greeting.
5. **Neater, darker, more minimal charts** — thinner lines, less area fill/glow, muted grid, smaller labels.
6. **Journal = calendar-first.** Small calendar in a side panel (month grid, dots on logged days); click a day → opens that entry. Replaces prev/next chevron nav as primary navigation.
7. **Frontmatter properties, Notion-style.** Kill the sliders. Journal metrics (and entry fields) render as a neat compact property list — label + value rows, click-to-edit inline (number popover/stepper for 1-10), like Notion properties. Neat, small, quiet.
8. **Fullscreen by default** — launch maximized (window_manager maximize on first show; remember user's size after).

## Status
- [x] Shipped 2026-07-17 — verified via shot harness (dashboard, journal, calendar, properties, accent picker).
