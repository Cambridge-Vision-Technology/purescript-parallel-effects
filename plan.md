# Parallel Effects – Delivery Plan

Status: In progress

## Done

- Added timing-based tests that demonstrated lack of parallelism.
- Implemented custom `Apply`/`Applicative` for `BatchRun` to merge batches.
- All tests pass; parallelism validated by timing spec.
- Lint (purescript-whine) and formatting (treefmt + purs‑tidy) wired via `flake.nix` and pass in `nix flake check`.

## Goals (next milestones)

1) Expand tests for behavior, not just structure
2) Improve API ergonomics for common parallel patterns
3) Document semantics (esp. error/cancellation), align README/COMPOSITION
4) Tighten CI (ensure checks run on PRs; tests stay offline/deterministic)

## Work Items

### 1) Tests (expand coverage)

- Parallel cancellation/propagation
  - Intent: When one branch in a batch fails, the whole batch fails quickly (siblings canceled).
  - Plan: Add test-only effect `FailF` with operation `failNow` whose handler rejects the Aff. Combine with a long `Delay` in `<*>` and assert total < 300ms and that the overall Aff fails.
  - Files:
    - `test/Test/Support/Fail.purs` (new)
    - `test/Test/Parallelism.purs` (add new spec)
  - Acceptance: Spec asserts failure and short total time; no flakiness.

- Reader semantics under batching
  - Intent: `ask` returns env consistently inside `<*>`.
  - Plan: `(\a b -> a <> b) <$> ask <*> ask` with env = "X" → result "XX".
  - Files: `test/Test/Reader.purs` (new)
  - Acceptance: Passes; no timing assertions.

- State semantics under batching
  - Intent: Parallel `modify (_ + 1)` increments twice, final state = 2 (order nondeterministic but count stable).
  - Plan: Use `runState 0` and `(\_ _ -> unit) <$> modify (_ + 1) <*> modify (_ + 1)`.
  - Files: `test/Test/State.purs` (new)
  - Acceptance: Final state == 2.

- FileSystem (offline, deterministic)
  - Intent: Verify write/read/delete and `fileExists` using `out/test/fs/...` as sandbox.
  - Plan: Write a file, read back contents, delete, assert `fileExists == false`.
  - Files: `test/Test/FileSystem.purs` (new)
  - Acceptance: Passes without network; writes only under `out/test/fs/...`.

- Applicative law sanity checks (lightweight)
  - Intent: Smoke-check identity, homomorphism, interchange with small pure programs; associativity of batch merging.
  - Files: Extend `test/Test/Control/Monad/BatchRun.purs`.
  - Acceptance: All pass; serves as regression guard for the custom instance.

### 2) API ergonomics

- Add helpers for parallel composition
  - `par2 :: BatchRun r a -> BatchRun r b -> BatchRun r (Tuple a b)`
  - `par3`, `gather :: Array (BatchRun r a) -> BatchRun r (Array a)`
  - `parTraverse :: (a -> BatchRun r b) -> Array a -> BatchRun r (Array b)`
  - Files: `src/Control/Monad/BatchRun/Parallel.purs` (new)
  - Acceptance: Unit tests that use these helpers to confirm parallel timing behaves as expected (reuse Delay effect).

### 3) Semantics & docs

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

### 4) Build & CI

- CI: run full checks on PRs
  - Action: Add GitHub Actions/CI pipeline to run `nix flake check`.
  - Acceptance: CI fails on lint/format/build regressions; no network during builds; tests pass offline.

- Optional: add test check to flake `checks`
  - Action: Add `checks.test = ps.test.run { };` so tests are part of `nix flake check` (currently only build/lint/formatting are checks; tests are an app).
  - Acceptance: `nix flake check` also runs tests.

## Conventions / Constraints

- No network in builds; tests must be offline/deterministic.
- Write test artifacts to `out/test/<suite>/...` only.
- Prefer typed errors (Either/Maybe) in user effects; use Aff rejection only for interpreter/error propagation semantics tests.
- Keep changes minimal and type-safe; avoid unsafe APIs.

## How to run

- Format: `nix run .#format-fix`
- Lint: `nix build .#lint` or `nix flake check`
- Tests: `nix run .#test`
- All checks: `nix flake check`

