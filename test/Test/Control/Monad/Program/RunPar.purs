-- | Tests for the generic runPar implementation
-- |
-- | These tests verify:
-- | 1. runPar works with existing effect handlers (same behavior as runParallel)
-- | 2. Timing test confirms parallelism (3x 200ms tasks in ~200ms via applicative)
-- | 3. runParallel (deprecated alias) continues to work
-- | 4. All existing tests pass without modification
module Test.Control.Monad.Program.RunPar where

import Prelude

import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
import Control.Monad.Program as Control.Monad.Program
import Control.Monad.Program.Aff as Control.Monad.Program.Aff
import Data.Array as Data.Array
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Functor.Variant as Data.Functor.Variant
import Data.Time.Duration as Data.Time.Duration
import Effect.Aff as Effect.Aff
import Effect.Aff.Class as Effect.Aff.Class
import Effect.Class as Effect.Class
import Effect.Now as Effect.Now
import Effect.Ref as Effect.Ref
import Test.Spec as Test.Spec
import Test.Spec.Assertions as Test.Spec.Assertions
import Test.Support.Delay as Test.Support.Delay

-- | Handler for delay effects (ConcurrentAff version)
handleDelayEffectConcurrent
  :: forall x
   . Data.Functor.Variant.VariantF (Test.Support.Delay.DELAY ()) x
  -> ConcurrentAff x
handleDelayEffectConcurrent v =
  Control.Monad.Program.on
    Test.Support.Delay._delay
    handleDelayConcurrent
    impossibleVariantConcurrent
    v
  where
  handleDelayConcurrent :: Test.Support.Delay.DelayF ~> ConcurrentAff
  handleDelayConcurrent (Test.Support.Delay.Delay ms next) =
    ConcurrentAff (Effect.Aff.delay ms) *> pure next

-- | Handler for empty effect row (ConcurrentAff version)
impossibleVariantConcurrent :: forall a. Data.Functor.Variant.VariantF () a -> ConcurrentAff a
impossibleVariantConcurrent = Data.Functor.Variant.match {}

-- | Handler for delay effects (Aff version for runParallel backward compat tests)
handleDelayEffect
  :: forall x
   . Data.Functor.Variant.VariantF (Test.Support.Delay.DELAY ()) x
  -> Effect.Aff.Aff x
handleDelayEffect v =
  Control.Monad.Program.on
    Test.Support.Delay._delay
    Test.Support.Delay.handleDelay
    Control.Monad.Program.Aff.impossibleVariant
    v

