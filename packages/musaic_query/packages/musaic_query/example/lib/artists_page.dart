import 'package:flutter/material.dart';
import 'package:musaic_query/musaic_query.dart';

class ArtistsPage extends StatefulWidget {
  const ArtistsPage({Key? key}) : super(key: key);

  @override
  State<ArtistsPage> createState() => _ArtistsPageState();
}

class _ArtistsPageState extends State<ArtistsPage> {
  final MusaicQuery _audioQuery = MusaicQuery();
  bool isLoading = true;
  List<ArtistModel> artists = [];

  @override
  void initState() {
    fetchArtists();
    super.initState();
  }

  Future<void> fetchArtists() async {
    try {
      artists = await _audioQuery.queryArtists();
      setState(() {});
    } catch (e) {
      // Handle error if needed
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artists'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: artists.length,
              itemBuilder: (context, index) {
                final artist = artists[index];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(artist.artist),
                  subtitle: Text('${artist.numberOfTracks} tracks'),
                );
              },
            ),
    );
  }
}
