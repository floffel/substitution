import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class DialogClearCache extends StatefulWidget {
  const DialogClearCache({super.key});

  @override
  State<DialogClearCache> createState() => _DialogClearCacheState();
}

class _DialogClearCacheState extends State<DialogClearCache> {
  bool _isClearing = false;

  Future<void> _clearCache() async {
    setState(() {
      _isClearing = true;
    });

    try {
      final client = Provider.of<Client>(context, listen: false);
      // Logout will clear persisted credentials and local client state
      await client.logout();

      if (!mounted) return;
      // After clearing cache, navigate to root so age-gate/intro flow can re-run
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isClearing = false;
      });
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to clear cache: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clear Cache'),
      content:
          _isClearing
              ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
              : const Text(
                'This will delete all local data. You will be logged out.',
              ),
      actions: [
        if (!_isClearing) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(onPressed: _clearCache, child: const Text('Clear')),
        ],
      ],
    );
  }
}
