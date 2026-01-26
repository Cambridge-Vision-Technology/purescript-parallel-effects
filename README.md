# PureScript Parallel Effects - Proof of Concept

A proof-of-concept implementation of an algebraic effect system in PureScript that combines **free monads** with **free applicatives** to enable parallel execution of independent effects.

## Overview

This library demonstrates the Fraxl pattern (from Haskell) ported to PureScript, enabling:

- **Sequential composition** via free monads (`>>=`)
- **Parallel batching** via free applicatives (`<*>`)
- **Extensible effects** via row-polymorphic variants
- **Type-safe effect interpretation** with Aff's Parallel typeclass

## Architecture

### Three-Layer Design

```purescript
data BatchF r a = Batch (FreeAp (VariantF r) a)

newtype Program r a = Program (Free (BatchF r) a)
```

This creates a three-layer architecture:

1. **VariantF** - Extensible effect rows
2. **FreeAp** - Free applicative for parallel batching
3. **Free** - Free monad for sequential composition

### Key Insight

When effects are combined with applicative operators (`<*>`), they are batched together in a FreeAp node. The interpreter can then:

1. Detect these batches
2. Convert each effect to `ParAff` (parallel Aff)
3. Execute all effects in the batch concurrently
4. Sequence results back into the monadic flow

## Example Usage

```purescript
demoProgram :: forall r. Program (HTTP r) (Array String)
demoProgram = do
  let baseUrl = "https://jsonplaceholder.typicode.com"

  -- These three requests execute IN PARALLEL
  results <- (\u p c -> [u, p, c])
    <$> get (baseUrl <> "/users/1")
    <*> get (baseUrl <> "/posts/1")
    <*> get (baseUrl <> "/comments/1")

  pure results

-- Run the program
main = launchAff_ do
  results <- runHTTP impossibleHandler demoProgram
  -- Results from all 3 requests, fetched concurrently!
```

### Parallel Composition Helpers

The `Control.Monad.Program.Parallel` module provides convenient helpers for explicit parallel composition:

```purescript
import Control.Monad.Program.Parallel

-- Execute two computations in parallel, return both results
userAndPost <- par2
  (get "/users/1")
  (get "/posts/1")
-- Returns: Tuple user post

-- Execute three computations in parallel
results <- par3
  (get "/users/1")
  (get "/posts/1")
  (get "/comments/1")
-- Returns: Tuple user (Tuple post comment)

-- Run an array of computations in parallel
users <- gather
  [ get "/users/1"
  , get "/users/2"
  , get "/users/3"
  ]
-- Returns: Array of results, preserving order

-- Map over an array and execute in parallel (parallel traverse)
users <- parTraverse
  (\id -> get ("/users/" <> show id))
  [1, 2, 3, 4, 5]
-- Returns: Array of users

-- Execute for side effects, discard results
parTraverse_
  (\url -> post url "data")
  ["/log/1", "/log/2", "/log/3"]
```

**When to use:**
- Use helpers when you want to make parallel intent explicit
- Use raw applicative syntax (`<$>` and `<*>`) for flexible composition
- Both approaches execute in parallel via the custom Applicative instance

## Implementation Highlights

### Parallel Interpreter

```purescript
runParallel
  :: forall r a
   . (forall x. VariantF r x -> Aff x)
  -> Program r a
  -> Aff a
runParallel handler (Program free) =
  foldFree interpretBatch free
  where
  interpretBatch :: BatchF r ~> Aff
  interpretBatch (Batch ap) =
    -- KEY: parallel transforms each effect, sequential combines results
    sequential $ foldFreeAp (parallel <<< handler) ap
```

### Effect Definition Pattern

Effects are defined as functors with continuation-passing style:

```purescript
data HttpF a
  = Get String (String -> a)
  | Post String String (String -> a)

derive instance Functor HttpF

get :: forall r. String -> Program (HTTP r) String
get url = lift _http (Get url identity)
```

### Error Handling & Cancellation

When parallel batches execute, the interpreter uses Aff's cancellation mechanism to handle failures:

- **First failure short-circuits**: If any effect in a parallel batch fails, the entire batch is canceled immediately
- **Sibling cancellation**: Other effects running in the same batch are canceled automatically
- **Fast failure propagation**: The failure is propagated without waiting for other effects to complete

**Best practices:**
- Use typed errors (Either/Maybe) in your effect functors for recoverable errors
- Reserve Aff rejection for true failures (network errors, resource exhaustion)
- This allows fine-grained error handling while preserving fast-failure semantics

