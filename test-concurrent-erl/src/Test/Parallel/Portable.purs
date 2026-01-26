-- NOTE: This is the Erlang-backend version of Test.Parallel.Portable.
-- The main version is at test/Test/Parallel/Portable.purs
--
-- The files are nearly identical - both test the parallel combinators.
-- This duplication is required because:
-- 1. The main file imports from src/Control/Monad/Program.purs which uses Aff
-- 2. This file imports from test-concurrent-erl/src/Control/Monad/Program.purs
--    which is the Erlang-compatible version without Aff imports
--
-- The purity check confirms both pass identical test results via flake.nix
-- portable-parity check. When modifying tests, update BOTH versions.
--
-- | Platform-agnostic tests for Control.Monad.Program.Parallel
-- |
-- | These tests are designed to work with any MonadConcurrent instance,
-- | making them portable across backends (JavaScript/Aff, Erlang/Effect).
-- |
-- | The tests use a simple result reporting mechanism rather than Test.Spec,
-- | since Test.Spec is Aff-specific.
module Test.Parallel.Portable
  ( module Test.Support.Portable
  , runTests
  , runTestsM
  , runTestsWithTiming
  , runTestsWithTimingM
  , testPar2ReturnsBothResults
  , testPar3ReturnsAllThreeResults
  , testGatherReturnsCorrectResults
  , testGatherTiming
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Control.Monad.Error.Class as Control.Monad.Error.Class
import Control.Monad.Program (impossibleVariantM)
import Control.Monad.Program as Program
import Control.Monad.Program.Parallel as Parallel
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Functor.Variant as Data.Functor.Variant
import Data.Traversable as Data.Traversable
import Data.Tuple as Data.Tuple
import Effect.Class as Effect.Class
import Effect.Exception as Effect.Exception
import Test.Support.DelayPortable (DelayF(..), DELAY, _delay, delay)
import Test.Support.Portable (TestResult(..), assertWithMsg, logResults)
import Test.Support.Portable as Test.Support.Portable

-- | Run all Parallel tests without timing and return results
runTests
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m (Array TestResult)
runTests = do
  results <- Data.Traversable.sequence
    [ testPar2ReturnsBothResults
    , testPar3ReturnsAllThreeResults
    , testGatherReturnsCorrectResults
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
  logResults "Parallel portable tests" results

-- | Test: par2 returns both results
-- |
-- | This test verifies that par2 executes two computations and returns
-- | both results as a tuple.
testPar2ReturnsBothResults
  :: forall m
   . Concurrent.MonadConcurrent m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m TestResult
testPar2ReturnsBothResults = do
  let
    program :: Program.Program () (Data.Tuple.Tuple String Int)
    program = Parallel.par2 (pure "hello") (pure 42)
  result <- Program.runPar impossibleVariantM program
  case result of
    Data.Tuple.Tuple a b ->
      assertWithMsg
        "par2 returns both results"
        ("Expected (\"hello\", 42), got (\"" <> a <> "\", " <> show b <> ")")
        (a == "hello" && b == 42)

-- | Test: par3 returns all three results
-- |
-- | This test verifies that par3 executes three computations and returns
-- | all three results as a nested tuple.
testPar3ReturnsAllThreeResults
  :: forall m
   . Concurrent.MonadConcurrent m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m TestResult
testPar3ReturnsAllThreeResults = do
  let
    program :: Program.Program () (Data.Tuple.Tuple String (Data.Tuple.Tuple Int Boolean))
    program = Parallel.par3 (pure "first") (pure 2) (pure true)
  result <- Program.runPar impossibleVariantM program
  case result of
    Data.Tuple.Tuple a (Data.Tuple.Tuple b c) ->
      assertWithMsg
        "par3 returns all three results"
        ("Expected (\"first\", (2, true)), got (\"" <> a <> "\", (" <> show b <> ", " <> show c <> "))")
        (a == "first" && b == 2 && c == true)

-- | Test: gather returns correct results
-- |
-- | This test verifies that gather executes an array of computations
-- | and returns all results in the correct order.
testGatherReturnsCorrectResults
  :: forall m
   . Concurrent.MonadConcurrent m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => m TestResult
testGatherReturnsCorrectResults = do
  let
    programs :: Array (Program.Program () Int)
    programs = [ pure 1, pure 2, pure 3, pure 4, pure 5 ]

    program :: Program.Program () (Array Int)
    program = Parallel.gather programs
  result <- Program.runPar impossibleVariantM program
  assertWithMsg
    "gather returns correct results"
    ("Expected [1, 2, 3, 4, 5], got " <> show result)
    (result == [ 1, 2, 3, 4, 5 ])

-- | Test: gather timing - runs all computations in parallel
-- |
-- | This test verifies that gather executes computations in parallel
-- | by checking that 3x200ms delays complete in ~200ms (not 600ms).
-- | Parameters:
-- | - delayMs: A function that delays for the given number of milliseconds
-- | - getTimeMs: A function that returns the current time in milliseconds
testGatherTiming
  :: forall m
   . Concurrent.MonadConcurrent m
  => Effect.Class.MonadEffect m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => (Number -> m Unit)
  -> m Number
  -> m TestResult
testGatherTiming delayMsM getTimeMsM = do
  let
    handleDelay :: forall x. Data.Functor.Variant.VariantF (DELAY ()) x -> m x
    handleDelay = Program.on _delay handleDelayF impossibleVariantM
      where
      handleDelayF :: DelayF ~> m
      handleDelayF (Delay ms next) = do
        delayMsM ms
        pure next

    programs :: Array (Program.Program (DELAY ()) Int)
    programs =
      [ delay 200.0 *> pure 1
      , delay 200.0 *> pure 2
      , delay 200.0 *> pure 3
      ]

    program :: Program.Program (DELAY ()) (Array Int)
    program = Parallel.gather programs
  start <- getTimeMsM
  result <- Program.runPar handleDelay program
  end <- getTimeMsM
  let elapsed = end - start
  assertWithMsg
    "gather timing: 3x200ms completes in parallel"
    ("Expected <350ms, got " <> show elapsed <> "ms, results: " <> show result)
    (elapsed < 350.0 && result == [ 1, 2, 3 ])

-- | Run all Parallel tests including timing tests
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
    [ testPar2ReturnsBothResults
    , testPar3ReturnsAllThreeResults
    , testGatherReturnsCorrectResults
    , testGatherTiming delayMs getTimeMs
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
  logResults "Parallel portable tests (with timing)" results
