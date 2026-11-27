cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "musaic_audio_windows")
project(${PROJECT_NAME} LANGUAGES CXX)
# C++20, not 17, because of a header C++/WinRT chooses on our behalf. Built as
# C++17 it includes <experimental/coroutine>; built as C++20 it includes the
# standard <coroutine>. MSVC 14.51, which ships with Visual Studio 2026, turned
# the deprecation of the experimental header into a hard error:
#
#   error C2338: static assertion failed: 'error STL1011: The /await compiler
#   option, <experimental/coroutine> ... are deprecated by Microsoft and will be
#   REMOVED SOON.'
#
# So this plugin does not build under VS 2026 at C++17, whether or not it uses
# coroutines itself - including <winrt/Windows.Media.Playback.h> is enough.
# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "musaic_audio_windows_plugin")

add_library(${PLUGIN_NAME} SHARED
  "musaic_audio_windows_plugin.cpp"
  "adaptive_source.hpp"
  "platform_thread.hpp"
  "playlist_order.hpp"
  "player.hpp"
)
apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PRIVATE cxx_std_20)
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL NOMINMAX)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin windowsapp)

# List of absolute paths to libraries that should be bundled with the plugin
set(musaic_audio_windows_bundled_libraries
  ""
  PARENT_SCOPE
)

# === Tests ===

if (include_${PROJECT_NAME}_tests)
  set(TEST_RUNNER "${PROJECT_NAME}_test")
  enable_testing()

  # Download googletest. Using the same version as the camera_windows plugin
  # for consistency across Flutter Windows plugins.
  include(FetchContent)
  FetchContent_Declare(
    googletest
    URL https://github.com/google/googletest/archive/release-1.11.0.zip
  )
  # Prevent overriding the parent project's compiler/linker settings.
  set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)
  # Disable install commands for gtest so it doesn't end up in the bundle.
  set(INSTALL_GTEST OFF CACHE BOOL "Disable installation of googletest" FORCE)

  FetchContent_MakeAvailable(googletest)

  # The URI and playlist helpers are independent of WinRT.
  add_executable(${TEST_RUNNER}
    test/playlist_order_test.cpp
    test/uri_utils_test.cpp
  )
  apply_standard_settings(${TEST_RUNNER})
  target_include_directories(${TEST_RUNNER} PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(${TEST_RUNNER} PRIVATE gtest_main)

  include(GoogleTest)
  gtest_discover_tests(${TEST_RUNNER})
endif()
