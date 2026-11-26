/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

/// The current player queue with jump/remove actions.
final class QueueScreen extends StatefulWidget {
  /// Creates the screen bound to [client].
  const QueueScreen({super.key, required this.client});

  final AppleMusicClient client;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  MusicQueue? _queue;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final queue = await widget.client.player.getQueue();
      if (mounted) setState(() => _queue = queue);
    } on MusicKitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: queue == null
          ? const Center(child: CircularProgressIndicator())
          : queue.entries.isEmpty
              ? const Center(child: Text('Queue is empty.'))
              : ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final entry = queue.entries[index];
                    final isCurrent = queue.currentIndex == index;
                    return ListTile(
                      leading: Icon(
                        isCurrent ? Icons.graphic_eq : Icons.music_note,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(entry.ref.id),
                      subtitle: Text(
                          '${entry.ref.type.wireName} · ${entry.ref.source.name}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          try {
                            await widget.client.player.removeAt(index);
                            await _refresh();
                          } on MusicKitException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.userMessage)),
                              );
                            }
                          }
                        },
                      ),
                      onTap: () async {
                        // Jump: rebuild the queue starting at this index.
                        final refs = queue.entries.map((e) => e.ref).toList();
                        await widget.client.player
                            .setQueue(refs, startIndex: index);
                        await _refresh();
                      },
                    );
                  },
                ),
    );
  }
}