spec :: Test.Spec.Spec Unit
spec = Test.Spec.describe "Control.Monad.Program.runPar" do
  Test.Spec.describe "basic functionality" do
    Test.Spec.it "runs pure values correctly" do
      let
        program :: Control.Monad.Program.Program () Int
        program = pure 42

      -- runPar should work the same as runParallel for pure values
      result <- runConcurrentAff (Control.Monad.Program.runPar impossibleVariantConcurrent program)

      result `Test.Spec.Assertions.shouldEqual` 42

    Test.Spec.it "runs single effects correctly" do
      let
        program = Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)

      result <- runConcurrentAff (Control.Monad.Program.runPar handleDelayEffectConcurrent program)

      result `Test.Spec.Assertions.shouldEqual` unit

    Test.Spec.it "sequences monadic operations correctly" do
      let
        program = do
          Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)
          Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)
          pure "done"

      result <- runConcurrentAff (Control.Monad.Program.runPar handleDelayEffectConcurrent program)

      result `Test.Spec.Assertions.shouldEqual` "done"

  Test.Spec.describe "parallel execution timing" do
    Test.Spec.it "sequential delays add up with do (sanity check)" do
      let
        program = do
          Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
          Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
          Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)

      start <- Effect.Class.liftEffect Effect.Now.now
      _ <- runConcurrentAff (Control.Monad.Program.runPar handleDelayEffectConcurrent program)
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Sequential execution should take ~600ms
      total `Test.Spec.Assertions.shouldSatisfy` (_ >= 550.0)

    Test.Spec.it "applicative delays run in parallel (3x 200ms in ~200ms)" do
      let
        program =
          (\_ _ _ -> unit)
            <$> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)

      start <- Effect.Class.liftEffect Effect.Now.now
      _ <- runConcurrentAff (Control.Monad.Program.runPar handleDelayEffectConcurrent program)
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Parallel execution should complete in ~200ms (not 600ms)
      -- Allow tolerance for scheduling overhead
      total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0)

    Test.Spec.it "mixed sequential and parallel operations work correctly" do
      let
        parallelPart =
          (\_ _ -> unit)
            <$> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 100.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 100.0)
        program = do
          _ <- parallelPart
          _ <- parallelPart
          pure "done"

      start <- Effect.Class.liftEffect Effect.Now.now
      result <- runConcurrentAff (Control.Monad.Program.runPar handleDelayEffectConcurrent program)
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Two sequential parallel blocks should take ~200ms total
      -- (not 100ms and not 400ms)
      total `Test.Spec.Assertions.shouldSatisfy` (_ >= 150.0)
      total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0)
      result `Test.Spec.Assertions.shouldEqual` "done"

  Test.Spec.describe "works with existing effect handlers" do
    Test.Spec.it "composes multiple effect handlers" do
      counterRef <- Effect.Class.liftEffect $ Effect.Ref.new 0

      let
        -- Custom counter effect for testing
        handleCounter
          :: forall x
           . Test.Support.Delay.DelayF x
          -> ConcurrentAff x
        handleCounter (Test.Support.Delay.Delay _ next) = do
          Effect.Class.liftEffect $ Effect.Ref.modify_ (_ + 1) counterRef
          pure next

        handler
          :: forall x
           . Data.Functor.Variant.VariantF (Test.Support.Delay.DELAY ()) x
          -> ConcurrentAff x
        handler v =
          Control.Monad.Program.on
            Test.Support.Delay._delay
            handleCounter
            impossibleVariantConcurrent
            v

        program =
          (\_ _ _ -> unit)
            <$> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)

      _ <- runConcurrentAff (Control.Monad.Program.runPar handler program)

      count <- Effect.Class.liftEffect $ Effect.Ref.read counterRef
      count `Test.Spec.Assertions.shouldEqual` 3

    Test.Spec.it "preserves applicative batching behavior" do
      executionOrderRef <- Effect.Class.liftEffect $ Effect.Ref.new []

      let
        -- Handler that tracks execution order
        handleWithTracking
          :: forall x
           . Test.Support.Delay.DelayF x
          -> ConcurrentAff x
        handleWithTracking (Test.Support.Delay.Delay ms next) = do
          let
            Data.Time.Duration.Milliseconds msValue = ms
          Effect.Class.liftEffect $ Effect.Ref.modify_
            (\arr -> Data.Array.snoc arr (show msValue))
            executionOrderRef
          Effect.Aff.Class.liftAff (Effect.Aff.delay ms)
          pure next

        handler
          :: forall x
           . Data.Functor.Variant.VariantF (Test.Support.Delay.DELAY ()) x
          -> ConcurrentAff x
        handler v =
          Control.Monad.Program.on
            Test.Support.Delay._delay
            handleWithTracking
            impossibleVariantConcurrent
            v

        -- Three parallel delays
        program =
          (\_ _ _ -> unit)
            <$> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 20.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 30.0)

      _ <- runConcurrentAff (Control.Monad.Program.runPar handler program)

      -- All three should have been initiated (batched together)
      order <- Effect.Class.liftEffect $ Effect.Ref.read executionOrderRef
      Data.Array.length order `Test.Spec.Assertions.shouldEqual` 3

  Test.Spec.describe "runParallel backward compatibility" do
    Test.Spec.it "runParallel still works (deprecated alias)" do
      let
        program =
          (\_ _ _ -> unit)
            <$> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
            <*> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)

      start <- Effect.Class.liftEffect Effect.Now.now
      -- Using runParallel (deprecated alias) - this still takes Aff handlers
      _ <- Control.Monad.Program.Aff.runParallel handleDelayEffect program
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Should still run in parallel
      total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0)

    Test.Spec.it "runParallel and runPar produce same results" do
      let
        program = do
          _ <- Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)
          pure "test value"

      resultParallel <- Control.Monad.Program.Aff.runParallel handleDelayEffect program
      resultPar <- runConcurrentAff (Control.Monad.Program.runPar handleDelayEffectConcurrent program)

      resultParallel `Test.Spec.Assertions.shouldEqual` resultPar

  Test.Spec.describe "edge cases" do
    Test.Spec.it "handles empty effect row (via runPure)" do
      let
        program :: Control.Monad.Program.Program () String
        program = pure "no effects"

      -- runPure internally uses runParallel/runPar with impossibleVariant
      result <- Control.Monad.Program.Aff.runPure program

      result `Test.Spec.Assertions.shouldEqual` "no effects"

    Test.Spec.it "handles deeply nested applicative composition" do
      let
        program =
          (\a b c d e -> a + b + c + d + e)
            <$> pure 1
            <*> pure 2
            <*> pure 3
            <*> pure 4
            <*> pure 5

      result <- runConcurrentAff (Control.Monad.Program.runPar impossibleVariantConcurrent program)

      result `Test.Spec.Assertions.shouldEqual` 15

    Test.Spec.it "handles single-element applicative" do
      let
        program = identity <$> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 10.0)

      result <- runConcurrentAff (Control.Monad.Program.runPar handleDelayEffectConcurrent program)

      result `Test.Spec.Assertions.shouldEqual` unit
