import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class DialogClearCache extends StatefulWidget {
  const DialogClearCache({Key? key}) : super(key: key);

  @override
  State<DialogClearCache> createState() => _DialogClearCacheState();
}

class _DialogClearCacheState extends State<DialogClearCache> {
  bool _isClearing = false;

  Future<void> _clearCache() async {
    if (!mounted) return;

    setState(() {
      _isClearing = true;
    });

    try {
      final client = Provider.of<Client>(context, listen: false);

      // Logout to end the session
      await client.logout();

      // Clear the local database
      await client.database?.clear();

      if (!mounted) return;

      // Navigate back to intro page
      context.go('/');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isClearing = false;
      });

      // Show error dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
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
      content: _isClearing
          ? const SizedBox(
              height: 50,
              child: Center(
                child: CircularProgressIndicator(),
              ),
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
          TextButton(
            onPressed: _clearCache,
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }
}
