-- | Tests for MonadConcurrent ConcurrentAff instance
-- |
-- | These tests verify the behavior of the MonadConcurrent type class
-- | when instantiated for ConcurrentAff (the Aff-based implementation).
module Test.Control.Monad.Concurrent where

import Prelude

import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
import Control.Monad.Concurrent.Aff as Concurrent
import Data.Array as Data.Array
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Either as Data.Either
import Data.Int as Data.Int
import Data.Time.Duration as Data.Time.Duration
import Data.Tuple as Data.Tuple
import Effect.Aff as Effect.Aff
import Effect.Aff.Class as Effect.Aff.Class
import Effect.Class as Effect.Class
import Effect.Now as Effect.Now
import Test.Spec as Test.Spec
import Test.Spec.Assertions as Test.Spec.Assertions

spec :: Test.Spec.Spec Unit
spec = Test.Spec.describe "Control.Monad.Concurrent" do
  Test.Spec.describe "MonadConcurrent ConcurrentAff" do
    Test.Spec.describe "fork/join law" do
      Test.Spec.it "fork >=> join should be identity for pure values" do
        runConcurrentAff do
          let
            value = 42
            computation = pure value :: ConcurrentAff Int

          fiber <- Concurrent.fork computation
          result <- Concurrent.join fiber

          case result of
            Data.Either.Right actual ->
              Effect.Aff.Class.liftAff (actual `Test.Spec.Assertions.shouldEqual` value)
            Data.Either.Left err ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail ("Expected Right " <> show value <> ", got Left: " <> show err))

      Test.Spec.it "fork >=> join should preserve computation results" do
        runConcurrentAff do
          let
            computation = ConcurrentAff do
              Effect.Aff.delay (Data.Time.Duration.Milliseconds 50.0)
              pure "hello"

          fiber <- Concurrent.fork computation
          result <- Concurrent.join fiber

          case result of
            Data.Either.Right actual ->
              Effect.Aff.Class.liftAff (actual `Test.Spec.Assertions.shouldEqual` "hello")
            Data.Either.Left err ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail ("Expected Right \"hello\", got Left: " <> show err))

      Test.Spec.it "fork >=> join should preserve complex computation results" do
        runConcurrentAff do
          let
            computation = ConcurrentAff do
              x <- pure 10
              y <- pure 20
              Effect.Aff.delay (Data.Time.Duration.Milliseconds 10.0)
              pure (x + y)

          fiber <- Concurrent.fork computation
          result <- Concurrent.join fiber

          case result of
            Data.Either.Right actual ->
              Effect.Aff.Class.liftAff (actual `Test.Spec.Assertions.shouldEqual` 30)
            Data.Either.Left err ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail ("Expected Right 30, got Left: " <> show err))

    Test.Spec.describe "cancel" do
      Test.Spec.it "cancel terminates a computation" do
        runConcurrentAff do
          fiber <- Concurrent.fork
            ( ConcurrentAff do
                Effect.Aff.delay (Data.Time.Duration.Milliseconds 5000.0)
                pure "should not complete"
            )

          Concurrent.cancel fiber

          result <- Concurrent.join fiber

          case result of
            Data.Either.Left _ ->
              pure unit
            Data.Either.Right _ ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail "Expected cancelled fiber to return an error")

      Test.Spec.it "cancel allows other fibers to continue" do
        runConcurrentAff do
          fiberToCancel <- Concurrent.fork
            ( ConcurrentAff do
                Effect.Aff.delay (Data.Time.Duration.Milliseconds 5000.0)
                pure "cancelled"
            )

          fiberToComplete <- Concurrent.fork
            ( ConcurrentAff do
                Effect.Aff.delay (Data.Time.Duration.Milliseconds 50.0)
                pure "completed"
            )

          Concurrent.cancel fiberToCancel

          result <- Concurrent.join fiberToComplete

          case result of
            Data.Either.Right actual ->
              Effect.Aff.Class.liftAff (actual `Test.Spec.Assertions.shouldEqual` "completed")
            Data.Either.Left err ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail ("Expected Right \"completed\", got Left: " <> show err))

    Test.Spec.describe "parTuple" do
      Test.Spec.it "runs two computations in parallel (timing test)" do
        runConcurrentAff do
          let
            slowComputation = ConcurrentAff do
              Effect.Aff.delay (Data.Time.Duration.Milliseconds 200.0)
              pure unit

          start <- Effect.Class.liftEffect Effect.Now.now
          result <- Concurrent.parTuple slowComputation slowComputation
          end <- Effect.Class.liftEffect Effect.Now.now

          let
            Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
            Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
            total = msEnd - msStart

          Effect.Aff.Class.liftAff (total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0))

          case result of
            Data.Either.Right (Data.Tuple.Tuple _ _) -> pure unit
            Data.Either.Left err ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail ("parTuple failed: " <> show err))

      Test.Spec.it "returns both results as a tuple" do
        runConcurrentAff do
          let
            computationA = pure "first" :: ConcurrentAff String
            computationB = pure "second" :: ConcurrentAff String

          result <- Concurrent.parTuple computationA computationB

          case result of
            Data.Either.Right (Data.Tuple.Tuple a b) -> do
              Effect.Aff.Class.liftAff (a `Test.Spec.Assertions.shouldEqual` "first")
              Effect.Aff.Class.liftAff (b `Test.Spec.Assertions.shouldEqual` "second")
            Data.Either.Left err ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail ("Expected tuple, got Left: " <> show err))

      Test.Spec.it "returns Left when first computation fails" do
        runConcurrentAff do
          let
            failingComputation = ConcurrentAff (Effect.Aff.throwError (Effect.Aff.error "first failed"))
            successComputation = pure "success" :: ConcurrentAff String

          result <- Concurrent.parTuple failingComputation successComputation

          case result of
            Data.Either.Left _ -> pure unit
            Data.Either.Right _ ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail "Expected parTuple to return Left when first computation fails")

      Test.Spec.it "returns Left when second computation fails" do
        runConcurrentAff do
          let
            successComputation = pure "success" :: ConcurrentAff String
            failingComputation = ConcurrentAff (Effect.Aff.throwError (Effect.Aff.error "second failed"))

          result <- Concurrent.parTuple successComputation failingComputation

          case result of
            Data.Either.Left _ -> pure unit
            Data.Either.Right _ ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail "Expected parTuple to return Left when second computation fails")

    Test.Spec.describe "parTraverseM" do
      Test.Spec.it "runs all computations in parallel (timing test)" do
        runConcurrentAff do
          let
            delays =
              [ Data.Time.Duration.Milliseconds 200.0
              , Data.Time.Duration.Milliseconds 200.0
              , Data.Time.Duration.Milliseconds 200.0
              ]
            computation ms = ConcurrentAff do
              Effect.Aff.delay ms
              pure unit

          start <- Effect.Class.liftEffect Effect.Now.now
          result <- Concurrent.parTraverseM computation delays
          end <- Effect.Class.liftEffect Effect.Now.now

          let
            Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
            Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
            total = msEnd - msStart

          Effect.Aff.Class.liftAff (total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0))

          case result of
            Data.Either.Right arr ->
              Effect.Aff.Class.liftAff (Data.Array.length arr `Test.Spec.Assertions.shouldEqual` 3)
            Data.Either.Left err ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail ("parTraverseM failed: " <> show err))

      Test.Spec.it "preserves order of results" do
        runConcurrentAff do
          let
            values = [ 1, 2, 3, 4, 5 ]
            computation n = ConcurrentAff do
              Effect.Aff.delay (Data.Time.Duration.Milliseconds (100.0 - Data.Int.toNumber n * 10.0))
              pure (n * 2)

          result <- Concurrent.parTraverseM computation values

          case result of
            Data.Either.Right arr ->
              Effect.Aff.Class.liftAff (arr `Test.Spec.Assertions.shouldEqual` [ 2, 4, 6, 8, 10 ])
            Data.Either.Left err ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail ("Expected results array, got Left: " <> show err))

      Test.Spec.it "returns Left when any computation fails" do
        runConcurrentAff do
          let
            values = [ 1, 2, 3, 4, 5 ]
            computation n =
              if n == 3 then
                ConcurrentAff (Effect.Aff.throwError (Effect.Aff.error "failed at 3"))
              else ConcurrentAff do
                Effect.Aff.delay (Data.Time.Duration.Milliseconds 10.0)
                pure (n * 2)

          result <- Concurrent.parTraverseM computation values

          case result of
            Data.Either.Left _ -> pure unit
            Data.Either.Right _ ->
              Effect.Aff.Class.liftAff (Test.Spec.Assertions.fail "Expected parTraverseM to return Left when a computation fails")
