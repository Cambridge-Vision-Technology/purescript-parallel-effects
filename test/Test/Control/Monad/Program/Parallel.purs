module Test.Control.Monad.Program.Parallel where

import Prelude

import Control.Monad.Program as Control.Monad.Program
import Control.Monad.Program.Aff as Control.Monad.Program.Aff
import Control.Monad.Program.Parallel as Control.Monad.Program.Parallel
import Data.Array as Data.Array
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Time.Duration as Data.Time.Duration
import Data.Tuple as Data.Tuple
import Effect.Class as Effect.Class
import Effect.Now as Effect.Now
import Test.Spec as Test.Spec
import Test.Spec.Assertions as Test.Spec.Assertions
import Test.Support.Delay as Test.Support.Delay

spec :: Test.Spec.Spec Unit
spec = Test.Spec.describe "Control.Monad.Program.Parallel" do
  Test.Spec.describe "par2" do
    Test.Spec.it "runs two computations in parallel" do
      let
        program = Control.Monad.Program.Parallel.par2
          (Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0))
          (Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0))

      start <- Effect.Class.liftEffect Effect.Now.now
      Data.Tuple.Tuple _ _ <- Control.Monad.Program.Aff.runParallel
        (\v -> Control.Monad.Program.on Test.Support.Delay._delay Test.Support.Delay.handleDelay Control.Monad.Program.Aff.impossibleVariant v)
        program
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Parallel execution should take ~200ms (not 400ms)
      total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0)

    Test.Spec.it "returns both results in a Tuple" do
      let
        program = Control.Monad.Program.Parallel.par2
          (pure "first")
          (pure "second")

      Data.Tuple.Tuple first second <- Control.Monad.Program.Aff.runPure program

      first `Test.Spec.Assertions.shouldEqual` "first"
      second `Test.Spec.Assertions.shouldEqual` "second"

  Test.Spec.describe "par3" do
    Test.Spec.it "runs three computations in parallel" do
      let
        program = Control.Monad.Program.Parallel.par3
          (Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0))
          (Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0))
          (Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0))

      start <- Effect.Class.liftEffect Effect.Now.now
      Data.Tuple.Tuple _ (Data.Tuple.Tuple _ _) <- Control.Monad.Program.Aff.runParallel
        (\v -> Control.Monad.Program.on Test.Support.Delay._delay Test.Support.Delay.handleDelay Control.Monad.Program.Aff.impossibleVariant v)
        program
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Parallel execution should take ~200ms (not 600ms)
      total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0)

    Test.Spec.it "returns all three results in nested Tuples" do
      let
        program = Control.Monad.Program.Parallel.par3
          (pure "first")
          (pure "second")
          (pure "third")

      Data.Tuple.Tuple first (Data.Tuple.Tuple second third) <- Control.Monad.Program.Aff.runPure program

      first `Test.Spec.Assertions.shouldEqual` "first"
      second `Test.Spec.Assertions.shouldEqual` "second"
      third `Test.Spec.Assertions.shouldEqual` "third"

  Test.Spec.describe "gather" do
    Test.Spec.it "runs an empty array" do
      let
        program = Control.Monad.Program.Parallel.gather []

      result <- Control.Monad.Program.Aff.runPure program

      result `Test.Spec.Assertions.shouldEqual` ([] :: Array Unit)

    Test.Spec.it "runs a single computation" do
      let
        program = Control.Monad.Program.Parallel.gather [ pure "only" ]

      result <- Control.Monad.Program.Aff.runPure program

      result `Test.Spec.Assertions.shouldEqual` [ "only" ]

    Test.Spec.it "runs multiple computations in parallel" do
      let
        delays =
          [ Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
          , Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
          , Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
          , Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0)
          ]
        program = Control.Monad.Program.Parallel.gather delays

      start <- Effect.Class.liftEffect Effect.Now.now
      _ <- Control.Monad.Program.Aff.runParallel
        (\v -> Control.Monad.Program.on Test.Support.Delay._delay Test.Support.Delay.handleDelay Control.Monad.Program.Aff.impossibleVariant v)
        program
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Parallel execution should take ~200ms (not 800ms)
      total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0)

    Test.Spec.it "preserves order of results" do
      let
        program = Control.Monad.Program.Parallel.gather
          [ pure 1
          , pure 2
          , pure 3
          , pure 4
          ]

      result <- Control.Monad.Program.Aff.runPure program

      result `Test.Spec.Assertions.shouldEqual` [ 1, 2, 3, 4 ]

  Test.Spec.describe "parTraverse" do
    Test.Spec.it "maps empty array" do
      let
        program = Control.Monad.Program.Parallel.parTraverse pure ([] :: Array Int)

      result <- Control.Monad.Program.Aff.runPure program

      result `Test.Spec.Assertions.shouldEqual` []

    Test.Spec.it "maps and executes in parallel" do
      let
        -- Map each number to a delay
        program = Control.Monad.Program.Parallel.parTraverse
          (\_ -> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0))
          [ 1, 2, 3 ]

      start <- Effect.Class.liftEffect Effect.Now.now
      _ <- Control.Monad.Program.Aff.runParallel
        (\v -> Control.Monad.Program.on Test.Support.Delay._delay Test.Support.Delay.handleDelay Control.Monad.Program.Aff.impossibleVariant v)
        program
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Parallel execution should take ~200ms (not 600ms)
      total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0)

    Test.Spec.it "preserves order and transforms values" do
      let
        program = Control.Monad.Program.Parallel.parTraverse
          (\n -> pure (n * 2))
          [ 1, 2, 3, 4 ]

      result <- Control.Monad.Program.Aff.runPure program

      result `Test.Spec.Assertions.shouldEqual` [ 2, 4, 6, 8 ]

  Test.Spec.describe "parTraverse_" do
    Test.Spec.it "executes effects in parallel and discards results" do
      let
        program = Control.Monad.Program.Parallel.parTraverse_
          (\_ -> Test.Support.Delay.delay (Data.Time.Duration.Milliseconds 200.0))
          [ 1, 2, 3 ]

      start <- Effect.Class.liftEffect Effect.Now.now
      _ <- Control.Monad.Program.Aff.runParallel
        (\v -> Control.Monad.Program.on Test.Support.Delay._delay Test.Support.Delay.handleDelay Control.Monad.Program.Aff.impossibleVariant v)
        program
      end <- Effect.Class.liftEffect Effect.Now.now

      let
        Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
        total = msEnd - msStart

      -- Parallel execution should take ~200ms (not 600ms)
      total `Test.Spec.Assertions.shouldSatisfy` (_ < 350.0)

    Test.Spec.it "returns unit" do
      let
        program = Control.Monad.Program.Parallel.parTraverse_
          (\n -> pure (n * 2))
          [ 1, 2, 3 ]

      result <- Control.Monad.Program.Aff.runPure program

      result `Test.Spec.Assertions.shouldEqual` unit
