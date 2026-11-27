#pragma once

// Forked from bdlukaa/just_audio_windows at
// 82314554ca96a1b872e8388a8c9e951366ccb399. Copyright (c) 2022 Bruno D'Luka and
// the project contributors. See LICENSE.

#include <chrono>
#include <functional>
#include <memory>
#include <stdexcept>

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "adaptive_source.hpp"
#include "platform_thread.hpp"
#include "playlist_order.hpp"
#include "uri_utils.hpp"

#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>
#include <winrt/Windows.Media.Playback.h>
#include <winrt/Windows.Media.h>
#include <winrt/Windows.Storage.h>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <limits>
#include <optional>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

namespace musaic_audio {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using List = flutter::EncodableList;
using Result = std::unique_ptr<flutter::MethodResult<Value>>;
using winrt::Windows::Foundation::TimeSpan;
using winrt::Windows::Foundation::Uri;
using winrt::Windows::Media::Core::MediaSource;
using namespace winrt::Windows::Media::Playback;

inline constexpr char kMethods[] = "com.deskbtm.musaic.audio.methods";
inline constexpr char kEvents[] = "com.deskbtm.musaic.audio.events";
enum class State { kIdle, kLoading, kBuffering, kReady, kCompleted };

inline const Value &ValueOrNull(const Map &map, const char *key) {
  static const Value null;
  const auto entry = map.find(Value(key));
  return entry == map.end() ? null : entry->second;
}

inline int64_t Integer(const Value &value) {
  if (const auto *int32_value = std::get_if<int32_t>(&value))
    return *int32_value;
  return std::get<int64_t>(value);
}

inline std::optional<int64_t> ReadInteger(const Map &map, const char *key) {
  const auto &value = ValueOrNull(map, key);
  return value.IsNull() ? std::nullopt : std::optional(Integer(value));
}

inline std::optional<uint32_t> ReadPeakBitrate(const Value &value) {
  if (value.IsNull())
    return std::nullopt;
  const double rate = std::get<double>(value);
  if (!std::isfinite(rate) || rate < 0 ||
      rate > std::numeric_limits<uint32_t>::max()) {
    throw std::invalid_argument("Invalid peak bitrate.");
  }
  return rate == 0 ? std::nullopt
                   : std::optional(static_cast<uint32_t>(std::max(1.0, rate)));
}

inline TimeSpan ToTimeSpan(int64_t micros) {
  return std::chrono::microseconds(
      std::clamp<int64_t>(micros, 0, std::numeric_limits<int64_t>::max() / 10));
}

inline int64_t Micros(TimeSpan time) {
  return std::chrono::duration_cast<std::chrono::microseconds>(time).count();
}

inline void Reply(Result &result, const Map &response = {}) {
  if (auto pending = std::move(result))
    pending->Success(Value(response));
}

inline void Abort(Result &result) {
  if (auto pending = std::move(result)) {
    pending->Error("abort", "Audio operation interrupted.");
  }
}

struct Entry {
  int64_t id;
  MediaPlaybackItem item;
  TimeSpan start;
  std::optional<TimeSpan> end;
  bool local = false;
  std::shared_ptr<AdaptiveSourceSettings> adaptive;
  bool opened = false;
  std::optional<std::pair<int32_t, std::string>> failure = std::nullopt;
};

inline winrt::fire_and_forget
BindLocalFile(winrt::Windows::Media::Core::MediaBindingEventArgs args,
              winrt::hstring path) {
  try {
    const auto deferral = args.GetDeferral();
    try {
      const auto operation =
          winrt::Windows::Storage::StorageFile::GetFileFromPathAsync(path);
      const auto canceled =
          args.Canceled(winrt::auto_revoke,
                        [operation](auto &&, auto &&) { operation.Cancel(); });
      args.SetStorageFile(co_await operation);
    } catch (const winrt::hresult_error &) {
      // The playback list reports an item error for an unresolved binding.
    }
    deferral.Complete();
  } catch (const winrt::hresult_error &) {
    // WinRT can cancel the binding when an item is removed.
  }
}

inline MediaSource
createMediaSource(const Map &source, bool &local,
                  const std::shared_ptr<AdaptiveSourceSettings> &adaptive) {
  const auto *path = std::get_if<std::string>(&ValueOrNull(source, "filePath"));
  local = path != nullptr;
  if (local) {
    winrt::Windows::Media::Core::MediaBinder binder;
    binder.Binding([path = winrt::to_hstring(*path)](auto &&, const auto &args) {
      BindLocalFile(args, path);
    });
    return MediaSource::CreateFromMediaBinder(binder);
  }

  const auto *address = std::get_if<std::string>(&ValueOrNull(source, "uri"));
  if (!address)
    throw std::invalid_argument("This audio source is unavailable on Windows.");
  const Uri uri(winrt::to_hstring(EncodeSpacesInUri(*address)));
  if (uri.SchemeName() != L"http" && uri.SchemeName() != L"https") {
    throw std::invalid_argument("Unsupported Windows media URL scheme.");
  }
  const auto *headers = std::get_if<Map>(&ValueOrNull(source, "headers"));
  if (adaptive) {
    RequestHeaders request_headers;
    if (headers) {
      for (const auto &[key, value] : *headers) {
        request_headers.emplace_back(
            winrt::to_hstring(std::get<std::string>(key)),
            winrt::to_hstring(std::get<std::string>(value)));
      }
    }
    return CreateAdaptiveSource(uri, std::move(request_headers), adaptive);
  }
  if (headers && !headers->empty()) {
    throw std::invalid_argument(
        "Windows request headers require the Dart HTTP proxy.");
  }

  return MediaSource::CreateFromUri(uri);
}

inline Entry createMediaPlaybackItem(int64_t id, const Map &arguments,
                                     std::optional<uint32_t> peak) {
  const auto start = ToTimeSpan(ReadInteger(arguments, "start").value_or(0));
  const auto end_us = ReadInteger(arguments, "end");
  const auto end = end_us ? std::optional(ToTimeSpan(*end_us)) : std::nullopt;
  if (end && *end <= start) {
    throw std::invalid_argument("The clip end must be later than its start.");
  }
  const auto *adaptive_flag =
      std::get_if<bool>(&ValueOrNull(arguments, "adaptive"));
  auto adaptive = adaptive_flag && *adaptive_flag
                      ? std::make_shared<AdaptiveSourceSettings>(peak)
                      : nullptr;
  bool local = false;
  const auto source = createMediaSource(arguments, local, adaptive);
  if (end)
    return {id,    MediaPlaybackItem(source, start, *end - start),
            start, end,
            local, std::move(adaptive)};
  if (start != TimeSpan::zero()) {
    return {id,    MediaPlaybackItem(source, start),
            start, end,
            local, std::move(adaptive)};
  }
  return {id,    MediaPlaybackItem(source), start, end,
          local, std::move(adaptive)};
}

class PlaybackEventSink {
public:
  // Prevent copying.
  PlaybackEventSink(PlaybackEventSink const &) = delete;
  PlaybackEventSink &operator=(PlaybackEventSink const &) = delete;

