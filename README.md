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

newtype BatchRun r a = BatchRun (Free (BatchF r) a)
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
demoProgram :: forall r. BatchRun (HTTP r) (Array String)
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

The `Control.Monad.BatchRun.Parallel` module provides convenient helpers for explicit parallel composition:

```purescript
import Control.Monad.BatchRun.Parallel

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
  -> BatchRun r a
  -> Aff a
runParallel handler (BatchRun free) =
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

get :: forall r. String -> BatchRun (HTTP r) String
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
import Control.Monad.BatchRun.SafeAff (liftSafeAff, SAFE_AFF)
import Control.Monad.BatchRun.SafeEffect (liftSafeEffect, SAFE_EFFECT)

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

BatchRun has a **custom Apply/Applicative instance** that merges adjacent batches:

```purescript
instance applyBatchRun :: Apply (BatchRun r) where
  apply = apBatch  -- Custom implementation that merges batches

instance applicativeBatchRun :: Applicative (BatchRun r) where
  pure a = BatchRun (pure a)
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
src/
├── Control/
│   └── Monad/
│       ├── BatchRun.purs           # Core types and interpreter
│       ├── Parallel.purs           # Parallel composition helpers
│       └── BatchRun/
│           ├── SafeAff.purs        # Safe Aff with typed errors
│           ├── SafeEffect.purs     # Safe Effect with typed errors
│           ├── Reader.purs         # Reader effect
│           ├── State.purs          # State effect
│           ├── Writer.purs         # Writer effect
│           ├── HTTP.purs           # HTTP effects (test/example)
│           ├── FileSystem.purs     # FileSystem effects (test/example)
│           └── Logging.purs        # Logging effects (test/example)
├── Demo.purs                        # Demo application
└── Main.purs                        # Library entry point
```

**Core Effects (shipped with library):**
- **SafeAff** - Wrap Aff computations with typed error handling (`Either Error a`)
- **SafeEffect** - Wrap Effect computations with typed error handling (`Either Error a`)
- **Reader** - Read-only environment access
- **State** - Mutable state management
- **Writer** - Accumulate monoidal values
- **Parallel** - Helper functions for explicit parallel composition (`par2`, `par3`, `gather`, `parTraverse`)

**Example Effects (for testing/demonstrations):**
- HTTP, FileSystem, Logging - Demonstrate patterns but not part of core library

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

## Tests

This repo uses BDD Markdown feature files for behavior-focused tests (powered by @bifravst/bdd-markdown, packaged via Nix).

- Run all checks (lint, format, build, unit tests, BDD specs):
  - `nix flake check`
- Run the BDD specs interactively:
  - `nix run .#test-playback -- test/features/*.feature.md`
  - The runner is compiled PureScript at `src/Test/BDD/Runner.purs` and is invoked by `test/bdd/steps.mjs`.

## Elegant Composition Pattern

Just like `purescript-run`, this library achieves elegant effect composition:

```purescript
-- Effect types are row type aliases
type HTTP r = (http :: HttpF | r)

-- Programs compose effects via row polymorphism
demoProgram :: forall r. String -> BatchRun (HTTP r) (Array String)
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
  -> BatchRun r a              -- Has HTTP effect
  -> Aff (BatchRun q a)        -- HTTP removed!
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
