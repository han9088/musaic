#pragma once

#include <cstdint>
#include <optional>
#include <vector>

namespace musaic_audio {

// Keep the playing item attached so the media engine retains its decoder.
template <typename Items, typename Item>
void ReorderPlaylist(const Items &items, const std::vector<Item> &desired,
                     std::optional<uint32_t> anchor) {
  const auto place = [&](const Item &item, uint32_t distance, bool from_end) {
    const auto size = items.Size();
    const auto slot =
        from_end && size > distance ? size - distance - 1 : distance;
    if (slot < size && items.GetAt(slot) == item)
      return;

    uint32_t existing = 0;
    if (items.IndexOf(item, existing))
      items.RemoveAt(existing);
    const auto destination = from_end ? items.Size() - distance : distance;
    if (destination == items.Size())
      items.Append(item);
    else
      items.InsertAt(destination, item);
  };

  const auto size = static_cast<uint32_t>(desired.size());
  const auto prefix = anchor.value_or(size);
  for (uint32_t i = 0; i < prefix; ++i)
    place(desired[i], i, false);
  if (!anchor)
    return;
  for (uint32_t i = size; i > *anchor + 1; --i) {
    place(desired[i - 1], size - i, true);
  }
}

} // namespace musaic_audio
