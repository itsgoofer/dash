import 'package:flutter/material.dart';

import '../theme/dash_theme.dart';

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
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? DashColors.danger : DashColors.accent,
            foregroundColor: DashColors.bg0,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
