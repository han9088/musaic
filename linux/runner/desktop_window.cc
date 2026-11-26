#include "desktop_window.h"

#include <algorithm>
#include <cstring>

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

namespace {
constexpr char kChannelName[] = "com.deskbtm.musaic/desktop_wallpaper";

bool IsTrue(FlValue* value) {
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_BOOL &&
         fl_value_get_bool(value);
}
}  // namespace

struct DesktopWindow::Lifetime {
  DesktopWindow* owner;
};

DesktopWindow::DesktopWindow(GtkWindow* window, FlBinaryMessenger* messenger)
    : window_(window),
      cancellable_(g_cancellable_new()),
      lifetime_(std::make_shared<Lifetime>(Lifetime{this})) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  channel_ = fl_method_channel_new(messenger, kChannelName,
                                  FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel_, HandleMethod, this,
                                            nullptr);

  // 必须早于 FlView realize 连接，先决定关窗是否进入后台，避免触发引擎退出。
  g_signal_connect(window_, "delete-event", G_CALLBACK(DeleteEvent), this);
  g_signal_connect(window_, "configure-event", G_CALLBACK(ConfigureEvent), this);
  g_signal_connect(window_, "window-state-event", G_CALLBACK(WindowStateEvent),
                   this);
  g_signal_connect(window_, "destroy", G_CALLBACK(WindowDestroyed), this);
  screen_ = gtk_widget_get_screen(GTK_WIDGET(window_));
  if (screen_ != nullptr) {
    g_object_ref(screen_);
    g_signal_connect(screen_, "size-changed", G_CALLBACK(ScreenChanged), this);
    g_signal_connect(screen_, "monitors-changed", G_CALLBACK(ScreenChanged),
                     this);
#ifdef GDK_WINDOWING_X11
    if (GDK_IS_X11_SCREEN(screen_)) {
      g_signal_connect(screen_, "window-manager-changed",
                       G_CALLBACK(WindowManagerChanged), this);
    }
#endif
  }
  tray_host_ = std::make_unique<TrayHostMonitor>([this](bool, int64_t) {
    EnforceRecovery();
    NotifyCapabilities();
  });
}

DesktopWindow::~DesktopWindow() {
  lifetime_->owner = nullptr;
  quitting_ = true;
  g_cancellable_cancel(cancellable_);
  tray_host_.reset();
  if (quit_source_ != 0) g_source_remove(quit_source_);
  if (window_ != nullptr) g_signal_handlers_disconnect_by_data(window_, this);
  if (screen_ != nullptr) {
    g_signal_handlers_disconnect_by_data(screen_, this);
    g_clear_object(&screen_);
  }
  fl_method_channel_set_method_call_handler(channel_, nullptr, nullptr, nullptr);
  g_clear_object(&channel_);
  g_clear_object(&cancellable_);
}

void DesktopWindow::HandleMethod(FlMethodChannel*, FlMethodCall* call,
                                 gpointer data) {
  auto* self = static_cast<DesktopWindow*>(data);
  const gchar* method = fl_method_call_get_name(call);
  if (std::strcmp(method, "getCapabilities") == 0) {
    g_autoptr(FlValue) capabilities = self->CreateCapabilities();
    fl_method_call_respond_success(call, capabilities, nullptr);
    return;
  }
  if (std::strcmp(method, "setTrayReady") == 0 ||
      std::strcmp(method, "setCloseToBackground") == 0) {
    FlValue* value = fl_method_call_get_args(call);
    if (value == nullptr || fl_value_get_type(value) != FL_VALUE_TYPE_BOOL) {
      fl_method_call_respond_error(call, "invalid_arguments",
                                   "Expected a boolean", nullptr, nullptr);
      return;
    }
    if (std::strcmp(method, "setTrayReady") == 0) {
      self->tray_ready_ = fl_value_get_bool(value);
    } else {
      self->shortcut_ready_ = fl_value_get_bool(value);
    }
    self->EnforceRecovery();
  } else if (std::strcmp(method, "embedWindow") == 0) {
    self->EmbedWindow();
  } else if (std::strcmp(method, "restoreWindow") == 0) {
    self->RestoreWindow();
  } else if (std::strcmp(method, "quit") == 0) {
    self->Quit();
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
    return;
  }
  fl_method_call_respond_success(call, nullptr, nullptr);
}