  PlaybackEventSink(flutter::BinaryMessenger *messenger, const std::string &id)
      : channel_(messenger, id, &flutter::StandardMethodCodec::GetInstance()) {}

  void Listen(std::function<void()> on_listen) {

    auto event_handler = std::make_unique<flutter::StreamHandlerFunctions<>>(
        [self = this, on_listen = std::move(on_listen)](
            const Value *, std::unique_ptr<flutter::EventSink<>> &&events)
            -> std::unique_ptr<flutter::StreamHandlerError<>> {
          self->sink = std::move(events);
          on_listen();
          return nullptr;
        },
        [self = this](
            const Value *) -> std::unique_ptr<flutter::StreamHandlerError<>> {
          self->sink.reset();
          return nullptr;
        });

    channel_.SetStreamHandler(std::move(event_handler));
  }

  void Success(const Value &event) const {
    if (sink) {
      sink->Success(event);
    }
  }

  void Close() {
    channel_.SetStreamHandler(nullptr);
    sink.reset();
  }

private:
  flutter::EventChannel<Value> channel_;
  std::unique_ptr<flutter::EventSink<>> sink;
};

class AudioPlayer : public std::enable_shared_from_this<AudioPlayer> {
public:
  AudioPlayer(const std::string &id, flutter::BinaryMessenger *messenger,
              std::shared_ptr<PlatformThreadDispatcher> dispatcher,
              const Map &request)
      : methods_(messenger, std::string(kMethods) + "." + id,
                 &flutter::StandardMethodCodec::GetInstance()),
        event_sink_(messenger, std::string(kEvents) + "." + id),
        dispatcher_(std::move(dispatcher)) {
    const auto *configuration =
        std::get_if<Map>(&ValueOrNull(request, "audioLoadConfiguration"));
    const auto *defaults =
        configuration ? std::get_if<Map>(
                            &ValueOrNull(*configuration, "darwinLoadControl"))
                      : nullptr;
    if (defaults)
      peak_bitrate_ =
          ReadPeakBitrate(ValueOrNull(*defaults, "preferredPeakBitRate"));
  }

