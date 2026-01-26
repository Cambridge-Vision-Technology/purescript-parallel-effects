-- | JavaScript entry point for the demo CLI application
-- |
-- | This module instantiates the portable Demo.Commands with the
-- | MonadConcurrent ConcurrentAff instance and platform-specific operations.
module Demo.Main where

import Prelude

import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
import Data.Array as Data.Array
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Time.Duration as Data.Time.Duration
import Demo.Commands as Demo.Commands
import Demo.ParallelWrite as Demo.ParallelWrite
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Aff.Class as Effect.Aff.Class
import Effect.Class as Effect.Class
import Effect.Class.Console as Effect.Class.Console
import Effect.Exception as Effect.Exception
import Effect.Now as Effect.Now
import Node.Encoding as Node.Encoding
import Node.FS.Aff as Node.FS.Aff
import Node.Process as Node.Process

main :: Effect.Effect Unit
main = Effect.Aff.launchAff_ do
  args <- Effect.Class.liftEffect Node.Process.argv
  let
    cliArgs = Data.Array.drop 2 args
    command = Demo.Commands.parseCommand cliArgs
  result <- runConcurrentAff (Demo.Commands.runCommand delayMs getTimeMs writeFile throwError command)
  Effect.Class.Console.log (Demo.Commands.formatResult result)
  Effect.Class.liftEffect case result of
    Demo.Commands.ErrorResult _ -> Node.Process.setExitCode 1
    _ -> pure unit
  where
  delayMs :: Number -> ConcurrentAff Unit
  delayMs ms = ConcurrentAff (Effect.Aff.delay (Data.Time.Duration.Milliseconds ms))

  getTimeMs :: ConcurrentAff Number
  getTimeMs = Effect.Class.liftEffect do
    instant <- Effect.Now.now
    let Data.Time.Duration.Milliseconds ms = Data.DateTime.Instant.unInstant instant
    pure ms

  writeFile :: Demo.ParallelWrite.FileWriteOp ConcurrentAff
  writeFile { path, content } = do
    Effect.Aff.Class.liftAff (Node.FS.Aff.writeTextFile Node.Encoding.UTF8 path content)

  throwError :: String -> ConcurrentAff Unit
  throwError msg = ConcurrentAff (Effect.Aff.throwError (Effect.Exception.error msg))
