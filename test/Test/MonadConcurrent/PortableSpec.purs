-- | Test.Spec wrapper for the portable MonadConcurrent tests
-- |
-- | This module adapts the portable tests to the Test.Spec framework,
-- | running them with the ConcurrentAff MonadConcurrent instance.
module Test.MonadConcurrent.PortableSpec
  ( spec
  ) where

import Prelude

import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Time.Duration as Data.Time.Duration
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Now as Effect.Now
import Test.MonadConcurrent.Portable as Portable
import Test.Spec as Test.Spec
import Test.Spec.Assertions as Test.Spec.Assertions

-- Standalone entry point for JavaScript testing
-- This import ensures the module is compiled even though it's not used here
import Test.MonadConcurrent.MainJS as MainJS

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

-- | Test.Spec suite wrapping the portable MonadConcurrent tests
-- |
-- | This runs the same portable tests using the ConcurrentAff MonadConcurrent instance,
-- | integrated with Test.Spec's test runner and reporting.
spec :: Test.Spec.Spec Unit
spec = Test.Spec.describe "MonadConcurrent Portable Tests" do
  Test.Spec.describe "fork/join identity" do
    Test.Spec.it "fork >=> join identity for pure values" do
      result <- runConcurrentAff Portable.testForkJoinIdentity
      assertResult result

    Test.Spec.it "fork >=> join preserves computation results" do
      result <- runConcurrentAff Portable.testForkJoinPreservesResult
      assertResult result

  Test.Spec.describe "cancel" do
    Test.Spec.it "cancel terminates long-running computation" do
      result <- runConcurrentAff Portable.testCancelTerminates
      assertResult result

  Test.Spec.describe "parTuple" do
    Test.Spec.it "parTuple returns both results" do
      result <- runConcurrentAff Portable.testParTupleReturnsResults
      assertResult result

    Test.Spec.it "parTuple timing: 2x200ms completes in parallel (<350ms)" do
      result <- runConcurrentAff (Portable.testParTupleTiming delayMs getTimeMs)
      assertResult result

  Test.Spec.describe "parTraverseM" do
    Test.Spec.it "parTraverseM preserves order" do
      result <- runConcurrentAff Portable.testParTraverseMPreservesOrder
      assertResult result

  Test.Spec.describe "multiple joins" do
    Test.Spec.it "multiple joins return consistent results" do
      result <- runConcurrentAff Portable.testMultipleJoins
      assertResult result