  void RegisterChannels() {
    methods_.SetMethodCallHandler([this](const auto &call, auto result) {
      HandleMethodCall(call, std::move(result));
    });
    event_sink_.Listen([this] { broadcastPlaybackEvent(); });
  }

  ~AudioPlayer() { Dispose(false); }

  void DisposeForEngineShutdown() { Dispose(true); }

private:
  void Dispose(bool engine_shutting_down) {
    if (disposed_)
      return;
    disposed_ = true;
    // The engine has already dropped its message handlers at registrar
    // teardown.
    if (!engine_shutting_down) {
      methods_.SetMethodCallHandler(nullptr);
      event_sink_.Close();
      Abort(load_result_);
      Abort(seek_result_);
      Abort(queued_seek_result_);
      Reply(play_result_);
    }
    CloseMedia();
  }

  bool disposed_ = false;

  void HandleMethodCall(const flutter::MethodCall<Value> &call, Result result) {
    try {
      const auto &method = call.method_name();
      const auto *request = std::get_if<Map>(call.arguments());
      if (!request) {
        result->Error("argument_error", "Expected an audio request map.");
        return;
      }
      const auto &args = *request;
      if (method == "load")
        return loadSource(args, result);
      if (method == "seek")
        return Seek(args, result);
      if (method == "play") {
        if (playing_)
          return Reply(result);
        if (mediaPlayer && state_ != State::kCompleted && !target_ &&
            !resume_after_seek_ && !failed_)
          mediaPlayer.Play();
        playing_ = true;
        play_result_ = std::move(result);
        if (state_ == State::kCompleted)
          Reply(play_result_);
        return;
      }
      if (method == "pause") {
        if (mediaPlayer)
          mediaPlayer.Pause();
        playing_ = false;
        Refresh(true);
        Reply(play_result_);
      } else if (method == "setPlaylist") {
        UpdatePlaylist(args);
        result->Success();
        return;
      } else if (method == "setVolume") {
        const double volume = std::get<double>(ValueOrNull(args, "volume"));
        if (!std::isfinite(volume))
          throw std::invalid_argument("Invalid volume.");
        if (mediaPlayer)
          mediaPlayer.Volume(volume);
        volume_ = volume;
      } else if (method == "setSpeed") {
        const double speed = std::get<double>(ValueOrNull(args, "speed"));
        if (!std::isfinite(speed) || speed <= 0) {
          throw std::invalid_argument("Invalid playback speed.");
        }
        if (mediaPlayer && !target_)
          mediaPlayer.PlaybackSession().PlaybackRate(speed);
        speed_ = speed;
        Refresh(true);
      } else if (method == "setLoopMode") {
        const auto mode = Integer(ValueOrNull(args, "loopMode"));
        if (mode < 0 || mode > 2)
          throw std::invalid_argument("Invalid loop mode.");
        loop_mode_ = mode;
        ApplyLoop();
      } else if (method == "setShuffleMode") {
        const auto mode = Integer(ValueOrNull(args, "shuffleMode"));
        if (mode < 0 || mode > 1)
          throw std::invalid_argument("Invalid shuffle mode.");
        shuffle_ = mode == 1;
        setShuffleOrder();
      } else if (method == "setPreferredPeakBitRate") {
        const auto peak = ReadPeakBitrate(ValueOrNull(args, "bitRate"));
        for (const auto &entry : entries_) {
          if (entry.adaptive)
            entry.adaptive->SetPeakBitrate(peak);
        }
        peak_bitrate_ = peak;
      } else if (method == "setPitch") {
        if (std::get<double>(ValueOrNull(args, "pitch")) != 1.0) {
          result->Error("unsupported",
                        "Independent pitch is unavailable on Windows.");
          return;
        }
      } else if (method == "setSkipSilence") {
        if (std::get<bool>(ValueOrNull(args, "enabled"))) {
          result->Error("unsupported",
                        "Skipping silence is unavailable on Windows.");
          return;
        }
      } else if (method != "setAutomaticallyWaitsToMinimizeStalling" &&
                 method !=
                     "setCanUseNetworkResourcesForLiveStreamingWhilePaused" &&
                 method != "setAllowsExternalPlayback" &&
                 method != "setAndroidAudioAttributes") {
        result->NotImplemented();
        return;
      }
      Reply(result);
    } catch (const winrt::hresult_error &error) {
      CommandFailed(call, result, static_cast<int32_t>(error.code()),
                    winrt::to_string(error.message()));
    } catch (const std::exception &error) {
      CommandFailed(call, result, 4, error.what());
    }
  }