bool DesktopWindow::CanRecover() const {
  return shortcut_ready_ || (tray_ready_ && tray_host_->available());
}

bool DesktopWindow::SupportsWallpaper() const {
#ifdef GDK_WINDOWING_X11
  if (window_ == nullptr || screen_ == nullptr || !GDK_IS_X11_SCREEN(screen_)) {
    return false;
  }
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window_));
  // 不强行切换 Wayland 后端，也不修改桌面全局设置；缺少协议时保留普通窗口。
  return GDK_IS_X11_DISPLAY(display) &&
         gdk_display_supports_input_shapes(display) &&
         gdk_x11_screen_supports_net_wm_hint(
             screen_, gdk_atom_intern_static_string("_NET_WM_WINDOW_TYPE_DESKTOP"));
#else
  return false;
#endif
}

bool DesktopWindow::CanEnterWallpaper() const {
  if (quitting_ || wallpaper_ || restoring_maximized_ || window_ == nullptr ||
      !CanRecover() ||
      !SupportsWallpaper() || !gtk_widget_get_visible(GTK_WIDGET(window_))) {
    return false;
  }
  GdkWindow* native = gtk_widget_get_window(GTK_WIDGET(window_));
  if (native == nullptr ||
      (gdk_window_get_state(native) &
       (GDK_WINDOW_STATE_ICONIFIED | GDK_WINDOW_STATE_FULLSCREEN)) != 0) {
    return false;
  }
  if ((gdk_window_get_state(native) & GDK_WINDOW_STATE_MAXIMIZED) != 0 &&
      !has_normal_geometry_) {
    // 尚未出现普通窗口配置时，无法可靠取得最大化之前的尺寸，先保留原窗口。
    return false;
  }
  // 文件选择器等原生模态窗口打开时，保留原来的焦点和父窗口关系。
  GList* windows = gtk_window_list_toplevels();
  bool modal = false;
  for (GList* item = windows; item != nullptr; item = item->next) {
    auto* other = GTK_WINDOW(item->data);
    if (other != window_ && gtk_widget_get_visible(GTK_WIDGET(other)) &&
        gtk_window_get_modal(other)) {
      modal = true;
      break;
    }
  }
  g_list_free(windows);
  return !modal;
}

void DesktopWindow::EmbedWindow() {
  if (preparing_ || !CanEnterWallpaper()) return;
  preparing_ = true;
  cancel_prepare_ = false;
  // 等待 Flutter 收起界面并绘制完成后再改变原生窗口，不重建或搬动 FlView。
  auto* lifetime = new std::weak_ptr<Lifetime>(lifetime_);
  fl_method_channel_invoke_method(channel_, "prepare", nullptr, cancellable_,
                                   PrepareFinished, lifetime);
}

void DesktopWindow::PrepareFinished(GObject* source, GAsyncResult* result,
                                    gpointer data) {
  std::unique_ptr<std::weak_ptr<Lifetime>> reference(
      static_cast<std::weak_ptr<Lifetime>*>(data));
  g_autoptr(GError) error = nullptr;
  g_autoptr(FlMethodResponse) response = fl_method_channel_invoke_method_finish(
      FL_METHOD_CHANNEL(source), result, &error);
  auto lifetime = reference->lock();
  if (!lifetime || lifetime->owner == nullptr) return;

  DesktopWindow* self = lifetime->owner;
  self->preparing_ = false;
  if (self->quitting_ || self->window_ == nullptr) return;
  FlValue* value = response == nullptr
                       ? nullptr
                       : fl_method_response_get_result(response, nullptr);
  if (self->cancel_prepare_ || !IsTrue(value) || !self->ShowWallpaper()) {
    // 恢复请求可能先于 prepare 返回；最后再回滚一次，防止迟到回调锁住界面。
    self->NotifyRestored();
  }
}

