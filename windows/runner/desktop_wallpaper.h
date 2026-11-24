#ifndef RUNNER_DESKTOP_WALLPAPER_H_
#define RUNNER_DESKTOP_WALLPAPER_H_

#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <optional>
#include <string>

class DesktopWallpaper {
 public:
  DesktopWallpaper(HWND window, flutter::FlutterViewController& controller);
  ~DesktopWallpaper();

  std::optional<LRESULT> HandleMessage(UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  static LRESULT CALLBACK HostProc(HWND window, UINT message, WPARAM wparam,
                                  LPARAM lparam);
  void EmbedWindow();
  void RestoreWindow();

  bool Show();
  void Restore();
  bool AttachViewToWindow();
  void CloseHost();
  bool AddTrayIcon();
  void RemoveTrayIcon();
  void ShowTrayMenu(POINT anchor);

  const HWND window_;
  const HWND view_;
  flutter::FlutterViewController& controller_;
  flutter::MethodChannel<flutter::EncodableValue> channel_;
  std::shared_ptr<int> lifetime_ = std::make_shared<int>(0);
  const UINT taskbar_created_;
  HWND host_ = nullptr;
  bool preparing_ = false;
  bool close_to_background_ = false;
  bool tray_icon_added_ = false;
  std::wstring set_title_ = L"Set as Wallpaper";
  std::wstring restore_title_ = L"Restore Window";
  std::wstring quit_title_ = L"Quit Musaic";
};

#endif  // RUNNER_DESKTOP_WALLPAPER_H_
