# Dash — Batch Plan

## Original request (reference)

Bugs: (1) new journal entry not visible on dashboard right away; (2) project updates don't refresh tile progress bar until accent change; (3) DB entry form not reset, keeps old item data; (4) DB/item creation-update flow buggy — tables, dashboard counts, chart stale or never update, items sometimes never added; (5) vault-name menu cut off → make it a centered modal.
Improvements: (6) streamline Custom Props modal, add dynamic-date type (auto-today on creation), rename checkbox→boolean; (7) cover images for DB entries + Notion-style up/down repositioning.
Projects module: (8) statuses pending/in progress/paused/cancelled/done/planning; (9) no tasks in both body AND frontmatter; (10) templating system (frontmatter/body templates for any db/project item).
Layout: (11) frontmatter → right-side collapsible sidebar, vertical stack, beautiful; (12) optional header image fading out to bottom, body starts at fade; (13) center body between left edge and sidebar; (14) hidden md markers on inactive lines must take NO width ("## Title" → "Title" flush left).
New: (15) "Notes" section for non-databaseable notes (list + search).
Global: (16) tags + backlinks everywhere, Obsidian-style, only if useful + feeds 3D neural viz.

Routing: Fable plans, Opus codes hard parts, Sonnet easy/mechanical.

---

## Phase 1 — Reactivity & save pipeline (bugs 1, 2, 3, 4) [Opus]

Root cause: indexProvider only updates via filesystem watcher (~1.3s+ lag), edit debounce timers are cancelled (not flushed) on dispose, empty-title guard silently drops entries.

- [x] Flush-on-dispose: `ref.onDispose` now fires a final `_persist(d)` (state-free write) in both notifiers — navigating away before the debounce no longer drops the edit.
- [x] Write-through index: added `IndexNotifier.applyLocalWrite/applyLocalDelete/hashOf` + `VaultIndex.metaFromContent`; every `_persist` reflects the save into the index immediately (watcher still reconciles, no-ops the echo).
- [x] New-entry creation: replaced the hard empty-title guard with `_hasContent` — saves as "Untitled" when body/fields set, only skips a truly blank entry; creation write-throughs so tables/counts update at once.
- [x] Project tile progress: write-through updates the note's contentHash → `projectTaskCountsProvider` family re-fires without the accent-remount hack (`app.dart` left as-is for real accent changes).
- [x] Form reset: `_FieldControlState.didUpdateWidget` resyncs the text controller; `DatabasesNavNotifier.showEntry(path:null)` invalidates the `(slug,null)` provider so "New entry" opens blank.
- [x] Reduced edit debounce 1s → 400ms in both `_schedule` methods.

Verify: `flutter analyze` clean ✓. Shot-harness end-to-end pass pending (create journal/DB item/toggle task → dashboard/table/tile refresh within a frame).

## Phase 2 — Vault modal (bug 5) [Sonnet]

- [ ] Replace `_VaultChip` DashMenuAnchor (`lib/features/shell/shell.dart:395-514`) with a centered modal dialog following `showConfirmDialog` pattern (`lib/widgets/confirm_dialog.dart:8-33`); actions from `lib/vault/vault_actions.dart`. Keep DashIcon/4px-radius design language.

Verify: shot of vault modal centered, no truncation, near-right-edge window width.

## Phase 3 — Editor/layout redesign (11, 12, 13, 14) [Opus for 14, Sonnet for rest]

- [ ] Right properties sidebar: build a reusable collapsible `PropertiesSidebar` from `_FieldsPanel/_FieldControl` (`entry_form.dart:105-208`); convert outer Columns to `Row(Expanded(body), sidebar)` in `journal_screen.dart:24-77`, `project_detail_screen.dart:37-156`, `entry_form.dart:46-101`. Gotcha: read/edit toggle already occupies top-right (`editor.dart:479-520`) — place collapse control to avoid collision.
- [ ] Center body: keep maxWidth 720 (sync BOTH `editor.dart:449` and `blocks/read_view.dart:143`), center within space left of the sidebar.
- [ ] Header fade: extend bottom gradient in `note_cover.dart:98-106` to full fade into bg0; overlap body start with the fade region (Stack/negative padding in each screen).
- [ ] Zero-width hidden markers: `lib/core/../markdown_editing_controller.dart:34` buildTextSpan — inactive markers currently transparent-but-full-width. RISK: making them zero-width (fontSize:1 trick like inline images, line 149) breaks caret/click offset mapping — must remap text-position↔visual-offset; budget the most time here, verify caret placement, selection, and line-activation clicks extensively.

