/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

/// Capability matrix + debug info for the current platform.
final class CapabilitiesScreen extends StatefulWidget {
  /// Creates the screen bound to [client].
  const CapabilitiesScreen({super.key, required this.client});

  final AppleMusicClient client;

  @override
  State<CapabilitiesScreen> createState() => _CapabilitiesScreenState();
}

class _CapabilitiesScreenState extends State<CapabilitiesScreen> {
  MusicCapabilities? _caps;
  MusicStorefront? _storefront;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final caps = await widget.client.capabilities.get();
      final storefront = await widget.client.catalog.getCurrentStorefront();
      if (mounted) {
        setState(() {
          _caps = caps;
          _storefront = storefront;
        });
      }
    } on MusicKitException catch (e) {
      if (mounted) setState(() => _error = e.userMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caps = _caps;
    return Scaffold(
      appBar: AppBar(title: const Text('Capabilities')),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : caps == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    if (_storefront != null)
                      ListTile(
                        title: const Text('Storefront'),
                        subtitle:
                            Text('${_storefront!.id} — ${_storefront!.name}'),
                      ),
                    const Divider(),
                    for (final entry in {
                      'Play catalog': caps.canPlayCatalog,
                      'Access library': caps.canAccessLibrary,
                      'Seek': caps.canSeek,
                      'Set queue': caps.canSetQueue,
                      'Edit queue': caps.canEditQueue,
                      'Shuffle': caps.canShuffle,
                      'Repeat': caps.canRepeat,
                      'Control volume': caps.canControlVolume,
                      'Background playback': caps.canPlayInBackground,
                      'Create playlist': caps.canCreatePlaylist,
                    }.entries)
                      ListTile(
                        leading: Icon(
                          entry.value.supported
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: entry.value.supported
                              ? Colors.green
                              : Colors.orange,
                        ),
                        title: Text(entry.key),
                        subtitle: Text(
                          entry.value.supported
                              ? (entry.value.detail ?? 'supported')
                              : entry.value.detail == null
                                  ? entry.value.reason.name
                                  : '${entry.value.reason.name} — ${entry.value.detail}',
                        ),
                      ),
                  ],
                ),
    );
  }
}