  void CommandFailed(const flutter::MethodCall<Value> &call, Result &result,
                     int32_t code, const std::string &message) {
    if (call.method_name() == "load" && result) {
      Abort(load_result_);
      Abort(seek_result_);
      Abort(queued_seek_result_);
      CloseMedia();
      entries_.clear();
      order_.clear();
      duration_.reset();
      index_.reset();
      position_ = 0;
      buffered_ = 0;
      failed_ = false;
      load_result_ = std::move(result);
    }
    if (result) {
      if (call.method_name() == "setPlaylist" && !mediaPlaybackList) {
        Failed(code, message, index_);
      }
      result->Error(std::to_string(code), message,
                    Value(Map{{Value("index"), IndexValue()}}));
      return;
    }
    Failed(code, message, index_);
  }

  // Only a queued platform-thread callback can lock the player. A full load
  // invalidates callbacks from the previous MediaPlayer and MediaPlaybackList.
  auto Dispatch() {
    return [weak = weak_from_this(), dispatcher = std::weak_ptr(dispatcher_),
            generation = generation_](auto action) {
      const auto thread = dispatcher.lock();
      if (!thread)
        return;
      thread->Post([weak, generation, action = std::move(action)] {
        const auto player = weak.lock();
        if (!player || player->generation_ != generation)
          return;
        try {
          action(*player);
        } catch (const winrt::hresult_error &error) {
          player->Failed(static_cast<int32_t>(error.code()),
                         winrt::to_string(error.message()), player->index_);
        }
      });
    };
  }

  void WatchMedia() {
    const auto dispatch = Dispatch();
    const auto refresh = [dispatch](const auto &, const auto &) {
      dispatch([](AudioPlayer &player) { player.Refresh(); });
    };
    const auto session = mediaPlayer.PlaybackSession();
    session.PlaybackStateChanged(refresh);
    session.NaturalDurationChanged(refresh);
    session.BufferedRangesChanged(refresh);
    session.PositionChanged([dispatch](const auto &, const auto &) {
      dispatch([](AudioPlayer &player) {
        if (player.loop_mode_ == 1)
          player.Refresh();
      });
    });
    session.SeekCompleted([dispatch](const auto &, const auto &) {
      dispatch([](AudioPlayer &player) { player.SeekCompleted(); });
    });
    mediaPlayer.MediaOpened(refresh);
    mediaPlaybackList.ItemOpened([dispatch](const auto &, const auto &args) {
      dispatch([item = args.Item()](AudioPlayer &player) {
        if (const auto index = player.FindItem(item)) {
          auto &entry = player.entries_[*index];
          entry.opened = true;
          entry.failure.reset();
          player.Refresh();
        }
      });
    });
    mediaPlayer.MediaEnded([dispatch](const auto &, const auto &) {
      dispatch([](AudioPlayer &player) { player.Ended(); });
    });
    mediaPlaybackList.CurrentItemChanged([dispatch](const auto &,
                                                    const auto &args) {
      const auto reason = args.Reason();
      auto failed = reason == MediaPlaybackItemChangedReason::Error
                        ? args.OldItem()
                        : nullptr;
      const bool ended = !args.NewItem() &&
                         reason == MediaPlaybackItemChangedReason::EndOfStream;
      dispatch([ended, failed = std::move(failed)](AudioPlayer &player) {
        if (ended)
          return player.Ended();
        if (failed) {
          if (const auto index = player.FindItem(failed)) {
            const auto &entry = player.entries_[*index];
            player.error_transition_item_ = entry.id;
            if (entry.failure) {
              return player.Failed(entry.failure->first, entry.failure->second,
                                   index);
            }
          }
        }
        player.Refresh();
      });
    });
    mediaPlaybackList.ItemFailed([dispatch](const auto &, const auto &args) {
      auto item = args.Item();
      const auto error = args.Error();
      const auto code = static_cast<int32_t>(error.ErrorCode());
      auto message = winrt::to_string(
          winrt::hresult_error(error.ExtendedError()).message());
      dispatch([item = std::move(item), code,
                message = std::move(message)](AudioPlayer &player) {
        const auto index = player.FindItem(item);
        if (index)
          player.ItemFailed(*index, code, message);
      });
    });
    mediaPlayer.MediaFailed([dispatch](const auto &, const auto &args) {
      const auto code = static_cast<int32_t>(args.Error());
      auto message = winrt::to_string(args.ErrorMessage());
      dispatch([code, message = std::move(message)](AudioPlayer &player) {
        player.Failed(code, message, player.index_);
      });
    });
  }

  void CloseMedia() {
    ++generation_;
    reported_seek_.reset();
    error_transition_item_.reset();
    resume_after_seek_ = false;
    end_after_seek_ = false;
    clip_offset_.reset();
    if (mediaPlayer) {
      try {
        mediaPlayer.Close();
      } catch (const winrt::hresult_error &) {
        // The projections still release their references on destruction.
      }
    }
    mediaPlayer = nullptr;
    mediaPlaybackList = nullptr;
  }

