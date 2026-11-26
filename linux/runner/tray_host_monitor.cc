#include "tray_host_monitor.h"

#include <cstring>
#include <utility>

namespace {
constexpr char kObjectPath[] = "/StatusNotifierWatcher";
constexpr char kHostProperty[] = "IsStatusNotifierHostRegistered";
}  // namespace

struct TrayHostMonitor::Lifetime {
  TrayHostMonitor* owner;
};

struct TrayHostMonitor::Request {
  std::weak_ptr<Lifetime> lifetime;
  size_t index;
  uint64_t serial;
};

TrayHostMonitor::TrayHostMonitor(Changed changed)
    : changed_(std::move(changed)),
      lifetime_(std::make_shared<Lifetime>(Lifetime{this})),
      cancellable_(g_cancellable_new()) {
  // 与 tray_manager 使用的 Linux 后端保持一致；不启动或修改桌面服务。
  const char* names[] = {"org.kde.StatusNotifierWatcher",
                         "com.canonical.StatusNotifierWatcher"};
  for (size_t i = 0; i < watchers_.size(); ++i) {
    Watcher& watcher = watchers_[i];
    watcher.owner = this;
    watcher.name = names[i];
    auto* request = new Request{lifetime_, i, watcher.request};
    g_dbus_proxy_new_for_bus(
        G_BUS_TYPE_SESSION, G_DBUS_PROXY_FLAGS_DO_NOT_AUTO_START, nullptr,
        watcher.name, kObjectPath, watcher.name, cancellable_, ProxyReady,
        request);
  }
}

TrayHostMonitor::~TrayHostMonitor() {
  lifetime_->owner = nullptr;
  g_cancellable_cancel(cancellable_);
  for (Watcher& watcher : watchers_) {
    if (watcher.proxy != nullptr) {
      g_signal_handlers_disconnect_by_data(watcher.proxy, &watcher);
      g_clear_object(&watcher.proxy);
    }
  }
  g_clear_object(&cancellable_);
}

void TrayHostMonitor::ProxyReady(GObject*, GAsyncResult* result, gpointer data) {
  std::unique_ptr<Request> request(static_cast<Request*>(data));
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusProxy) proxy = g_dbus_proxy_new_for_bus_finish(result, &error);
  auto lifetime = request->lifetime.lock();
  if (!lifetime || lifetime->owner == nullptr || proxy == nullptr) return;

  TrayHostMonitor* self = lifetime->owner;
  Watcher& watcher = self->watchers_[request->index];
  watcher.proxy = G_DBUS_PROXY(g_steal_pointer(&proxy));
  g_signal_connect(watcher.proxy, "notify::g-name-owner",
                   G_CALLBACK(OwnerChanged), &watcher);
  g_signal_connect(watcher.proxy, "g-properties-changed",
                   G_CALLBACK(PropertiesChanged), &watcher);
  g_signal_connect(watcher.proxy, "g-signal", G_CALLBACK(SignalReceived),
                   &watcher);
  self->ReadProperty(watcher);
  self->Publish();
}

void TrayHostMonitor::OwnerChanged(GObject*, GParamSpec*, gpointer data) {
  auto& watcher = *static_cast<Watcher*>(data);
  ++watcher.request;
  watcher.owner->ReadProperty(watcher);
  // 宿主进程重启后，托盘后端需要重新注册图标，即使另一宿主仍然存在。
  watcher.owner->Publish(true);
}

void TrayHostMonitor::PropertiesChanged(GDBusProxy*, GVariant* properties,
                                         const gchar* const* invalidated,
                                         gpointer data) {
  auto& watcher = *static_cast<Watcher*>(data);
  g_autoptr(GVariant) value = g_variant_lookup_value(
      properties, kHostProperty, G_VARIANT_TYPE_BOOLEAN);
  if (value != nullptr) {
    ++watcher.request;
    watcher.owner->ReadProperty(watcher);
    watcher.owner->Publish();
    return;
  }
  for (const gchar* const* key = invalidated; *key != nullptr; ++key) {
    if (std::strcmp(*key, kHostProperty) != 0) continue;
    watcher.available = false;
    watcher.owner->Publish();
    watcher.owner->RefreshProperty(watcher);
    return;
  }
}

void TrayHostMonitor::SignalReceived(GDBusProxy*, const gchar*,
                                    const gchar* signal, GVariant*,
                                    gpointer data) {
  if (std::strcmp(signal, "StatusNotifierHostRegistered") != 0 &&
      std::strcmp(signal, "StatusNotifierHostUnregistered") != 0) {
    return;
  }
  auto& watcher = *static_cast<Watcher*>(data);
  if (std::strcmp(signal, "StatusNotifierHostUnregistered") == 0) {
    // 先恢复可达性，再确认是否还有其他宿主；不让 D-Bus 超时挡住窗口恢复。
    watcher.available = false;
    watcher.owner->Publish();
  }
  // 部分面板只发送协议事件，不发送 PropertiesChanged；按事件读取一次。
  watcher.owner->RefreshProperty(watcher);
}

void TrayHostMonitor::ReadProperty(Watcher& watcher) {
  g_autofree gchar* owner = g_dbus_proxy_get_name_owner(watcher.proxy);
  g_autoptr(GVariant) value =
      g_dbus_proxy_get_cached_property(watcher.proxy, kHostProperty);
  watcher.available = owner != nullptr && value != nullptr &&
                      g_variant_is_of_type(value, G_VARIANT_TYPE_BOOLEAN) &&
                      g_variant_get_boolean(value);
}

void TrayHostMonitor::RefreshProperty(Watcher& watcher) {
  ++watcher.request;
  auto* request = new Request{
      lifetime_, static_cast<size_t>(&watcher - watchers_.data()),
      watcher.request};
  g_dbus_proxy_call(
      watcher.proxy, "org.freedesktop.DBus.Properties.Get",
      g_variant_new("(ss)", watcher.name, kHostProperty),
      G_DBUS_CALL_FLAGS_NO_AUTO_START, 2000, cancellable_, PropertyReady,
      request);
}

void TrayHostMonitor::PropertyReady(GObject* source, GAsyncResult* result,
                                   gpointer data) {
  std::unique_ptr<Request> request(static_cast<Request*>(data));
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) reply =
      g_dbus_proxy_call_finish(G_DBUS_PROXY(source), result, &error);
  auto lifetime = request->lifetime.lock();
  if (!lifetime || lifetime->owner == nullptr) return;

  TrayHostMonitor* self = lifetime->owner;
  Watcher& watcher = self->watchers_[request->index];
  if (watcher.request != request->serial) return;

  watcher.available = false;
  if (reply != nullptr && g_variant_is_of_type(reply, G_VARIANT_TYPE("(v)"))) {
    g_autoptr(GVariant) boxed = g_variant_get_child_value(reply, 0);
    g_autoptr(GVariant) value = g_variant_get_variant(boxed);
    g_autofree gchar* owner = g_dbus_proxy_get_name_owner(watcher.proxy);
    watcher.available = owner != nullptr &&
                        g_variant_is_of_type(value, G_VARIANT_TYPE_BOOLEAN) &&
                        g_variant_get_boolean(value);
    g_dbus_proxy_set_cached_property(watcher.proxy, kHostProperty, value);
  }
  self->Publish();
}

void TrayHostMonitor::Publish(bool owner_changed) {
  bool available = false;
  for (const Watcher& watcher : watchers_) {
    available = available || watcher.available;
  }
  if (available == available_ && !owner_changed) return;
  available_ = available;
  ++revision_;
  changed_(available_, revision_);
}
