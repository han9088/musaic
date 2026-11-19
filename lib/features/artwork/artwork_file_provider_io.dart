import 'dart:io';

import 'package:flutter/widgets.dart';

/// Creates the native file provider for a resolved local artwork URI.
/// Creates the native file provider for a resolved local artwork URI.
ImageProvider<Object> fileArtworkProvider(String uri) =>
    FileImage(File.fromUri(Uri.parse(uri)));
