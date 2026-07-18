import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dash_theme.dart';
import 'dash_chip.dart';
import 'dash_icon.dart';

/// Field text style used by all controls — tighter line height than body so
/// controls stay [DashSize.control] tall.
const _fieldStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 13,
  height: 1.2,
  fontWeight: FontWeight.w400,
  color: DashColors.text0,
);

/// Tight, fixed-height text field. One height for every control in a row.
class DashTextField extends StatefulWidget {
  const DashTextField({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.numeric = false,
    this.icon,
    this.height = DashSize.control,
    this.style,
  });

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  /// Rejects any input that isn't a (possibly negative, possibly decimal) number.
  final bool numeric;
  final String? icon;
  final double height;
  final TextStyle? style;

  @override
  State<DashTextField> createState() => _DashTextFieldState();
}

class _DashTextFieldState extends State<DashTextField> {
  final _focus = FocusNode();
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: DashMotion.hover,
        height: widget.height,
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
        decoration: BoxDecoration(
          color: DashColors.bg1,
          borderRadius: DashRadius.br,
          border: Border.all(
            color: focused
                ? DashColors.accent
                : _hovering
                    ? Colors.white.withValues(alpha: 0.14)
                    : DashColors.glassBorder,
          ),
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              DashIcon(widget.icon!, size: 14, color: focused ? DashColors.accent : DashColors.text2),
              const SizedBox(width: DashSpace.x2),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                style: widget.style ?? _fieldStyle,
                cursorHeight: 14,
                inputFormatters: widget.numeric
                    ? [
                        TextInputFormatter.withFunction((old, next) =>
                            RegExp(r'^-?\d*\.?\d*$').hasMatch(next.text) ? next : old),
                      ]
                    : null,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: widget.hint,
                  hintStyle: _fieldStyle.copyWith(color: DashColors.text2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum DashButtonKind { primary, ghost, danger }

/// Tight button, same height as [DashTextField] so rows line up.
class DashButton extends StatefulWidget {
  const DashButton(
    this.label, {
    super.key,
    required this.onTap,
    this.kind = DashButtonKind.ghost,
    this.icon,
    this.height = DashSize.control,
  });

  final String label;
  final VoidCallback? onTap;
  final DashButtonKind kind;
  final String? icon;
  final double height;

  @override
  State<DashButton> createState() => _DashButtonState();
}

class _DashButtonState extends State<DashButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (widget.kind) {
      DashButtonKind.primary => (
          _hovering ? Color.lerp(DashColors.accent, Colors.white, 0.12)! : DashColors.accent,
          DashColors.bg0,
          Colors.transparent,
        ),
      DashButtonKind.ghost => (
          _hovering ? DashColors.hover : Colors.transparent,
          _hovering ? DashColors.text0 : DashColors.text1,
          DashColors.glassBorder,
        ),
      DashButtonKind.danger => (
          DashColors.danger.withValues(alpha: _hovering ? 0.22 : 0.12),
          DashColors.danger,
          DashColors.danger.withValues(alpha: 0.35),
        ),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DashMotion.hover,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: bg, borderRadius: DashRadius.br, border: Border.all(color: border)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                DashIcon(widget.icon!, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(widget.label,
                  style: TextStyle(
                      fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, height: 1.0, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tight icon-only button (no Material 48px tap-target inflation).
class DashIconBtn extends StatefulWidget {
  const DashIconBtn(this.icon, {super.key, required this.onTap, this.color, this.tooltip, this.size = 15});
  final String icon;
  final VoidCallback? onTap;
  final Color? color;
  final String? tooltip;
  final double size;

  @override
  State<DashIconBtn> createState() => _DashIconBtnState();
}

class _DashIconBtnState extends State<DashIconBtn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final child = MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DashMotion.hover,
          width: DashSize.iconButton,
          height: DashSize.iconButton,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: _hovering ? DashColors.hover : Colors.transparent, borderRadius: DashRadius.br),
          child: DashIcon(widget.icon,
              size: widget.size, color: widget.color ?? (_hovering ? DashColors.text0 : DashColors.text1)),
        ),
      ),
    );
    return widget.tooltip == null ? child : Tooltip(message: widget.tooltip!, child: child);
  }
}

/// 16px checkbox — 4px radius, no Material tap-target padding.
class DashCheckbox extends StatelessWidget {
  const DashCheckbox({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: DashMotion.hover,
          width: 16,
          height: 16,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: value ? DashColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: value ? DashColors.accent : DashColors.text2, width: 1.2),
          ),
          child: value ? const DashIcon('check', size: 12, color: DashColors.bg0) : null,
        ),
      ),
    );
  }
}