  std::vector<Entry> ReadEntries(const Map &args) const {
    std::unordered_map<int64_t, const Entry *> old;
    for (const auto &entry : entries_)
      old.emplace(entry.id, &entry);
    std::vector<Entry> entries;
    for (const auto &value : std::get<List>(ValueOrNull(args, "items"))) {
      const auto &item = std::get<Map>(value);
      const auto id = Integer(ValueOrNull(item, "id"));
      const auto found = old.find(id);
      entries.push_back(found == old.end()
                            ? createMediaPlaybackItem(id, item, peak_bitrate_)
                            : *found->second);
    }
    return entries;
  }

  static std::vector<uint32_t> ReadOrder(const Map &args, size_t count) {
    const auto &values = std::get<List>(ValueOrNull(args, "shuffleOrder"));
    if (values.size() != count)
      throw std::invalid_argument("Invalid shuffle order.");
    std::vector<uint32_t> order;
    std::vector<bool> seen(count);
    for (const auto &value : values) {
      const auto index = Integer(value);
      if (index < 0 || static_cast<size_t>(index) >= count ||
          seen[static_cast<size_t>(index)])
        throw std::invalid_argument("Invalid shuffle index.");
      seen[static_cast<size_t>(index)] = true;
      order.push_back(static_cast<uint32_t>(index));
    }
    return order;
  }

  void loadSource(const Map &args, Result &result) {
    auto entries = ReadEntries(args);
    auto order = ReadOrder(args, entries.size());
    const auto requested = ReadInteger(args, "initialIndex").value_or(0);
    if (!entries.empty() &&
        (requested < 0 || static_cast<size_t>(requested) >= entries.size())) {
      throw std::invalid_argument("Initial index is outside the playlist.");
    }
    const auto position = ReadInteger(args, "initialPosition").value_or(0);
    Abort(load_result_);
    Abort(seek_result_);
    Abort(queued_seek_result_);
    CloseMedia();
    entries_ = std::move(entries);
    order_ = std::move(order);
    index_ = std::nullopt;
    target_ = std::nullopt;
    position_ = 0;
    duration_ = std::nullopt;
    buffered_ = 0;
    failed_ = false;
    if (entries_.empty()) {
      state_ = State::kIdle;
      broadcastPlaybackEvent();
      Reply(result, {{Value("duration"), Value()}});
      Reply(play_result_);
      return;
    }

    index_ = static_cast<uint32_t>(requested);
    target_ = entries_[*index_].id;
    target_position_ = position;
    state_ = State::kLoading;
    load_result_ = std::move(result);
    broadcastPlaybackEvent();

    mediaPlaybackList = MediaPlaybackList();
    mediaPlaybackList.MaxPlayedItemsToKeepOpen(2);
    const auto items = mediaPlaybackList.Items();
    for (const auto &entry : entries_)
      items.Append(entry.item);
    setShuffleOrder();
    mediaPlaybackList.StartingItem(entries_[*index_].item);

    mediaPlayer = MediaPlayer();
    mediaPlayer.CommandManager().IsEnabled(false);
    mediaPlayer.Volume(volume_);
    ApplyLoop();
    WatchMedia();
    mediaPlayer.Source(mediaPlaybackList);
  }

  void Seek(const Map &args, Result &result) {
    if (entries_.empty())
      return Reply(result);
    const auto requested =
        ReadInteger(args, "index").value_or(index_.value_or(0));
    if (requested < 0 || static_cast<size_t>(requested) >= entries_.size()) {
      throw std::invalid_argument("Seek index is outside the playlist.");
    }
    const auto index = static_cast<uint32_t>(requested);
    if (result && reported_seek_) {
      Abort(queued_seek_result_);
      queued_seek_ = args;
      queued_seek_result_ = std::move(result);
      return;
    }
    Abort(seek_result_);
    seek_result_ = std::move(result);
    const auto current = CurrentIndex();
    const bool changing = current != index || failed_;
    const auto position = ReadInteger(args, "position");
    if (!changing && !target_ && ReadyToSeek()) {
      const bool resume = state_ == State::kCompleted;
      if (resume)
        state_ = State::kReady;
      seekToPosition(position);
      resume_after_seek_ = resume;
      Refresh(true);
      return;
    }

    failed_ = false;
    target_ = entries_[index].id;
    target_position_ = position;
    reported_seek_.reset();
    clip_offset_.reset();
    index_ = index;
    state_ = load_result_ ? State::kLoading : State::kBuffering;
    position_ = position.value_or(0);
    duration_ = std::nullopt;
    buffered_ = 0;
    broadcastPlaybackEvent();
    if (changing)
      mediaPlaybackList.MoveTo(index);
    Refresh();
  }

