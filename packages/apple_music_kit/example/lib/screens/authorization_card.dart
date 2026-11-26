/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

/// Shows authorization + subscription state and a request button.
final class AuthorizationCard extends StatefulWidget {
  /// Creates the card bound to [client].
  const AuthorizationCard({super.key, required this.client});

  final AppleMusicClient client;

  @override
  State<AuthorizationCard> createState() => _AuthorizationCardState();
}

class _AuthorizationCardState extends State<AuthorizationCard> {
  MusicAuthorizationStatus? _auth;
  MusicSubscription? _sub;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final auth = await widget.client.authorization.getStatus();
    final sub = await widget.client.subscription.status;
    if (!mounted) return;
    setState(() {
      _auth = auth;
      _sub = sub;
    });
  }

  Future<void> _request() async {
    setState(() => _busy = true);
    try {
      await widget.client.authorization.request();
      await _refresh();
    } on MusicKitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.userMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = _auth;
    final sub = _sub;
    final authorized = auth == MusicAuthorizationStatus.authorized;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              authorized ? Icons.check_circle : Icons.cancel,
              color: authorized ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Authorization: ${auth?.name ?? '…'}'),
                  Text('Subscription: ${sub?.status.name ?? '…'}'),
                ],
              ),
            ),
            FilledButton(
              onPressed: _busy ? null : _request,
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Authorize'),
            ),
          ],
        ),
      ),
    );
  }
}
