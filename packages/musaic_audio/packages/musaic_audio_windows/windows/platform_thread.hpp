#pragma once

// This must be included before many other Windows headers.
#include <windows.h>

#include <functional>
#include <mutex>
#include <stdexcept>
#include <utility>
#include <vector>

// Runs closures on the Flutter platform thread.
//
// WinRT delivers MediaPlayer's events (PlaybackStateChanged, MediaFailed,
// CurrentItemChanged, ItemFailed) on thread-pool threads, but a Flutter
// platform channel may only be written from the platform thread. Writing from
// another thread risks dropped messages and crashes, and the engine logs
//
//   The '...' channel sent a message from native to Flutter on a non-platform
//   thread.
//
// for each one. So anything that reaches an EventSink from a WinRT callback is
// queued here and run on the platform thread instead.
//
// The mechanism is a message-only window owned by this class: work goes on a
// mutex-guarded queue and a message is posted to that window, whose WndProc
// runs on the thread that created it — the platform thread — and drains the
// queue.
//
class PlatformThreadDispatcher {
public:
  PlatformThreadDispatcher() {
    // This constructor runs during plugin registration, i.e. on the platform
    // thread, so the window created here belongs to that thread and its WndProc
    // is pumped by it.
    WNDCLASSEXW cls{};
    cls.cbSize = sizeof(cls);
    cls.lpfnWndProc = &PlatformThreadDispatcher::WndProc;
    cls.hInstance = GetModuleHandleW(nullptr);
    cls.lpszClassName = kWindowClass;
    // A second registration fails with ERROR_CLASS_ALREADY_EXISTS, which is
    // harmless — CreateWindowExW below only needs the class to exist.
    if (!RegisterClassExW(&cls) &&
        GetLastError() != ERROR_CLASS_ALREADY_EXISTS) {
      throw std::runtime_error("Could not register the audio dispatcher.");
    }

    window_ = CreateWindowExW(0, kWindowClass, L"", 0, 0, 0, 0, 0, HWND_MESSAGE,
                              nullptr, GetModuleHandleW(nullptr), nullptr);
    if (!window_) {
      throw std::runtime_error("Could not create the audio dispatcher.");
    }
    SetWindowLongPtrW(window_, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));
  }

  ~PlatformThreadDispatcher() { Close(); }

  PlatformThreadDispatcher(const PlatformThreadDispatcher &) = delete;
  PlatformThreadDispatcher &
  operator=(const PlatformThreadDispatcher &) = delete;

  // Called on the platform thread before the plugin releases its dispatcher.
  void Close() {
    HWND window;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      window = std::exchange(window_, nullptr);
      tasks_.clear();
    }
    if (window) {
      SetWindowLongPtrW(window, GWLP_USERDATA, 0);
      DestroyWindow(window);
    }
  }

  void Post(std::function<void()> task) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!window_)
      return;
    const bool schedule_drain = tasks_.empty();
    tasks_.push_back(std::move(task));
    if (schedule_drain && !PostMessageW(window_, kRunTasks, 0, 0)) {
      tasks_.pop_back();
    }
  }

private:
  static constexpr const wchar_t *kWindowClass =
      L"MusaicAudioWindowsDispatcherWindow";
  static constexpr UINT kRunTasks = WM_USER + 1;

  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                                  LPARAM lparam) {
    if (message == kRunTasks) {
      auto *self = reinterpret_cast<PlatformThreadDispatcher *>(
          GetWindowLongPtrW(hwnd, GWLP_USERDATA));
      if (self) {
        self->Drain();
        return 0;
      }
    }
    return DefWindowProcW(hwnd, message, wparam, lparam);
  }

  void Drain() {
    // Swap the queue out and run outside the lock: a task may post more work,
    // and holding the mutex through it would deadlock.
    std::vector<std::function<void()>> tasks;
    {
      std::lock_guard<std::mutex> lock(mutex_);
      tasks.swap(tasks_);
    }
    for (auto &task : tasks) {
      task();
    }
  }

  HWND window_ = nullptr;
  std::mutex mutex_;
  std::vector<std::function<void()>> tasks_;
};