  void SeekCompleted() {
    const bool reached_end = std::exchange(end_after_seek_, false);
    reported_seek_.reset();
    Refresh(true);
    if (!queued_seek_result_) {
      if (reached_end)
        Ended();
      return;
    }
    auto pending = std::move(queued_seek_result_);
    auto args = std::move(queued_seek_);
    try {
      Seek(args, pending);
    } catch (const winrt::hresult_error &error) {
      if (pending)
        seek_result_ = std::move(pending);
      Failed(static_cast<int32_t>(error.code()),
             winrt::to_string(error.message()), index_);
    } catch (const std::exception &error) {
      if (pending)
        seek_result_ = std::move(pending);
      Failed(4, error.what(), index_);
    }
  }

  bool ReadyToSeek() const {
    using NativeState = MediaPlaybackState;
    const auto state = mediaPlayer.PlaybackSession().PlaybackState();
    return state == NativeState::Paused || state == NativeState::Playing;
  }

  void seekToPosition(std::optional<int64_t> position) {
    const auto session = mediaPlayer.PlaybackSession();
    if (!session.CanSeek() || !index_)
      return;
    const auto offset = ClipOffset();
    auto destination = TimeSpan::max();
    if (position) {
      destination =
          offset + std::min(TimeSpan::max() - offset,
                            ToTimeSpan(std::min(
                                *position, duration_.value_or(*position))));
    } else if (duration_) {
      destination = offset + ToTimeSpan(*duration_);
    } else {
      const auto ranges = session.GetSeekableRanges();
      if (ranges.Size() == 0)
        return;
      destination = ranges.GetAt(ranges.Size() - 1).End;
    }
    if (session.Position() != destination) {
      session.Position(destination);
      reported_seek_ = std::max<int64_t>(0, Micros(destination - offset));
    }
  }

  std::optional<uint32_t> CurrentIndex() const {
    const auto current = mediaPlaybackList.CurrentItemIndex();
    return current < entries_.size() ? std::optional(current) : std::nullopt;
  }

  std::optional<uint32_t> FindItem(const MediaPlaybackItem &item) const {
    const auto found =
        std::find_if(entries_.begin(), entries_.end(),
                     [&](const Entry &entry) { return entry.item == item; });
    if (found == entries_.end())
      return std::nullopt;
    return static_cast<uint32_t>(found - entries_.begin());
  }

  TimeSpan ClipOffset() {
    const auto start = entries_[*index_].start;
    if (start == TimeSpan::zero())
      return start;
    if (!clip_offset_) {
      const auto position = mediaPlayer.PlaybackSession().Position();
      clip_offset_ = position >= start ? start : TimeSpan::zero();
    }
    return *clip_offset_;
  }

  void ReadTimeline() {
    const auto session = mediaPlayer.PlaybackSession();
    const auto &entry = entries_[*index_];
    const auto offset = ClipOffset();
    const auto natural = entry.item.Source().Duration();
    const auto native_duration = session.NaturalDuration();
    auto length =
        natural ? natural.Value() - entry.start : native_duration - offset;
    if (entry.end) {
      const auto limit = *entry.end - entry.start;
      length = length > TimeSpan::zero() ? std::min(length, limit) : limit;
    }
    duration_ = length > TimeSpan::zero() && native_duration != TimeSpan::max()
                    ? std::optional(Micros(length))
                    : std::nullopt;
    const auto position = session.Position();
    position_ = reported_seek_.value_or(
        std::max<int64_t>(0, Micros(position - offset)));
    if (duration_)
      position_ = std::min(position_, *duration_);

    buffered_ = position_;
    if (entry.local && duration_) {
      buffered_ = *duration_;
      return;
    }
    try {
      for (const auto &range : session.GetBufferedRanges()) {
        if (range.Start <= position && range.End >= position) {
          buffered_ = std::max(buffered_, Micros(range.End - offset));
        }
      }
    } catch (const winrt::hresult_error &) {
      // Some sources do not expose buffered ranges.
    }
    if (duration_)
      buffered_ = std::min(buffered_, *duration_);
  }

