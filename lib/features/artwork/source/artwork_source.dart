enum ArtworkSourceType { asset, network, directory, placeholder }

/// Parsed identity and type for every artwork source.
class ArtworkSource {
  const ArtworkSource._(this.type, this.value);

  factory ArtworkSource.parse(String reference) {
    if (reference.startsWith('directory:')) {
      return ArtworkSource._(
        ArtworkSourceType.directory,
        reference.substring('directory:'.length),
      );
    }
    if (reference.startsWith('local:')) {
      return ArtworkSource._(
        ArtworkSourceType.placeholder,
        reference.substring('local:'.length),
      );
    }

    final uri = Uri.tryParse(reference);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return ArtworkSource._(ArtworkSourceType.network, uri.toString());
    }
    return ArtworkSource._(ArtworkSourceType.asset, reference);
  }

  final ArtworkSourceType type;
  final String value;

  String get identity => switch (type) {
    ArtworkSourceType.asset || ArtworkSourceType.network => value,
    ArtworkSourceType.directory => 'directory:$value',
    ArtworkSourceType.placeholder => 'local:$value',
  };

  String get cacheKey => identity;
  bool get isDirectory => type == ArtworkSourceType.directory;
  bool get isPlaceholder => type == ArtworkSourceType.placeholder;
}
