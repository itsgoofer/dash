# Dash — Overview & Design

Flutter desktop app (macOS first, Windows later) replacing Obsidian/Notion for one user (Goofer). Covers: daily journaling with metrics, custom databases (movies, people, gaming accounts…), 3D-project tracking, all as an Obsidian-compatible md vault synced via Dropbox.

**Why Dash exists:** Obsidian's *interface* is the problem, not its format. Dash keeps md+frontmatter flexibility with a UI worth looking at.

## Design principles

1. **Frontmatter is invisible.** Never show raw YAML. Metadata renders only as designed controls: glowing 1–10 sliders, status chips, tag pills, typed forms, date pickers. The editor shows the note body only.
2. **Jarvis dark theme, one theme done well.** Deep dark palette, cyan/blue glow accent, glassy panels (blur + translucency), 8pt spacing grid, real typographic scale (display-size note titles, ~70ch reading measure, generous line height). **Inter font** for all UI (bundled asset). **Sharp geometry: 4px corner radii everywhere** — no pill/rounded buttons.
3. **UI polish ships with every phase** — the design system is built in Phase 0 and every screen consumes it. No "make it pretty later."
4. **Editor reads like a document, not source code.** Headings at display sizes, real bold/italic, dimmed syntax markers, styled checkboxes (Bear/Craft feel), later cursor-aware syntax hiding + inline images.
5. **Databases look like Notion, not files.** Typed table cells (number badges, colored select chips, checkboxes), polished forms, empty states with personality.
6. **Motion with restraint.** 150–250ms eased transitions, staggered list entrances, chart draw-ins, animated brain visual. Nothing delays input.
7. **Fast & small.** Frontmatter-only index, lazy note bodies, animations paused on window blur, no embedded DB engine.
8. **Notion-ish niceties.** The interactions should feel like Notion, not a file manager: slash-command menu (`/` in editor → insert heading, checkbox, image, divider…), hover row actions in tables, styled callouts, smooth inline editing everywhere. Files/markdown stay the storage truth; the niceties are pure UI.

## Dashboard (home screen)

- Greeting + date, stat tiles (active projects, open tasks, journal streak).
- 14-day area/line chart: day rating, energy, productivity (fl_chart, glow-styled).
- **Brain visual:** ~300 3D-projected particles on a noisy two-lobe sphere, precomputed neighbor edges, slow rotation, additive glow (MaskFilter.blur), Ticker-driven in a RepaintBoundary, paused on blur. Decorative now; `BrainNode.notePath` reserved so nodes can map to real notes later.

## Locked decisions

Obsidian-compatible vault · fresh vault (no import) · one md per DB entry + schema yamls in `.dash/` · custom source-first editor (rejected appflowy_editor/quill/fleather = lossy conversion, super_editor = document-model-first; `flutter_markdown` discontinued — render from `markdown` AST) · 1–10 sliders · macOS first · dark only.
