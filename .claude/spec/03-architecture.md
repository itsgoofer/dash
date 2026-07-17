# Architecture

```
UI (features/) → State (riverpod) → Index (in-memory) → Vault I/O → Disk
                 Core models & parsers shared by all      (strict downward deps)
```

## Packages

`flutter_riverpod` · `fl_chart` · `markdown` (AST; NOT flutter_markdown — discontinued) · `yaml` (read only; frontmatter written by tiny hand-rolled serializer for byte stability) · `watcher` · `window_manager` + `macos_window_utils` · `file_picker` · `shared_preferences` (last vault path + window prefs only) · `super_clipboard` + `desktop_drop` (image paste/drag) · `path`, `intl`, `collection`. No router (sidebar + IndexedStack). No sqlite/isar/hive — the vault is the database.

## Layers

- **`lib/vault/vault_fs.dart`** — pure file ops: read note, atomic write (tmp+rename), save attachment, vault scaffold creation. No app logic.
- **`lib/core/frontmatter.dart`** — split leading `---` fences, YAML→`Map<String,dynamic>`, body kept as raw string. Serializer: schema-ordered keys, skip unset fields, semantic-no-change → keep original bytes.
- **`lib/vault/index.dart`** — `VaultIndex` (riverpod Notifier): startup scan `**/*.md` (skip `.dash/`, dotfiles), frontmatter only, bodies lazy. `NoteMeta {path, type, frontmatter, mtime, contentHash}` keyed by path + secondary maps (journal-by-date, entries-by-db, projects).
- **`lib/vault/vault_watcher.dart`** — `watcher` events → 300ms debounce → hash-compare vs index, skip identical. **Self-write suppression:** every write registers (path, hash) in `expectedWrites` with short TTL; matching events dropped. Watcher errors / directory events → cheap full rescan.
- **`lib/state/providers.dart`** — `vaultProvider`, `indexProvider`, `dashboardMetricsProvider` (last-14-days series), `dbRowsProvider(db)`, `openNoteProvider` (body load + ~1s idle autosave debounce).
- **External edits while open:** editor clean → silent reload; dirty → non-blocking "changed on disk" banner (reload / keep). Never auto-merge.

## Editor (source-first)

Markdown text IS the document model (like Obsidian's CodeMirror). Fidelity is perfect by construction — we only save what the user typed.

- **Stage A:** multiline TextField + `MarkdownEditingController.buildTextSpan` — display-size headings, real bold/italic, dimmed markers, styled checkboxes/links. Frontmatter stripped from the editing surface (managed by UI controls).
- **Stage B (polish):** hide syntax markers away from cursor line; block-hybrid rendering (focused block = editable TextField, others rendered md, inline images/HRs/tables).
- **Fallback if B stalls:** Stage A + toggle rendered preview pane from `markdown` AST.

## lib/ layout

```
lib/
  main.dart                 # window setup, vault bootstrap, ProviderScope
  app.dart                  # MaterialApp, dark theme, Shell
  theme/dash_theme.dart     # palette, type scale, spacing, glow/glass styles
  core/
    models/                 # note.dart, journal_entry.dart, db_schema.dart, project.dart
    frontmatter.dart
    tasks.dart              # parse/toggle "- [ ]" lines (string-level)
  vault/                    # vault_fs, vault_scaffold, vault_watcher, index
  state/providers.dart
  features/
    shell/                  # sidebar nav, window chrome, vault picker
    dashboard/              # screen, metric_charts, stat_tiles, brain/ (view, painter, model)
    journal/                # screen, metric_sliders, day_nav
    databases/              # db_list, db_table_view, entry_form, schema_editor
    projects/               # screen, detail, task_list
    editor/                 # editor, markdown_editing_controller, blocks/ (stage B)
  widgets/                  # glass_panel, glow_text, empty_state
```

## Risks & mitigations

1. **Editor complexity** — source-first kills fidelity risk; only rendering polish can slip; fallback defined.
2. **Watch loops** — suppression + debounce + hash compare. Test: save storm → exactly one index update.
3. **Dropbox conflicts** — atomic writes, byte-stable output, conflicted-copy detection banner.
4. **Perf** — frontmatter-only index, lazy bodies, RepaintBoundary + pause-on-blur for animations.
