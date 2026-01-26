-- | Test.Spec wrapper for the portable Parallel tests
-- |
-- | This module adapts the portable tests to the Test.Spec framework,
-- | running them with the ConcurrentAff MonadConcurrent instance.
module Test.Parallel.PortableSpec
  ( spec
  ) where

import Prelude

import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Time.Duration as Data.Time.Duration
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Now as Effect.Now
import Test.Parallel.Portable as Portable
import Test.Spec as Test.Spec
import Test.Spec.Assertions as Test.Spec.Assertions

-- | Convert a TestResult to a Test.Spec assertion
assertResult :: Portable.TestResult -> Effect.Aff.Aff Unit
assertResult (Portable.Pass _) = pure unit
assertResult (Portable.Fail name msg) =
  Test.Spec.Assertions.fail (name <> ": " <> msg)

-- | ConcurrentAff-specific delay function for timing tests
delayMs :: Number -> ConcurrentAff Unit
delayMs ms = ConcurrentAff (Effect.Aff.delay (Data.Time.Duration.Milliseconds ms))

-- | ConcurrentAff-specific get time function for timing tests
getTimeMs :: ConcurrentAff Number
getTimeMs = do
  instant <- Effect.Class.liftEffect Effect.Now.now
  let Data.Time.Duration.Milliseconds ms = Data.DateTime.Instant.unInstant instant
  pure ms

-- | Test.Spec suite wrapping the portable Parallel tests
-- |
-- | This runs the same portable tests using the ConcurrentAff MonadConcurrent instance,
-- | integrated with Test.Spec's test runner and reporting.
spec :: Test.Spec.Spec Unit
spec = Test.Spec.describe "Parallel Portable Tests" do
  Test.Spec.describe "par2" do
    Test.Spec.it "par2 returns both results" do
      result <- runConcurrentAff Portable.testPar2ReturnsBothResults
      assertResult result

  Test.Spec.describe "par3" do
    Test.Spec.it "par3 returns all three results" do
      result <- runConcurrentAff Portable.testPar3ReturnsAllThreeResults
      assertResult result

  Test.Spec.describe "gather" do
    Test.Spec.it "gather returns correct results" do
      result <- runConcurrentAff Portable.testGatherReturnsCorrectResults
      assertResult result

    Test.Spec.it "gather timing: 3x200ms completes in parallel (<350ms)" do
      result <- runConcurrentAff (Portable.testGatherTiming delayMs getTimeMs)
      assertResult result
