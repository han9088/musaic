import 'package:flutter/widgets.dart';

/// Web uses the browser's HTTP cache; cached_network_image disk caching is IO-only.
ImageProvider<Object> networkArtworkProvider(String url) => NetworkImage(url);
