import '../../../services/music/music_models.dart';

List<Map<String, dynamic>> mapProviderAlbums(List<ProviderAlbum> albums) => [
  for (final album in albums)
    <String, dynamic>{
      'asset': album.artworkUrl ?? 'local:${album.reference.id}',
      'title': album.title,
      'artist': album.artist ?? '',
    },
];
