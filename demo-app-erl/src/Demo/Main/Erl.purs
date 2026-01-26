-- | Erlang entry point for the demo CLI application
-- |
-- | This module instantiates the portable Demo.Commands with the
-- | MonadConcurrent ConcurrentEffect instance and platform-specific operations
-- | for the Erlang/BEAM runtime.
-- |
-- | Run with: nix run .#demo-erl -- parallel-timing
module Demo.Main.Erl where

import Prelude

import Control.Monad.Concurrent.Effect (ConcurrentEffect(..), runConcurrentEffect)
import Demo.Commands as Demo.Commands
import Demo.ParallelWrite as Demo.ParallelWrite
import Effect as Effect
import Effect.Console as Effect.Console

main :: Effect.Effect Unit
main = do
  args <- getArgv
  let
    command = Demo.Commands.parseCommand args
  result <- runConcurrentEffect (Demo.Commands.runCommand delayMs getTimeMs writeFile throwError command)
  Effect.Console.log (Demo.Commands.formatResult result)
  case result of
    Demo.Commands.ErrorResult _ -> erlangHalt 1
    _ -> pure unit

-- | Get command-line arguments (escript style).
-- | Returns only the actual arguments, not the escript path.
foreign import getArgv :: Effect.Effect (Array String)

-- | ConcurrentEffect-specific delay function.
delayMs :: Number -> ConcurrentEffect Unit
delayMs ms = ConcurrentEffect (delayMsImpl ms)

foreign import delayMsImpl :: Number -> Effect.Effect Unit

-- | ConcurrentEffect-specific get time function.
getTimeMs :: ConcurrentEffect Number
getTimeMs = ConcurrentEffect getTimeMsImpl

foreign import getTimeMsImpl :: Effect.Effect Number

-- | Write a file to disk (in ConcurrentEffect).
writeFile :: Demo.ParallelWrite.FileWriteOp ConcurrentEffect
writeFile { path, content } = ConcurrentEffect (writeFileImpl path content)

foreign import writeFileImpl :: String -> String -> Effect.Effect Unit

-- | Exit the Erlang VM with the specified exit code.
foreign import erlangHalt :: Int -> Effect.Effect Unit

-- | Throw an error (in ConcurrentEffect).
throwError :: String -> ConcurrentEffect Unit
throwError msg = ConcurrentEffect (throwErrorImpl msg)

foreign import throwErrorImpl :: String -> Effect.Effect Unit
