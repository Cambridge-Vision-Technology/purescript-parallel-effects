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

### Labeled Effect Instances (Multiple Same-Type Effects)

Add support for multiple instances of the same effect type using variant labels, following PureScript Run's pattern.

**Motivation**: Enable computations with multiple different states, readers, or writers simultaneously (e.g., counter state + name state, config reader + user reader).

**Design Pattern** (based on Run):
- Use `Row.Cons sym f r1 r2` constraint with `IsSymbol sym` to enable labeled effects
- Provide "At" variants of all operations: `getAt`, `putAt`, `askAt`, `tellAt`, etc.
- Keep existing simple operations as defaults using standard labels
- All "At" operations take a `Proxy sym` parameter to specify the label

**Required Changes**:

1. **State Effect** (`src/Control/Monad/BatchRun/State.purs`):
   - Add `getAt`, `putAt`, `modifyAt` with `Row.Cons` constraints
   - Add `runStateAt` with label parameter
   - Keep existing `get`, `put`, `modify`, `runState` as default-labeled convenience functions
   - Example usage:
     ```purescript
     _counterState = Proxy :: Proxy "counterState"
     _nameState = Proxy :: Proxy "nameState"

     program :: BatchRun (counterState :: StateF Int, nameState :: StateF String | r) String
     program = do
       count <- getAt _counterState
       putAt _counterState (count + 1)
       name <- getAt _nameState
       pure $ name <> " (" <> show count <> ")"
     ```

2. **Reader Effect** (`src/Control/Monad/BatchRun/Reader.purs`):
   - Add `askAt`, `asksAt` with `Row.Cons` constraints
   - Add `runReaderAt` with label parameter
   - Keep existing `ask`, `runReader` as defaults

3. **Writer Effect** (`src/Control/Monad/BatchRun/Writer.purs`):
   - Add `tellAt` with `Row.Cons` constraints
   - Add `runWriterAt` with label parameter
   - Keep existing `tell`, `runWriter` as defaults
   - Consider adding `censorAt` for modifying output (like Run)

**Implementation Notes**:
- Must work with our parallel execution model (AVar for State, Ref for Writer)
- Handler composition must support multiple labeled instances
- Type inference should remain ergonomic despite added constraints

---

### Except Effect (Exception Handling)

Add a dedicated Except effect for typed exception handling, following Run's pattern.

**Motivation**: Provide first-class exception handling without relying on Aff rejection or Either return values in every computation.

**Design** (based on Run.Except):

1. **Data Type** (`src/Control/Monad/BatchRun/Except.purs`):
   ```purescript
   newtype ExceptF e a = ExceptF e

   type EXCEPT e r = (except :: ExceptF e | r)
   type FAIL r = (except :: ExceptF Unit | r)  -- Simple failure without error value

   _except :: Proxy "except"
   _except = Proxy
   ```

2. **Core Operations**:
   - `throw :: forall e a r. e -> BatchRun (EXCEPT e r) a` - Throw exception
   - `throwAt :: forall sym e a r. Proxy sym -> e -> BatchRun r a` - Labeled variant
   - `fail :: forall a r. BatchRun (FAIL r) a` - Simple failure
   - `failAt :: forall sym a r. Proxy sym -> BatchRun r a` - Labeled simple failure

3. **Handling Exceptions**:
   - `catch :: forall e a r. (e -> BatchRun r a) -> BatchRun (EXCEPT e r) a -> BatchRun r a`
   - `catchAt :: forall sym e a r. Proxy sym -> (e -> BatchRun t a) -> BatchRun r a -> BatchRun t a`

4. **Running to Either**:
   - `runExcept :: forall e a r. BatchRun (EXCEPT e r) a -> BatchRun r (Either e a)`
   - `runExceptAt :: forall sym e a r. Proxy sym -> BatchRun r a -> BatchRun t (Either e a)`

5. **Utility Functions**:
   - `rethrow :: forall e a r. Either e a -> BatchRun (EXCEPT e r) a` - Convert Either
   - `note :: forall e a r. e -> Maybe a -> BatchRun (EXCEPT e r) a` - Convert Maybe
   - `fromJust :: forall a r. Maybe a -> BatchRun (FAIL r) a` - Extract or fail

