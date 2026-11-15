# musaic_query_platform_interface

A common platform interface for the `musaic_query` plugin.

This interface allows platform-specific implementations of the `musaic_query`
plugin, as well as the plugin itself, to ensure they are supporting the
same interface.

# Usage

To implement a new platform-specific implementation of `musaic_query`, extend
[`MusaicQueryPlatform`][1] with an implementation that performs the
platform-specific behavior, and when you register your plugin, set the default
`MusaicQueryPlatform` by calling
`MusaicQueryPlatform.instance = MyPlatformMusaicQuery()`.

# Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface)
over breaking changes for this package.

See https://flutter.dev/go/platform-interface-breaking-changes for a discussion
on why a less-clean interface is preferable to a breaking change.

[1]: lib/musaic_query_platform_interface.dart