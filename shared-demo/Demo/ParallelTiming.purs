module Demo.ParallelTiming
  ( runParallelTiming
  , ParallelTimingResult
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Data.Either as Data.Either
import Data.Tuple (Tuple(..))
import Effect.Exception as Effect.Exception

type ParallelTimingResult =
  { resultA :: Int
  , resultB :: String
  , elapsedMs :: Number
  }

runParallelTiming
  :: forall m
   . Concurrent.MonadConcurrent m
  => (Number -> m Unit)
  -> m Number
  -> m (Data.Either.Either Effect.Exception.Error ParallelTimingResult)
runParallelTiming delayMs getTimeMs = do
  start <- getTimeMs
  result <- Concurrent.parTuple computationA computationB
  end <- getTimeMs
  let elapsed = end - start
  pure case result of
    Data.Either.Right (Tuple a b) ->
      Data.Either.Right
        { resultA: a
        , resultB: b
        , elapsedMs: elapsed
        }
    Data.Either.Left err ->
      Data.Either.Left err
  where
  computationA :: m Int
  computationA = do
    delayMs 200.0
    pure 42

  computationB :: m String
  computationB = do
    delayMs 200.0
    pure "hello"
