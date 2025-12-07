# Elegant Effect Composition - Inspired by purescript-run

This document explains how our Program system achieves the same elegant effect composition pattern as `purescript-run`, while adding parallel execution capabilities.

## The Pattern

### 1. Effect Type Aliases

Effects are defined as row type aliases with a polymorphic tail:

```purescript
type HTTP r = (http :: HttpF | r)
type STATE s r = (state :: StateF s | r)
type READER e r = (reader :: ReaderF e | r)
```

The `r` parameter allows effects to compose:
- `HTTP ()` - Just HTTP
- `HTTP (STATE String ())` - HTTP + State
- `HTTP (STATE String (READER Config ()))` - HTTP + State + Reader

### 2. Effect Composition in Program Types

Programs use the polymorphic tail to remain open to additional effects:

```purescript
-- This program only requires HTTP
myProgram :: forall r. String -> Program (HTTP r) String

-- This program requires HTTP and STATE
statefulProgram :: forall r. Program (HTTP (STATE Int r)) String

-- Can be used anywhere that has at least these effects
useProgram :: Program (HTTP (STATE Int (READER Config ()))) String
useProgram = statefulProgram
```

### 3. Handler Pattern with Row.Cons

Handlers use `Row.Cons` to express "row `r` consists of effect `f` at label `sym`, plus remaining effects `q`":

```purescript
runHTTP
  :: forall sym q r a
   . IsSymbol sym
  => Row.Cons sym HttpF q r  -- r = (sym :: HttpF | q)
  => Proxy sym
  -> Program r a              -- Input: has HTTP effect
  -> Aff (Program q a)        -- Output: HTTP removed!
```

**Key insight**: When `r = (http :: HttpF | q)`, handling the HTTP effect gives us `Program q a` where `q` is everything except HTTP.

### 4. Handler Implementation

Handlers follow this pattern:

```purescript
runHTTPAt sym = loop
  where
  handle = on sym Left Right  -- Pattern match on the effect

  loop br = case peel br of    -- Inspect next instruction
    Right a ->                 -- Pure value
      pure $ pure a
    Left (Batch ap) -> do      -- Batch of effects
      batchResult <- sequential $ foldFreeAp interpretOne ap
      loop batchResult

  interpretOne v = case handle v of
    Left httpEff ->            -- Matched HTTP effect
      handleHTTP httpEff >>= (pure <<< pure)
    Right otherEff ->          -- Different effect
      pure $ send otherEff     -- Pass through
```

### 5. Handler Composition

Handlers compose naturally by removing effects one by one:

```purescript
program :: forall r. Program (HTTP (STATE String r)) Int

-- Peel effects off right-to-left
result = program
  # runState ""       -- Removes STATE, returns Aff (Program (HTTP r) (Tuple String Int))
  >>= runHTTP         -- Removes HTTP, returns Aff (Program r (Tuple String Int))
  >>= runPure         -- Requires r ~ (), returns Aff (Tuple String Int)
```

## Core Functions

### `peel` - Inspect the next effect

```purescript
peel :: forall r a. Program r a -> Either (BatchF r (Program r a)) a
```

Returns either:
- `Right a` - Pure value (computation finished)
- `Left (Batch ap)` - Next batch of effects to handle

### `on` - Pattern match on a specific effect

```purescript
on :: forall sym f r1 r2 a b
   . IsSymbol sym
  => Row.Cons sym f r1 r2
  => Proxy sym
  -> (f a -> b)              -- Handler for matched effect
  -> (VariantF r1 a -> b)    -- Handler for others
  -> VariantF r2 a
  -> b
```

If the VariantF contains the effect at `sym`: applies first function
Otherwise: applies second function to variant without that label

### `send` - Pass an effect through unchanged

```purescript
send :: forall r a. VariantF r a -> Program r a
```

Lifts a VariantF back into Program without handling it.

### `runPure` - Execute computation with no effects

```purescript
runPure :: forall a. Program () a -> Aff a
```

Executes a computation with an empty effect row, returning the result in Aff. Only works when all effects have been handled (empty row).

## Type-Level Magic

### Row.Cons - The Key to "Removing" Effects

`Row.Cons sym f q r` is a four-way relation:

Given any three, you can compute the fourth:
- **Given `sym`, `f`, `q`**: Compute `r = (sym :: f | q)`
- **Given `sym`, `f`, `r`**: Compute `q` (everything except the effect!)

This is how handlers "remove" effects:
```purescript
Row.Cons "http" HttpF q r  -- Says: r = (http :: HttpF | q)

-- Handler transforms: Program r a -> Program q a
-- The HTTP effect disappears from the type!
```

### VariantF - Extensible Sum of Functors

```purescript
VariantF :: Row (Type -> Type) -> Type -> Type
```

Think of it as:
```purescript
VariantF (http :: HttpF, state :: StateF String | r) a

-- Can contain:
-- - HttpF a (HTTP effect)
-- - StateF String a (State effect)
-- - Or any effect from r
```

The `on` function lets you pattern match:
- If it's the effect you're handling: extract it
- Otherwise: get a "smaller" variant (without that case)

## Comparison to purescript-run

Our implementation follows the same pattern:

| Aspect | purescript-run | Program |
|--------|----------------|----------|
| Effect definition | `type EFFECT r = (label :: Effect | r)` | ✓ Same |
| Program types | `Run (EFFECT r) a` | `Program (EFFECT r) a` |
| Handler constraints | `Row.Cons sym f q r` | ✓ Same |
| Handler pattern | `peel`, `on`, `send` | ✓ Same |
| Handler composition | Right-to-left removal | ✓ Same |
| **Extra feature** | - | Free applicative batching! |

## The Parallel Execution Addition

While matching purescript-run's composition elegance, we add:

```purescript
-- Sequential (via >>=)
do
  x <- get "/users/1"
  y <- get "/posts/1"  -- Waits for x
  pure [x, y]

-- Parallel (via <*>)
(\x y -> [x, y])
  <$> get "/users/1"
  <*> get "/posts/1"  -- Both execute simultaneously!
```

The free applicative captures the parallel structure at the type level, and our interpreter executes it concurrently using Aff's `Parallel` typeclass.

## Key Takeaways

1. **Row type aliases** create composable effect types
2. **Polymorphic tail `r`** enables open effect composition
3. **Row.Cons** expresses effect presence and removal
4. **Pattern matching with `on`** separates handled from unhandled effects
5. **Handler chaining** removes effects one-by-one, type-safely
6. **Free applicatives** add parallel execution on top of this pattern

This is the best of both worlds: purescript-run's elegant composition + parallel execution!
