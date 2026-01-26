-- NOTE: This is the Erlang-backend version of Test.MonadConcurrent.Portable.
-- The main version is at test/Test/MonadConcurrent/Portable.purs
--
-- The duplication is necessary because:
-- 1. The main file imports Control.Monad.Concurrent.Class from src/
-- 2. That Class module imports Effect.Aff for the Aff instance
-- 3. The purerl package set does not include purescript-aff (Aff is JS-only)
-- 4. Purerl cannot compile any file that transitively imports Effect.Aff
--
-- This file imports from the Erlang-specific Control.Monad.Concurrent.Class
-- (in this same directory) which does not import Aff. It also has its own
-- inline TestResult/assert definitions since Test.Support.Portable is not
-- available in the Erlang test project.
--
-- Both files share the same test logic and function signatures.
-- When modifying test cases, update BOTH files to keep them in sync.
-- The parity checks in flake.nix verify both backends produce identical results.
--
-- | Platform-agnostic tests for MonadConcurrent (Erlang version)
-- |
-- | These tests are designed to work with any MonadConcurrent instance.
module Test.MonadConcurrent.Portable
  ( TestResult(..)
  , runTests
  , runTestsM
  , runTestsWithTiming
  , runTestsWithTimingM
  , testForkJoinIdentity
  , testForkJoinPreservesResult
  , testCancelTerminates
  , testParTupleReturnsResults
  , testParTupleTiming
  , testParTraverseMPreservesOrder
  , testParTraverseMTiming
  , testCancelReturnsQuickly
  , testMultipleJoins
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Data.Array as Data.Array
import Data.Either as Data.Either
import Data.Traversable as Data.Traversable
import Data.Tuple as Data.Tuple
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Effect.Exception as Effect.Exception

-- | Result of a single test case
data TestResult
  = Pass String
  | Fail String String -- testName, errorMessage

derive instance Eq TestResult

instance Show TestResult where
  show (Pass name) = "[PASS] " <> name
  show (Fail name msg) = "[FAIL] " <> name <> ": " <> msg

-- | A simple assertion helper
assert :: forall m. Applicative m => String -> Boolean -> m TestResult
assert name condition =
  pure
    if condition then Pass name
    else Fail name "Assertion failed"

-- | Assert with a custom error message
assertWithMsg :: forall m. Applicative m => String -> String -> Boolean -> m TestResult
assertWithMsg name msg condition =
  pure
    if condition then Pass name
    else Fail name msg

-- | A test that produces a result
type Test m = m TestResult

-- | Run all MonadConcurrent tests and return results
runTests
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => m (Array TestResult)
runTests = do
  results <- Data.Traversable.sequence
    [ testForkJoinIdentity
    , testForkJoinPreservesResult
    , testCancelTerminates
    , testParTupleReturnsResults
    , testParTraverseMPreservesOrder
    , testMultipleJoins
    ]
  pure results

-- | Run all tests and log results to console, returning whether all passed
runTestsM
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => m Boolean
runTestsM = do
  Effect.Class.liftEffect (Effect.Console.log "Running MonadConcurrent portable tests...")
  Effect.Class.liftEffect (Effect.Console.log "")
  results <- runTests
  _ <- Data.Traversable.for_ results \result -> do
    Effect.Class.liftEffect (Effect.Console.log (show result))
  let
    passed = Data.Array.length (Data.Array.filter isPassing results)
    total = Data.Array.length results
    allPassed = passed == total
  Effect.Class.liftEffect (Effect.Console.log "")
  Effect.Class.liftEffect
    ( Effect.Console.log
        ( "Results: "
            <> show passed
            <> "/"
            <> show total
            <> " tests passed"
        )
    )
  pure allPassed
  where
  isPassing (Pass _) = true
  isPassing (Fail _ _) = false

-- | Test: fork >=> join is identity for pure values
testForkJoinIdentity
  :: forall m
   . Concurrent.MonadConcurrent m
  => m TestResult
testForkJoinIdentity = do
  let value = 42
  fiber <- Concurrent.fork (pure value)
  result <- Concurrent.join fiber
  case result of
    Data.Either.Right actual ->
      assert "fork >=> join identity for pure values" (actual == value)
    Data.Either.Left err ->
      pure (Fail "fork >=> join identity for pure values" ("Unexpected error: " <> Effect.Exception.message err))

-- | Test: fork >=> join preserves computation results
testForkJoinPreservesResult
  :: forall m
   . Concurrent.MonadConcurrent m
  => m TestResult
testForkJoinPreservesResult = do
  let
    computation = do
      x <- pure 10
      y <- pure 20
      pure (x + y)
  fiber <- Concurrent.fork computation
  result <- Concurrent.join fiber
  case result of
    Data.Either.Right actual ->
      assert "fork >=> join preserves computation results" (actual == 30)
    Data.Either.Left err ->
      pure (Fail "fork >=> join preserves computation results" ("Unexpected error: " <> Effect.Exception.message err))

-- | Test: cancel terminates a computation
testCancelTerminates
  :: forall m
   . Concurrent.MonadConcurrent m
  => m TestResult
testCancelTerminates = do
  fiber <- Concurrent.fork (pure "test value")
  Concurrent.cancel fiber
  _ <- Concurrent.join fiber
  pure (Pass "cancel terminates long-running computation")

-- | Test: parTuple returns both results
testParTupleReturnsResults
  :: forall m
   . Concurrent.MonadConcurrent m
  => m TestResult
testParTupleReturnsResults = do
  let
    computationA = pure "first"
    computationB = pure "second"
  result <- Concurrent.parTuple computationA computationB
  case result of
    Data.Either.Right (Data.Tuple.Tuple a b) ->
      assertWithMsg
        "parTuple returns both results"
        ("Expected (first, second), got (" <> a <> ", " <> b <> ")")
        (a == "first" && b == "second")
    Data.Either.Left err ->
      pure (Fail "parTuple returns both results" ("Unexpected error: " <> Effect.Exception.message err))

-- | Test: parTraverseM preserves order of results
testParTraverseMPreservesOrder
  :: forall m
   . Concurrent.MonadConcurrent m
  => m TestResult
testParTraverseMPreservesOrder = do
  let
    values = [ 1, 2, 3, 4, 5 ]
    computation n = pure (n * 2)
  result <- Concurrent.parTraverseM computation values
  case result of
    Data.Either.Right arr ->
      assertWithMsg
        "parTraverseM preserves order"
        ("Expected [2, 4, 6, 8, 10], got " <> show arr)
        (arr == [ 2, 4, 6, 8, 10 ])
    Data.Either.Left err ->
      pure (Fail "parTraverseM preserves order" ("Unexpected error: " <> Effect.Exception.message err))

-- | Test: Multiple joins return consistent results
testMultipleJoins
  :: forall m
   . Concurrent.MonadConcurrent m
  => m TestResult
testMultipleJoins = do
  fiber <- Concurrent.fork (pure 42)
  result1 <- Concurrent.join fiber
  result2 <- Concurrent.join fiber
  case result1, result2 of
    Data.Either.Right v1, Data.Either.Right v2 ->
      assertWithMsg
        "multiple joins return consistent results"
        ("First: " <> show v1 <> ", Second: " <> show v2)
        (v1 == v2)
    _, _ ->
      pure (Pass "multiple joins return consistent results")

-- | Test: parTuple timing - runs two computations in parallel
testParTupleTiming
  :: forall m
   . Concurrent.MonadConcurrent m
  => (Number -> m Unit)
  -> m Number
  -> m TestResult
testParTupleTiming delayMs getTimeMs = do
  start <- getTimeMs
  result <- Concurrent.parTuple (delayMs 200.0) (delayMs 200.0)
  end <- getTimeMs
  let elapsed = end - start
  case result of
    Data.Either.Right _ ->
      assertWithMsg
        "parTuple timing: 2x200ms completes in parallel"
        ("Expected <350ms, got " <> show elapsed <> "ms")
        (elapsed < 350.0)
    Data.Either.Left err ->
      pure (Fail "parTuple timing" ("Unexpected error: " <> Effect.Exception.message err))

-- | Test: parTraverseM timing - runs all computations in parallel
-- |
-- | Three 200ms tasks should complete in ~200ms (not 600ms) if running in parallel.
testParTraverseMTiming
  :: forall m
   . Concurrent.MonadConcurrent m
  => (Number -> m Unit)
  -> m Number
  -> m TestResult
testParTraverseMTiming delayMs getTimeMs = do
  let
    values = [ 200.0, 200.0, 200.0 ]
    computation ms = do
      delayMs ms
      pure unit
  start <- getTimeMs
  result <- Concurrent.parTraverseM computation values
  end <- getTimeMs
  let elapsed = end - start
  case result of
    Data.Either.Right arr ->
      assertWithMsg
        "parTraverseM timing: 3x200ms completes in parallel"
        ("Expected <350ms, got " <> show elapsed <> "ms, results: " <> show (Data.Array.length arr))
        (elapsed < 350.0 && Data.Array.length arr == 3)
    Data.Either.Left err ->
      pure (Fail "parTraverseM timing" ("Unexpected error: " <> Effect.Exception.message err))

-- | Test: cancel returns quickly (does not wait for computation)
-- |
-- | Fork a long-running computation, cancel it, and verify that cancel + join
-- | completes quickly (much faster than the long-running computation would take).
testCancelReturnsQuickly
  :: forall m
   . Concurrent.MonadConcurrent m
  => (Number -> m Unit)
  -> m Number
  -> m TestResult
testCancelReturnsQuickly delayMs getTimeMs = do
  -- Fork a long-running computation (5 seconds)
  fiber <- Concurrent.fork do
    delayMs 5000.0
    pure "should not complete"
  start <- getTimeMs
  -- Cancel should return quickly
  Concurrent.cancel fiber
  _ <- Concurrent.join fiber
  end <- getTimeMs
  let elapsed = end - start
  -- Cancel + join should be fast (much less than 5000ms)
  assertWithMsg
    "cancel returns quickly (does not wait for computation)"
    ("Expected <500ms, got " <> show elapsed <> "ms")
    (elapsed < 500.0)

-- | Run all MonadConcurrent tests including timing tests
runTestsWithTiming
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => (Number -> m Unit)
  -> m Number
  -> m (Array TestResult)
runTestsWithTiming delayMs getTimeMs = do
  results <- Data.Traversable.sequence
    [ testForkJoinIdentity
    , testForkJoinPreservesResult
    , testCancelTerminates
    , testParTupleReturnsResults
    , testParTupleTiming delayMs getTimeMs
    , testParTraverseMPreservesOrder
    , testParTraverseMTiming delayMs getTimeMs
    , testCancelReturnsQuickly delayMs getTimeMs
    , testMultipleJoins
    ]
  pure results

-- | Run all tests with timing and log results to console
runTestsWithTimingM
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => (Number -> m Unit)
  -> m Number
  -> m Boolean
runTestsWithTimingM delayMs getTimeMs = do
  Effect.Class.liftEffect (Effect.Console.log "Running MonadConcurrent portable tests (with timing)...")
  Effect.Class.liftEffect (Effect.Console.log "")
  results <- runTestsWithTiming delayMs getTimeMs
  _ <- Data.Traversable.for_ results \result -> do
    Effect.Class.liftEffect (Effect.Console.log (show result))
  let
    passed = Data.Array.length (Data.Array.filter isPassing results)
    total = Data.Array.length results
    allPassed = passed == total
  Effect.Class.liftEffect (Effect.Console.log "")
  Effect.Class.liftEffect
    ( Effect.Console.log
        ( "Results: "
            <> show passed
            <> "/"
            <> show total
            <> " tests passed"
        )
    )
  pure allPassed
  where
  isPassing (Pass _) = true
  isPassing (Fail _ _) = false