/// One entry of a [DashDropdown] / [DashMultiSelect] menu.
class DashOption<T> {
  const DashOption(this.value, this.label, {this.chipColor});
  final T value;
  final String label;

  /// Render the label as a colored chip (select-style options).
  final Color? chipColor;
}

/// An actual dropdown: field-like trigger, animated list anchored underneath.
/// No Material menu machinery anywhere near it.
class DashDropdown<T> extends StatefulWidget {
  const DashDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select…',
    this.onAddOption,
    this.triggerBuilder,
    this.height = DashSize.control,
    this.menuWidth,
  });

  final T? value;
  final List<DashOption<T>> options;
  final ValueChanged<T> onChanged;
  final String hint;

  /// When set, the menu gets a "+ add option" footer row.
  final ValueChanged<String>? onAddOption;

  /// Custom trigger (e.g. a status chip). Defaults to a field-look trigger.
  final Widget Function(BuildContext, bool open)? triggerBuilder;
  final double height;
  final double? menuWidth;

  @override
  State<DashDropdown<T>> createState() => _DashDropdownState<T>();
}

class _DashDropdownState<T> extends State<DashDropdown<T>> {
  Widget _defaultTrigger(BuildContext context, bool open, bool hovering) {
    final selected = widget.options.where((o) => o.value == widget.value).firstOrNull;
    return AnimatedContainer(
      duration: DashMotion.hover,
      height: widget.height,
      padding: const EdgeInsets.only(left: DashSpace.x2, right: 6),
      decoration: BoxDecoration(
        color: DashColors.bg1,
        borderRadius: DashRadius.br,
        border: Border.all(
            color: open
                ? DashColors.accent
                : hovering
                    ? Colors.white.withValues(alpha: 0.14)
                    : DashColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: selected == null
                ? Text(widget.hint,
                    style: _fieldStyle.copyWith(color: DashColors.text2), overflow: TextOverflow.ellipsis)
                : selected.chipColor != null
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: DashChip(selected.label, color: selected.chipColor!))
                    : Text(selected.label, style: _fieldStyle, overflow: TextOverflow.ellipsis),
          ),
          AnimatedRotation(
            turns: open ? 0.5 : 0,
            duration: DashMotion.duration,
            curve: DashMotion.curve,
            child: DashIcon('expand_more', size: 16, color: open ? DashColors.accent : DashColors.text2),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashMenuAnchor(
      menuWidth: widget.menuWidth,
      triggerBuilder: (context, open, hovering) =>
          widget.triggerBuilder?.call(context, open) ?? _defaultTrigger(context, open, hovering),
      itemCount: widget.options.length,
      itemBuilder: (context, i, close) {
        final o = widget.options[i];
        return _MenuRow(
          selected: o.value == widget.value,
          onTap: () {
            widget.onChanged(o.value);
            close();
          },
          child: o.chipColor != null
              ? Align(alignment: Alignment.centerLeft, child: DashChip(o.label, color: o.chipColor!))
              : Text(o.label, style: _fieldStyle, overflow: TextOverflow.ellipsis),
        );
      },
      footer: widget.onAddOption == null ? null : (context, close) => _AddOptionRow(onAdd: widget.onAddOption!),
    );
  }
}

/// Multi-select variant: chips in the trigger, checkbox rows that keep the
/// menu open while toggling.
class DashMultiSelect extends StatelessWidget {
  const DashMultiSelect({
    super.key,
    required this.values,
    required this.options,
    required this.onChanged,
    this.hint = 'Select…',
    this.onAddOption,
  });

  final List<String> values;
  final List<DashOption<String>> options;
  final ValueChanged<List<String>> onChanged;
  final String hint;
  final ValueChanged<String>? onAddOption;

  void _toggle(String v) {
    final next = List<String>.of(values);
    next.contains(v) ? next.remove(v) : next.add(v);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return DashMenuAnchor(
      triggerBuilder: (context, open, hovering) => AnimatedContainer(
        duration: DashMotion.hover,
        constraints: const BoxConstraints(minHeight: DashSize.control),
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2, vertical: 4),
        decoration: BoxDecoration(
          color: DashColors.bg1,
          borderRadius: DashRadius.br,
          border: Border.all(
              color: open
                  ? DashColors.accent
                  : hovering
                      ? Colors.white.withValues(alpha: 0.14)
                      : DashColors.glassBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: values.isEmpty
                  ? Text(hint, style: _fieldStyle.copyWith(color: DashColors.text2))
                  : Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final v in values) DashChip(v, color: DashChip.optionColor(v)),
                      ],
                    ),
            ),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: DashMotion.duration,
              curve: DashMotion.curve,
              child: DashIcon('expand_more', size: 16, color: open ? DashColors.accent : DashColors.text2),
            ),
          ],
        ),
      ),
      itemCount: options.length,
      itemBuilder: (context, i, close) {
        final o = options[i];
        final on = values.contains(o.value);
        return _MenuRow(
          selected: false,
          showCheckmark: false,
          onTap: () => _toggle(o.value),
          child: Row(
            children: [
              DashCheckbox(value: on, onChanged: (_) => _toggle(o.value)),
              const SizedBox(width: DashSpace.x2),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: DashChip(o.label, color: o.chipColor ?? DashChip.optionColor(o.label)),
                ),
              ),
            ],
          ),
        );
      },
      footer: onAddOption == null ? null : (context, close) => _AddOptionRow(onAdd: onAddOption!),
    );
  }
}

