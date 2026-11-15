import XCTest
import musaic_query_ios

final class MusaicQueryTests: XCTestCase {
  func testSongCaseAndOrder() {
    let songs: [[String: Any?]] = [["title": "Zebra"], ["title": "apple"]]
    let insensitive = formatSongList(args: ["ignoreCase": true], allSongs: songs)
    XCTAssertEqual(insensitive.first?["title"] as? String, "apple")
    let sensitive = formatSongList(args: ["ignoreCase": false], allSongs: songs)
    XCTAssertEqual(sensitive.first?["title"] as? String, "Zebra")
    let descending = formatSongList(args: ["ignoreCase": true, "orderType": 1], allSongs: songs)
    XCTAssertEqual(descending.first?["title"] as? String, "Zebra")
  }

  func testIntegerDurationsAndMissingValues() {
    let songs: [[String: Any?]] = [["duration": 200], ["duration": nil], ["duration": 100]]
    let sorted = formatSongList(args: ["sortType": 3], allSongs: songs)
    XCTAssertEqual(sorted[0]["duration"] as? Int, 100)
    XCTAssertEqual(sorted[1]["duration"] as? Int, 200)
    XCTAssertNil(sorted[2]["duration"] ?? nil)
  }

  func testAlbumAndArtistSortEnumIndices() {
    let albums: [[String: Any?]] = [["numsongs": 20], ["numsongs": 2]]
    XCTAssertEqual(
      formatAlbumList(args: ["sortType": 2], allAlbums: albums).first?["numsongs"] as? Int, 2)
    let artists: [[String: Any?]] = [["number_of_tracks": 20], ["number_of_tracks": 2]]
    XCTAssertEqual(
      formatArtistList(args: ["sortType": 1], allArtists: artists).first?["number_of_tracks"]
        as? Int, 2)
  }

  func testEmptyResults() {
    XCTAssertTrue(formatSongList(args: [:], allSongs: []).isEmpty)
    XCTAssertTrue(formatAlbumList(args: [:], allAlbums: []).isEmpty)
    XCTAssertTrue(formatArtistList(args: [:], allArtists: []).isEmpty)
    XCTAssertTrue(formatGenreList(args: [:], allGenres: []).isEmpty)
  }
}
