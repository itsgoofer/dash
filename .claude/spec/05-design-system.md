# Dash Design System

Single source of truth for all UI. Every token lives in `lib/theme/dash_theme.dart` — components never hardcode colors/sizes/durations. If a screen needs something not listed here, add the token here first.

## Color tokens (dark only)

| Token | Value | Use |
|---|---|---|
| `bg0` | `#0A0E14` | App/window background |
| `bg1` | `#0F141C` | Sidebar, wells, inset areas |
| `glassFill` | white 4% | Panel fill (over blur) |
| `glassBorder` | white 7% | 1px panel & control borders |
| `hover` | white 5% | Hover fills (rows, nav, ghost buttons) |
| `active` | white 9% | Pressed/selected fills |
| `accent` | `#22D3EE` | Cyan — primary actions, focus, glow, selection |
| `accentDim` | accent 15% | Selected-item backgrounds, focus rings |
| `accent2` | `#818CF8` | Violet — secondary data series, subtle contrast accents |
| `success` | `#34D399` | Done status, positive deltas |
| `warning` | `#FBBF24` | Paused status, conflict banners |
| `danger` | `#F87171` | Destructive actions, errors |
| `text0` | `#E6EDF3` | Primary text |
| `text1` | `#8B98A9` | Secondary text, labels |
| `text2` | `#4B5666` | Faint: placeholders, disabled, syntax markers |

Rules: accent is for *focus and action*, not decoration — max one glowing element per region. Semantic colors only for their meanings. Text on accent fill = `bg0` (dark on cyan).

## Typography — Inter (bundled asset, family `Inter`)

| Style | Size/weight | Use |
|---|---|---|
| `display` | 28 / 700, -0.5 tracking | Dashboard greeting, screen titles |
| `title` | 20 / 600 | Panel titles, note titles in lists |
| `heading` | 16 / 600 | Section headers, table headers |
| `body` | 15 / 400, line-height 1.6 | Default UI + editor body text |
| `label` | 13 / 500 | Buttons, nav items, form labels, chips |
| `small` | 12 / 400 | Timestamps, captions, footnotes |
| `mono` | 13 / 400 `SF Mono`/`Consolas` | Inline code, stat numbers |

Editor scale (body 15 base): H1 26/700 · H2 21/600 · H3 17/600 · code block mono 13. Reading measure ~70ch (max ~720px), centered.

## Geometry

- **Radius: 4px. Everywhere.** Buttons, inputs, panels, chips, menus, images. No pills, no capsules. (Circular is allowed only where inherently round: slider thumb, avatar dots, brain particles.)
- Spacing on the 8pt grid: `4, 8, 12, 16, 24, 32, 48` (`DashSpace.x1..x6`+). Panel padding 16–24. Sidebar 220px. Row height 40 (dense) / 48 (default).
- Borders 1px `glassBorder`; focus = 1px `accent` + 2px `accentDim` ring. No 2px+ decorative borders.

## Glass & elevation

- **GlassPanel**: blur 24, `glassFill`, 1px `glassBorder`, radius 4. Optional `glow: true` adds accent shadow (accent 18%, blur 24, no offset) — reserve for hero elements (brain panel, primary chart).
- Elevation via fill steps (bg0 → bg1 → glassFill), not drop shadows. Menus/dialogs: bg1 fill, 1px border, shadow black 40% blur 32.

## Motion

- Hover states 120ms · standard transitions 180ms `easeOutCubic` (`DashMotion.duration/curve`) · screen switches 200ms fade · charts draw-in 400ms · list entrances stagger 30ms/item (first load only, cap at 10 items).
- Nothing blocks or delays input; animations are interruptible. All looping visuals (brain) pause on window blur.

## Components

- **Control height — one shared token `controlHeight = 32`** (28 compact). All inline controls — buttons, text inputs, dropdowns, date pickers, search fields — use it so anything on the same row aligns pixel-perfect. Never hardcode a control height.
- **Buttons** — height `controlHeight`, radius 4, `label` type, padding H16. Primary: accent fill, `bg0` text, hover brightens 8%. Secondary: transparent, 1px `glassBorder`, `text0`, hover fill. Ghost: text-only `text1`, hover fill + `text0`. Destructive: danger outline → danger fill on hover. Icon buttons 28×28.
- **Inputs** — `controlHeight` high, bg1 fill, 1px border, radius 4, focus ring per Geometry; placeholder `text2`. Same recipe for dropdowns/date pickers (menu = Menus spec).
- **Metric slider (1–10)** — track 4px `glassBorder`-tone; filled portion accent with subtle glow; thumb 14px circle, white, accent ring on drag; value shown in `mono` beside label. Discrete steps, no half values.
- **Chips** — status/select values: radius 4, H8/V3 padding, `label` 12, tinted 15% of its semantic/accent color + matching text. Multiselect tags: `hover` fill, `text1`.
- **Sidebar item** — 36 high, radius 4, icon 18 + `label`; rest `text1`; hover fill; selected: `accentDim` fill, `accent` icon/text, 2px accent bar on left edge.
- **Table (databases)** — header row `heading` 13 `text1`, sortable arrow accent; rows 48, separator `glassBorder` 50%; hover reveals row actions (open/delete icons, fade in 120ms); typed cells: number → `mono`, checkbox → accent check, select → chip, date → `small`, url → accent underline-on-hover.
- **Cards** (db gallery/projects) — GlassPanel radius 4, cover/emoji top, `title` + chips, hover: border → accent 40% + translate -2px (180ms).
- **Empty states** — centered 40px icon `text2`, `body` `text1` message with personality, optional primary button.
- **Banners** (conflicts, changed-on-disk) — full-width bar under titlebar, warning tint 12% fill + border, `label` text + inline actions; slides in 180ms.
- **Menus / slash menu** — bg1, radius 4, item height 32, hover fill, icon + label + shortcut `small text2`; opens 120ms fade+2px rise.
- **Tooltips** — bg1, 1px border, radius 4, `small`, 300ms delay.
- **Scrollbars** — 6px, white 12%, hover 20%, no track.

## Charts (fl_chart)

Series: rating `accent` · energy `accent2` · productivity `success`. Line 2px with soft glow (same color 25%, blur 6); area gradient fill color 18% → 0%. Grid: horizontal only, `glassBorder` 50%. Axis labels `small text2`. Tooltip per Menus spec. No legends when ≤3 series — label lines directly at right edge. Dots only on hover point.

## Iconography

**SVG assets, never the Icons font** — Material Symbols *outlined* SVGs downloaded from Google's material-design-icons repo into `assets/icons/<name>.svg`, rendered via `flutter_svg` through the shared `DashIcon` widget (`lib/widgets/dash_icon.dart`: name + size + color, defaults 20px/`text1`). Sharper rendering, exact color control. 18–20px in controls, `text1` default → `accent` when selected. Need a new icon → download the SVG into assets/icons first; never fall back to `Icons.*`.

## Voice

Short, confident, a bit Jarvis: "Systems online.", "Nothing logged yet — today's a blank page." Never robotic error-speak; always say what to do next.

## Don'ts

No light theme · no pills/rounded buttons · no raw YAML/paths in UI · no drop-shadow elevation on panels · no more than one glow focus per region · no spinner where a 200ms skeleton/fade works · no Material default splash/ripple.
