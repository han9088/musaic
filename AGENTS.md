# Musaic

Flutter app, Android and iOS. Package: `com.deskbtm.musaic`.

- Use `mise install` to provision the SDK pinned in `mise.toml`.
- Use current Flutter docs and Context7 for library/API documentation, code generation, setup and configuration.
- Use signals_flutter for state shared across pages. Self-contained UI (dialogs, sheets, animation and input) owns its state with StatefulWidget and local controllers. Pass services through constructors.
- Use feature-first organization: keep feature-owned state, controllers, orchestration, visual behavior, and interactions under `lib/features/`, grouped by capability. Keep `lib/pages/` limited to page entry points and page/sheet assembly. A feature used by only one page still belongs to its feature. Keep application assembly and lifecycle in `lib/app/`, shared UI primitives and themes in `lib/ui/`, existing business services and external integrations in `lib/services/`, persistence in `lib/storage/`, configuration in `lib/config/`, and localization in `lib/l10n/`.
- Name route pages `*_page.dart`. Keep related types, state, and behavior with their owning feature; do not place feature controllers, planners, or transition engines in `lib/pages/`. Share presentation primitives through `lib/ui/` while keeping business orchestration in its feature. Features must not import pages or application assembly. Services and storage must not import pages, UI, or application assembly.
- Follow `analysis_options.yaml`; use Phosphor Icons for app UI.
- Keep tests in `test/`, matching the source directories.
- Run Flutter commands serially: `flutter analyze`, `flutter test`, platform builds.
- After editing ARB files, run `flutter gen-l10n`.
- After editing Drift, Envied or Dart Mappable sources, run `dart run build_runner build`.
- Never commit `.env`, signing material, generated environment values or machine paths.
- Keep changes scoped.
- Use Conventional Commits when a commit is requested; do not commit automatically.
- If `.codegraph/` exists, use CodeGraph before searching or reading application code.

## Code design

- Write elegant, readable code: use precise names, straightforward control flow, and explicit state transitions.
- Keep cohesion high: each module owns one clear responsibility, with its related state and behavior kept together.
- Keep coupling low: communicate through small, explicit interfaces, pass dependencies through constructors, and keep implementation details private.
- Split files, components, and functions along responsibility and change boundaries. Choose sizes that make the logic easy to follow; introduce an abstraction only when it clarifies the current design or removes meaningful duplication.
- Aim for the highest practical performance while preserving correctness and clarity: minimize redundant computation, widget rebuilds, repaints, allocations, and I/O; keep expensive work off the UI thread and use profiling to verify performance improvements.