Verify: shots of journal/project/db entry — sidebar collapsed+expanded, centered body, fading cover; edit-mode shot proving "## Title" flush-left with working caret clicks.

## Phase 4 — Schema/props & covers (6, 7) [Sonnet, Opus for cover drag]

- [ ] Rename checkbox→boolean: label-only change in `schema_editor.dart` dropdown + `entry_form.dart` display; KEEP enum value `checkbox` in `db_schema.dart` (no vault migration).
- [ ] Dynamic date: add flag (or `FieldType.dynamicDate`) on date fields; on entry creation `DbEntryNotifier` fills today (yyyy-MM-dd, matches DashDateField `dash_controls.dart:734-796`).
- [ ] Streamline schema editor UI (`lib/features/databases/schema_editor.dart`): compact rows, adaptive layout, DashControls only.
- [ ] DB entry covers: wire `NoteCoverHeader` (`note_cover.dart:17`) into `entry_form.dart` (currently only journal + project screens use it).
- [ ] Cover reposition: add `coverY` frontmatter value; vertical drag in `note_cover.dart` `_banner` mapping to `Alignment/FractionalOffset`. Gotcha: clamp 0-1, persist through the Phase-1 write path.

Verify: shot — new entry with dynamic date pre-filled, boolean label, DB entry cover dragged and persisted after reload.

## Phase 5 — Projects module (8, 9, 10) [Sonnet, Opus for templating]

- [ ] Expand statuses to pending/in progress/paused/cancelled/done/planning: `vault_scaffold.dart:7-14` (new vaults), migrate existing vaults via `addSchemaOption` (`schema_ops.dart`), fallback list `project_detail_screen.dart:33`, colors `project_widgets.dart:9-14`. Gotcha: existing-vault yaml migration must be idempotent.
- [ ] Replace hardcoded `=='active'` filters (providers.dart:347, :364) with an in-flight status set {pending, in progress, planning} (+ map legacy 'active'→'in progress').
- [ ] Tasks single-source: keep tasks body-only (`lib/core/tasks.dart`); verify `project_detail_screen.dart` `_Body` (80-156) and the new sidebar never render task fields from frontmatter — no duplication.
- [ ] Templating: templates as md files in `.dash/templates/`; picker (Dash overlay menu) on new project/db entry; apply = merge template frontmatter + body in `DbEntryNotifier` initial-body and `projects_list_screen._createProject`.

Verify: shot — project with each status color; new project from template; dashboard active-projects count correct with new statuses.

## Phase 6 — Notes section (15) [Sonnet]

- [ ] Add `ShellSection.notes` (`providers.dart:19`), tab in `shell.dart:54-59`, body case `shell.dart:106-111`.
- [ ] Index accessor for "plain notes" (VaultIndex.byPath minus db/journal/project paths) in `lib/vault/index.dart` or a derived provider.
- [ ] NotesListScreen mirroring DbListScreen: grid/list + search field (DashControls), opens NoteEditor with Phase-3 layout.

Verify: shot — notes tab listing loose .md files, search filtering, open+edit round-trip indexed instantly (Phase 1).

## Phase 7 — Tags & backlinks (16) [GATED — confirm with Goofer before building]

Only if it earns its keep and feeds the brain viz. Decide scope first; skip cancelled/paused ideas.

- [ ] Link-graph pass in `lib/vault/index.dart`: parse `[[wikilinks]]` + `#tags` at index time; store forward/back maps on VaultIndex.
- [ ] Inline rendering: extend `markdown_editing_controller.dart` regex + `read_view.dart` for link/tag styling and click-to-navigate.
- [ ] Backlinks panel: small section in the Phase-3 properties sidebar.
- [ ] Brain viz: feed link edges into brain model (nodes already carry `notePath`) — connections mirror real note graph.

Verify: shot — note with tag + wikilink rendered, backlink shown on target, brain viz edge appears.