/// Shared anchor + overlay machinery: positions the menu under the trigger,
/// animates open/close, closes on outside tap or Escape.
class DashMenuAnchor extends StatefulWidget {
  const DashMenuAnchor({
    super.key,
    required this.triggerBuilder,
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
    this.menuWidth,
  });

  final Widget Function(BuildContext, bool open, bool hovering) triggerBuilder;
  final int itemCount;
  final Widget Function(BuildContext, int index, VoidCallback close) itemBuilder;
  final Widget Function(BuildContext, VoidCallback close)? footer;
  final double? menuWidth;

  @override
  State<DashMenuAnchor> createState() => _DashMenuAnchorState();
}

class _DashMenuAnchorState extends State<DashMenuAnchor> with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _portal = OverlayPortalController();
  late final AnimationController _anim;
  late final CurvedAnimation _curve;
  bool _open = false;
  bool _hovering = false;
  double _triggerWidth = 0;

  @override
  void initState() {
    super.initState();
    // Created eagerly: a lazy `late final` would be first touched in dispose(),
    // and creating a ticker during unmount does an illegal ancestor lookup.
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _curve = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  }

  @override
  void dispose() {
    _curve.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _show() {
    _triggerWidth = (context.findRenderObject() as RenderBox?)?.size.width ?? 200;
    setState(() => _open = true);
    _portal.show();
    _anim.forward(from: 0);
  }

  Future<void> _close() async {
    if (!_open) return;
    setState(() => _open = false);
    await _anim.reverse();
    if (mounted && _portal.isShowing) _portal.hide();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Positioned(
          width: widget.menuWidth ?? _triggerWidth,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            showWhenUnlinked: false,
            child: TapRegion(
              groupId: this,
              onTapOutside: (_) => _close(),
              child: FadeTransition(
                opacity: _curve,
                child: AnimatedBuilder(
                  animation: _curve,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -6 * (1 - _curve.value)),
                    child: Transform.scale(
                      scaleY: 0.9 + 0.1 * _curve.value,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                  child: _menu(context),
                ),
              ),
            ),
          ),
        ),
        child: TapRegion(
          groupId: this,
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (node, event) {
              if (_open && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                _close();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovering = true),
              onExit: (_) => setState(() => _hovering = false),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _open ? _close() : _show(),
                child: widget.triggerBuilder(context, _open, _hovering),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: const Color(0xFF11141C),
          borderRadius: DashRadius.br,
          border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: DashRadius.br,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.itemCount; i++) widget.itemBuilder(context, i, _close),
                if (widget.footer != null) ...[
                  if (widget.itemCount > 0)
                    Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: DashColors.glassBorder),
                  widget.footer!(context, _close),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.child, required this.onTap, this.selected = false, this.showCheckmark = true});
  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  final bool showCheckmark;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: DashMotion.hover,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: DashSpace.x2),
          decoration: BoxDecoration(
            color: _hovering ? DashColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            children: [
              Expanded(child: widget.child),
              if (widget.selected && widget.showCheckmark)
                DashIcon('check', size: 14, color: DashColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOptionRow extends StatefulWidget {
  const _AddOptionRow({required this.onAdd});
  final ValueChanged<String> onAdd;

  @override
  State<_AddOptionRow> createState() => _AddOptionRowState();
}

class _AddOptionRowState extends State<_AddOptionRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String v) {
    final t = v.trim();
    if (t.isEmpty) return;
    widget.onAdd(t);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: DashSpace.x2),
          const DashIcon('add', size: 14, color: DashColors.text2),
          const SizedBox(width: DashSpace.x2),
          Expanded(
            child: TextField(
              controller: _controller,
              style: _fieldStyle,
              cursorHeight: 13,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintText: 'Add option…',
                hintStyle: _fieldStyle.copyWith(color: DashColors.text2),
              ),
              onSubmitted: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
