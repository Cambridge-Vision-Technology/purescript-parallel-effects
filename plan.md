# Parallel Effects – Delivery Plan

Status: In progress

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

## Goals (next milestones)

1) Document semantics (esp. error/cancellation), align README/COMPOSITION
2) Add GitHub Actions CI pipeline to run checks on PRs

## Work Items

### 1) Semantics & docs

- Define error/cancellation semantics
  - Decision: Interpreter short-circuits batch on first `Aff` rejection and cancels siblings.
  - Document trade-offs with guidance preference for typed errors; recommend using typed `Either` in effect functors, but allow interpreter to reflect actual `Aff` failures too.
  - Files: `README.md`, `COMPOSITION.md` (update)
  - Acceptance: Docs describe observed/tested behavior; code and tests align.

- Align docs with current API
  - Replace any `extract` references with `runPure`.
  - Clarify that Applicative instance is custom to enable batching.
  - Files: `README.md`, `COMPOSITION.md`
  - Acceptance: No mismatches between docs and exports.

### 2) Build & CI

- CI: run full checks on PRs
  - Action: Add GitHub Actions/CI pipeline to run `nix flake check`.
  - Acceptance: CI fails on lint/format/build regressions; no network during builds; tests pass offline.

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

