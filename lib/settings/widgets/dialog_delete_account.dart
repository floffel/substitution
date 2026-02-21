import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

class DialogDeleteAccount extends StatefulWidget {
  const DialogDeleteAccount({super.key});

  @override
  State<DialogDeleteAccount> createState() => _DialogDeleteAccountState();
}

class _DialogDeleteAccountState extends State<DialogDeleteAccount> {
  bool _isDeleting = false;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password.')),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final client = Provider.of<Client>(context, listen: false);

      final authData = AuthenticationPassword(
        password: password,
        identifier: AuthenticationUserIdentifier(user: client.userID!),
      );

      // Call deactivateAccount, erase: true ensures all content from the user is marked for redaction
      await client.deactivateAccount(
        erase: true,
        auth: authData,
      );

      // Ensure the internal state and the local SQLite database cache are cleared.
      await client.logout();
      await client.database.clear();

      if (!mounted) return;

      // Navigate back to the intro page where the user can login again or close the app
      context.go('/');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
      });

      // Show error dialog
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to delete account: $e'),
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
      title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
      content: _isDeleting
          ? const SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 16),
                    Text('Deleting account data...'),
                  ],
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to permanently delete your account?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This action cannot be undone. All your posts, messages, and uploaded files will be requested to be erased from the server.',
                ),
                const SizedBox(height: 16),
                const Text('Enter your password to confirm:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
      actions: [
        if (!_isDeleting) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: _deleteAccount,
            child: const Text('Confirm Delete Account'),
          ),
        ],
      ],
    );
  }
}
