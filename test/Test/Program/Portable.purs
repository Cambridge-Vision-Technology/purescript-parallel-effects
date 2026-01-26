-- | Platform-agnostic tests for Control.Monad.Program
-- |
-- | These tests are designed to work with any MonadConcurrent instance,
-- | making them portable across backends (JavaScript/Aff, Erlang/Effect).
-- |
-- | The tests use a simple result reporting mechanism rather than Test.Spec,
-- | since Test.Spec is Aff-specific.
module Test.Program.Portable
  ( TestResult(..)
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
import Control.Monad.Program as Program
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Array as Data.Array
import Data.Functor.Variant as Data.Functor.Variant
import Data.Traversable as Data.Traversable
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Effect.Exception as Effect.Exception
import Effect.Ref as Effect.Ref
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
  Effect.Class.liftEffect (Effect.Console.log "Running Program portable tests...")
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
  Effect.Class.liftEffect (Effect.Console.log "Running Program portable tests (with timing)...")
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
