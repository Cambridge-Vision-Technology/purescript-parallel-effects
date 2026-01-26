module Demo.GatherResults
  ( runGatherResults
  , GatherResultsResult
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Data.Either as Data.Either
import Effect.Exception as Effect.Exception

type GatherResultsResult =
  { values :: Array Int
  , elapsedMs :: Number
  }

runGatherResults
  :: forall m
   . Concurrent.MonadConcurrent m
  => (Number -> m Unit)
  -> m Number
  -> m (Data.Either.Either Effect.Exception.Error GatherResultsResult)
runGatherResults delayMs getTimeMs = do
  start <- getTimeMs
  result <- Concurrent.parTraverseM makeComputation inputs
  end <- getTimeMs
  let elapsed = end - start
  pure case result of
    Data.Either.Right values ->
      Data.Either.Right
        { values
        , elapsedMs: elapsed
        }
    Data.Either.Left err ->
      Data.Either.Left err
  where
  inputs :: Array Int
  inputs = [ 1, 2, 3, 4, 5 ]

  makeComputation :: Int -> m Int
  makeComputation n = do
    delayMs 100.0
    pure (n * 10)
