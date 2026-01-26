-- | Orchestration layer tests for MonadConcurrent
-- |
-- | These tests demonstrate how an outer coordinator can use MonadConcurrent
-- | directly (not through runPar applicative) to:
-- | - Fork multiple `runPar` invocations as fibers
-- | - Join them to collect results
-- | - Cancel them if needed
-- |
-- | This is the "orchestration layer" pattern where MonadConcurrent primitives
-- | are used explicitly for coarse-grained parallelism between Program computations.
module Test.Orchestration where

import Prelude

import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
import Control.Monad.Concurrent.Aff as Concurrent
import Control.Monad.Program as Control.Monad.Program
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Time.Duration as Data.Time.Duration
import Data.Tuple as Data.Tuple
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Now as Effect.Now
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

  impossibleVariantConcurrent :: forall a. Data.Functor.Variant.VariantF () a -> ConcurrentAff a
  impossibleVariantConcurrent = Data.Functor.Variant.match {}

-- | Handler for empty effect row (ConcurrentAff version)
impossibleVariantConcurrent :: forall a. Data.Functor.Variant.VariantF () a -> ConcurrentAff a
impossibleVariantConcurrent = Data.Functor.Variant.match {}

spec :: Test.Spec.Spec Unit
spec = Test.Spec.describe "Orchestration" do
  Test.Spec.describe "Explicit fork-join at orchestration layer" do
    Test.Spec.it "forks two independent Program computations and joins both" do
      runConcurrentAff do
        -- Two independent Program computations
        let
          programA :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) String
          programA = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 100.0)
            pure "result A"

          programB :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) Int
          programB = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 100.0)
            pure 42

        -- Fork both Program executions as fibers (using MonadConcurrent directly)
        fiberA <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent programA)
        fiberB <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent programB)

        -- Join both to collect results
        resultA <- Concurrent.join fiberA
        resultB <- Concurrent.join fiberB

        -- Verify both results
        case resultA of
          Data.Either.Right a -> a `shouldEqualConcurrent` "result A"
          Data.Either.Left err ->
            failConcurrent ("Expected Right \"result A\", got Left: " <> show err)

        case resultB of
          Data.Either.Right b -> b `shouldEqualConcurrent` 42
          Data.Either.Left err ->
            failConcurrent ("Expected Right 42, got Left: " <> show err)

    Test.Spec.it "forked Programs run in parallel (timing test)" do
      runConcurrentAff do
        -- Two slow Program computations
        let
          slowProgram :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) Unit
          slowProgram = Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)

        start <- Effect.Class.liftEffect Effect.Now.now

        -- Fork both
        fiberA <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent slowProgram)
        fiberB <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent slowProgram)

        -- Join both
        _ <- Concurrent.join fiberA
        _ <- Concurrent.join fiberB

        end <- Effect.Class.liftEffect Effect.Now.now

        let
          Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
          Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
          total = msEnd - msStart

        -- Two 200ms tasks forked in parallel should complete in ~200ms (not 400ms)
        total `shouldSatisfyConcurrent` (_ < 350.0)

    Test.Spec.it "uses parTuple to run two Programs in parallel" do
      runConcurrentAff do
        let
          programA :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) String
          programA = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 100.0)
            pure "first"

          programB :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) String
          programB = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 100.0)
            pure "second"

        start <- Effect.Class.liftEffect Effect.Now.now

        -- Use parTuple to run both Programs in parallel
        result <- Concurrent.parTuple
          (Control.Monad.Program.runPar handleDelayEffectConcurrent programA)
          (Control.Monad.Program.runPar handleDelayEffectConcurrent programB)

        end <- Effect.Class.liftEffect Effect.Now.now

        let
          Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
          Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
          total = msEnd - msStart

        -- Should complete in ~100ms (parallel), not 200ms (sequential)
        total `shouldSatisfyConcurrent` (_ < 200.0)

        -- Verify results
        case result of
          Data.Either.Right (Data.Tuple.Tuple a b) -> do
            a `shouldEqualConcurrent` "first"
            b `shouldEqualConcurrent` "second"
          Data.Either.Left err ->
            failConcurrent ("Expected tuple, got Left: " <> show err)

  Test.Spec.describe "Cancellation terminates computation" do
    Test.Spec.it "cancel terminates a long-running forked Program computation" do
      runConcurrentAff do
        let
          longRunningProgram :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) String
          longRunningProgram = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 5000.0)
            pure "should not complete"

        -- Fork the long-running computation
        fiber <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent longRunningProgram)

        -- Cancel it immediately
        Concurrent.cancel fiber

        -- Joining should return a cancellation error
        result <- Concurrent.join fiber

        case result of
          Data.Either.Left _ ->
            -- Expected: cancelled fiber returns an error
            pure unit
          Data.Either.Right _ ->
            failConcurrent "Expected cancelled fiber to return an error"

    Test.Spec.it "cancel does not affect other fibers" do
      runConcurrentAff do
        let
          longRunningProgram :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) String
          longRunningProgram = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 5000.0)
            pure "should not complete"

          shortProgram :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) String
          shortProgram = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 50.0)
            pure "completed"

        -- Fork both
        fiberToCancel <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent longRunningProgram)
        fiberToComplete <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent shortProgram)

        -- Cancel only the long-running one
        Concurrent.cancel fiberToCancel

        -- The short program should complete successfully
        result <- Concurrent.join fiberToComplete

        case result of
          Data.Either.Right actual -> actual `shouldEqualConcurrent` "completed"
          Data.Either.Left err ->
            failConcurrent ("Expected Right \"completed\", got Left: " <> show err)

    Test.Spec.it "cancel returns quickly (does not wait for computation)" do
      runConcurrentAff do
        let
          longRunningProgram :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) String
          longRunningProgram = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 5000.0)
            pure "should not complete"

        fiber <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent longRunningProgram)

        start <- Effect.Class.liftEffect Effect.Now.now

        -- Cancel should return quickly
        Concurrent.cancel fiber
        _ <- Concurrent.join fiber

        end <- Effect.Class.liftEffect Effect.Now.now

        let
          Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
          Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
          total = msEnd - msStart

        -- Cancel + join should be fast (much less than 5000ms)
        total `shouldSatisfyConcurrent` (_ < 500.0)

  Test.Spec.describe "Complex orchestration patterns" do
    Test.Spec.it "orchestrates multiple Programs with different handlers" do
      runConcurrentAff do
        -- This demonstrates the orchestration layer can coordinate
        -- multiple independent Program executions
        let
          programWithDelay :: Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) Int
          programWithDelay = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 50.0)
            pure 100

          pureProgram :: Control.Monad.Program.Program () Int
          pureProgram = pure 200

        -- Fork both with their respective handlers
        fiber1 <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent programWithDelay)
        fiber2 <- Concurrent.fork (Control.Monad.Program.runPar impossibleVariantConcurrent pureProgram)

        -- Join both
        result1 <- Concurrent.join fiber1
        result2 <- Concurrent.join fiber2

        -- Combine results
        case result1, result2 of
          Data.Either.Right a, Data.Either.Right b ->
            (a + b) `shouldEqualConcurrent` 300
          Data.Either.Left err, _ ->
            failConcurrent ("First fiber failed: " <> show err)
          _, Data.Either.Left err ->
            failConcurrent ("Second fiber failed: " <> show err)

    Test.Spec.it "can selectively cancel some fibers while waiting for others" do
      runConcurrentAff do
        let
          makeProgram :: Int -> Control.Monad.Program.Program (Test.Support.Delay.DELAY ()) Int
          makeProgram n = do
            Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 100.0)
            pure n

        -- Fork three Programs
        fiber1 <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent (makeProgram 1))
        fiber2 <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent (makeProgram 2))
        fiber3 <- Concurrent.fork (Control.Monad.Program.runPar handleDelayEffectConcurrent (makeProgram 3))

        -- Cancel the middle one
        Concurrent.cancel fiber2

        -- Join all three
        result1 <- Concurrent.join fiber1
        result2 <- Concurrent.join fiber2
        result3 <- Concurrent.join fiber3

        -- Verify: fiber1 and fiber3 succeeded, fiber2 was cancelled
        case result1 of
          Data.Either.Right n -> n `shouldEqualConcurrent` 1
          Data.Either.Left err ->
            failConcurrent ("Fiber 1 failed: " <> show err)

        case result2 of
          Data.Either.Left _ -> pure unit -- Expected: cancelled
          Data.Either.Right _ ->
            failConcurrent "Expected fiber 2 to be cancelled"

        case result3 of
          Data.Either.Right n -> n `shouldEqualConcurrent` 3
          Data.Either.Left err ->
            failConcurrent ("Fiber 3 failed: " <> show err)

-- Helper functions to lift Test.Spec.Assertions into ConcurrentAff
shouldEqualConcurrent :: forall a. Eq a => Show a => a -> a -> ConcurrentAff Unit
shouldEqualConcurrent actual expected =
  ConcurrentAff (actual `Test.Spec.Assertions.shouldEqual` expected)

shouldSatisfyConcurrent :: forall a. Show a => a -> (a -> Boolean) -> ConcurrentAff Unit
shouldSatisfyConcurrent actual pred =
  ConcurrentAff (actual `Test.Spec.Assertions.shouldSatisfy` pred)

failConcurrent :: String -> ConcurrentAff Unit
failConcurrent msg = ConcurrentAff (Test.Spec.Assertions.fail msg)
