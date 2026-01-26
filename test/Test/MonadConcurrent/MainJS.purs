-- | JavaScript/Node.js entry point for portable tests.
-- |
-- | This module runs all portable tests using the ConcurrentAff MonadConcurrent instance,
-- | providing ConcurrentAff-specific delay and timing functions.
-- |
-- | Run with: nix run .#test-concurrent-js
module Test.MonadConcurrent.MainJS
  ( main
  ) where

import Prelude

import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Time.Duration as Data.Time.Duration
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Effect.Now as Effect.Now
import Node.Process as Node.Process
import Test.MonadConcurrent.Portable as MonadConcurrentPortable
import Test.Orchestration.Portable as OrchestrationPortable
import Test.Parallel.Portable as ParallelPortable
import Test.Program.Portable as ProgramPortable

-- | ConcurrentAff-specific delay function for timing tests
delayMs :: Number -> ConcurrentAff Unit
delayMs ms = ConcurrentAff (Effect.Aff.delay (Data.Time.Duration.Milliseconds ms))

-- | ConcurrentAff-specific get time function for timing tests
getTimeMs :: ConcurrentAff Number
getTimeMs = do
  instant <- Effect.Class.liftEffect Effect.Now.now
  let Data.Time.Duration.Milliseconds ms = Data.DateTime.Instant.unInstant instant
  pure ms

-- | Main entry point for JS/ConcurrentAff portable tests.
-- |
-- | Runs all portable tests with timing, outputs results to console,
-- | and exits with appropriate exit code.
main :: Effect.Effect Unit
main = Effect.Aff.launchAff_ do
  Effect.Class.liftEffect (Effect.Console.log "=== Portable Tests (JavaScript/ConcurrentAff) ===")
  Effect.Class.liftEffect (Effect.Console.log "")

  -- Run MonadConcurrent tests
  monadConcurrentPassed <- runConcurrentAff (MonadConcurrentPortable.runTestsWithTimingM delayMs getTimeMs)
  Effect.Class.liftEffect (Effect.Console.log "")

  -- Run Program tests
  programPassed <- runConcurrentAff (ProgramPortable.runTestsWithTimingM delayMs getTimeMs)
  Effect.Class.liftEffect (Effect.Console.log "")

  -- Run Parallel tests
  parallelPassed <- runConcurrentAff (ParallelPortable.runTestsWithTimingM delayMs getTimeMs)
  Effect.Class.liftEffect (Effect.Console.log "")

  -- Run Orchestration tests
  orchestrationPassed <- runConcurrentAff (OrchestrationPortable.runTestsWithTimingM delayMs getTimeMs)
  Effect.Class.liftEffect (Effect.Console.log "")

  let allPassed = monadConcurrentPassed && programPassed && parallelPassed && orchestrationPassed
  Effect.Class.liftEffect do
    if allPassed then do
      Effect.Console.log "All tests passed!"
    else do
      Effect.Console.log "Some tests failed!"
      Node.Process.setExitCode 1