**Example:**
```purescript
-- If the first request fails after 10ms, the second is canceled immediately
-- Total time: ~10ms, not 500ms
results <- (\a b -> [a, b])
  <$> get "/fail-fast"      -- Fails after 10ms
  <*> get "/slow-endpoint"  -- Would take 500ms, but gets canceled
```

See `test/features/parallel-cancellation.feature.md` for behavioral specification.

### Safe Effects (Typed Error Handling)

For recoverable errors, use **Safe Effects** that return `Either Error a` instead of throwing:

```purescript
import Control.Monad.Program.SafeAff (liftSafeAff, SAFE_AFF)
import Control.Monad.Program.SafeEffect (liftSafeEffect, SAFE_EFFECT)

-- Wrap an Aff that might throw
result <- liftSafeAff (Affjax.get url)
case result of
  Right response -> -- handle success
  Left error -> -- handle error, no cancellation

-- Wrap an Effect that might throw
value <- liftSafeEffect (readFile path)
case value of
  Right contents -> pure contents
  Left err -> pure "default contents"
```

**Key difference from Aff rejection:**

| Behavior | Aff Rejection (throw) | Safe Effects (Either) |
|----------|----------------------|----------------------|
| Parallel batch | Cancels siblings immediately | All complete, return Either results |
| Error handling | Must catch at interpreter | Explicit in return type |
| Use case | Fatal failures | Recoverable errors |

**Example: Mixed results without cancellation**

```purescript
-- Both operations complete, one succeeds and one fails
results <- (\a b -> Tuple a b)
  <$> liftSafeAff successfulOp  -- Returns Right value
  <*> liftSafeAff failingOp      -- Returns Left error

-- Both results are available:
-- results :: Tuple (Either Error A) (Either Error B)
```

This allows you to handle partial failures gracefully without canceling the entire batch.

See `test/features/safe-effects.feature.md` for behavioral specification.

### Custom Applicative Instance

Program has a **custom Apply/Applicative instance** that merges adjacent batches:

```purescript
instance applyProgram :: Apply (Program r) where
  apply = apBatch  -- Custom implementation that merges batches

instance applicativeProgram :: Applicative (Program r) where
  pure a = Program (pure a)
```

**Why this matters:**
- Default Applicative would create separate batches for each `<*>`
- Custom instance merges them into a single batch
- Result: All effects composed with `<*>` execute in parallel in one batch

**The difference:**
```purescript
-- With custom instance: ONE batch with 3 parallel effects
results <- (\a b c -> [a, b, c])
  <$> effect1
  <*> effect2
  <*> effect3

-- Sequential (monadic) composition: 3 separate batches
results <- do
  a <- effect1  -- Batch 1
  b <- effect2  -- Batch 2
  c <- effect3  -- Batch 3
  pure [a, b, c]
```

## Project Structure

```
src/                                   # JavaScript-specific modules
├── Control/
│   └── Monad/
│       ├── Concurrent/
│       │   ├── Class.purs           # MonadConcurrent type class + Effect instance (portable)
│       │   ├── Aff.purs             # ConcurrentAff newtype for JavaScript backend
│       │   └── Erl.purs             # Erlang FFI helpers (internal)
│       └── Program/
│           ├── Aff.purs             # Aff-specific interpreters (runParallel, runPure)
│           ├── Parallel.purs        # Parallel composition helpers (par2, gather, etc.)
│           ├── SafeAff.purs         # Safe Aff with typed errors
│           ├── SafeEffect.purs      # Safe Effect with typed errors
│           ├── Reader.purs          # Reader effect
│           ├── State.purs           # State effect
│           ├── Writer.purs          # Writer effect
│           ├── HTTP.purs            # HTTP effects (test/example)
│           ├── FileSystem.purs      # FileSystem effects (test/example)
│           └── Logging.purs         # Logging effects (test/example)
└── Test/
    └── BDD/
        └── Runner.purs              # BDD test runner

shared/                               # Portable modules (JS + Erlang)
├── Control/
│   └── Monad/
│       └── Program.purs             # Core Program monad (portable)
└── Test/
    └── Support/
        ├── Portable.purs            # Portable test infrastructure
        └── DelayPortable.purs       # Portable delay abstraction

shared-demo/                          # Portable demo app modules
└── Demo/
    ├── Commands.purs                # Command dispatcher
    ├── ParallelTiming.purs          # Parallel delay demo
    ├── ParallelWrite.purs           # Concurrent file I/O demo
    ├── CancelFiber.purs             # Fiber cancellation demo
    ├── ErrorPropagation.purs        # Error handling demo
    └── GatherResults.purs           # Result collection demo
```

