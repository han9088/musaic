import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider<Object> createArtworkFileProvider(String uri) =>
    FileImage(File.fromUri(Uri.parse(uri)));
