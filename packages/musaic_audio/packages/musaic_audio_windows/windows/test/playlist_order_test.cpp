#include "../playlist_order.hpp"

#include <gtest/gtest.h>

#include <algorithm>
#include <utility>

namespace musaic_audio {
namespace {

class Playlist {
public:
  explicit Playlist(std::vector<char> values) : values_(std::move(values)) {}

  uint32_t Size() const { return static_cast<uint32_t>(values_.size()); }
  char GetAt(uint32_t i) const { return values_.at(i); }
  bool IndexOf(char value, uint32_t &i) const {
    const auto found = std::find(values_.begin(), values_.end(), value);
    if (found == values_.end())
      return false;
    i = static_cast<uint32_t>(found - values_.begin());
    return true;
  }
  void RemoveAt(uint32_t i) const {
    removed_.push_back(values_.at(i));
    values_.erase(values_.begin() + i);
  }
  void InsertAt(uint32_t i, char value) const {
    values_.insert(values_.begin() + i, value);
  }
  void Append(char value) const { values_.push_back(value); }

  mutable std::vector<char> values_;
  mutable std::vector<char> removed_;
};

TEST(PlaylistOrder, KeepsCurrentTrackAttachedWhenItsIndexMoves) {
  const Playlist list({'A', 'B', 'C'});
  const std::vector<char> desired{'B', 'C', 'A'};
  ReorderPlaylist(list, desired, 0);
  EXPECT_EQ(list.values_, desired);
  EXPECT_EQ(std::count(list.removed_.begin(), list.removed_.end(), 'B'), 0);
}

TEST(PlaylistOrder, InsertsAndReordersOnBothSidesOfCurrentTrack) {
  const Playlist list({'A', 'B', 'C'});
  const std::vector<char> desired{'C', 'D', 'B', 'E', 'A'};
  ReorderPlaylist(list, desired, 2);
  EXPECT_EQ(list.values_, desired);
  EXPECT_EQ(std::count(list.removed_.begin(), list.removed_.end(), 'B'), 0);
}

TEST(PlaylistOrder, KeepsUnchangedItemsAttached) {
  const Playlist list({'A', 'B', 'C'});
  const std::vector<char> desired{'A', 'B', 'C', 'D'};
  ReorderPlaylist(list, desired, 1);
  EXPECT_EQ(list.values_, desired);
  EXPECT_TRUE(list.removed_.empty());
}

} // namespace
} // namespace musaic_audio
