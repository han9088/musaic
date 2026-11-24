// Copyright (c) 2018-2025 Larry Aasen. All rights reserved.
// Adapted from upgrader 14.0.0 for MUSAIC's UI-independent update core.

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'update_os.dart';

/// 传递给各更新源的最小上下文，不包含 UI、Widget 或 BuildContext。
class UpdateCheckContext {
  const UpdateCheckContext({
    required this.client,
    required this.upgraderOS,
    this.clientHeaders,
    this.debugLogging = false,
    this.packageInfo,
  });

  final http.Client client;
  final Map<String, String>? clientHeaders;
  final bool debugLogging;
  final PackageInfo? packageInfo;
  final MusaicUpdateOS upgraderOS;
}
