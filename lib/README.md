# MUSAIC — lib architecture

This is a map of ownership, not an additional runtime layer.

## Entry and composition

- `app/`: application bootstrap, provider ownership, theme/localization, and the root bottom-sheet host.
- `pages/home/`: home-level coordination of source selection, playback binding, orientation, and mode switching. `HomePage` owns `AnimationController` and `Ticker` lifetimes that span multiple presentations; it does not implement canvas painting or Cover Flow physics.
- `l10n/`: ARB catalogs and Flutter-generated localization classes.

## Feature modules

- `features/canvas/`: visible grid construction (`AlbumCanvasViewport`), touch state (`CanvasInteractionState`), pure drift update (`CanvasDrift`), grid snapshots, layout handoff state, and portrait tilt.
- `features/cover_flow/`: the Cover Flow presentation, input adapters, swipe/settling numerical state (`CoverFlowMotion`), and shared cover geometry (`CoverFlowGeometry`).
- `features/layout/`: temporary grid-to-Cover-Flow interpolation, presentation overlay, and layout switch affordance.
- `features/artwork/`: asset/directory artwork dispatch, Xerox artwork widget, shader parameters/LOD/seed, and bounded visible-artwork preloading.
- `features/music/catalog/`: provider-album mapping into existing presentation maps.
- `features/music/transition/`: timing and per-tile source motion, with `HomeSourceTransition` owning the exit/handoff/enter animation timeline. The page owns the actual catalog commit and playback binding through the handoff callback.
- `features/music/playback/`: album playback state exposed to presentation widgets.
- `features/music/presentation/`: music-source selection UI.
- `features/settings/`: per-platform settings affordances and app-icon picker.

## Infrastructure and shared UI

- `services/music/`: provider adapters, source selection, directory scanning, and local library integrations.
- `storage/music/`: SQLite index I/O and separately grouped pure snapshot decoding.
- `ui/bottom_sheet/`: reusable bottom-sheet engine and UI. The `types.dart` entry library exposes definitions from grouped `part` files without changing import paths.
- `ui/dialogs/` and `ui/widgets/`: shared effects and notification/rendering components. Large painters/overlays use Dart library parts so private contracts and public entry points remain intact.
- `ui/theme/` and `ui/thinking_orbs/`: shared visual primitives.

## Behavioral contracts

1. The infinite grid is viewport-built; don't turn the entire canvas into a global image post-process.
2. Grid motion, Cover Flow motion, and the source transition timeline have distinct owners. Changes to numerical formulas or phase durations require dedicated regression tests.
3. A source switch commits the target catalog and binds playback at **handoff**, not at the start of the exit animation.
4. The selected album, grid offset, and flow offset are shared through `HomeAlbumLayoutState`; selection and transition continuity must survive mode changes.
5. Xerox keeps the same grayscale/edge/threshold/grain shader and resolution policy. The original image remains a fallback until the shader and sampled image are ready.
6. Directory scanning and image decoding are asynchronous, and visible-artwork preloading is capped to a small concurrent batch.
7. Existing public imports of `storage/music/music_index.dart`, `ui/bottom_sheet/types.dart`, and the shared UI entry files should continue to work.

## Validation

Run `flutter analyze` and `flutter test` with the project's declared Flutter/Dart SDK and sibling path dependencies available. For animation changes, compare grid drift, Cover Flow coasting, source exit/handoff/enter, Xerox shader output, and bottom-sheet UI against the original `codex/refactor-directory-structure` branch on the same device, frame rate, display size, and DPR.

An unrun test is **not** a passing test. Architecture changes and measured performance optimizations should remain separate commits.