bool DesktopWindow::ShowWallpaper() {
  if (!CanEnterWallpaper()) return false;
  GtkWidget* widget = GTK_WIDGET(window_);
  GdkWindow* native = gtk_widget_get_window(widget);
  GdkDisplay* display = gtk_widget_get_display(widget);
  GdkMonitor* monitor = gdk_display_get_monitor_at_window(display, native);
  if (monitor == nullptr) return false;
  GdkRectangle bounds;
  gdk_monitor_get_geometry(monitor, &bounds);
  if (bounds.width <= 0 || bounds.height <= 0) return false;

  gtk_window_get_position(window_, &snapshot_.x, &snapshot_.y);
  gtk_window_get_size(window_, &snapshot_.width, &snapshot_.height);
  snapshot_.decorated = gtk_window_get_decorated(window_);
  snapshot_.resizable = gtk_window_get_resizable(window_);
  snapshot_.accept_focus = gtk_window_get_accept_focus(window_);
  snapshot_.focus_on_map = gtk_window_get_focus_on_map(window_);
  snapshot_.skip_taskbar = gtk_window_get_skip_taskbar_hint(window_);
  snapshot_.skip_pager = gtk_window_get_skip_pager_hint(window_);
  snapshot_.type = gtk_window_get_type_hint(window_);
  snapshot_.state = gdk_window_get_state(native);
  if ((snapshot_.state & GDK_WINDOW_STATE_MAXIMIZED) != 0) {
    // 最大化时 get_size 返回屏幕大小，恢复后再次取消最大化仍应回到原尺寸。
    snapshot_.x = normal_geometry_.x;
    snapshot_.y = normal_geometry_.y;
    snapshot_.width = normal_geometry_.width;
    snapshot_.height = normal_geometry_.height;
  }

  // 隐藏只取消映射，不销毁 GTK 窗口和 Flutter 引擎。
  gtk_widget_hide(widget);
  wallpaper_ = true;
  gtk_window_unmaximize(window_);
  gtk_window_set_type_hint(window_, GDK_WINDOW_TYPE_HINT_DESKTOP);
  gtk_window_set_decorated(window_, FALSE);
  gtk_window_set_resizable(window_, FALSE);
  gtk_window_set_accept_focus(window_, FALSE);
  gtk_window_set_focus_on_map(window_, FALSE);
  gtk_window_set_skip_taskbar_hint(window_, TRUE);
  gtk_window_set_skip_pager_hint(window_, TRUE);
  gtk_window_set_keep_above(window_, FALSE);
  gtk_window_set_keep_below(window_, TRUE);
  gtk_window_stick(window_);
  gtk_window_move(window_, bounds.x, bounds.y);
  gtk_window_resize(window_, bounds.width, bounds.height);
  cairo_region_t* input = cairo_region_create();
  gtk_widget_input_shape_combine_region(widget, input);
  cairo_region_destroy(input);
  gtk_widget_show(widget);
  return true;
}

