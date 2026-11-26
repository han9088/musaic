/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

import '../widgets/player_bar.dart';
import 'authorization_card.dart';
import 'capabilities_screen.dart';
import 'library_tab.dart';
import 'queue_screen.dart';
import 'search_tab.dart';

/// The example home: authorization status, search, library, player.
final class HomeScreen extends StatefulWidget {
  /// Creates the home screen with the client [config].
  const HomeScreen({super.key, required this.config, required this.liveMode});

  final AppleMusicConfig config;
  final bool liveMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppleMusicClient _client;
  String _initError = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _client = AppleMusicClient(config: widget.config);
    _boot();
  }

  Future<void> _boot() async {
    try {
      await _client.initialize();
      setState(() => _initialized = true);
    } on MusicKitException catch (e) {
      setState(() => _initError = '${e.code.name}: ${e.message}');
    } catch (e) {
      setState(() => _initError = e.toString());
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MusicKit ${widget.liveMode ? '(live)' : '(mock)'}'),
        actions: [
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => QueueScreen(client: _client)),
            ),
          ),
          IconButton(
            tooltip: 'Capabilities',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => CapabilitiesScreen(client: _client)),
            ),
          ),
        ],
      ),
      body: !_initialized
          ? Center(
              child: _initError.isEmpty
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Initialization failed:\n$_initError',
                          style: const TextStyle(color: Colors.red)),
                    ),
            )
          : Column(
              children: [
                AuthorizationCard(client: _client),
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(tabs: [
                          Tab(text: 'Search'),
                          Tab(text: 'Library'),
                        ]),
                        Expanded(
                          child: TabBarView(
                            children: [
                              SearchTab(client: _client),
                              LibraryTab(client: _client),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _initialized ? PlayerBar(client: _client) : null,
    );
  }
}
