#pragma once

#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>
#include <winrt/Windows.Media.Streaming.Adaptive.h>
#include <winrt/Windows.Web.Http.Filters.h>
#include <winrt/Windows.Web.Http.Headers.h>
#include <winrt/Windows.Web.Http.h>

#include <cwchar>
#include <memory>
#include <mutex>
#include <optional>
#include <utility>
#include <vector>

namespace musaic_audio {

using AdaptiveMediaSource =
    winrt::Windows::Media::Streaming::Adaptive::AdaptiveMediaSource;
using AdaptiveMediaSourceCreationStatus = winrt::Windows::Media::Streaming::
    Adaptive::AdaptiveMediaSourceCreationStatus;
using RequestHeaders = std::vector<std::pair<winrt::hstring, winrt::hstring>>;

class AdaptiveSourceSettings {
public:
  explicit AdaptiveSourceSettings(std::optional<uint32_t> peak) : peak_(peak) {}

  void SetPeakBitrate(std::optional<uint32_t> peak) {
    std::lock_guard lock(mutex_);
    if (source_)
      ApplyPeak(source_, peak);
    peak_ = peak;
  }

  void SetSource(AdaptiveMediaSource source) {
    std::lock_guard lock(mutex_);
    ApplyPeak(source, peak_);
    source_ = std::move(source);
  }

private:
  static void ApplyPeak(const AdaptiveMediaSource &source,
                        std::optional<uint32_t> peak) {
    using winrt::Windows::Foundation::IReference;
    source.DesiredMaxBitrate(
        peak ? winrt::box_value(*peak).as<IReference<uint32_t>>() : nullptr);
  }

  std::mutex mutex_;
  std::optional<uint32_t> peak_;
  AdaptiveMediaSource source_{nullptr};
};

namespace adaptive_source {

using winrt::Windows::Foundation::IAsyncOperationWithProgress;
using winrt::Windows::Foundation::IClosable;
using winrt::Windows::Foundation::Uri;
using winrt::Windows::Web::Http::HttpClient;
using winrt::Windows::Web::Http::HttpProgress;
using winrt::Windows::Web::Http::HttpRequestMessage;
using winrt::Windows::Web::Http::HttpResponseMessage;
using winrt::Windows::Web::Http::Filters::HttpBaseProtocolFilter;
using winrt::Windows::Web::Http::Filters::IHttpFilter;

inline bool SameOrigin(const Uri &first, const Uri &second) {
  return first.SchemeName() == second.SchemeName() &&
         first.Host() == second.Host() && first.Port() == second.Port();
}

// Give credentials to same-origin manifests, segments and redirects only.
class OriginHeadersFilter
    : public winrt::implements<OriginHeadersFilter, IHttpFilter, IClosable> {
public:
  OriginHeadersFilter(Uri origin, RequestHeaders headers)
      : origin_(std::move(origin)), headers_(std::move(headers)) {
    inner_.AllowAutoRedirect(false);
  }

  void Close() { inner_.Close(); }

  IAsyncOperationWithProgress<HttpResponseMessage, HttpProgress>
  SendRequestAsync(HttpRequestMessage request) {
    auto lifetime = get_strong();
    auto cancellation = co_await winrt::get_cancellation_token();
    cancellation.enable_propagation();

    // Construct a request for each hop. The input holds the engine's own
    // headers, so a redirect can never carry auth injected on a previous hop.
    auto uri = request.RequestUri();
    const auto requested = uri;
    for (int redirect = 0;; ++redirect) {
      if (uri.SchemeName() != L"http" && uri.SchemeName() != L"https")
        throw winrt::hresult_invalid_argument(L"Unsupported redirect scheme.");
      HttpRequestMessage current(request.Method(), uri);
      const bool same_request_origin = SameOrigin(uri, requested);
      for (const auto &header : request.Headers()) {
        const auto key = header.Key();
        if (!same_request_origin &&
            (_wcsicmp(key.c_str(), L"authorization") == 0 ||
             _wcsicmp(key.c_str(), L"proxy-authorization") == 0 ||
             _wcsicmp(key.c_str(), L"cookie") == 0)) {
          continue;
        }
        current.Headers().TryAppendWithoutValidation(key, header.Value());
      }
      if (SameOrigin(uri, origin_)) {
        for (const auto &[name, value] : headers_) {
          if (current.Headers().HasKey(name))
            current.Headers().Remove(name);
          current.Headers().TryAppendWithoutValidation(name, value);
        }
      }
      auto response = co_await inner_.SendRequestAsync(current);
      const auto status = static_cast<int>(response.StatusCode());
      if (status != 301 && status != 302 && status != 303 && status != 307 &&
          status != 308)
        co_return response;
      const auto location = response.Headers().Location();
      if (!location || redirect == 9)
        co_return response;
      uri = Uri(uri.AbsoluteUri(), location.RawUri());
      response.Close();
    }
  }

private:
  Uri origin_;
  RequestHeaders headers_;
  HttpBaseProtocolFilter inner_;
};

inline winrt::fire_and_forget
Bind(winrt::Windows::Media::Core::MediaBindingEventArgs args, Uri uri,
     RequestHeaders headers, std::shared_ptr<AdaptiveSourceSettings> settings) {
  try {
    const auto deferral = args.GetDeferral();
    try {
      const auto operation =
          headers.empty()
              ? AdaptiveMediaSource::CreateFromUriAsync(uri)
              : AdaptiveMediaSource::CreateFromUriAsync(
                    uri, HttpClient(winrt::make<OriginHeadersFilter>(
                             uri, std::move(headers))));
      const auto canceled =
          args.Canceled(winrt::auto_revoke,
                        [operation](auto &&, auto &&) { operation.Cancel(); });
      const auto result = co_await operation;
      if (result.Status() == AdaptiveMediaSourceCreationStatus::Success) {
        const auto source = result.MediaSource();
        settings->SetSource(source);
        args.SetAdaptiveMediaSource(source);
      }
    } catch (const winrt::hresult_error &) {
      // Completing an unresolved binding lets the playlist report an item
      // error.
    }
    deferral.Complete();
  } catch (const winrt::hresult_error &) {
    // The item can be closed while WinRT cancels its binding.
  }
}

} // namespace adaptive_source

inline winrt::Windows::Media::Core::MediaSource
CreateAdaptiveSource(winrt::Windows::Foundation::Uri uri,
                     RequestHeaders headers,
                     std::shared_ptr<AdaptiveSourceSettings> settings) {
  using namespace winrt::Windows::Media::Core;
  MediaBinder binder;
  binder.Binding([uri = std::move(uri), headers = std::move(headers),
                  settings = std::move(settings)](auto &&, const auto &args) {
    adaptive_source::Bind(args, uri, headers, settings);
  });
  return MediaSource::CreateFromMediaBinder(binder);
}

} // namespace musaic_audio
