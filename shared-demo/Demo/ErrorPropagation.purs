module Demo.ErrorPropagation
  ( runErrorPropagation
  , ErrorPropagationResult
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Data.Either as Data.Either
import Effect.Exception as Effect.Exception

type ErrorPropagationResult =
  { errorCaptured :: Boolean
  , errorMessage :: String
  , elapsedMs :: Number
  }

runErrorPropagation
  :: forall m
   . Concurrent.MonadConcurrent m
  => m Number
  -> (String -> m Unit)
  -> m (Data.Either.Either Effect.Exception.Error ErrorPropagationResult)
runErrorPropagation getTimeMs throwError = do
  start <- getTimeMs
  fiber <- Concurrent.fork failingComputation
  result <- Concurrent.join fiber
  end <- getTimeMs
  let elapsed = end - start
  pure case result of
    Data.Either.Left err ->
      Data.Either.Right
        { errorCaptured: true
        , errorMessage: Effect.Exception.message err
        , elapsedMs: elapsed
        }
    Data.Either.Right _ ->
      Data.Either.Left
        (Effect.Exception.error "Expected error but computation succeeded")
  where
  failingComputation :: m Int
  failingComputation = do
    throwError "Intentional failure for demo"
    pure 42