### Module Organization

The codebase is organized to support both JavaScript (Aff) and Erlang (Effect) backends:

| Module | Location | Purpose | Backend |
|--------|----------|---------|---------|
| `Control.Monad.Concurrent.Class` | `src/` | Type class + Effect instance | Portable |
| `Control.Monad.Concurrent.Aff` | `src/` | ConcurrentAff newtype | JS only |
| `Control.Monad.Program` | `shared/` | Core Program monad | Portable |
| `Control.Monad.Program.Aff` | `src/` | Aff-specific interpreters | JS only |

### Import Patterns by Backend

**JavaScript (Aff) backend:**
```purescript
-- For MonadConcurrent operations
import Control.Monad.Concurrent.Aff (ConcurrentAff, runConcurrentAff, class MonadConcurrent, fork, join, cancel, parTuple)

-- For Program monad with parallel execution
import Control.Monad.Program.Aff (Program, runParallel, runPure, impossibleVariant)
```

**Erlang (Effect) backend:**
```purescript
-- For MonadConcurrent operations (Effect instance)
import Control.Monad.Concurrent.Class (class MonadConcurrent, fork, join, cancel, parTuple)

-- For Program monad
import Control.Monad.Program (Program, run, runPar, impossibleVariantM)
```

**Writing portable code:**
```purescript
-- Use the MonadConcurrent constraint for portable concurrent code
myPortableComputation :: forall m. MonadConcurrent m => m (Tuple Int Int)
myPortableComputation = parTuple (pure 1) (pure 2)
```

### Core Effects (shipped with library)

- **SafeAff** - Wrap Aff computations with typed error handling (`Either Error a`)
- **SafeEffect** - Wrap Effect computations with typed error handling (`Either Error a`)
- **Reader** - Read-only environment access
- **State** - Mutable state management
- **Writer** - Accumulate monoidal values
- **Parallel** - Helper functions for explicit parallel composition (`par2`, `par3`, `gather`, `parTraverse`)

### Example Effects (for testing/demonstrations)

HTTP, FileSystem, Logging - Demonstrate patterns but not part of core library

## Behavior Specs (BDD Markdown)

Behavior-focused specifications are defined as Markdown features under `test/features/` and are intended to be executed by a BDD Markdown harness.

- Parallel cancellation/propagation: `test/features/parallel-cancellation.feature.md`
- Reader semantics under batching: `test/features/reader-semantics.feature.md`
- State semantics under batching: `test/features/state-semantics.feature.md`
- FileSystem sandboxed ops: `test/features/filesystem.feature.md`
- Applicative law sanity checks: `test/features/applicative-laws.feature.md`

These specs are offline/deterministic and write any artifacts under `out/test/...`.

## Building

This project uses **purs-nix** for reproducible Nix-based builds:

```bash
# Build the library
nix build

# Build the demo
nix build .#demo

# Enter development shell
nix develop
```

## Running on Erlang

