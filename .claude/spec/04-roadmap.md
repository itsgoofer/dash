# Roadmap

Each phase is shippable. NO test suite (Goofer's call) — verify per phase: `flutter analyze` clean, `flutter build macos --debug`, run the app and exercise the feature. Standing check from Phase 2: open vault in Obsidian, confirm two-way interop.

## Phase 0 — Scaffold + window + design system  [x]
`flutter create` (macos+windows targets), window_manager/macos_window_utils (hidden titlebar, min size), `dash_theme.dart` built fully: palette, type scale, 8pt spacing, glass panel + glow widgets, animated sidebar shell with empty sections. Every later phase consumes this system.

## Phase 1 — Vault core  [x]
Vault picker (open/create), scaffold creation, frontmatter parse/serialize, `VaultFs` atomic writes, `VaultIndex` scan, watcher + debounce + self-write suppression.

## Phase 2 — Journal + basic editor  [x]
Today view, 5 glowing metric sliders (write frontmatter invisibly), document-styled source editor (Stage A), 1s-idle autosave, prev/next day nav + backfill.

## Phase 3 — Dashboard  [x]
Greeting, stat tiles (projects, tasks, streak), fl_chart 14-day area chart (rating/energy/productivity) from `dashboardMetricsProvider`, brain visual (CustomPainter, ~300 particles, neighbor edges, rotation, glow; paused on blur).

## Phase 4 — Databases  [ ]
Schema yaml parse, db list, typed sortable table view from index, entry create/edit (typed form + body editor), in-app new-database + field editor writing `.dash/databases/*.yaml`. Databases are fully user-defined — no presets ship with the app (Projects is the only built-in); creating one in-app is the primary flow, so make it first-class and polished.

## Phase 5 — Projects  [ ]
Built-in `projects.yaml` schema, project list with status chips, detail = fields + task checklist + notes body, project/task stats wired onto dashboard.

## Phase 6 — Editor live-preview polish (Stage B)  [ ]
Cursor-aware syntax hiding, block-hybrid rendering (images/HRs/tables), attachment handling: image paste (`super_clipboard`) + any-file drag (`desktop_drop`) → **copied into Attachments/** (never linked externally), images inline, other files as links.

## Later / ideas
Functional brain (nodes = real notes via `notePath`), Windows polish pass, global quick-search (cmd+K), journal templates.

Notion-ish niceties (fold into phases where natural, rest here): slash-command insert menu in editor (Phase 6 candidate), hover row actions in db tables (Phase 4), callout blocks (`> [!note]` Obsidian-style, rendered pretty), gallery/board views for databases, drag-to-reorder tasks.
