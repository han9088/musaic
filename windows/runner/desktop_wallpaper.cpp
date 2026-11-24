#include "desktop_wallpaper.h"

#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <windowsx.h>

#include <cwchar>
#include <utility>

#include "resource.h"

namespace {
constexpr UINT kWallpaperCommand = 0x1F00;
constexpr UINT kQuitCommand = 0x1F10;
constexpr UINT kTrayMessage = WM_APP + 1;
constexpr UINT kHostLost = WM_APP + 2;
constexpr UINT kTrayIconId = 1;
constexpr UINT kCreateWallpaperLayer = 0x052C;
constexpr wchar_t kHostClass[] = L"Musaic.DesktopWallpaper";
constexpr wchar_t kDesktopIcons[] = L"SHELLDLL_DefView";

struct DesktopLayer {
  HWND parent = nullptr;
  HWND icons = nullptr;
};

struct WorkerSearch {
  DWORD shell_process;
  HWND worker = nullptr;
};

BOOL CALLBACK FindClassicWorker(HWND window, LPARAM data) {
  auto& search = *reinterpret_cast<WorkerSearch*>(data);
  DWORD process = 0;
  GetWindowThreadProcessId(window, &process);
  if (process != search.shell_process ||
      !FindWindowExW(window, nullptr, kDesktopIcons, nullptr)) {
    return TRUE;
  }
  const HWND worker = FindWindowExW(nullptr, window, L"WorkerW", nullptr);
  if (!worker || !IsWindowVisible(worker) ||
      FindWindowExW(worker, nullptr, kDesktopIcons, nullptr)) {
    return TRUE;
  }
  GetWindowThreadProcessId(worker, &process);
  if (process != search.shell_process) return TRUE;
  search.worker = worker;
  return FALSE;
}

DesktopLayer FindDesktopLayer() {
  const HWND shell = GetShellWindow();
  const HWND progman = FindWindowW(L"Progman", nullptr);
  DWORD shell_process = 0;
  DWORD progman_process = 0;
  GetWindowThreadProcessId(shell, &shell_process);
  GetWindowThreadProcessId(progman, &progman_process);
  if (!progman || !shell_process || shell_process != progman_process) return {};

  // Explorer's classic desktop creates a separate WorkerW. The raised desktop
  // in Windows 11 uses sibling icon and wallpaper layers inside Progman.
  DWORD_PTR result = 0;
  if (!SendMessageTimeoutW(progman, kCreateWallpaperLayer, 0xD, 1,
                           SMTO_ABORTIFHUNG | SMTO_BLOCK, 750, &result)) {
    return {};
  }
  if (GetWindowLongPtrW(progman, GWL_EXSTYLE) & WS_EX_NOREDIRECTIONBITMAP) {
    const HWND icons = FindWindowExW(progman, nullptr, kDesktopIcons, nullptr);
    const HWND wallpaper = FindWindowExW(progman, icons, L"WorkerW", nullptr);
    return icons && wallpaper ? DesktopLayer{progman, icons} : DesktopLayer{};
  }

  WorkerSearch search{shell_process};
  EnumWindows(FindClassicWorker, reinterpret_cast<LPARAM>(&search));
  return {search.worker, nullptr};
}

std::wstring WideString(const std::string& value) {
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       value.c_str(), -1, nullptr, 0);
  if (length <= 1) return {};
  std::wstring result(length, L'\0');
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.c_str(), -1,
                           result.data(), length)) return {};
  result.pop_back();
  return result;
}
}  // namespace

DesktopWallpaper::DesktopWallpaper(HWND window,
                                   flutter::FlutterViewController& controller)
    : window_(window),
      view_(controller.view()->GetNativeWindow()),
      controller_(controller),
      channel_(controller.engine()->messenger(),
               "com.deskbtm.musaic/desktop_wallpaper",
               &flutter::StandardMethodCodec::GetInstance()),
      taskbar_created_(RegisterWindowMessageW(L"TaskbarCreated")) {
  if (const HMENU menu = GetSystemMenu(window_, FALSE)) {
    InsertMenuW(menu, SC_CLOSE, MF_BYCOMMAND | MF_STRING | MF_GRAYED,
                kWallpaperCommand, set_title_.c_str());
    AppendMenuW(menu, MF_STRING, kQuitCommand, quit_title_.c_str());
  }
  channel_.SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "setCloseToBackground") {
      const auto* enabled = std::get_if<bool>(call.arguments());
      close_to_background_ = enabled && *enabled;
      result->Success();
      return;
    }
    if (call.method_name() == "restoreWindow") {
      RestoreWindow();
      result->Success();
      return;
    }
    if (call.method_name() == "embedWindow") {
      EmbedWindow();
      result->Success();
      return;
    }
    if (call.method_name() != "setMenuTitles") {
      result->NotImplemented();
      return;
    }
    const auto* titles = std::get_if<flutter::EncodableMap>(call.arguments());
    if (titles) {
      const auto set = titles->find(flutter::EncodableValue("set"));
      const auto restore = titles->find(flutter::EncodableValue("restore"));
      if (set != titles->end() && restore != titles->end()) {
        const auto* set_text = std::get_if<std::string>(&set->second);
        const auto* restore_text = std::get_if<std::string>(&restore->second);
        if (set_text && restore_text) {
          set_title_ = WideString(*set_text);
          restore_title_ = WideString(*restore_text);
        }
      }
      const auto quit = titles->find(flutter::EncodableValue("quit"));
      if (quit != titles->end()) {
        if (const auto* text = std::get_if<std::string>(&quit->second)) {
          quit_title_ = WideString(*text);
        }
      }
    }
    result->Success();
  });
}

