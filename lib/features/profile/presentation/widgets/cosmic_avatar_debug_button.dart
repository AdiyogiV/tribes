import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';

/// THROWAWAY debug trigger to preview the AI cosmic avatar during development.
///
/// Delete this widget (and its single call site in edit_user_profile.dart) once
/// generation is wired into the onboarding signs-reveal. It exists only so we
/// can eyeball Imagen's mythic-playful output inside the real app, since the
/// laptop can't call Vertex directly (VPC Service Controls).
class CosmicAvatarDebugButton extends StatefulWidget {
  const CosmicAvatarDebugButton({super.key});

  @override
  State<CosmicAvatarDebugButton> createState() =>
      _CosmicAvatarDebugButtonState();
}

class _CosmicAvatarDebugButtonState extends State<CosmicAvatarDebugButton> {
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    String? url;
    String? error;
    try {
      url = await AstrologyService().generateCosmicAvatar(force: true);
      if (url == null) error = 'Generation returned no URL (check function logs)';
    } catch (e) {
      error = e.toString();
    }
    if (!mounted) return;
    setState(() => _loading = false);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cosmic Avatar (debug)'),
        content: url != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(url, width: 260, height: 260,
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(url, style: const TextStyle(fontSize: 10)),
                ],
              )
            : Text('Failed: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _generate,
      icon: _loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(_loading ? 'Summoning...' : 'Generate cosmic avatar (debug)'),
    );
  }
}
