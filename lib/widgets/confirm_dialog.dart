import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';
import 'dash_controls.dart';

/// Destructive-confirm dialog (entry/database deletion etc). Returns true if
/// confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  bool destructive = true,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: DashColors.bg1,
      shape: RoundedRectangleBorder(borderRadius: DashRadius.br, side: BorderSide(color: DashColors.glassBorder)),
      title: Text(title, style: DashType.heading),
      content: Text(message, style: DashType.body.copyWith(color: DashColors.text1)),
      actions: [
        DashButton('Cancel', onTap: () => Navigator.pop(context, false)),
        DashButton(
          confirmLabel,
          kind: destructive ? DashButtonKind.danger : DashButtonKind.primary,
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );
  return result ?? false;
}
