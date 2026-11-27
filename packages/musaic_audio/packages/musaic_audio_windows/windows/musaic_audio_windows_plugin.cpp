// Forked from bdlukaa/just_audio_windows. See LICENSE.

#include "include/musaic_audio_windows/musaic_audio_windows_plugin_c_api.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <unordered_map>

#include "player.hpp"

namespace {

using musaic_audio::AudioPlayer;
using musaic_audio::kMethods;
using musaic_audio::Map;
using musaic_audio::Reply;
using musaic_audio::Result;
using musaic_audio::Value;
using musaic_audio::ValueOrNull;

class MusaicAudioWindowsPlugin : public flutter::Plugin {
public:
  static void
  RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
    registrar->AddPlugin(
        std::make_unique<MusaicAudioWindowsPlugin>(registrar->messenger()));
  }

  explicit MusaicAudioWindowsPlugin(flutter::BinaryMessenger *messenger)
      : messenger_(messenger),
        channel_(messenger, kMethods,
                 &flutter::StandardMethodCodec::GetInstance()) {
    channel_.SetMethodCallHandler([this](const auto &call, auto result) {
      HandleMethodCall(call, std::move(result));
    });
  }

  ~MusaicAudioWindowsPlugin() override {
    for (auto &[id, player] : players_) {
      player->DisposeForEngineShutdown();
    }
    players_.clear();
    if (dispatcher_)
      dispatcher_->Close();
  }

private:
  void HandleMethodCall(const flutter::MethodCall<Value> &call, Result result) {
    try {
      const auto &method = call.method_name();
      if (method == "disposeAllPlayers") {
        players_.clear();
        return Reply(result);
      }
      if (method != "init" && method != "disposePlayer") {
        result->NotImplemented();
        return;
      }
      const auto *args = std::get_if<Map>(call.arguments());
      const auto *id =
          args ? std::get_if<std::string>(&ValueOrNull(*args, "id")) : nullptr;
      if (!id || id->empty()) {
        result->Error("argument_error", "Player ID is missing.");
        return;
      }
      if (method == "disposePlayer") {
        players_.erase(*id);
        return Reply(result);
      }
      if (players_.count(*id)) {
        result->Error("error", "Platform player already exists.");
        return;
      }
      if (!dispatcher_)
        dispatcher_ = std::make_shared<PlatformThreadDispatcher>();
      auto player =
          std::make_shared<AudioPlayer>(*id, messenger_, dispatcher_, *args);
      player->RegisterChannels();
      players_.emplace(*id, std::move(player));
      result->Success();
    } catch (const std::exception &error) {
      result->Error("error", error.what());
    }
  }

  flutter::BinaryMessenger *messenger_;
  flutter::MethodChannel<Value> channel_;
  std::shared_ptr<PlatformThreadDispatcher> dispatcher_;
  std::unordered_map<std::string, std::shared_ptr<AudioPlayer>> players_;
};

} // namespace

void MusaicAudioWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  MusaicAudioWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
