/// Physical origin category for an artwork reference.
/// Placeholder is retained for legacy `local:` references, but is rendered by
/// the UI layer and must not be sent through image loading or rasterization.
enum ArtworkSourceType { asset, network, directory, placeholder }

/// Parsed identity and type for every artwork source.
class ArtworkSource {
  const ArtworkSource._(this.type, this.value);

  /// Interprets the app's legacy source string into a typed source descriptor.
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

  /// Canonical identity shared by widgets and cache lookups.
  String get identity => switch (type) {
    ArtworkSourceType.asset || ArtworkSourceType.network => value,
    ArtworkSourceType.directory => 'directory:$value',
    ArtworkSourceType.placeholder => 'local:$value',
  };

  String get cacheKey => identity;
  bool get isDirectory => type == ArtworkSourceType.directory;
  bool get isPlaceholder => type == ArtworkSourceType.placeholder;
}
