-- | Test.Spec wrapper for the portable Orchestration tests
-- |
-- | This module adapts the portable tests to the Test.Spec framework,
-- | running them with the ConcurrentAff MonadConcurrent instance.
module Test.Orchestration.PortableSpec
  ( spec
  ) where

import Prelude

import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Time.Duration as Data.Time.Duration
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Now as Effect.Now
import Test.Orchestration.Portable as Portable
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

-- | Test.Spec suite wrapping the portable Orchestration tests
-- |
-- | This runs the same portable tests using the ConcurrentAff MonadConcurrent instance,
-- | integrated with Test.Spec's test runner and reporting.
spec :: Test.Spec.Spec Unit
spec = Test.Spec.describe "Orchestration Portable Tests" do
  Test.Spec.describe "multiple Programs with different handlers" do
    Test.Spec.it "orchestrates multiple Programs with different handlers" do
      result <- runConcurrentAff Portable.testOrchestratesMultipleProgramsWithDifferentHandlers
      assertResult result

  Test.Spec.describe "selective fiber cancellation" do
    Test.Spec.it "selective fiber cancellation works" do
      result <- runConcurrentAff Portable.testSelectiveFiberCancellation
      assertResult result

    Test.Spec.it "selective fiber cancellation timing (<500ms for cancelled long-running fiber)" do
      result <- runConcurrentAff (Portable.testSelectiveFiberCancellationTiming delayMs getTimeMs)
      assertResult result
