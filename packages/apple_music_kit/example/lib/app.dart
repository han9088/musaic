/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
library;

import 'package:apple_music_kit/apple_music_kit.dart';
import 'package:flutter/material.dart';

import 'mode.dart';
import 'screens/home_screen.dart';
import 'token_source.dart';

/// The example app root.
final class ExampleApp extends StatelessWidget {
  /// Creates the app in [mode].
  const ExampleApp({super.key, required this.mode});

  /// Whether the app runs against the mock or the real platform.
  final ExampleMode mode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'apple_music_kit example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.pink, useMaterial3: true),
      home: HomeScreen(
        config: AppleMusicConfig(
          appName: 'apple_music_kit example',
          appBuild: '1.0.0',
          developerTokenProvider:
              mode == ExampleMode.live ? ExampleTokenProvider() : null,
        ),
        liveMode: mode == ExampleMode.live,
      ),
    );
  }
}
