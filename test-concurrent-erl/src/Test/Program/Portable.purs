-- NOTE: This is the Erlang-backend version of Test.Program.Portable.
-- The main version is at test/Test/Program/Portable.purs
--
-- The duplication is necessary because:
-- 1. The main file imports Control.Monad.Program from src/
-- 2. That Program module imports Effect.Aff for backward-compatible functions
-- 3. The purerl package set does not include purescript-aff (Aff is JS-only)
-- 4. Purerl cannot compile any file that transitively imports Effect.Aff
--
-- This file imports from the Erlang-specific Control.Monad.Program
-- (in this same project) which does not import Aff.
--
-- Both files share the same test logic and function signatures.
-- When modifying test cases, update BOTH files to keep them in sync.
-- The parity checks in flake.nix verify both backends produce identical results.
--
-- | Platform-agnostic tests for Control.Monad.Program (Erlang version)
-- |
-- | These tests are designed to work with any MonadConcurrent instance,
-- | making them portable across backends (JavaScript/Aff, Erlang/Effect).
module Test.Program.Portable
  ( module Test.Support.Portable
  , runTests
  , runTestsM
  , runTestsWithTiming
  , runTestsWithTimingM
  , testRunPureReturnsValue
  , testApplicativeComposesSingleEffect
  , testApplicativeComposesMultipleEffects
  , testRunParExecutesInParallel
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Control.Monad.Error.Class as Control.Monad.Error.Class
import Control.Monad.Program (impossibleVariantM)
import Control.Monad.Program as Program
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Functor.Variant as Data.Functor.Variant
import Data.Traversable as Data.Traversable
import Effect.Class as Effect.Class
import Effect.Exception as Effect.Exception
import Effect.Ref as Effect.Ref
import Test.Support.DelayPortable (DelayF(..), DELAY, _delay, delay)
import Test.Support.Portable (TestResult(..), assert, assertWithMsg, logResults)
import Test.Support.Portable as Test.Support.Portable

-- | Run all Program tests without timing and return results
runTests
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m (Array TestResult)
runTests = do
  results <- Data.Traversable.sequence
    [ testRunPureReturnsValue
    , testApplicativeComposesSingleEffect
    , testApplicativeComposesMultipleEffects
    ]
  pure results

-- | Run all tests and log results to console, returning whether all passed
runTestsM
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m Boolean
runTestsM = do
  results <- runTests
  logResults "Program portable tests" results

-- | Test: runPure returns pure values with empty effect row
-- |
-- | This test verifies that a Program with no effects can be executed
-- | and returns the expected pure value.
testRunPureReturnsValue
  :: forall m
   . Concurrent.MonadConcurrent m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m TestResult
testRunPureReturnsValue = do
  let
    program :: Program.Program () Int
    program = pure 42
  result <- Program.runPar impossibleVariantM program
  assert "runPure returns pure values" (result == 42)

-- | Test: Program applicative composes a single effect
-- |
-- | This test verifies that a single effect can be lifted into Program
-- | and executed correctly.
testApplicativeComposesSingleEffect
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m TestResult
testApplicativeComposesSingleEffect = do
  counterRef <- Effect.Class.liftEffect (Effect.Ref.new 0)
  let
    handleDelay :: forall x. Data.Functor.Variant.VariantF (DELAY ()) x -> m x
    handleDelay = Program.on _delay handleDelayF impossibleVariantM
      where
      handleDelayF :: DelayF ~> m
      handleDelayF (Delay _ next) = do
        Effect.Class.liftEffect (Effect.Ref.modify_ (_ + 1) counterRef)
        pure next

    program :: Program.Program (DELAY ()) Unit
    program = delay 100.0
  _ <- Program.runPar handleDelay program
  count <- Effect.Class.liftEffect (Effect.Ref.read counterRef)
  assert "Program applicative composes single effect" (count == 1)

-- | Test: Program applicative composes multiple effects
-- |
-- | This test verifies that multiple effects can be composed with *>
-- | and each effect is executed exactly once.
testApplicativeComposesMultipleEffects
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m TestResult
testApplicativeComposesMultipleEffects = do
  counterRef <- Effect.Class.liftEffect (Effect.Ref.new 0)
  let
    handleDelay :: forall x. Data.Functor.Variant.VariantF (DELAY ()) x -> m x
    handleDelay = Program.on _delay handleDelayF impossibleVariantM
      where
      handleDelayF :: DelayF ~> m
      handleDelayF (Delay _ next) = do
        Effect.Class.liftEffect (Effect.Ref.modify_ (_ + 1) counterRef)
        pure next

    program :: Program.Program (DELAY ()) Unit
    program = delay 100.0 *> delay 100.0 *> delay 100.0
  _ <- Program.runPar handleDelay program
  count <- Effect.Class.liftEffect (Effect.Ref.read counterRef)
  assertWithMsg
    "Program applicative composes multiple effects"
    ("Expected 3 effects, got " <> show count)
    (count == 3)

-- | Test: runPar executes applicative branches in parallel
-- |
-- | This test verifies that when effects are composed with `<*>`,
-- | they are executed in parallel (not sequentially).
-- | Parameters:
-- | - delayMs: A function that delays for the given number of milliseconds
-- | - getTimeMs: A function that returns the current time in milliseconds
testRunParExecutesInParallel
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => (Number -> m Unit)
  -> m Number
  -> m TestResult
testRunParExecutesInParallel delayMsM getTimeMsM = do
  let
    handleDelay :: forall x. Data.Functor.Variant.VariantF (DELAY ()) x -> m x
    handleDelay = Program.on _delay handleDelayF impossibleVariantM
      where
      handleDelayF :: DelayF ~> m
      handleDelayF (Delay ms next) = do
        delayMsM ms
        pure next

    program :: Program.Program (DELAY ()) Unit
    program = delay 200.0 *> delay 200.0
  start <- getTimeMsM
  _ <- Program.runPar handleDelay program
  end <- getTimeMsM
  let elapsed = end - start
  assertWithMsg
    "runPar executes applicative branches in parallel"
    ("Expected <350ms for 2x200ms parallel delays, got " <> show elapsed <> "ms")
    (elapsed < 350.0)

-- | Run all Program tests including timing tests
-- |
-- | This version accepts platform-specific delay and timing functions
-- | to enable the timing tests.
runTestsWithTiming
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => (Number -> m Unit)
  -> m Number
  -> m (Array TestResult)
runTestsWithTiming delayMs getTimeMs = do
  results <- Data.Traversable.sequence
    [ testRunPureReturnsValue
    , testApplicativeComposesSingleEffect
    , testApplicativeComposesMultipleEffects
    , testRunParExecutesInParallel delayMs getTimeMs
    ]
  pure results

-- | Run all tests with timing and log results to console
runTestsWithTimingM
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => (Number -> m Unit)
  -> m Number
  -> m Boolean
runTestsWithTimingM delayMs getTimeMs = do
  results <- runTestsWithTiming delayMs getTimeMs
  logResults "Program portable tests (with timing)" results