  void Refresh(bool force = false) {
    if (!mediaPlayer || failed_ || state_ == State::kCompleted)
      return;
    const auto old_state = state_;
    const auto old_index = index_;
    const auto old_duration = duration_;
    const auto old_buffered = buffered_;
    const auto old_position = position_;

    const auto current = CurrentIndex();
    if (!current || (target_ && entries_[*current].id != *target_))
      return;
    index_ = current;
    if (index_ != old_index) {
      reported_seek_.reset();
      clip_offset_.reset();
    }
    const auto session = mediaPlayer.PlaybackSession();
    const auto native = session.PlaybackState();
    using NativeState = MediaPlaybackState;
    if (native == NativeState::None || native == NativeState::Opening) {
      if (!load_result_)
        state_ = State::kBuffering;
      if (index_ != old_index) {
        position_ = 0;
        duration_ = std::nullopt;
        buffered_ = 0;
      }
    } else if (native == NativeState::Buffering && !entries_[*current].opened) {
      state_ = load_result_ ? State::kLoading : State::kBuffering;
      if (!target_ && index_ == old_index)
        ReadTimeline();
    } else {
      state_ =
          native == NativeState::Buffering ? State::kBuffering : State::kReady;
      ReadTimeline();
      if (target_) {
        if (!load_result_ || target_position_.value_or(0) > 0) {
          seekToPosition(target_position_);
          ReadTimeline();
        }
        target_.reset();
        if (session.PlaybackRate() != speed_)
          session.PlaybackRate(speed_);
        resume_after_seek_ = true;
        force = true;
      }
    }
    if (force || old_state != state_ || old_index != index_ ||
        (loop_mode_ == 1 && position_ < old_position) ||
        old_duration != duration_ || old_buffered != buffered_) {
      broadcastPlaybackEvent();
    }
    if (!target_ && !reported_seek_) {
      if (resume_after_seek_) {
        resume_after_seek_ = false;
        if (playing_)
          mediaPlayer.Play();
      }
      Reply(load_result_, {{Value("duration"), DurationValue()}});
      Reply(seek_result_);
    }
  }

  void Ended() {
    if (!mediaPlayer || target_ || failed_ || !index_ || loop_mode_ != 0 ||
        state_ == State::kCompleted)
      return;
    const auto last =
        shuffle_ ? order_.back() : static_cast<uint32_t>(entries_.size() - 1);
    if (index_ != last)
      return;
    if (reported_seek_) {
      end_after_seek_ = true;
      return;
    }
    position_ = duration_.value_or(position_);
    buffered_ = std::max(buffered_, position_);
    state_ = State::kCompleted;
    broadcastPlaybackEvent();
    Reply(play_result_);
  }

  void ApplyLoop() {
    if (mediaPlayer)
      mediaPlayer.IsLoopingEnabled(loop_mode_ == 1);
    if (mediaPlaybackList)
      mediaPlaybackList.AutoRepeatEnabled(loop_mode_ == 2);
  }

  void setShuffleOrder() {
    if (!mediaPlaybackList)
      return;
    mediaPlaybackList.ShuffleEnabled(shuffle_);
    if (shuffle_ && !order_.empty()) {
      std::vector<MediaPlaybackItem> items;
      for (const auto index : order_)
        items.push_back(entries_[index].item);
      mediaPlaybackList.SetShuffledItems(std::move(items));
    }
  }

  void UpdatePlaylist(const Map &args) {
    auto entries = ReadEntries(args);
    auto order = ReadOrder(args, entries.size());
    if (!mediaPlaybackList) {
      if (entries.empty())
        return;
      Result ignored;
      loadSource(args, ignored);
      return;
    }
    if (entries.empty()) {
      Abort(load_result_);
      Abort(seek_result_);
      Abort(queued_seek_result_);
      Reply(play_result_);
      CloseMedia();
      entries_.clear();
      order_.clear();
      index_.reset();
      target_.reset();
      state_ = State::kIdle;
      duration_.reset();
      position_ = 0;
      buffered_ = 0;
      broadcastPlaybackEvent();
      return;
    }

    auto active = target_ ? index_ : CurrentIndex();
    if (!active)
      active = index_;
    const auto current = active && *active < entries_.size()
                             ? std::optional(entries_[*active].id)
                             : std::nullopt;
    std::optional<uint32_t> anchor;
    std::unordered_set<int64_t> retained;
    std::vector<MediaPlaybackItem> desired;
    desired.reserve(entries.size());
    for (size_t i = 0; i < entries.size(); ++i) {
      retained.insert(entries[i].id);
      desired.push_back(entries[i].item);
      if (current == entries[i].id)
        anchor = static_cast<uint32_t>(i);
    }

    size_t removed_before_current = 0;
    for (size_t i = 0; active && i < *active; ++i) {
      if (!retained.count(entries_[i].id))
        ++removed_before_current;
    }
    const auto next_index = std::min(
        active.value_or(0) - removed_before_current, entries.size() - 1);
    try {
      const auto items = mediaPlaybackList.Items();
      for (uint32_t i = items.Size(); i > 0; --i) {
        if (!retained.count(entries_[i - 1].id))
          items.RemoveAt(i - 1);
      }
      ReorderPlaylist(items, desired, anchor);
      entries_ = std::move(entries);
      order_ = std::move(order);
      setShuffleOrder();
    } catch (const winrt::hresult_error &) {
      // A partially edited native list can no longer be indexed by entries_.
      Map reload = args;
      reload[Value("initialIndex")] = Value(static_cast<int64_t>(
          anchor.value_or(static_cast<uint32_t>(next_index))));
      reload[Value("initialPosition")] = Value(anchor ? position_ : int64_t{0});
      auto pending = std::move(load_result_);
      CloseMedia();
      entries_.clear();
      try {
        loadSource(reload, pending);
      } catch (...) {
        if (pending)
          load_result_ = std::move(pending);
        throw;
      }
      return;
    }

    if (anchor) {
      index_ = anchor;
      Refresh(true);
      if (state_ == State::kCompleted || failed_)
        broadcastPlaybackEvent();
    } else {
      Map next{{Value("index"), Value(static_cast<int64_t>(next_index))},
               {Value("position"), Value(int64_t{0})}};
      Result ignored;
      Seek(next, ignored);
    }
  }

