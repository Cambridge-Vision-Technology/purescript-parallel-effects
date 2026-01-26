module Demo.Commands
  ( Command(..)
  , CommandResult(..)
  , parseCommand
  , runCommand
  , formatResult
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Data.Array as Data.Array
import Data.Either as Data.Either
import Data.Maybe as Data.Maybe
import Demo.CancelFiber as Demo.CancelFiber
import Demo.ErrorPropagation as Demo.ErrorPropagation
import Demo.GatherResults as Demo.GatherResults
import Demo.ParallelTiming as Demo.ParallelTiming
import Demo.ParallelWrite as Demo.ParallelWrite
import Effect.Exception as Effect.Exception

data Command
  = ParallelTiming
  | ParallelWrite String
  | CancelFiber
  | ErrorPropagation
  | GatherResults
  | Help
  | Unknown String

derive instance Eq Command

instance Show Command where
  show ParallelTiming = "parallel-timing"
  show (ParallelWrite dir) = "parallel-write " <> dir
  show CancelFiber = "cancel-fiber"
  show ErrorPropagation = "error-propagation"
  show GatherResults = "gather-results"
  show Help = "help"
  show (Unknown cmd) = "unknown: " <> cmd

data CommandResult
  = TimingResult Demo.ParallelTiming.ParallelTimingResult
  | WriteResult Demo.ParallelWrite.ParallelWriteResult
  | CancelResult Demo.CancelFiber.CancelFiberResult
  | ErrorPropResult Demo.ErrorPropagation.ErrorPropagationResult
  | GatherResult Demo.GatherResults.GatherResultsResult
  | HelpResult String
  | ErrorResult String

parseCommand :: Array String -> Command
parseCommand args = case Data.Array.uncons args of
  Data.Maybe.Just { head: "parallel-timing", tail: _ } ->
    ParallelTiming
  Data.Maybe.Just { head: "parallel-write", tail: rest } ->
    case Data.Array.head rest of
      Data.Maybe.Just dir -> ParallelWrite dir
      Data.Maybe.Nothing -> ParallelWrite "out/demo/parallel-write"
  Data.Maybe.Just { head: "cancel-fiber", tail: _ } ->
    CancelFiber
  Data.Maybe.Just { head: "error-propagation", tail: _ } ->
    ErrorPropagation
  Data.Maybe.Just { head: "gather-results", tail: _ } ->
    GatherResults
  Data.Maybe.Just { head: "help", tail: _ } ->
    Help
  Data.Maybe.Just { head: "--help", tail: _ } ->
    Help
  Data.Maybe.Just { head: "-h", tail: _ } ->
    Help
  Data.Maybe.Just { head: cmd, tail: _ } ->
    Unknown cmd
  Data.Maybe.Nothing ->
    Help

runCommand
  :: forall m
   . Concurrent.MonadConcurrent m
  => (Number -> m Unit)
  -> m Number
  -> Demo.ParallelWrite.FileWriteOp m
  -> (String -> m Unit)
  -> Command
  -> m CommandResult
runCommand delayMs getTimeMs writeFile throwError command = case command of
  ParallelTiming -> do
    result <- Demo.ParallelTiming.runParallelTiming delayMs getTimeMs
    pure case result of
      Data.Either.Right r -> TimingResult r
      Data.Either.Left err -> ErrorResult (Effect.Exception.message err)

  ParallelWrite outputDir -> do
    result <- Demo.ParallelWrite.runParallelWrite writeFile getTimeMs outputDir
    pure case result of
      Data.Either.Right r -> WriteResult r
      Data.Either.Left err -> ErrorResult (Effect.Exception.message err)

  CancelFiber -> do
    result <- Demo.CancelFiber.runCancelFiber delayMs getTimeMs
    pure case result of
      Data.Either.Right r -> CancelResult r
      Data.Either.Left err -> ErrorResult (Effect.Exception.message err)

  ErrorPropagation -> do
    result <- Demo.ErrorPropagation.runErrorPropagation getTimeMs throwError
    pure case result of
      Data.Either.Right r -> ErrorPropResult r
      Data.Either.Left err -> ErrorResult (Effect.Exception.message err)

  GatherResults -> do
    result <- Demo.GatherResults.runGatherResults delayMs getTimeMs
    pure case result of
      Data.Either.Right r -> GatherResult r
      Data.Either.Left err -> ErrorResult (Effect.Exception.message err)

  Help ->
    pure (HelpResult helpText)

  Unknown cmd ->
    pure (ErrorResult ("Unknown command: " <> cmd <> "\n\n" <> helpText))

formatResult :: CommandResult -> String
formatResult result = case result of
  TimingResult r ->
    "Parallel Timing Demo\n"
      <> "====================\n"
      <> "Result A: "
      <> show r.resultA
      <> "\n"
      <> "Result B: "
      <> r.resultB
      <> "\n"
      <> "Elapsed: "
      <> show r.elapsedMs
      <> "ms\n"
      <> "\n"
      <> "Note: Two 200ms delays completed in "
      <> show r.elapsedMs
      <> "ms\n"
      <> "(If parallel: ~200ms, if sequential: ~400ms)"

  WriteResult r ->
    "Parallel Write Demo\n"
      <> "===================\n"
      <> "File 1: "
      <> r.file1Path
      <> "\n"
      <> "File 2: "
      <> r.file2Path
      <> "\n"
      <> "Elapsed: "
      <> show r.elapsedMs
      <> "ms\n"
      <> "\n"
      <> "Both files written concurrently."

  CancelResult r ->
    "Cancel Fiber Demo\n"
      <> "=================\n"
      <> "Cancelled: "
      <> show r.cancelled
      <> "\n"
      <> "Elapsed: "
      <> show r.elapsedMs
      <> "ms\n"
      <> "\n"
      <> "Note: A 2000ms computation was cancelled immediately.\n"
      <> "(If cancellation works: <500ms, if not: ~2000ms)"

  ErrorPropResult r ->
    "Error Propagation Demo\n"
      <> "======================\n"
      <> "Error captured: "
      <> show r.errorCaptured
      <> "\n"
      <> "Error message: "
      <> r.errorMessage
      <> "\n"
      <> "Elapsed: "
      <> show r.elapsedMs
      <> "ms\n"
      <> "\n"
      <> "Fiber errors are captured and returned via join."

  GatherResult r ->
    "Gather Results Demo\n"
      <> "===================\n"
      <> "Values: "
      <> show r.values
      <> "\n"
      <> "Elapsed: "
      <> show r.elapsedMs
      <> "ms\n"
      <> "\n"
      <> "Note: 5x100ms computations ran in parallel.\n"
      <> "(If parallel: ~100ms, if sequential: ~500ms)"

  HelpResult text ->
    text

  ErrorResult err ->
    "Error: " <> err

helpText :: String
helpText =
  """Demo App - MonadConcurrent Examples
====================================

Usage: demo-app <command> [args]

Commands:
  parallel-timing           Run two 200ms delays in parallel
                           Demonstrates parallel execution timing

  parallel-write [dir]      Write two files concurrently
                           Default dir: out/demo/parallel-write

  cancel-fiber             Fork and cancel a long computation
                           Demonstrates fiber cancellation

  error-propagation        Fork a failing computation
                           Demonstrates error capture via join

  gather-results           Collect results from multiple fibers
                           Demonstrates parTraverseM

  help, --help, -h         Show this help message

Examples:
  demo-app parallel-timing
  demo-app parallel-write /tmp/demo-output
  demo-app cancel-fiber
  demo-app error-propagation
  demo-app gather-results

This demo app demonstrates MonadConcurrent features and runs
identically on both JavaScript (Aff) and Erlang (Effect) backends.
"""
