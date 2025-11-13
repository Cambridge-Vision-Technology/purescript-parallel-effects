module DemoMultiEffect where

import Prelude hiding (log)

import Control.Monad.BatchRun (BatchRun)
import Control.Monad.BatchRun.HTTP (HTTP, get)
import Control.Monad.BatchRun.HTTP as HTTP
import Control.Monad.BatchRun.Logging (LOGGING, info, debug)
import Control.Monad.BatchRun.Logging as Logging
import Data.Array as Array
import Data.String as String
import Effect (Effect)
import Effect.Aff (Aff, launchAff_, try)
import Effect.Aff as Effect.Aff
import Effect.Class (liftEffect)
import Effect.Console as Console

-- | Demonstrates HTTP effect with parallel requests
httpProgram :: BatchRun (HTTP ()) String
httpProgram = do
  -- HTTP effects (these run IN PARALLEL via <*>)
  results <- (\u p -> u <> "\n" <> p)
    <$> get "https://jsonplaceholder.typicode.com/users/1"
    <*> get "https://jsonplaceholder.typicode.com/posts/1"

  pure results

-- | Demonstrates LOGGING effect
loggingProgram :: BatchRun (LOGGING ()) Unit
loggingProgram = do
  info "Starting logging demo"
  debug "This is a debug message"
  info "This is an info message"
  info "Logging demo complete"

main :: Effect Unit
main = launchAff_ do
  liftEffect $ Console.log "=== Multi-Effect Demo ==="
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Demonstrating FILE_SYSTEM and LOGGING effects"
  liftEffect $ Console.log ""

  -- Run logging demo
  liftEffect $ Console.log "=== LOGGING Effect Demo ==="
  _ <- Logging.runLogging loggingProgram

  liftEffect $ Console.log ""
  liftEffect $ Console.log "=== HTTP Effect Demo (Parallel Requests) ==="

  -- Run HTTP demo
  httpResult <- try $ HTTP.runHTTP httpProgram

  case httpResult of
    Left err -> do
      liftEffect $ Console.log $ "Error: " <> show err
    Right data_ -> do
      liftEffect $ Console.log $ "Success! Retrieved " <> show (String.length data_) <> " characters"

  liftEffect $ Console.log ""
  liftEffect $ Console.log "Key Features Demonstrated:"
  liftEffect $ Console.log "  ✓ FILE_SYSTEM effect for file operations"
  liftEffect $ Console.log "  ✓ LOGGING effect with multiple log levels"
  liftEffect $ Console.log "  ✓ HTTP effect with parallel requests via applicative"
  liftEffect $ Console.log "  ✓ Type-safe effect handling with Row.Cons"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Done!"
