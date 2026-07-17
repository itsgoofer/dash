import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../../theme/dash_theme.dart';
import '../../vault/vault_scaffold.dart';
import '../../widgets/glass_panel.dart';
import '../../widgets/glow_text.dart';

/// Shown when no vault path has been chosen yet: open an existing folder or
/// scaffold a fresh vault into a new/empty one.
class VaultPicker extends ConsumerStatefulWidget {
  const VaultPicker({super.key});

  @override
  ConsumerState<VaultPicker> createState() => _VaultPickerState();
}

class _VaultPickerState extends ConsumerState<VaultPicker> {
  bool _busy = false;
  String? _error;

  Future<void> _openVault() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    await ref.read(vaultPathProvider.notifier).setPath(dir);
  }

  Future<void> _createVault() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await scaffoldVault(dir);
      await ref.read(vaultPathProvider.notifier).setPath(dir);
    } catch (e) {
      setState(() => _error = 'Could not create vault: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashColors.bg0,
      body: Center(
        child: GlassPanel(
          glow: true,
          padding: const EdgeInsets.all(DashSpace.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GlowText('DASH', style: DashType.display),
              const SizedBox(height: DashSpace.x2),
              Text(
                'No vault open yet',
                style: DashType.body.copyWith(color: DashColors.text1),
              ),
              const SizedBox(height: DashSpace.x4),
              if (_busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: DashColors.accent),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(onPressed: _openVault, child: const Text('Open Vault')),
                    const SizedBox(width: DashSpace.x3),
                    OutlinedButton(onPressed: _createVault, child: const Text('Create Vault')),
                  ],
                ),
              if (_error != null) ...[
                const SizedBox(height: DashSpace.x3),
                Text(_error!, style: DashType.label.copyWith(color: DashColors.danger)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