**Parallel Execution Semantics**:
- When one computation in a parallel batch throws, sibling computations should be cancelled (consistent with existing cancellation tests)
- Exception should propagate through the batch
- `catch` should work within parallel batches

**Integration with Safe Effects**:
- SafeAff and SafeEffect already return `Either Error a`
- Consider how Except interacts with these patterns
- Except provides control flow; SafeAff/SafeEffect provide explicit error returns
- Both patterns are complementary and should coexist

**Handler Implementation**:
- Follow similar pattern to State/Reader/Writer handlers
- Use `Data.Functor.Variant.on` to handle Except instructions
- Must integrate with parallel batch execution
- Consider stack safety for exception propagation

---

### Implementation Strategy

**Phase 1: Labeled State** (prove the pattern)
1. Add `Row.Cons` and `IsSymbol` constraints to State module
2. Implement `getAt`, `putAt`, `modifyAt`
3. Implement `runStateAt`
4. Write tests with multiple state instances
5. Ensure parallel execution works correctly with multiple states

**Phase 2: Labeled Reader & Writer** (replicate the pattern)
1. Apply same pattern to Reader (`askAt`, `runReaderAt`)
2. Apply same pattern to Writer (`tellAt`, `runWriterAt`)
3. Write tests with multiple reader/writer instances
4. Test combinations (e.g., 2 states + 1 reader + 1 writer)

**Phase 3: Except Effect** (new effect type)
1. Implement ExceptF functor and basic operations
2. Implement exception throwing and catching
3. Implement handlers with proper parallel semantics
4. Write comprehensive tests for exception behavior
5. Test exception propagation in parallel batches
6. Document interaction with SafeAff/SafeEffect

**Phase 4: Documentation & Examples**
1. Update README with labeled effects examples
2. Add COMPOSITION.md section on multiple same-type effects
3. Add exception handling patterns to docs
4. Create comprehensive examples showing:
   - Multiple states in parallel computations
   - Exception handling across parallel batches
   - Combining labeled effects with existing patterns

**Testing Requirements**:
- BDD specs for labeled effects (multiple states/readers/writers)
- BDD specs for Except effect (throw, catch, parallel propagation)
- Timing tests to ensure parallelism preserved with labeled effects
- Integration tests combining all effect types
- Edge cases: exception in one batch branch, cancellation propagation

**Type Safety Goals**:
- Compile-time guarantee that labeled effects are handled
- Type inference should work well (minimal type annotations needed)
- Error messages should be clear when labels are mismatched
- Row type composition should remain ergonomic

---

### Design Questions to Resolve

1. **Handler Composition**: How do labeled effects compose with our current `runParallel` API?
   - Current: `runParallel handler program`
   - With labels: Need to handle multiple instances of same effect type
   - Solution: Handler must pattern-match on all labels (Run uses `on` chaining)

2. **Type Aliases**: Should we provide convenience type aliases for common multi-effect scenarios?
   - Example: `type TwoStates s1 s2 r = (state1 :: StateF s1, state2 :: StateF s2 | r)`
   - Tradeoff: Convenience vs. explicitness

3. **Default vs. Labeled**: When should users prefer labeled variants?
   - Guideline: Use defaults for single instance, labels for multiple instances
   - Document the migration path from simple to labeled

4. **Except vs. SafeAff**: How do these patterns relate?
   - Except: Control flow for exceptional conditions (short-circuit computation)
   - SafeAff: Explicit error handling in type signature (no short-circuit)
   - Document when to use each pattern

5. **Parallel Exception Semantics**: What happens when multiple parallel computations throw?
   - Current cancellation behavior: first failure cancels siblings
   - Should Except follow same pattern?
   - Or collect all exceptions? (more complex, may not align with Aff cancellation)

---

### Success Criteria

- Can write programs with 2+ states/readers/writers of same effect type
- Exception handling works correctly in sequential and parallel contexts
- All existing tests pass (no regression)
- New BDD specs validate labeled effects and exception behavior
- Documentation clearly explains when and how to use new features
- Type inference remains ergonomic
- Performance not significantly degraded

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

