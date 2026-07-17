import 'package:flutter/material.dart';

import '../../theme/dash_theme.dart';
import '../../widgets/dash_icon.dart';

/// Back-to-previous-view icon button, shared by the table and entry screens.
class BackNavButton extends StatefulWidget {
  const BackNavButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  State<BackNavButton> createState() => _BackNavButtonState();
}

class _BackNavButtonState extends State<BackNavButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: DashSize.iconButton,
          height: DashSize.iconButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovering ? DashColors.hover : Colors.transparent,
            borderRadius: DashRadius.br,
          ),
          child: DashIcon('chevron_left', size: 18, color: _hovering ? DashColors.text0 : DashColors.text1),
        ),
      ),
    );
  }
}

/// "Changed on disk while editing" banner — same look as Journal's.
class ChangedOnDiskBanner extends StatelessWidget {
  const ChangedOnDiskBanner({super.key, required this.onReload, this.message = 'This changed on disk while you were editing.'});
  final VoidCallback onReload;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DashSpace.x3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DashSpace.x3, vertical: DashSpace.x2),
        decoration: BoxDecoration(
          color: DashColors.warning.withValues(alpha: 0.12),
          borderRadius: DashRadius.br,
          border: Border.all(color: DashColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const DashIcon('warning', size: 16, color: DashColors.warning),
            const SizedBox(width: DashSpace.x2),
            Expanded(child: Text(message, style: DashType.label.copyWith(color: DashColors.warning))),
            TextButton(onPressed: onReload, child: const Text('Reload')),
          ],
        ),
      ),
    );
  }
}
