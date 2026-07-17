# Dash Memory

- Dash = Flutter desktop app (macOS first, Windows later) replacing Obsidian/Notion. Goofer left Obsidian **because of its interface** — keep md+frontmatter flexibility, but UI must be beautiful (Jarvis dark theme, cyan glow, glass panels). Frontmatter is NEVER shown raw in the app.
- Vault: Obsidian-compatible (.md + YAML frontmatter), lives in Dropbox. Fresh vault created by app; schemas in `.dash/` inside vault. Full format: `.claude/spec/02-vault-format.md`.
- Editor: custom source-first (markdown text = document model; perfect fidelity). Rejected appflowy/quill/super_editor (lossy rewrites). `flutter_markdown` is discontinued — render from `markdown` AST.
- Metrics: energy, rating, productivity, exercise, gaming — all 1–10 sliders in daily journal frontmatter.
- Brain visual: decorative CustomPainter particles now; nodes carry optional `notePath` for future functional graph.
- Roadmap/phases: `.claude/spec/04-roadmap.md`. Update phase status there as work completes.
- Git: remote `origin` = git@github.com:itsgoofer/dash.git — **commit + push after each completed phase**.
- **NO test suite** (Goofer's call, 2026-07-17). Verify per phase: `flutter analyze` clean + `flutter build macos --debug` + run the app. Code effectively/efficiently instead.
- Flutter at `/Users/omar/flutter/bin/flutter` (3.44 stable).
- Attachments: ANY attached file is copied into vault `Attachments/` (self-contained vault), images inline, others as links.
- Design: **Inter font** (bundled asset), **4px radii everywhere** — no rounded/pill buttons. **Icons = Material Symbols SVGs in assets/icons via DashIcon widget — NEVER the Icons.* font.** Full system: `.claude/spec/05-design-system.md`.
- Goofer wants **Notion-ish niceties**: slash-command menu, hover actions, callouts, gallery/board views. UI-only — md stays storage truth.
- **UI Redesign v2 pending** (after Phase 6, Fable implements directly): darker gray/navy + white text, changeable accent (vault setting), smaller text/better typography, bigger brain on home, minimal darker charts, journal side-calendar nav, Notion-style property rows instead of sliders, fullscreen by default. Spec: `.claude/spec/06-redesign.md`.
- Model routing: Sonnet 5 for routine implementation, **Opus/Fable for complicated tasks** (custom editor, live preview, watcher/index concurrency, brain painter), Haiku for explore/research.