DesktopWallpaper::~DesktopWallpaper() {
  lifetime_.reset();
  channel_.SetMethodCallHandler(nullptr);
  RemoveTrayIcon();
  CloseHost();
}

std::optional<LRESULT> DesktopWallpaper::HandleMessage(UINT message,
                                                       WPARAM wparam,
                                                       LPARAM lparam) {
  if (message == WM_CLOSE && close_to_background_) {
    ShowWindow(window_, SW_HIDE);
    return 0;
  }
  if ((message == WM_INITMENU || message == WM_INITMENUPOPUP) &&
      reinterpret_cast<HMENU>(wparam) == GetSystemMenu(window_, FALSE)) {
    ModifyMenuW(reinterpret_cast<HMENU>(wparam), kWallpaperCommand,
                MF_BYCOMMAND | MF_STRING | (preparing_ ? MF_GRAYED : MF_ENABLED),
                kWallpaperCommand, set_title_.c_str());
    ModifyMenuW(reinterpret_cast<HMENU>(wparam), kQuitCommand,
                MF_BYCOMMAND | MF_STRING, kQuitCommand, quit_title_.c_str());
  } else if (message == WM_SYSCOMMAND &&
             (wparam & 0xFFF0) == kWallpaperCommand) {
    EmbedWindow();
    return 0;
  } else if (message == WM_SYSCOMMAND && (wparam & 0xFFF0) == kQuitCommand) {
    DestroyWindow(window_);
    return 0;
  } else if (message == kTrayMessage) {
    const UINT event = LOWORD(lparam);
    if (event == NIN_SELECT || event == NIN_KEYSELECT || event == WM_CONTEXTMENU) {
      ShowTrayMenu({GET_X_LPARAM(wparam), GET_Y_LPARAM(wparam)});
    }
    return 0;
  } else if (message == kHostLost ||
             (host_ && (message == WM_DISPLAYCHANGE ||
                        message == taskbar_created_))) {
    Restore();
    return 0;
  }
  return std::nullopt;
}

void DesktopWallpaper::EmbedWindow() {
  if (preparing_ || host_ || !IsWindowVisible(window_) || IsIconic(window_)) return;
  preparing_ = true;
  const std::weak_ptr<int> lifetime = lifetime_;
  using Value = flutter::EncodableValue;
  channel_.InvokeMethod("prepare", nullptr,
      std::make_unique<flutter::MethodResultFunctions<Value>>(
          [this, lifetime](const Value* response) {
            if (lifetime.expired()) return;
            preparing_ = false;
            const auto* ready = std::get_if<bool>(response);
            if (!ready || !*ready) return;
            if (!Show()) {
              channel_.InvokeMethod("didRestore", nullptr);
              MessageBoxW(window_, L"The Windows desktop wallpaper layer is unavailable.",
                          L"Musaic", MB_OK | MB_ICONWARNING);
            }
          },
          [this, lifetime](const auto&, const auto&, const Value*) {
            if (!lifetime.expired()) preparing_ = false;
          },
          [this, lifetime]() {
            if (!lifetime.expired()) preparing_ = false;
          }));
}

bool DesktopWallpaper::Show() {
  if (!IsWindowVisible(window_) || IsIconic(window_)) return false;
  const DesktopLayer layer = FindDesktopLayer();
  MONITORINFO monitor{};
  monitor.cbSize = sizeof(monitor);
  if (!layer.parent || !GetMonitorInfoW(MonitorFromWindow(window_,
      MONITOR_DEFAULTTONEAREST), &monitor)) return false;

  const HINSTANCE instance = GetModuleHandleW(nullptr);
  WNDCLASSW window_class{};
  window_class.hInstance = instance;
  window_class.lpszClassName = kHostClass;
  window_class.lpfnWndProc = HostProc;
  if (!RegisterClassW(&window_class) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
    return false;
  }

  const RECT bounds = monitor.rcMonitor;
  POINT origin{bounds.left, bounds.top};
  if (!ScreenToClient(layer.parent, &origin)) return false;
  const int width = bounds.right - bounds.left;
  const int height = bounds.bottom - bounds.top;
  const DWORD style = WS_EX_NOACTIVATE | WS_EX_TRANSPARENT |
                      (layer.icons ? WS_EX_LAYERED : 0);
  host_ = CreateWindowExW(style, kHostClass, L"Musaic Wallpaper",
                          WS_CHILD | WS_CLIPCHILDREN | WS_CLIPSIBLINGS | WS_DISABLED,
                          origin.x, origin.y, width, height,
                          layer.parent, nullptr, instance, this);
  if (!host_) return false;
  if ((layer.icons && !SetLayeredWindowAttributes(host_, 0, 255, LWA_ALPHA)) ||
      !SetWindowPos(host_, layer.icons ? layer.icons : HWND_TOP,
                    0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE) ||
      !AddTrayIcon() || SetParent(view_, host_) != window_ ||
      !SetWindowPos(view_, nullptr, 0, 0, width, height,
                    SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW)) {
    AttachViewToWindow();
    CloseHost();
    RemoveTrayIcon();
    return false;
  }
  ShowWindow(window_, SW_HIDE);
  ShowWindow(host_, SW_SHOWNOACTIVATE);
  controller_.ForceRedraw();
  return true;
}

