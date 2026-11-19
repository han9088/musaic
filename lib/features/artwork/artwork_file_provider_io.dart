import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object> fileArtworkProvider(String uri) =>
    FileImage(File.fromUri(Uri.parse(uri)));
