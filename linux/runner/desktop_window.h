// 文件职责：管理 Linux 窗口、托盘恢复入口和 X11 桌面壁纸会话。
#ifndef RUNNER_DESKTOP_WINDOW_H_
#define RUNNER_DESKTOP_WINDOW_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

#include <memory>

#include "tray_host_monitor.h"

class DesktopWindow {
 public:
  DesktopWindow(GtkWindow* window, FlBinaryMessenger* messenger);
  ~DesktopWindow();

  DesktopWindow(const DesktopWindow&) = delete;
  DesktopWindow& operator=(const DesktopWindow&) = delete;

  bool has_window() const { return window_ != nullptr; }
  void RestoreWindow();

 private:
  struct Lifetime;
  struct WindowSnapshot {
    gint x = 0;
    gint y = 0;
    gint width = 0;
    gint height = 0;
    gboolean decorated = TRUE;
    gboolean resizable = TRUE;
    gboolean accept_focus = TRUE;
    gboolean focus_on_map = TRUE;
    gboolean skip_taskbar = FALSE;
    gboolean skip_pager = FALSE;
    GdkWindowTypeHint type = GDK_WINDOW_TYPE_HINT_NORMAL;
    GdkWindowState state = static_cast<GdkWindowState>(0);
  };

  static void HandleMethod(FlMethodChannel* channel, FlMethodCall* call,
                           gpointer data);
  static gboolean DeleteEvent(GtkWidget* widget, GdkEvent* event,
                              gpointer data);
  static gboolean ConfigureEvent(GtkWidget* widget, GdkEventConfigure* event,
                                 gpointer data);
  static gboolean WindowStateEvent(GtkWidget* widget, GdkEventWindowState* event,
                                   gpointer data);
  static void WindowDestroyed(GtkWidget* widget, gpointer data);
  static void ScreenChanged(GdkScreen* screen, gpointer data);
  static void WindowManagerChanged(GdkScreen* screen, gpointer data);
  static void PrepareFinished(GObject* source, GAsyncResult* result,
                              gpointer data);

  bool CanRecover() const;
  bool SupportsWallpaper() const;
  bool CanEnterWallpaper() const;
  void EmbedWindow();
  bool ShowWallpaper();
  void RestoreWallpaper();
  void EnforceRecovery();
  void NotifyRestored();
  void NotifyCapabilities();
  FlValue* CreateCapabilities() const;
  void Quit();

  GtkWindow* window_;
  GdkScreen* screen_ = nullptr;
  FlMethodChannel* channel_ = nullptr;
  GCancellable* cancellable_ = nullptr;
  std::shared_ptr<Lifetime> lifetime_;
  std::unique_ptr<TrayHostMonitor> tray_host_;
  WindowSnapshot snapshot_;
  GdkRectangle normal_geometry_ = {0, 0, 0, 0};
  guint quit_source_ = 0;
  bool has_normal_geometry_ = false;
  bool restoring_maximized_ = false;
  bool tray_ready_ = false;
  bool shortcut_ready_ = false;
  bool wallpaper_ = false;
  bool hidden_to_tray_ = false;
  bool preparing_ = false;
  bool cancel_prepare_ = false;
  bool quitting_ = false;
};

#endif  // RUNNER_DESKTOP_WINDOW_H_