This library supports the **Erlang/OTP** backend via [purerl](https://github.com/purerl/purerl), enabling the same `MonadConcurrent` code to run on both JavaScript (via Aff) and Erlang (via native processes).

### Compiling PureScript to Erlang

The project uses purerl to compile PureScript to Erlang source, then erlc to compile to BEAM bytecode:

```bash
# Compile a simple hello-world example to Erlang
nix build .#hello-erl

# Compile the MonadConcurrent test suite to Erlang
nix build .#test-concurrent-erl-output   # Erlang source
nix build .#test-concurrent-erl-beam     # Compiled BEAM files
```

### Running Erlang Tests

```bash
# Run MonadConcurrent portable tests on Erlang backend
nix run .#test-concurrent-erl

# Run the same tests on JavaScript backend (for comparison)
nix run .#test-concurrent-js
```

Both backends should produce identical test results:

```
=== Portable Tests (Erlang/Effect) ===

Running MonadConcurrent portable tests (with timing)...
[PASS] fork >=> join identity for pure values
[PASS] fork >=> join preserves computation results
...
Results: 9/9 tests passed

Running Program portable tests (with timing)...
[PASS] runPure returns pure values
...
Results: 4/4 tests passed

Running Parallel portable tests (with timing)...
[PASS] par2 returns both results
...
Results: 4/4 tests passed

Running Orchestration portable tests (with timing)...
[PASS] orchestrates multiple Programs with different handlers
...
Results: 3/3 tests passed

All tests passed!
```

**Total:** 20 portable tests run on both JavaScript and Erlang backends.

### Verifying Backend Parity

To verify both backends produce identical results:

```bash
# Run the concurrent-parity check (compares JS and Erlang outputs)
nix build .#checks.aarch64-darwin.concurrent-parity  # macOS ARM
nix build .#checks.x86_64-linux.concurrent-parity    # Linux x86_64

# Or run all checks including parity verification
nix flake check
```

### Verifying Parallelism

Both backends include a timing test that verifies parallelism:

**Test:** Two 200ms operations run via `parTuple` should complete in ~200ms (parallel), not ~400ms (sequential).

- **JavaScript (Aff):** Uses `Aff.forkAff` for fiber-based parallelism
- **Erlang (Effect):** Uses native Erlang processes via `spawn_monitor`

The timing threshold is set to 350ms to account for scheduling overhead while still detecting sequential execution.

### Basic Usage Example

```purescript
import Control.Monad.Concurrent.Class (class MonadConcurrent, fork, join, parTuple)

-- This code runs on BOTH JavaScript and Erlang backends
parallelExample :: forall m. MonadConcurrent m => m (Tuple Int Int)
parallelExample = parTuple
  (pure 1)   -- Runs in parallel
  (pure 2)   -- Runs in parallel

-- On JavaScript: interpreted via Aff fibers
-- On Erlang: interpreted via native Erlang processes
```

### Erlang Implementation Details

The Erlang backend uses:
- `erlang:spawn_monitor/1` for forking computations
- ETS tables for result caching (enables multiple joins on the same fiber)
- `erlang:exit/2` for fiber cancellation
- Native Erlang process mailbox for join synchronization

## Tests

This repo uses BDD Markdown feature files for behavior-focused tests (powered by @bifravst/bdd-markdown, packaged via Nix).

- Run all checks (lint, format, build, unit tests, BDD specs):
  - `nix flake check`
- Run the BDD specs interactively:
  - `nix run .#test-playback -- test/features/*.feature.md`
  - The runner is compiled PureScript at `src/Test/BDD/Runner.purs` and is invoked by `test/bdd/steps.mjs`.

### Running BDD Tests (MonadConcurrent Demo App)

The MonadConcurrent abstraction is tested via a BDD approach using Cucumber and a demo CLI app. This enables 100% test portability across JavaScript and Erlang backends by testing only observable behavior (stdout, files, timing, exit codes).

**Run all BDD tests:**

```bash
nix run .#test-bdd-demo
```

**Run tests for a specific backend:**

```bash
# JavaScript backend only
nix run .#test-bdd-demo -- --tags @js

# Erlang backend only
nix run .#test-bdd-demo -- --tags @erl
```

**Run tests for a specific feature:**

```bash
# Parallel timing tests only
nix run .#test-bdd-demo -- --tags @parallel

# Fiber cancellation tests only
nix run .#test-bdd-demo -- --tags @cancel

# Error propagation tests only
nix run .#test-bdd-demo -- --tags @error

# Gather results tests only
nix run .#test-bdd-demo -- --tags @gather
```

**Test coverage:**

The BDD tests verify MonadConcurrent features across both backends:

| Feature | Scenarios | What It Tests |
|---------|-----------|---------------|
| `parallel-execution.feature` | 10 | Parallel delays and concurrent file I/O with timestamps |
| `fiber-cancellation.feature` | 6 | Canceling long-running fibers completes quickly |
| `error-propagation.feature` | 8 | Failed fibers propagate errors correctly |
| `gather-results.feature` | 10 | Collecting results from multiple fibers |
| **Total** | **34** | **Both JavaScript and Erlang backends (17 JS + 17 Erlang)** |

**Directory structure:**

```
test/bdd/
├── cucumber.js           # Cucumber configuration
├── package.json          # Node.js dependencies (Cucumber)
├── features/             # Gherkin feature files
│   ├── parallel-timing.feature
│   ├── parallel-execution.feature
│   ├── fiber-cancellation.feature
│   ├── error-propagation.feature
│   └── gather-results.feature
├── steps/                # Step definitions (JavaScript)
│   └── demo_steps.js     # Given/When/Then implementations
└── support/              # Test helpers
    └── world.js          # Cucumber World class with assertions
```

### Adding New BDD Scenarios

1. **Create or update a feature file** in `test/bdd/features/`:

   ```gherkin
   Feature: My Feature
     As a developer using MonadConcurrent
     I want to verify specific behavior
     So my program works correctly

     @demo @my-tag @js
     Scenario: My scenario (JavaScript)
       Given I have the demo app built for "js"
       When I run the "my-command" command
       Then the command should succeed
       And stdout should contain "expected output"

     @demo @my-tag @erl
     Scenario: My scenario (Erlang)
       Given I have the demo app built for "erl"
       When I run the "my-command" command
       Then the command should succeed
       And stdout should contain "expected output"
   ```

2. **Add demo app commands** if needed:
   - JavaScript: `demo-app/src/Demo/MyCommand.purs` (uses `MonadConcurrent m` constraint)
   - Erlang: `demo-app-erl/src/Demo/MyCommand.purs` (uses concrete `Effect` type)
   - Update `Commands.purs` to dispatch to new command

3. **Add step definitions** if the existing steps are insufficient:
   - Edit `test/bdd/steps/demo_steps.js`
   - Available assertions from World class:
     - `assertContains(stdout, expected)`
     - `assertLessThan(value, threshold, message)`
     - `assertFileExists(path)`
     - `assertTimestampsClose(ts1, ts2, toleranceMs)`
     - `parseElapsedTime(stdout)` - extracts "Elapsed: Xms" from output

4. **Run the new scenarios:**

   ```bash
   nix run .#test-bdd-demo -- --tags @my-tag
   ```

### Demo App Commands

The demo app supports these commands for BDD testing:

| Command | Purpose | Key Observable Behavior |
|---------|---------|------------------------|
| `parallel-timing` | Test parallel delays | Completes in ~200ms, outputs "Result A" and "Result B" |
| `parallel-write <dir>` | Test concurrent file I/O | Creates file1.txt and file2.txt with close timestamps |
| `cancel-fiber` | Test fiber cancellation | Completes quickly (<500ms), outputs "Cancelled: true" |
| `error-propagation` | Test error handling | Outputs "Error captured: true" and error message |
| `gather-results` | Test result collection | Outputs "Values: [10,20,30,40,50]" in ~100ms |

## Elegant Composition Pattern

Just like `purescript-run`, this library achieves elegant effect composition:

```purescript
-- Effect types are row type aliases
type HTTP r = (http :: HttpF | r)

-- Programs compose effects via row polymorphism
demoProgram :: forall r. String -> Program (HTTP r) (Array String)
demoProgram baseUrl = do
  results <- (\u p c -> [u, p, c])
    <$> get (baseUrl <> "/users/1")
    <*> get (baseUrl <> "/posts/1")
    <*> get (baseUrl <> "/comments/1")
  pure results

-- Handlers use Row.Cons to "peel off" effects
runHTTP
  :: forall sym q r a
   . IsSymbol sym
  => Row.Cons sym HttpF q r  -- Key: r = (sym :: HttpF | q)
  => Proxy sym
  -> Program r a              -- Has HTTP effect
  -> Aff (Program q a)        -- HTTP removed!
```

### Key Type-Level Tricks

1. **Row Type Aliases**: `type HTTP r = (http :: HttpF | r)` allows composition
2. **Polymorphic Tail**: The `r` parameter lets effects stack elegantly
3. **Row.Cons Constraint**: Expresses "removing" an effect from the row
4. **Pattern Matching with `on`**: Separates handled effects from others

## Comparison to PureScript Run

| Feature | PureScript Run | This Library |
|---------|----------------|--------------|
| Effect composition | ✓ Row-polymorphic variants | ✓ Row-polymorphic variants |
| Free monad basis | ✓ | ✓ |
| Parallel execution | ✗ Not built-in | ✓ Free applicative batching |
| Handler pattern | ✓ Row.Cons "peeling" | ✓ Row.Cons "peeling" |
| Maturity | Production-ready | Proof of concept |

## Research Background

This implementation is based on:

- **Fraxl** (Haskell): https://github.com/ElvishJerricco/fraxl
- **"Applicative Effects in Free Monads"** by ElvishJerricco
- **Haxl** (Facebook): Original inspiration for applicative batching
- **"Free Applicative Functors"** (arXiv 1403.0749)

## Limitations & Future Work

This is a **proof of concept** demonstrating the core architecture. Production use would require:

1. **Effect Composition** - Better support for composing multiple effect interpreters
2. **Performance** - Optimize O(n²) free applicative operations
3. **MonadEffect/MonadAff** - Proper lifting of base effects

## Key Learnings

1. **Free applicatives make parallelism visible** - The structure exposes independent operations before execution
2. **PureScript's variant system works well** - Row polymorphism provides clean extensibility
3. **Aff's Parallel typeclass integrates seamlessly** - Existing PureScript concurrency primitives map naturally to the pattern
4. **Type safety is preserved** - All effect composition is checked at compile time

## License

MIT

## Acknowledgments

Built as part of exploring algebraic effect systems and free monad/applicative combinations in PureScript.