bool DesktopWallpaper::AttachViewToWindow() {
  if (GetParent(view_) != window_) {
    SetParent(view_, window_);
    if (GetParent(view_) != window_) return false;
  }
  RECT bounds{};
  if (GetClientRect(window_, &bounds)) {
    SetWindowPos(view_, nullptr, 0, 0, bounds.right, bounds.bottom,
                 SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }
  return true;
}

void DesktopWallpaper::Restore() {
  if (!AttachViewToWindow()) return;
  CloseHost();
  RemoveTrayIcon();
  ShowWindow(window_, SW_SHOW);
  SetForegroundWindow(window_);
  controller_.ForceRedraw();
  channel_.InvokeMethod("didRestore", nullptr);
}

void DesktopWallpaper::RestoreWindow() {
  if (host_) {
    Restore();
  } else {
    ShowWindow(window_, IsIconic(window_) ? SW_RESTORE : SW_SHOW);
    SetForegroundWindow(window_);
  }
}

void DesktopWallpaper::CloseHost() {
  if (const HWND host = std::exchange(host_, nullptr)) DestroyWindow(host);
}

bool DesktopWallpaper::AddTrayIcon() {
  NOTIFYICONDATAW icon{};
  icon.cbSize = sizeof(icon);
  icon.hWnd = window_;
  icon.uID = kTrayIconId;
  icon.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  icon.uCallbackMessage = kTrayMessage;
  icon.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON));
  wcscpy_s(icon.szTip, L"Musaic");
  tray_icon_added_ = Shell_NotifyIconW(NIM_ADD, &icon) != FALSE;
  if (tray_icon_added_) {
    icon.uVersion = NOTIFYICON_VERSION_4;
    if (!Shell_NotifyIconW(NIM_SETVERSION, &icon)) RemoveTrayIcon();
  }
  return tray_icon_added_;
}

void DesktopWallpaper::RemoveTrayIcon() {
  if (!std::exchange(tray_icon_added_, false)) return;
  NOTIFYICONDATAW icon{};
  icon.cbSize = sizeof(icon);
  icon.hWnd = window_;
  icon.uID = kTrayIconId;
  Shell_NotifyIconW(NIM_DELETE, &icon);
}

void DesktopWallpaper::ShowTrayMenu(POINT anchor) {
  if (!host_) return;
  const HMENU menu = CreatePopupMenu();
  if (!menu) return;
  AppendMenuW(menu, MF_STRING, kWallpaperCommand, restore_title_.c_str());
  AppendMenuW(menu, MF_STRING, kQuitCommand, quit_title_.c_str());
  SetForegroundWindow(window_);
  const UINT command = static_cast<UINT>(TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
      anchor.x, anchor.y, 0, window_, nullptr));
  DestroyMenu(menu);
  PostMessageW(window_, WM_NULL, 0, 0);
  if (command == kWallpaperCommand && host_) Restore();
  if (command == kQuitCommand) PostMessageW(window_, WM_SYSCOMMAND, kQuitCommand, 0);
}

LRESULT CALLBACK DesktopWallpaper::HostProc(HWND window, UINT message,
                                            WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }
  auto* wallpaper = reinterpret_cast<DesktopWallpaper*>(
      GetWindowLongPtrW(window, GWLP_USERDATA));
  if (wallpaper && (message == WM_SHOWWINDOW || message == WM_DESTROY)) {
    // Keep the engine's visible-window state in sync with the wallpaper host.
    wallpaper->controller_.HandleTopLevelWindowProc(window, message, wparam, lparam);
    if (message == WM_DESTROY && wallpaper->host_ == window) {
      wallpaper->host_ = nullptr;
      wallpaper->AttachViewToWindow();
      PostMessageW(wallpaper->window_, kHostLost, 0, 0);
    }
  }
  return DefWindowProcW(window, message, wparam, lparam);
}
