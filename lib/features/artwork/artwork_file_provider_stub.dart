import 'package:flutter/widgets.dart';

/// Local directory artwork is unavailable on platforms without dart:io.
ImageProvider<Object>? fileArtworkProvider(String uri) => null;
