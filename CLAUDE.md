<project>
PureScript AE

An Algebraidc effect system (based on purescript-run) that combines the concepts of free monads and free applicatives to achieve a DSL where developers can have parts of their programs run in parallel.
```

</project>
<guidance>
<general>
# General Software Development Rules

## Core Principles

- Brutal honesty: call out bad ideas early.
- Delete completely; do not comment out code (git has history).
- Fail fast: crash on missing inputs; no fallbacks, no empty catches. Use `set -euo pipefail` and `${VAR:?error}`.
- Consolidate before creating: search codebase first.
- Document technical debt with a remediation plan.

## Design & Types

- Prefer explicit types (Either/Maybe/Result) over exceptions.
- Make invalid states unrepresentable (e.g., nest co-dependent fields).
- Parse at boundaries; enforce invariants via types.
- Effects at edges; keep core pure.
- Immutability first; DRY; single responsibility; one approach per problem class.
- Prefer functional + statically typed languages.

## Testing

- Verify outcomes/effects, not “didn’t crash”.
- Never generate expected values in tests; compare to independent fixtures/constants.
- Assume failure; write tests to prove correctness.

## Hygiene

- Minimal comments: code=how, types=what, comments=why (non-obvious, invariants, module docs).
- No hard-coded paths.
- Predictable outputs: write to `out/<command>/…`; avoid temp dirs.
- Avoid env vars in our code; use explicit CLI args (accept env only from external tools).
- Improve guidance when you learn something useful.

## Versioning & Tooling

- No backward-compat shims unless explicitly requested; breaking changes are acceptable (users can pin versions).
- Configure tools via `flake.nix`; run `nix flake check` or `nix run .#format-fix`.
- No code in planning docs; no new documentation unless requested.

## Commits

- Use Conventional Commits: `type(scope)!: short imperative summary`.
- Common types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- Subject in imperative mood, ≤ 72 chars; no trailing period.
- Optional body: why and how, wrapped to ~72 chars.
- Footer for breaking changes and refs:
  - `BREAKING CHANGE: describe impact and required actions`
  - `Refs: #123` or `Closes: #123`
- Prefer small, focused commits; one logical change per commit.
</general>
<nix>
# Nix

Primary build system: Nix flakes (Determinate Nix). Keep dev, build, and test commands in `flake.nix` only.

## What to Run
- `nix flake check`: runs checks (lint, format, build, playback tests).
- `nix build .#<pkg>`: builds a specific package (e.g., `.#build`).
- `nix run`: default app (production entry).
- `nix run .#dev`: development app (servers, watchers, etc.).
- Tests: `.#test-playback` (pure), `.#test-live`, `.#test-record` (side‑effects). Pass test framework args through: `nix run .#test-live -- [args]`.

## Core Rules
- Single source of truth: only `flake.nix` for dev commands (no Makefile/just/package.json scripts as runners).
- Use ecosystem integrations: purs-nix (PureScript+JS), uv2nix (Python), buildNpmPackage (JS).
- No network in builds: fetch deps via derivations; network allowed only in `nix run` apps.
- Split deps: build both `deps` (all) and `deps-prod` (runtime only via `--omit=dev`).
- Hash deps correctly: never use `lib.fakeHash`. Get real hash: `nix run nixpkgs#prefetch-npm-deps -- package-lock.json` and set `npmDepsHash = "…"`.
- Monolithic source; packages include what they need via `pkgs.lib.fileset` (configs/assets copied per package).
- Fail fast: no fallbacks/version detection; crash on missing inputs.
- Policy: CI builds from tracked files only; require staged/committed changes.
- Symlink when read-only; copy when modifying. Never mutate derivation outputs.
- All command output in `out/<command>/…`; add `out/` to `.gitignore`.

## Package Model
- Internal derivations (not exposed): `source`, `deps`, `deps-prod`, `test-harness`.
- Exposed packages: `lint`, `format`, `build`, `dev`.
- Checks derive from packages: `lint`, `format`, `build`, `test-playback`.
- Apps: `default` (run built app), `dev` (dev server), `test-live`, `test-record`, `test-playback`, `format-fix` (tools-only).

