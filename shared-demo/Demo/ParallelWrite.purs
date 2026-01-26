module Demo.ParallelWrite
  ( runParallelWrite
  , ParallelWriteResult
  , FileWriteOp
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Concurrent
import Data.Either as Data.Either
import Data.Tuple (Tuple(..))
import Effect.Exception as Effect.Exception

type FileWriteOp m =
  { path :: String
  , content :: String
  }
  -> m Unit

type ParallelWriteResult =
  { file1Path :: String
  , file2Path :: String
  , elapsedMs :: Number
  }

runParallelWrite
  :: forall m
   . Concurrent.MonadConcurrent m
  => FileWriteOp m
  -> m Number
  -> String
  -> m (Data.Either.Either Effect.Exception.Error ParallelWriteResult)
runParallelWrite writeFile getTimeMs outputDir = do
  let
    file1Path = outputDir <> "/file1.txt"
    file2Path = outputDir <> "/file2.txt"
    content1 = "Content written to file 1 at " <> file1Path
    content2 = "Content written to file 2 at " <> file2Path
  start <- getTimeMs
  result <- Concurrent.parTuple
    (writeFile { path: file1Path, content: content1 })
    (writeFile { path: file2Path, content: content2 })
  end <- getTimeMs
  let elapsed = end - start
  pure case result of
    Data.Either.Right (Tuple _ _) ->
      Data.Either.Right
        { file1Path
        , file2Path
        , elapsedMs: elapsed
        }
    Data.Either.Left err ->
      Data.Either.Left err
