-- | Erlang/BEAM entry point for portable tests.
-- |
-- | Run with: nix run .#test-concurrent-erl
module Test.MonadConcurrent.Main
  ( main
  ) where

import Prelude

import Control.Monad.Concurrent.Effect (ConcurrentEffect(..), runConcurrentEffect)
import Effect as Effect
import Effect.Console as Effect.Console
import Test.MonadConcurrent.Portable as MonadConcurrentPortable
import Test.Orchestration.Portable as OrchestrationPortable
import Test.Parallel.Portable as ParallelPortable
import Test.Program.Portable as ProgramPortable

-- | ConcurrentEffect-specific delay function for timing tests
delayMs :: Number -> ConcurrentEffect Unit
delayMs ms = ConcurrentEffect (delayMsImpl ms)

foreign import delayMsImpl :: Number -> Effect.Effect Unit

-- | ConcurrentEffect-specific get time function for timing tests
getTimeMs :: ConcurrentEffect Number
getTimeMs = ConcurrentEffect getTimeMsImpl

foreign import getTimeMsImpl :: Effect.Effect Number

-- | Main entry point for Erlang/ConcurrentEffect portable tests.
main :: Effect.Effect Unit
main = do
  Effect.Console.log "=== Portable Tests (Erlang/ConcurrentEffect) ==="
  Effect.Console.log ""

  -- Run MonadConcurrent tests
  monadConcurrentPassed <- runConcurrentEffect (MonadConcurrentPortable.runTestsWithTimingM delayMs getTimeMs)
  Effect.Console.log ""

  -- Run Program tests
  programPassed <- runConcurrentEffect (ProgramPortable.runTestsWithTimingM delayMs getTimeMs)
  Effect.Console.log ""

  -- Run Parallel tests
  parallelPassed <- runConcurrentEffect (ParallelPortable.runTestsWithTimingM delayMs getTimeMs)
  Effect.Console.log ""

  -- Run Orchestration tests
  orchestrationPassed <- runConcurrentEffect (OrchestrationPortable.runTestsWithTimingM delayMs getTimeMs)
  Effect.Console.log ""

  let allPassed = monadConcurrentPassed && programPassed && parallelPassed && orchestrationPassed
  if allPassed then do
    Effect.Console.log "All tests passed!"
  else do
    Effect.Console.log "Some tests failed!"
    erlangHalt 1

-- | FFI to call erlang:halt/1 for non-zero exit codes.
foreign import erlangHalt :: Int -> Effect.Effect Unit
