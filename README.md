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

## Project Structure

```
src/
├── Control/
│   └── Monad/
│       ├── BatchRun.purs           # Core types and interpreter
│       └── BatchRun/
│           ├── HTTP.purs            # HTTP effects
│           ├── Reader.purs          # Reader effect
│           └── State.purs           # State effect
├── Demo.purs                        # Demo application
└── Main.purs                        # Library entry point
```

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
3. **Error Handling** - Robust error propagation through parallel batches
4. **MonadEffect/MonadAff** - Proper lifting of base effects
5. **Testing** - Comprehensive test suite with actual parallel execution verification

## Key Learnings

1. **Free applicatives make parallelism visible** - The structure exposes independent operations before execution
2. **PureScript's variant system works well** - Row polymorphism provides clean extensibility
3. **Aff's Parallel typeclass integrates seamlessly** - Existing PureScript concurrency primitives map naturally to the pattern
4. **Type safety is preserved** - All effect composition is checked at compile time

## License

MIT

## Acknowledgments

Built as part of exploring algebraic effect systems and free monad/applicative combinations in PureScript.
