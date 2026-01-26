-- | Platform-agnostic tests for Control.Monad.Program.Parallel
-- |
-- | These tests are designed to work with any MonadConcurrent instance,
-- | making them portable across backends (JavaScript/Aff, Erlang/Effect).
-- |
-- | The tests use a simple result reporting mechanism rather than Test.Spec,
-- | since Test.Spec is Aff-specific.
module Test.Parallel.Portable
  ( TestResult(..)
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
import Control.Monad.Program as Program
import Control.Monad.Program.Parallel as Parallel
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Array as Data.Array
import Data.Functor.Variant as Data.Functor.Variant
import Data.Traversable as Data.Traversable
import Data.Tuple as Data.Tuple
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Effect.Exception as Effect.Exception
import Type.Proxy as Type.Proxy
import Unsafe.Coerce as Unsafe.Coerce

-- | Result of a single test case
data TestResult
  = Pass String
  | Fail String String

derive instance Eq TestResult

instance Show TestResult where
  show (Pass name) = "[PASS] " <> name
  show (Fail name msg) = "[FAIL] " <> name <> ": " <> msg

assert :: forall m. Applicative m => String -> Boolean -> m TestResult
assert name condition =
  pure
    if condition then Pass name
    else Fail name "Assertion failed"

assertWithMsg :: forall m. Applicative m => String -> String -> Boolean -> m TestResult
assertWithMsg name msg condition =
  pure
    if condition then Pass name
    else Fail name msg

-- | A simple delay effect for testing
data DelayF a = Delay Number a

derive instance Functor DelayF

type DELAY r = (delay :: DelayF | r)

_delay :: Type.Proxy.Proxy "delay"
_delay = Type.Proxy.Proxy

delay :: forall r. Number -> Program.Program (DELAY r) Unit
delay ms = Program.lift _delay (Delay ms unit)

impossibleVariantM :: forall m x. Data.Functor.Variant.VariantF () x -> m x
impossibleVariantM = Unsafe.Coerce.unsafeCoerce

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
  Effect.Class.liftEffect (Effect.Console.log "Running Parallel portable tests...")
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
  Effect.Class.liftEffect (Effect.Console.log "Running Parallel portable tests (with timing)...")
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
