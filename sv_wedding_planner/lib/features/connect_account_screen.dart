import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';

/// Prompts the user to connect a Google/Gmail account, which gates the AI
/// Copilot and unlocks live online suggestions.
///
/// The connect action here is a lightweight stand-in for real Google OAuth.
/// To make it production-real, wire `google_sign_in`, then call
/// `accountProvider.notifier.connect(googleUser.email)` on success — no other
/// screen needs to change.
class ConnectAccountScreen extends ConsumerStatefulWidget {
  /// If set, pop and run this after a successful connect (e.g. open Copilot).
  final VoidCallback? onConnected;
  const ConnectAccountScreen({super.key, this.onConnected});

  @override
  ConsumerState<ConnectAccountScreen> createState() => _ConnectAccountScreenState();
}

class _ConnectAccountScreenState extends ConsumerState<ConnectAccountScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  Future<void> _connect() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid Gmail address.')));
      return;
    }
    setState(() => _busy = true);
    await ref.read(accountProvider.notifier).connect(email);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pop();
    widget.onConnected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = ref.watch(accountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect account')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Icon(Icons.auto_awesome, size: 48, color: AppTheme.gold),
          const SizedBox(height: 12),
          Text('Connect Gmail to use the AI Copilot',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'The AI Wedding Copilot and live online suggestions (real honeymoon '
            'prices, vendor & outfit picks) require a connected Google account. '
            'Your basic roadmap, budget and reminders always work offline.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (account.connected)
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.verified, color: Colors.green),
                title: Text('Connected as ${account.email}'),
                trailing: TextButton(
                  onPressed: () => ref.read(accountProvider.notifier).disconnect(),
                  child: const Text('Disconnect'),
                ),
              ),
            )
          else ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Gmail address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _connect,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 8),
            Text(
              'Demo connect. Production wiring uses google_sign_in OAuth.',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}