void DesktopWindow::RestoreWallpaper() {
  if (!wallpaper_ || window_ == nullptr) return;
  GtkWidget* widget = GTK_WIDGET(window_);
  gtk_widget_hide(widget);
  wallpaper_ = false;
  gtk_widget_input_shape_combine_region(widget, nullptr);
  gtk_window_set_type_hint(window_, snapshot_.type);
  gtk_window_set_decorated(window_, snapshot_.decorated);
  gtk_window_set_resizable(window_, snapshot_.resizable);
  gtk_window_set_accept_focus(window_, snapshot_.accept_focus);
  gtk_window_set_focus_on_map(window_, snapshot_.focus_on_map);
  gtk_window_set_skip_taskbar_hint(window_, snapshot_.skip_taskbar);
  gtk_window_set_skip_pager_hint(window_, snapshot_.skip_pager);
  gtk_window_set_keep_below(window_,
                           (snapshot_.state & GDK_WINDOW_STATE_BELOW) != 0);
  gtk_window_set_keep_above(window_,
                           (snapshot_.state & GDK_WINDOW_STATE_ABOVE) != 0);
  if ((snapshot_.state & GDK_WINDOW_STATE_STICKY) == 0) {
    gtk_window_unstick(window_);
  }
  gint x = snapshot_.x;
  gint y = snapshot_.y;
  gint width = snapshot_.width;
  gint height = snapshot_.height;
  GdkDisplay* display = gtk_widget_get_display(widget);
  GdkRectangle saved = {x, y, width, height};
  bool reachable = false;
  for (gint i = 0; i < gdk_display_get_n_monitors(display); ++i) {
    GdkRectangle bounds;
    gdk_monitor_get_workarea(gdk_display_get_monitor(display, i), &bounds);
    if (gdk_rectangle_intersect(&saved, &bounds, nullptr)) {
      reachable = true;
      break;
    }
  }
  if (!reachable) {
    // 只有整个窗口已经离开所有屏幕时才修正；正常跨屏窗口保持原尺寸和位置。
    GdkMonitor* monitor = gdk_display_get_monitor_at_point(display, x, y);
    if (monitor != nullptr) {
      GdkRectangle bounds;
      gdk_monitor_get_workarea(monitor, &bounds);
      if (bounds.width > 0 && bounds.height > 0) {
        width = std::min(width, bounds.width);
        height = std::min(height, bounds.height);
        x = std::max(bounds.x, std::min(x, bounds.x + bounds.width - width));
        y = std::max(bounds.y, std::min(y, bounds.y + bounds.height - height));
      }
    }
  }
  normal_geometry_ = {x, y, width, height};
  has_normal_geometry_ = true;
  restoring_maximized_ = (snapshot_.state & GDK_WINDOW_STATE_MAXIMIZED) != 0;
  gtk_window_move(window_, x, y);
  gtk_window_resize(window_, width, height);
  if (restoring_maximized_) {
    gtk_window_maximize(window_);
  }
}

void DesktopWindow::RestoreWindow() {
  if (window_ == nullptr || quitting_) return;
  const bool notify = wallpaper_ || preparing_;
  cancel_prepare_ = preparing_;
  hidden_to_tray_ = false;
  RestoreWallpaper();
  gtk_widget_show(GTK_WIDGET(window_));
  gtk_window_deiconify(window_);
  gtk_window_present(window_);
  if (notify) NotifyRestored();
}

void DesktopWindow::EnforceRecovery() {
  if (window_ == nullptr || quitting_ || CanRecover()) return;
  if (wallpaper_ || preparing_ || hidden_to_tray_) {
    RestoreWindow();
  }
}

gboolean DesktopWindow::DeleteEvent(GtkWidget*, GdkEvent*, gpointer data) {
  auto* self = static_cast<DesktopWindow*>(data);
  if (self->quitting_ || !self->CanRecover()) return FALSE;
  if (self->wallpaper_ || self->preparing_) {
    self->RestoreWindow();
  }
  self->hidden_to_tray_ = true;
  gtk_widget_hide(GTK_WIDGET(self->window_));
  return TRUE;
}

