# Parallel Effects – Delivery Plan

Status: Complete ✅

## Done

- Added timing-based tests that demonstrated lack of parallelism.
- Implemented custom `Apply`/`Applicative` for `BatchRun` to merge batches.
- All tests pass; parallelism validated by timing spec.
- Lint (purescript-whine) and formatting (treefmt + purs‑tidy) wired via `flake.nix` and pass in `nix flake check`.
- Integrated BDD specs into flake checks (`nix flake check` now includes BDD tests).
- Comprehensive test coverage via BDD feature specs:
  - Parallel cancellation/propagation (siblings cancel when one batch fails quickly).
  - Reader semantics under batching (consistent env access in `<*>`).
  - State semantics under batching (parallel modifications increment correctly).
  - FileSystem operations (offline/deterministic write/read/delete tests).
  - Applicative law sanity checks (identity, homomorphism, interchange, batch associativity).
- Hardened BDD infrastructure:
  - Fixed PureScript lint in BDD runner (matching aliases, consistent case branches).
  - Centralized and corrected JS step definitions (delay/fail parsing, FS operations).
  - Normalized feature files to avoid unresolved placeholders.
  - Corrected BDD runner path in flake apps for direct bundle execution.
- Tests run offline/deterministically via vendored bdd-markdown.
- Added ergonomic parallel composition helpers:
  - `par2` and `par3` for combining 2-3 computations with explicit parallel intent.
  - `gather` for running an array of computations in parallel.
  - `parTraverse` and `parTraverse_` for mapping and executing in parallel.
  - New module: `src/Control/Monad/BatchRun/Parallel.purs`
  - Comprehensive test suite with 13 tests validating timing and correctness.
- Implemented core library effects with typed error handling:
  - **SafeAff**: Wraps Aff operations returning `Either Error a` for explicit error handling.
  - **SafeEffect**: Wraps Effect operations returning `Either Error a` for explicit error handling.
  - **Writer**: Monoidal value accumulation via `tell`.
  - Core library now ships with: SafeAff, SafeEffect, Reader, State, Writer, Parallel.
  - HTTP, FileSystem, and Logging moved to test/example code only.
  - New modules: `src/Control/Monad/BatchRun/{SafeAff,SafeEffect,Writer}.purs`
  - BDD test suite for safe effects with 6 scenarios validating error handling and parallel behavior.
  - Test helpers in `test/Test/Support/SafeEffects.purs` for safe effect testing patterns.
- Updated documentation:
  - Fixed all `extract` → `runPure` references in COMPOSITION.md.
  - Added error/cancellation semantics section to README.md.
  - Added custom Applicative instance documentation to README.md.
  - Added parallel helpers usage examples to README.md.
  - Added Safe Effects section showing typed error handling patterns.
  - Updated project structure to distinguish core vs example effects.
- Added GitHub Actions CI pipeline:
  - Multi-OS matrix (Ubuntu latest, macOS latest).
  - Uses DeterminateSystems/determinate-nix-action for optimal Nix performance.
  - Runs `nix flake check` to validate lint, format, build, and tests.
- System support: Limited to macOS ARM (aarch64-darwin) and Linux x64 (x86_64-linux).

## Goals (next milestones)

None - all core goals completed!

## Conventions / Constraints

- No network in builds; tests must be offline/deterministic.
- Write test artifacts to `out/test/<suite>/...` only.
- Prefer typed errors (Either/Maybe) in user effects; use Aff rejection only for interpreter/error propagation semantics tests.
- Keep changes minimal and type-safe; avoid unsafe APIs.

## How to run

- Format: `nix run .#format-fix`
- Lint: `nix build .#lint` or `nix flake check`
- PureScript tests: `nix run .#test`
- BDD tests (playback): `nix run .#test-playback` (or specific feature: `nix run .#test-playback -- test/features/parallel-cancellation.feature.md`)
- All checks (lint, format, build, PS tests, BDD specs): `nix flake check`

