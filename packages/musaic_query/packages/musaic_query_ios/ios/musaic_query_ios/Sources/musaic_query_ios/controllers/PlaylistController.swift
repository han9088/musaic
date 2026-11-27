import Flutter
import MediaPlayer

class PlaylistController {
  var args: [String: Any]
  var result: FlutterResult

  init(args: [String: Any], result: @escaping FlutterResult) {
    self.args = args
    self.result = result
  }

  func createPlaylist() {
    guard let playlistName = args["playlistName"] as? String,
      !playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      result(false)
      return
    }
    let playlistAuthor = args["playlistAuthor"] as? String
    let playlistDesc = args["playlistDesc"] as? String

    Log.type.debug("Playlist info: ")
    Log.type.debug("\tname: \(playlistName)")
    Log.type.debug("\tauthor: \(String(describing: playlistAuthor))")
    Log.type.debug("\tdescription: \(String(describing: playlistDesc))")

    let playlistMetadata = MPMediaPlaylistCreationMetadata(name: playlistName)
    playlistMetadata.authorDisplayName = playlistAuthor
    playlistMetadata.descriptionText = playlistDesc ?? ""

    MPMediaLibrary().getPlaylist(
      with: UUID(), creationMetadata: playlistMetadata,
      completionHandler: { playlist, _ in

        let playlistHasBeenCreated = playlist != nil
        Log.type.debug("Playlist has been created: \(playlistHasBeenCreated)")

        DispatchQueue.main.async { self.result(playlistHasBeenCreated) }
      })
  }

  func addToPlaylist() {
    guard let playlistNumber = args["playlistId"] as? NSNumber,
      let audioNumber = args["audioId"] as? NSNumber
    else {
      result(
        FlutterError(
          code: "InvalidArguments", message: "playlistId and audioId are required", details: nil))
      return
    }
    let playlistId = playlistNumber.uint64Value
    let audioId = audioNumber.uint64Value

    Log.type.debug("Playlist info: ")
    Log.type.debug("\tid: \(playlistId)")
    Log.type.debug("\taudioId: \(audioId)")

    DispatchQueue.global(qos: .userInitiated).async {
      guard let playlist = self.loadPlaylist(id: playlistId) else {
        DispatchQueue.main.async { self.result(false) }
        return
      }
      let query = MPMediaQuery.songs()
      query.addFilterPredicate(
        MPMediaPropertyPredicate(
          value: audioId, forProperty: MPMediaItemPropertyPersistentID))
      guard let item = query.items?.first else {
        DispatchQueue.main.async { self.result(false) }
        return
      }
      playlist.add([item]) { error in
        DispatchQueue.main.async { self.result(error == nil) }
      }
    }
  }

  private func loadPlaylist(id: UInt64) -> MPMediaPlaylist? {
    let cursor = MPMediaQuery.playlists()

    // Create a filter using the playlist id.
    let playlistFilter = MPMediaPropertyPredicate(
      value: id, forProperty: MPMediaPlaylistPropertyPersistentID)

    cursor.addFilterPredicate(playlistFilter)

    return cursor.collections?.first as? MPMediaPlaylist
  }
}