gboolean DesktopWindow::ConfigureEvent(GtkWidget* widget,
                                       GdkEventConfigure* event,
                                       gpointer data) {
  auto* self = static_cast<DesktopWindow*>(data);
#ifdef GDK_WINDOWING_X11
  if (!GDK_IS_X11_DISPLAY(gtk_widget_get_display(widget))) return FALSE;
#else
  return FALSE;
#endif
  GdkWindow* native = gtk_widget_get_window(widget);
  if (self->wallpaper_ || self->restoring_maximized_ || self->quitting_ ||
      native == nullptr || event->width <= 0 || event->height <= 0) {
    return FALSE;
  }
  if ((gdk_window_get_state(native) &
       (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN |
        GDK_WINDOW_STATE_ICONIFIED)) != 0) {
    return FALSE;
  }
  // 仅随窗口配置事件记录普通状态，不轮询，也不读取或调整其他平台窗口。
  gtk_window_get_position(self->window_, &self->normal_geometry_.x,
                           &self->normal_geometry_.y);
  self->normal_geometry_.width = event->width;
  self->normal_geometry_.height = event->height;
  self->has_normal_geometry_ = true;
  return FALSE;
}

gboolean DesktopWindow::WindowStateEvent(GtkWidget*, GdkEventWindowState* event,
                                         gpointer data) {
  auto* self = static_cast<DesktopWindow*>(data);
  if ((event->new_window_state & GDK_WINDOW_STATE_MAXIMIZED) != 0) {
    self->restoring_maximized_ = false;
  }
  return FALSE;
}

void DesktopWindow::WindowDestroyed(GtkWidget*, gpointer data) {
  auto* self = static_cast<DesktopWindow*>(data);
  self->window_ = nullptr;
  self->quitting_ = true;
  g_cancellable_cancel(self->cancellable_);
}

void DesktopWindow::ScreenChanged(GdkScreen*, gpointer data) {
  auto* self = static_cast<DesktopWindow*>(data);
  // 显示器移除或缩放变化时回到普通窗口，避免壁纸尺寸与输入区域脱节。
  if (self->wallpaper_ || self->preparing_) self->RestoreWindow();
}

void DesktopWindow::WindowManagerChanged(GdkScreen*, gpointer data) {
  auto* self = static_cast<DesktopWindow*>(data);
  if (self->wallpaper_ || self->preparing_) self->RestoreWindow();
  self->NotifyCapabilities();
}

void DesktopWindow::NotifyRestored() {
  fl_method_channel_invoke_method(channel_, "didRestore", nullptr, cancellable_,
                                   nullptr, nullptr);
}

FlValue* DesktopWindow::CreateCapabilities() const {
  FlValue* value = fl_value_new_map();
  fl_value_set_string_take(value, "wallpaper",
                            fl_value_new_bool(SupportsWallpaper()));
  fl_value_set_string_take(value, "trayHost",
                            fl_value_new_bool(tray_host_->available()));
  fl_value_set_string_take(value, "trayRevision",
                            fl_value_new_int(tray_host_->revision()));
  return value;
}

void DesktopWindow::NotifyCapabilities() {
  if (quitting_) return;
  g_autoptr(FlValue) value = CreateCapabilities();
  fl_method_channel_invoke_method(channel_, "capabilitiesChanged", value,
                                   cancellable_, nullptr, nullptr);
}

void DesktopWindow::Quit() {
  if (quitting_ || window_ == nullptr) return;
  quitting_ = true;
  cancel_prepare_ = true;
  tray_ready_ = false;
  shortcut_ready_ = false;
  GtkApplication* application = gtk_window_get_application(window_);
  // 先返回方法结果；下一个主循环直接退出，避免关闭事件再次把窗口隐藏。
  quit_source_ = g_idle_add_full(
      G_PRIORITY_DEFAULT_IDLE,
      [](gpointer data) -> gboolean {
        auto* self = static_cast<DesktopWindow*>(data);
        self->quit_source_ = 0;
        if (self->window_ != nullptr) {
          GApplication* application =
              G_APPLICATION(gtk_window_get_application(self->window_));
          if (application != nullptr) g_application_quit(application);
        }
        return G_SOURCE_REMOVE;
      },
      this, nullptr);
  if (application == nullptr) {
    g_source_remove(quit_source_);
    quit_source_ = 0;
    gtk_widget_destroy(GTK_WIDGET(window_));
  }
}
