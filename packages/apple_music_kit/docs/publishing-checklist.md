# pub.dev publishing checklist

Before each release:

- [ ] Update `CHANGELOG.md` with the release notes.
- [ ] Bump versions in all 5 `pubspec.yaml` files consistently.
- [ ] Replace `publish_to: none` with real publishing config.
- [ ] Point inter-package deps at published versions (not path:).
- [ ] Replace placeholder homepage/repository URLs and author email.
- [ ] `dart format` clean in every package.
- [ ] `dart analyze --fatal-infos` clean in every package.
- [ ] `flutter test` green in platform_interface, apple_music_kit and apple_music_kit_desktop.
- [ ] Desktop browser tests: `node --test packages/apple_music_kit_desktop/test/companion_test.cjs`.
- [ ] Windows/Linux example builds and live browser-companion sign-in/playback verified on each target OS.
- [ ] `flutter pub publish --dry-run` passes for each package.
- [ ] README claims match reality (update capability matrix + known
      limitations if platform status changed).
- [ ] No tokens, keys, or Apple AARs committed anywhere.
- [ ] (For platform runtime changes) device/browser smoke test notes
      recorded in docs/known-limitations.md.
