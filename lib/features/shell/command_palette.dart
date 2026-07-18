import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/models/note.dart';
import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';
import 'boot_screen.dart';

const _sections = [
  (section: ShellSection.dashboard, icon: 'dashboard', label: 'Dashboard'),
  (section: ShellSection.journal, icon: 'book_2', label: 'Journal'),
  (section: ShellSection.databases, icon: 'database', label: 'Databases'),
  (section: ShellSection.projects, icon: 'deployed_code', label: 'Projects'),
];

/// Shell-level keyboard layer: ⌘K / Ctrl+K toggles the command palette and
/// ⌘1–⌘4 (or Ctrl on other platforms) jump straight to a section. Only
/// Cmd/Ctrl-modified activators — plain typing is never intercepted.
class CommandPaletteScope extends ConsumerStatefulWidget {
  const CommandPaletteScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CommandPaletteScope> createState() => _CommandPaletteScopeState();
}

class _CommandPaletteScopeState extends ConsumerState<CommandPaletteScope> {
  bool _open = false;
  final _focus = FocusNode(debugLabel: 'shell-shortcuts', skipTraversal: true);

  void _toggle() => setState(() => _open = !_open);
  void _close() => setState(() => _open = false);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Boot overlay steals focus for its skip handler; take it back when done
    // so shortcuts keep working before the user ever clicks anything.
    ref.listen(bootCompleteProvider, (_, done) {
      if (done) _focus.requestFocus();
    });

    void select(int i) => ref.read(shellSectionProvider.notifier).select(_sections[i].section);
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _toggle,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): _toggle,
        for (var i = 0; i < digits.length; i++) ...{
          SingleActivator(digits[i], meta: true): () => select(i),
          SingleActivator(digits[i], control: true): () => select(i),
        },
      },
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            if (_open) CommandPalette(onClose: _close),
          ],
        ),
      ),
    );
  }
}

class _Cmd {
  const _Cmd({required this.icon, required this.title, this.subtitle, required this.run});

  final String icon;
  final String title;
  final String? subtitle;
  final void Function() run;
}

