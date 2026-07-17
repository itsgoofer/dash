# Vault Format (Obsidian-compatible)

Vault = any folder on disk (user puts it in Dropbox). Plain .md + YAML frontmatter; Obsidian can open it directly (it just adds its own `.obsidian/`). Dash config lives in `.dash/` (dotfolder → ignored by Obsidian, travels with the vault).

```
MyVault/
  .dash/
    settings.yaml               # vault prefs: journal folder, attachments folder
    databases/
      projects.yaml             # the ONLY schema created by scaffold; user-editable
      movies.yaml               # EXAMPLE — user creates any databases they want in-app
  Journal/2026/2026-07-17.md    # year subfolders
  Databases/Movies/Dune Part Two.md
  Projects/Sci-fi Corridor.md
  Attachments/2026/img-20260717-154233.png
```

## Journal note

```yaml
---
type: journal
date: 2026-07-17
energy: 7        # all metrics 1–10, omitted if unset
rating: 6
productivity: 8
exercise: 3
gaming: 5
---
Free markdown body…
```

## Database schema

Databases are entirely user-defined: created, named, and field-designed in-app (which writes a schema yaml + creates the folder). Nothing is preset except Projects. Example (`.dash/databases/movies.yaml`):

```yaml
name: Movies
folder: Databases/Movies
fields:
  - {name: title, type: text, required: true}   # title = filename
  - {name: rating, type: number, min: 1, max: 10}
  - {name: watched, type: date}
  - {name: status, type: select, options: [backlog, watching, done]}
```

Field types: `text, number, date, checkbox, select, multiselect, url`.
Filename = sanitized title; on drift, frontmatter is authoritative.

## Entry / Project notes

- DB entry frontmatter: `type: db`, `db: movies`, then schema fields; optional md body.
- Project frontmatter: `type: project`, `status: active|paused|done`, `software: [Blender, Houdini]`, schema in `.dash/databases/projects.yaml`; **tasks are standard `- [ ]` lines in the body** (Obsidian-compatible). Toggling rewrites only the `[ ]`↔`[x]` characters via line-level string edits — never AST rewrite.

## Attachments

**Anything attached to a note — image, PDF, video, .blend, any file — is COPIED into the vault** at `Attachments/<year>/…` (never referenced at its original outside path), so the vault stays self-contained and Dropbox-portable.

- Pasted images: `img-<yyyyMMdd-HHmmss>[-n].png`.
- Dragged/picked files: keep original basename, timestamp-prefix on collision.
- Images embed inline: `![](Attachments/2026/img-….png)`; other file types link: `[name.pdf](Attachments/2026/name.pdf)`. Both relative + Obsidian-renderable.

## Write rules (Dropbox safety)

- Atomic writes: write `x.md.tmp`, rename over target.
- Byte-stable serialization: fixed key order (schema order), only write set fields; **never rewrite a file whose semantic content didn't change** (if reparse equals old values, keep original bytes).
- Detect `* (conflicted copy *` filenames during scan → surface banner; user resolves manually, no auto-merge.