## Tests
- Aggregate apps accept test framework filters (files/tags/names) via passthrough args.
- Playback tests are pure; run via `nix flake check` or `nix build .#checks.<system>.test-playback`.
- Live/record tests use `nix run .#test-live|.#test-record -- [args]`.

## Dependency Updates
- Automate with update-flake-lock (weekly PRs).

## Tips
- Use the `result` symlink to inspect outputs.
- Keep source-only derivation small; let packages pull exact files they need.
</nix>
<purescript>
# PureScript

## FFI (Foreign Function Interface)

- Do not import FFI as pure (JS can throw). Use `EffectFn*` + `runEffectFn*`.
- Keep JS minimal; stub external libs only.
- Avoid `Foreign`; model concrete types.
- For multi-arg functions use `EffectFnN`/`FnN` (uncurried) when perf‑critical.
- Promises: return `Effect (Promise a)` and convert via `Control.Promise.toAff`.

## Advanced Patterns

- Existential types (Data.Exists) for heterogeneous collections and plug‑ins.

## Error Handling

- Use Either/Maybe for all errors; never throw/unsafe.

## Import Standards

- Qualified imports: `import Data.Maybe as Data.Maybe`
- Use fully qualified names: `Data.Maybe.fromMaybe`
- Exceptions: Prelude and explicit symbol/type imports
- Remove duplicates/unused imports

## Safety

- Ban "unsafe" functions: `Partial`, `unsafePartial`, `unsafeCoerce`, `unsafePerformEffect`, `unsafePerformAff`, `crashWith`.
- Use Either/Maybe; Effect/Aff/Run; proper conversions (not coercions).

## Debugging

- Type holes (`?placeholder`) for compiler guidance (one per compile).
- `purescript-debug`: `spy`, `spyWith` for dev only; remove before prod.

---


- **Uncurried FFI**: Use `Fn2`-`Fn10` for performance-critical FFI. Avoids currying overhead.

---

## Web UI
- Halogen with Elm-style central state (see Halogen Realworld).

## Libraries

- Use Pursuit for search by name or type.
- Key: Argonaut (JSON), Affjax (HTTP), aff (async), js-promise-aff (Promise/Aff FFI), effect, run (algebraic effects), Halogen (web UI).

## Nix

- Use purs-nix for builds; purescript-overlay for tooling. No spago for builds. IDE: `purs-nix compile --json-errors`.

## Effects & Testing

- Type classes per effect. Use transformers or Run. Test modes: see `testing.md`.
</purescript>
<testing>
# Testing

## BDD Integration

- Test externally observable behavior (APIs, UIs, CLIs) only.
- Verify real effects (files/DB), avoid mocks.
- CI runs playback only against built artifacts.
- Write outputs to `out/test/{scenario}/` (never temp dirs).
- Never generate expected values in tests; verify against fixtures/constants.

## Modes

- Playback (pure): `nix flake check` or `nix run .#test-playback -- [args]`
  - Offline/deterministic; fixtures required; fail fast if missing.
- Live (impure): `nix run .#test-live -- [args]`
  - Real endpoints; supports `--tags`, names, files.
- Record (impure): `nix run .#test-record -- [args]`
  - Regenerates fixtures; filter what to record; `git add` fixtures before `nix flake check`.
- All modes use the same built test harness.

## Layout

- One feature per suite (kebab-case): `auth-flow`, `data-export`.
- Specs: `test/features/<feature>.feature.md`
- Fixtures: `test/fixtures/<feature>/`

## Commands

- Playback: `nix run .#test-playback -- features/auth-flow.feature`
- Live: `nix run .#test-live -- --tags @smoke`
- Record: `nix run .#test-record -- --name "User login"`
- CI: `nix flake check`

## Debugging

- Filter narrowly by file/tags/name to iterate quickly.

## Tools

- BDD Markdown specs; JS/TS step defs.
- Minimize side-effect calls; reuse results across assertions.

## Retro-fit

- Capture current correct output → write tests → confirm pass.
- Introduce a deliberate fault once to see tests fail.
</testing>
</guidance>

This file is generated, do not edit it directly. Edit either the project specific information in [agents.yml](./agents.yml) or the [company guidance](https://github.com/Cambridge-Vision-Technology/agen/wiki) and then rerun `agen`
To install the agen tool `nix profile add github:Cambridge-Vision-Technology/agen`