/// Centered glass overlay: fuzzy search over sections, quick actions, and
/// every note in the vault index. Arrows + Enter navigate, Esc closes.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette>
    with SingleTickerProviderStateMixin {
  static const _rowHeight = 44.0;
  static const _maxResults = 12;

  late final AnimationController _in;
  final _query = TextEditingController();
  final _scroll = ScrollController();
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 150))
      ..forward();
    _query.addListener(() => setState(() => _selected = 0));
  }

  @override
  void dispose() {
    _in.dispose();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Command sources ────────────────────────────────────────────────────────

  List<_Cmd> _all() {
    final shell = ref.read(shellSectionProvider.notifier);
    final cmds = <_Cmd>[
      for (final s in _sections)
        _Cmd(
          icon: s.icon,
          title: s.label,
          subtitle: 'Go to section',
          run: () => shell.select(s.section),
        ),
      _Cmd(
        icon: 'calendar_today',
        title: "Today's Journal",
        subtitle: 'Jump to today',
        run: () {
          ref.read(selectedJournalDateProvider.notifier).goToday();
          shell.select(ShellSection.journal);
        },
      ),
    ];

    final index = ref.watch(indexProvider).value;
    if (index == null) return cmds;

    final notes = index.byPath.values.toList()..sort((a, b) => b.mtime.compareTo(a.mtime));
    for (final note in notes) {
      cmds.add(_Cmd(
        icon: switch (note.type) {
          NoteType.journal => 'book_2',
          NoteType.db => 'database',
          NoteType.project => 'deployed_code',
          NoteType.note => 'title',
        },
        title: _titleOf(note),
        subtitle: note.path,
        run: () => _openNote(note),
      ));
    }
    return cmds;
  }

  static String _titleOf(NoteMeta note) =>
      (note.frontmatter['title'] as String?)?.trim().isNotEmpty == true
          ? note.frontmatter['title'] as String
          : p.basenameWithoutExtension(note.path);

  /// Deep-links where the nav providers allow; otherwise just lands on the
  /// closest section.
  void _openNote(NoteMeta note) {
    final shell = ref.read(shellSectionProvider.notifier);
    switch (note.type) {
      case NoteType.journal:
        final raw = note.frontmatter['date'];
        final date = raw is DateTime ? raw : DateTime.tryParse(raw?.toString() ?? '');
        if (date != null) ref.read(selectedJournalDateProvider.notifier).set(date);
        shell.select(ShellSection.journal);
      case NoteType.db:
        final slug = note.frontmatter['db'] as String?;
        if (slug != null) {
          ref.read(databasesNavProvider.notifier).showEntry(slug, path: note.path);
        } else {
          ref.read(databasesNavProvider.notifier).showList();
        }
        shell.select(ShellSection.databases);
      case NoteType.project:
        ref.read(projectsNavProvider.notifier).showDetail(note.path);
        shell.select(ShellSection.projects);
      case NoteType.note:
        // Plain notes have no viewer surface yet — nothing to open.
        break;
    }
  }

  List<_Cmd> _results() {
    final q = _query.text.trim();
    final all = _all();
    if (q.isEmpty) return all.take(_maxResults).toList();
    final scored = <(int, _Cmd)>[];
    for (final cmd in all) {
      final s = _fuzzyScore(q, cmd.title) ?? _fuzzyScore(q, cmd.subtitle ?? '');
      if (s != null) scored.add((s, cmd));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final e in scored.take(_maxResults)) e.$2];
  }

  /// Subsequence fuzzy match: null = no match, higher = better. Bonuses for
  /// word starts and consecutive runs.
  static int? _fuzzyScore(String query, String text) {
    final q = query.toLowerCase(), t = text.toLowerCase();
    if (q.isEmpty || t.isEmpty) return null;
    var score = 0, ti = 0, streak = 0;
    for (var qi = 0; qi < q.length; qi++) {
      final found = t.indexOf(q[qi], ti);
      if (found == -1) return null;
      final wordStart = found == 0 || ' /-_.'.contains(t[found - 1]);
      streak = found == ti ? streak + 1 : 1;
      score += 1 + streak * 2 + (wordStart ? 6 : 0) - ((found - ti) ~/ 4);
      ti = found + 1;
    }
    return score - (t.length ~/ 8); // slight preference for shorter targets
  }

  // ── Interaction ────────────────────────────────────────────────────────────

  void _activate(_Cmd cmd) {
    cmd.run();
    widget.onClose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, List<_Cmd> results) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onClose();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1, results.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _move(-1, results.length);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
        if (results.isNotEmpty) _activate(results[_selected.clamp(0, results.length - 1)]);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + delta) % count < 0
        ? (_selected + delta) % count + count
        : (_selected + delta) % count);
    // Keep the selection on screen.
    final target = _selected * _rowHeight;
    if (!_scroll.hasClients) return;
    final view = _scroll.position;
    if (target < view.pixels) {
      _scroll.jumpTo(target);
    } else if (target + _rowHeight > view.pixels + view.viewportDimension) {
      _scroll.jumpTo(target + _rowHeight - view.viewportDimension);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final results = _results();
    if (_selected >= results.length) _selected = results.isEmpty ? 0 : results.length - 1;
    final curve = CurvedAnimation(parent: _in, curve: Curves.easeOutCubic);

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose,
        child: FadeTransition(
          opacity: curve,
          child: Container(
            color: Colors.black.withValues(alpha: 0.45),
            alignment: const Alignment(0, -0.55),
            child: GestureDetector(
              onTap: () {}, // absorb taps inside the panel
              child: ScaleTransition(
                scale: Tween(begin: 0.98, end: 1.0).animate(curve),
                child: _panel(results),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(List<_Cmd> results) {
    return ClipRRect(
      borderRadius: DashRadius.br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: DashColors.bg1.withValues(alpha: 0.78),
            borderRadius: DashRadius.br,
            border: Border.all(color: DashColors.accent.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 16)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Focus(
                onKeyEvent: (node, event) => _onKey(node, event, results),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3, vertical: DashSpace.x2),
                  child: Row(
                    children: [
                      DashIcon('search', size: 16, color: DashColors.accent),
                      const SizedBox(width: DashSpace.x2),
                      Expanded(
                        child: TextField(
                          controller: _query,
                          autofocus: true,
                          style: DashType.body,
                          cursorColor: DashColors.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Search sections, actions, notes…',
                            hintStyle: DashType.body.copyWith(color: DashColors.text2),
                          ),
                        ),
                      ),
                      Text('ESC', style: DashType.hudLabel.copyWith(fontSize: 10, color: DashColors.text2)),
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: DashColors.glassBorder),
              Flexible(
                child: results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(DashSpace.x4),
                        child: Text('NO MATCHES', style: DashType.hudLabel.copyWith(color: DashColors.text2)),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        itemExtent: _rowHeight,
                        padding: const EdgeInsets.symmetric(vertical: DashSpace.x1),
                        itemCount: results.length,
                        itemBuilder: (context, i) => _row(results[i], i),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(_Cmd cmd, int index) {
    final selected = index == _selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _selected = index),
      child: GestureDetector(
        onTap: () => _activate(cmd),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: DashSpace.x1),
          padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
          decoration: BoxDecoration(
            color: selected ? DashColors.accentDim : Colors.transparent,
            borderRadius: DashRadius.br,
            border: Border(
              left: BorderSide(color: selected ? DashColors.accent : Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            children: [
              DashIcon(cmd.icon, size: 16, color: selected ? DashColors.accent : DashColors.text1),
              const SizedBox(width: DashSpace.x2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cmd.title,
                      style: DashType.body.copyWith(
                        fontSize: 13,
                        color: selected ? DashColors.text0 : DashColors.text1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (cmd.subtitle != null)
                      Text(
                        cmd.subtitle!,
                        style: DashType.small.copyWith(fontSize: 10, color: DashColors.text2),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (selected)
                Text('↵', style: DashType.small.copyWith(color: DashColors.text2)),
            ],
          ),
        ),
      ),
    );
  }
}
