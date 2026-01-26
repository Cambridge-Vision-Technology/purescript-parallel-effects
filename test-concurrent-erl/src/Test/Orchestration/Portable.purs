-- NOTE: This is the Erlang-backend version of Test.Orchestration.Portable.
-- The main version is at test/Test/Orchestration/Portable.purs
--
-- The files are functionally identical - both test orchestration patterns.
-- This duplication is required because:
-- 1. The main file imports Control.Monad.Program which imports Effect.Aff
-- 2. The purerl package set does not include purescript-aff (Aff is JS-only)
-- 3. Purerl cannot compile any file that transitively imports Effect.Aff
--
-- This file imports from the local Erlang-compatible versions of:
-- - Control.Monad.Program (test-concurrent-erl/src/Control/Monad/Program.purs)
-- - Test.Support.Portable (test-concurrent-erl/src/Test/Support/Portable.purs)
-- - Test.Support.DelayPortable (test-concurrent-erl/src/Test/Support/DelayPortable.purs)
--
-- When modifying the test logic, update BOTH versions to keep them in sync.
-- The parity checks in flake.nix verify that both backends produce identical results.
module Test.Orchestration.Portable
  ( module Test.Support.Portable
  , runTests
  , runTestsM
  , runTestsWithTiming
  , runTestsWithTimingM
  , testOrchestratesMultipleProgramsWithDifferentHandlers
  , testSelectiveFiberCancellation
  , testSelectiveFiberCancellationTiming
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Control.Monad.Error.Class as Control.Monad.Error.Class
import Control.Monad.Program (impossibleVariantM)
import Control.Monad.Program as Program
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Traversable as Data.Traversable
import Effect.Class as Effect.Class
import Effect.Exception as Effect.Exception
import Test.Support.DelayPortable (DelayF(..), DELAY, _delay, delay)
import Test.Support.Portable (TestResult(..), assertWithMsg, logResults)
import Test.Support.Portable as Test.Support.Portable

-- | Run all Orchestration tests without timing and return results
runTests
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m (Array TestResult)
runTests = do
  results <- Data.Traversable.sequence
    [ testOrchestratesMultipleProgramsWithDifferentHandlers
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
  logResults "Orchestration portable tests" results

-- | Test: orchestrates multiple Programs with different handlers
-- |
-- | This test demonstrates the orchestration layer coordinating
-- | multiple independent Program executions with different effect handlers.
-- | One Program uses a delay effect handler, another uses an empty handler.
testOrchestratesMultipleProgramsWithDifferentHandlers
  :: forall m
   . Concurrent.MonadConcurrent m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m TestResult
testOrchestratesMultipleProgramsWithDifferentHandlers = do
  let
    programWithDelay :: Program.Program (DELAY ()) Int
    programWithDelay = do
      delay 1.0
      pure 100

    pureProgram :: Program.Program () Int
    pureProgram = pure 200

    handleDelayNoOp :: forall x. Data.Functor.Variant.VariantF (DELAY ()) x -> m x
    handleDelayNoOp = Program.on _delay handleDelayF impossibleVariantM
      where
      handleDelayF :: DelayF ~> m
      handleDelayF (Delay _ next) = pure next

  fiber1 <- Concurrent.fork (Program.runPar handleDelayNoOp programWithDelay)
  fiber2 <- Concurrent.fork (Program.runPar impossibleVariantM pureProgram)

  result1 <- Concurrent.join fiber1
  result2 <- Concurrent.join fiber2

  case result1, result2 of
    Data.Either.Right a, Data.Either.Right b ->
      assertWithMsg
        "orchestrates multiple Programs with different handlers"
        ("Expected sum 300, got " <> show a <> " + " <> show b <> " = " <> show (a + b))
        (a + b == 300)
    Data.Either.Left err, _ ->
      pure (Fail "orchestrates multiple Programs with different handlers" ("First fiber failed: " <> Effect.Exception.message err))
    _, Data.Either.Left err ->
      pure (Fail "orchestrates multiple Programs with different handlers" ("Second fiber failed: " <> Effect.Exception.message err))

-- | Test: selective fiber cancellation works (non-timing version)
-- |
-- | This test verifies that cancelling one fiber does not affect others.
-- | Three fibers are started, the middle one is cancelled, and the other
-- | two should complete successfully.
-- |
-- | NOTE: This test verifies the broader property that cancel does not affect
-- | other fibers. Fiber 2 may complete before cancel reaches it (race condition
-- | with pure programs). The primary assertion is that fiber 1 and fiber 3
-- | succeed regardless of fiber 2's final state.
testSelectiveFiberCancellation
  :: forall m
   . Concurrent.MonadConcurrent m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m TestResult
testSelectiveFiberCancellation = do
  let
    makeProgram :: Int -> Program.Program () Int
    makeProgram n = pure n

  fiber1 <- Concurrent.fork (Program.runPar impossibleVariantM (makeProgram 1))
  fiber2 <- Concurrent.fork (Program.runPar impossibleVariantM (makeProgram 2))
  fiber3 <- Concurrent.fork (Program.runPar impossibleVariantM (makeProgram 3))

  Concurrent.cancel fiber2

  result1 <- Concurrent.join fiber1
  _ <- Concurrent.join fiber2
  result3 <- Concurrent.join fiber3

  case result1, result3 of
    Data.Either.Right v1, Data.Either.Right v3 ->
      assertWithMsg
        "selective fiber cancellation works"
        ("Expected fiber1=1, fiber3=3, got fiber1=" <> show v1 <> ", fiber3=" <> show v3)
        (v1 == 1 && v3 == 3)
    Data.Either.Left err, _ ->
      pure (Fail "selective fiber cancellation" ("Fiber 1 failed: " <> Effect.Exception.message err))
    _, Data.Either.Left err ->
      pure (Fail "selective fiber cancellation" ("Fiber 3 failed: " <> Effect.Exception.message err))

-- | Test: selective fiber cancellation with timing
-- |
-- | This test verifies cancellation with actual delays, ensuring that
-- | cancelled fibers are terminated and other fibers complete successfully.
-- | Parameters:
-- | - delayMs: A function that delays for the given number of milliseconds
-- | - getTimeMs: A function that returns the current time in milliseconds
testSelectiveFiberCancellationTiming
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => (Number -> m Unit)
  -> m Number
  -> m TestResult
testSelectiveFiberCancellationTiming delayMsM getTimeMsM = do
  let
    handleDelay :: forall x. Data.Functor.Variant.VariantF (DELAY ()) x -> m x
    handleDelay = Program.on _delay handleDelayF impossibleVariantM
      where
      handleDelayF :: DelayF ~> m
      handleDelayF (Delay ms next) = do
        delayMsM ms
        pure next

    makeProgram :: Int -> Program.Program (DELAY ()) Int
    makeProgram n = do
      delay 100.0
      pure n

    longRunningProgram :: Program.Program (DELAY ()) Int
    longRunningProgram = do
      delay 5000.0
      pure 999

  start <- getTimeMsM

  fiber1 <- Concurrent.fork (Program.runPar handleDelay (makeProgram 1))
  fiberToCancel <- Concurrent.fork (Program.runPar handleDelay longRunningProgram)
  fiber3 <- Concurrent.fork (Program.runPar handleDelay (makeProgram 3))

  Concurrent.cancel fiberToCancel

  result1 <- Concurrent.join fiber1
  _ <- Concurrent.join fiberToCancel
  result3 <- Concurrent.join fiber3

  end <- getTimeMsM
  let elapsed = end - start

  case result1, result3 of
    Data.Either.Right v1, Data.Either.Right v3 ->
      assertWithMsg
        "selective fiber cancellation timing"
        ( "Expected <500ms and fiber1=1, fiber3=3, got "
            <> show elapsed
            <> "ms, fiber1="
            <> show v1
            <> ", fiber3="
            <> show v3
        )
        (elapsed < 500.0 && v1 == 1 && v3 == 3)
    Data.Either.Left err, _ ->
      pure (Fail "selective fiber cancellation timing" ("Fiber 1 failed: " <> Effect.Exception.message err))
    _, Data.Either.Left err ->
      pure (Fail "selective fiber cancellation timing" ("Fiber 3 failed: " <> Effect.Exception.message err))

-- | Run all Orchestration tests including timing tests
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
    [ testOrchestratesMultipleProgramsWithDifferentHandlers
    , testSelectiveFiberCancellation
    , testSelectiveFiberCancellationTiming delayMs getTimeMs
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
  logResults "Orchestration portable tests (with timing)" results
