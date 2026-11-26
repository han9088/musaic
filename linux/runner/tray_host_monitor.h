// 文件职责：异步观察 Linux 托盘宿主，避免在没有恢复入口时隐藏窗口。
#ifndef RUNNER_TRAY_HOST_MONITOR_H_
#define RUNNER_TRAY_HOST_MONITOR_H_

#include <gio/gio.h>

#include <array>
#include <cstdint>
#include <functional>
#include <memory>

class TrayHostMonitor {
 public:
  using Changed = std::function<void(bool, int64_t)>;

  explicit TrayHostMonitor(Changed changed);
  ~TrayHostMonitor();

  TrayHostMonitor(const TrayHostMonitor&) = delete;
  TrayHostMonitor& operator=(const TrayHostMonitor&) = delete;

  bool available() const { return available_; }
  int64_t revision() const { return revision_; }

 private:
  struct Lifetime;
  struct Request;
  struct Watcher {
    TrayHostMonitor* owner = nullptr;
    const char* name = nullptr;
    GDBusProxy* proxy = nullptr;
    uint64_t request = 0;
    bool available = false;
  };

  static void ProxyReady(GObject* source, GAsyncResult* result, gpointer data);
  static void PropertyReady(GObject* source, GAsyncResult* result, gpointer data);
  static void OwnerChanged(GObject* object, GParamSpec* spec, gpointer data);
  static void PropertiesChanged(GDBusProxy* proxy, GVariant* properties,
                                const gchar* const* invalidated, gpointer data);
  static void SignalReceived(GDBusProxy* proxy, const gchar* sender,
                             const gchar* signal, GVariant* parameters,
                             gpointer data);
  void ReadProperty(Watcher& watcher);
  void RefreshProperty(Watcher& watcher);
  void Publish(bool owner_changed = false);

  Changed changed_;
  std::shared_ptr<Lifetime> lifetime_;
  GCancellable* cancellable_ = nullptr;
  std::array<Watcher, 2> watchers_;
  bool available_ = false;
  int64_t revision_ = 0;
};

#endif  // RUNNER_TRAY_HOST_MONITOR_H_
