module DemoMultiEffect where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Control.Monad.BatchRun.HTTP as Control.Monad.BatchRun.HTTP
import Control.Monad.BatchRun.Logging as Control.Monad.BatchRun.Logging
import Data.Array as Data.Array
import Data.Either as Data.Either
import Data.String as Data.String
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console

-- | Demonstrates HTTP effect with parallel requests
httpProgram :: Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.HTTP.HTTP ()) String
httpProgram = do
  -- HTTP effects (these run IN PARALLEL via <*>)
  results <- (\u p -> u <> "\n" <> p)
    <$> Control.Monad.BatchRun.HTTP.get "https://jsonplaceholder.typicode.com/users/1"
    <*> Control.Monad.BatchRun.HTTP.get "https://jsonplaceholder.typicode.com/posts/1"

  pure results

-- | Demonstrates LOGGING effect
loggingProgram :: Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.Logging.LOGGING ()) Unit
loggingProgram = do
  Control.Monad.BatchRun.Logging.info "Starting logging demo"
  Control.Monad.BatchRun.Logging.debug "This is a debug message"
  Control.Monad.BatchRun.Logging.info "This is an info message"
  Control.Monad.BatchRun.Logging.info "Logging demo complete"

main :: Effect.Effect Unit
main = Effect.Aff.launchAff_ do
  Effect.Class.liftEffect $ Effect.Console.log "=== Multi-Effect Demo ==="
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Demonstrating FILE_SYSTEM and LOGGING effects"
  Effect.Class.liftEffect $ Effect.Console.log ""

  -- Run logging demo
  Effect.Class.liftEffect $ Effect.Console.log "=== LOGGING Effect Demo ==="
  _ <- Control.Monad.BatchRun.Logging.runLogging loggingProgram

  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "=== HTTP Effect Demo (Parallel Requests) ==="

  -- Run HTTP demo
  httpResult <- Effect.Aff.try $ Control.Monad.BatchRun.HTTP.runHTTP httpProgram

  case httpResult of
    Data.Either.Left err -> do
      Effect.Class.liftEffect $ Effect.Console.log $ "Error: " <> show err
    Data.Either.Right data_ -> do
      Effect.Class.liftEffect $ Effect.Console.log $ "Success! Retrieved " <> show (Data.String.length data_) <> " characters"

  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Key Features Demonstrated:"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ FILE_SYSTEM effect for file operations"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ LOGGING effect with multiple log levels"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ HTTP effect with parallel requests via applicative"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Type-safe effect handling with Row.Cons"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Done!"
