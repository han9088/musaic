/// Copyright (c) 2026, deskbtm. BSD-3-Clause.
///
/// Example app for apple_music_kit.
///
/// Supports two modes:
/// - Mock Mode: no Apple credentials needed; drives the mock platform.
/// - Live Mode: requires a real developer token served by YOUR backend
///   (see token_source.dart).
library;

import 'package:apple_music_kit/mock.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'mode.dart';
import 'token_source.dart';

void main() {
  // Flip this to false (or set ExampleMode.live) for real-device testing.
  const mode = useMockByDefault ? ExampleMode.mock : ExampleMode.live;
  if (mode == ExampleMode.mock) {
    installMusicKitMock();
  }
  runApp(ExampleApp(mode: mode));
}