  void ItemFailed(uint32_t index, int32_t code, const std::string &message) {
    auto &entry = entries_[index];
    entry.failure.emplace(code, message);
    if (index == index_ || entry.id == target_ ||
        entry.id == error_transition_item_) {
      Failed(code, message, index);
      return;
    }
  }

  void Failed(int32_t code, const std::string &message,
              std::optional<uint32_t> index) {
    if (failed_)
      return;
    if (mediaPlayer) {
      try {
        mediaPlayer.Pause();
      } catch (const winrt::hresult_error &) {
        // Keep the original playback error.
      }
    }
    failed_ = true;
    target_.reset();
    reported_seek_.reset();
    resume_after_seek_ = false;
    end_after_seek_ = false;
    index_ = index;
    state_ = State::kIdle;
    broadcastPlaybackEvent(code, message);
    const Value details(Map{{Value("index"), IndexValue()}});
    if (auto pending = std::move(load_result_))
      pending->Error(std::to_string(code), message, details);
    if (auto pending = std::move(seek_result_))
      pending->Error(std::to_string(code), message, details);
    if (auto pending = std::move(queued_seek_result_))
      pending->Error(std::to_string(code), message, details);
    Reply(play_result_);
  }

  Value IndexValue() const {
    return index_ ? Value(static_cast<int64_t>(*index_)) : Value();
  }

  Value DurationValue() const {
    return duration_ ? Value(*duration_) : Value();
  }

  void broadcastPlaybackEvent(std::optional<int32_t> code = {},
                              const std::string &message = "") const {
    const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
                         std::chrono::system_clock::now().time_since_epoch())
                         .count();
    Map event{{Value("processingState"), Value(static_cast<int32_t>(state_))},
              {Value("updateTime"), Value(static_cast<int64_t>(now))},
              {Value("updatePosition"), Value(position_)},
              {Value("bufferedPosition"), Value(buffered_)},
              {Value("duration"), DurationValue()},
              {Value("currentIndex"), IndexValue()}};
    if (code) {
      event.emplace(Value("errorCode"), Value(*code));
      event.emplace(Value("errorMessage"), Value(message));
    }
    event_sink_.Success(Value(event));
  }

  flutter::MethodChannel<Value> methods_;
  PlaybackEventSink event_sink_;
  std::shared_ptr<PlatformThreadDispatcher> dispatcher_;
  uint64_t generation_ = 0;

  MediaPlayer mediaPlayer{nullptr};
  MediaPlaybackList mediaPlaybackList{nullptr};
  std::vector<Entry> entries_;
  std::vector<uint32_t> order_;
  std::optional<uint32_t> index_;
  std::optional<int64_t> target_;
  std::optional<int64_t> error_transition_item_;
  std::optional<int64_t> target_position_;
  std::optional<int64_t> reported_seek_;
  std::optional<TimeSpan> clip_offset_;
  Result load_result_;
  Result seek_result_;
  Map queued_seek_;
  Result queued_seek_result_;
  Result play_result_;

  State state_ = State::kIdle;
  std::optional<int64_t> duration_;
  int64_t position_ = 0;
  int64_t buffered_ = 0;
  double volume_ = 1.0;
  std::optional<uint32_t> peak_bitrate_;
  double speed_ = 1.0;
  int64_t loop_mode_ = 0;
  bool shuffle_ = false;
  bool playing_ = false;
  bool resume_after_seek_ = false;
  bool end_after_seek_ = false;
  bool failed_ = false;
};

} // namespace musaic_audio
