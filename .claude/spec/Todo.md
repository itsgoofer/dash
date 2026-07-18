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

- [x] Replaced `_VaultChip` DashMenuAnchor with a centered `showDialog`/`Dialog` modal (vault-name header + reused `_VaultMenuItem` rows); errors now surface via the chip tooltip. Chip is a click target (MouseRegion + GestureDetector). No edge clipping.

Verify: `flutter analyze` clean ✓. Visual shot pending.

## Phase 3 — Editor/layout redesign (11, 12, 13, 14) [Opus for 14, Sonnet for rest]

- [x] Right properties sidebar: new reusable `lib/widgets/properties_sidebar.dart` (`PropertiesSidebar` + `PropertyGroup`, app-wide collapse via `propertiesCollapsedProvider`, animates to a 40px strip). Wired into journal (metrics + calendar), project (status + software; tasks stay in the body), and db-entry (schema fields) screens via `Row(Expanded(main), PropertiesSidebar(...))`.
- [x] Center body: NoteEditor `centered: true` on all three screens (720px measure centered in the space left of the sidebar).
- [x] Header fade: `note_cover.dart` gradient now fades transparent→transparent→bg0 over the lower third; removed the bottom margin so the body starts right at the fade.
- [x] Zero-width hidden markers: inactive-line markers collapse to fontSize-1 (~zero width) in `markdown_editing_controller.dart`, with the heading branch collapsing too — "## Title" reads flush-left; clicking a line re-activates and re-expands the markers (same trick already used for inline images).

Verify: `flutter analyze` clean ✓, `flutter build macos --debug` ✓. Interactive/visual check of caret clicks + collapse animation pending on Goofer's machine.

## Phase 4 — Schema/props & covers (6, 7) [Sonnet, Opus for cover drag]

- [x] Rename checkbox→boolean: label-only via `_fieldTypeLabel` in `schema_editor.dart` (dropdown shows "Boolean"); enum value `checkbox` unchanged (no vault migration).
- [x] Dynamic date: new `FieldType.dynamicDate` (renders/edits exactly like `date`); `DbEntryNotifier.build` prefills today (yyyy-MM-dd) on new entries, and `_hasContent` ignores it so opening "New entry" doesn't create a blank note.
- [x] Streamlined schema editor: rows grouped in bordered containers, added a Required toggle, aligned controls; DashControls only.
- [x] DB entry covers: `NoteCoverHeader` wired into `entry_form.dart` (cover + coverY via `fields['cover']`/`fields['coverY']`).
- [x] Cover reposition: `NoteCoverHeader` gains `coverY` + `onReposition`; vertical drag maps to `Alignment(0, coverY*2-1)`, clamped 0–1, resize cursor. Persisted for journal (new `JournalDoc.coverY`), project, and db entries via the Phase-1 write path.

Verify: `flutter analyze` clean ✓; build pending. Visual/drag check on Goofer's machine.

## Phase 5 — Projects module (8, 9, 10) [Sonnet, Opus for templating]

- [x] Statuses expanded to planning/pending/in progress/paused/cancelled/done. Migration-free: new constant `lib/core/project_status.dart` (`kProjectStatuses`) drives the status dropdown regardless of vault yaml; scaffold updated for new vaults; `statusColor` gained cases for the new set.
- [x] Replaced hardcoded `=='active'` filters with `kActiveStatuses.contains(...)` (planning/pending/in progress + legacy 'active' still count); new projects start `kDefaultProjectStatus` = 'planning'.
- [x] Tasks single-source: verified — tasks live only as body markdown (`lib/core/tasks.dart`); no frontmatter task field exists anywhere, so nothing is duplicated. The Tasks panel and body editor are two views of the same body string (intentional).
- [x] Templating: `lib/vault/templates.dart` (list/load/save under `.dash/templates/`) + `TemplateMenu` widget (apply a template's fields+body, or save the current item as a template) wired into the DB-entry and project screens.

Verify: `flutter analyze` clean ✓, build ✓. Template apply/save round-trip pending on Goofer's machine.

## Phase 6 — Notes section (15) [Sonnet]

- [x] Added `ShellSection.notes` + shell tab (after Journal) + body case; command palette (⌘-digit) + `_openNote` updated for the new section.
- [x] Plain-notes accessor: `notesListProvider` (all `NoteType.note` entries, newest first) + `notesNavProvider` (list ↔ detail).
- [x] `NotesScreen`: searchable card grid + "New note" (creates `Notes/<title>.md`) + a detail editor over `plainNoteProvider` (new `PlainNoteNotifier`, same write-through + flush-on-dispose pipeline; frontmatter preserved, fence-free when empty). Centered body, no sidebar.

Verify: `flutter analyze` clean ✓, build pending. Icon: reused `edit` (no dedicated notes glyph in assets).

## Phase 7 — Tags & backlinks (16) [GATED — confirm with Goofer before building]

Only if it earns its keep and feeds the brain viz. Decide scope first; skip cancelled/paused ideas.

- [ ] Link-graph pass in `lib/vault/index.dart`: parse `[[wikilinks]]` + `#tags` at index time; store forward/back maps on VaultIndex.
- [ ] Inline rendering: extend `markdown_editing_controller.dart` regex + `read_view.dart` for link/tag styling and click-to-navigate.
- [ ] Backlinks panel: small section in the Phase-3 properties sidebar.
- [ ] Brain viz: feed link edges into brain model (nodes already carry `notePath`) — connections mirror real note graph.

Verify: shot — note with tag + wikilink rendered, backlink shown on target, brain viz edge appears.
