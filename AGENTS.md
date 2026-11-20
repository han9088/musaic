# Musaic

Flutter app, Android and iOS. Package: `com.deskbtm.musaic`.

## Architecture: Feature-first (required for AI agents)

**This project uses Feature-first architecture. All AI agents must follow these boundaries when adding, moving, or refactoring code.**

- Organize code by the feature that owns its responsibility, not by the page that happens to use it. A feature used by only one page still belongs under `lib/features/`.
- `lib/pages/` contains page entry points, page/sheet layout assembly, event wiring, and necessary page lifecycle wiring only. `lib/pages/home/` contains `home_page.dart` and `home_sheet.dart`. Do not add feature controllers, planners, resource pipelines, or transition engines to page directories, or move their implementations into page files.
- `lib/features/<feature>/` owns the feature's related state, types, controllers, orchestration, visual behavior, and interactions. Keep each feature cohesive; do not create a generic `features/home/` bucket for unrelated capabilities used by Home.
- `lib/ui/` contains shared UI primitives, shared visual calculations, and themes. Keep feature-specific workflows and transition state machines in their owning feature.
- Keep application assembly and lifecycle in `lib/app/`, existing business services and external integrations in `lib/services/`, persistence in `lib/storage/`, configuration in `lib/config/`, and localization in `lib/l10n/`.
- Features must not import pages or application assembly. Services and storage must not import pages, UI, or application assembly.
- Before adding or moving a file, identify its owning feature and check the import direction. Keep tests in `test/`, matching the source directories.

## Development workflow

- Use `mise install` to provision the SDK pinned in `mise.toml`.
- Use current Flutter docs and Context7 for library/API documentation, code generation, setup and configuration.
- Use signals_flutter for state shared across pages. Self-contained UI (dialogs, sheets, animation and input) owns its state with StatefulWidget and local controllers. Pass services through constructors.
- Name route pages `*_page.dart`.
- Follow `analysis_options.yaml`; use Phosphor Icons for app UI.
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
