module Demo.CancelFiber
  ( runCancelFiber
  , CancelFiberResult
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Data.Either as Data.Either
import Effect.Exception as Effect.Exception

type CancelFiberResult =
  { cancelled :: Boolean
  , elapsedMs :: Number
  }

runCancelFiber
  :: forall m
   . Concurrent.MonadConcurrent m
  => (Number -> m Unit)
  -> m Number
  -> m (Data.Either.Either Effect.Exception.Error CancelFiberResult)
runCancelFiber delayMs getTimeMs = do
  start <- getTimeMs
  fiber <- Concurrent.fork longRunningComputation
  Concurrent.cancel fiber
  end <- getTimeMs
  let elapsed = end - start
  pure
    ( Data.Either.Right
        { cancelled: true
        , elapsedMs: elapsed
        }
    )
  where
  longRunningComputation :: m Unit
  longRunningComputation = do
    delayMs 2000.0
    pure unit
