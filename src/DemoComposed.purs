module DemoComposed where

import Prelude

import Affjax.Node as Affjax
import Affjax.RequestBody as RequestBody
import Affjax.ResponseFormat as ResponseFormat
import Control.Monad.BatchRun (BatchRun, on, runParallel)
import Control.Monad.BatchRun.HTTP (HTTP, HttpF(..), get, _http)
import Control.Monad.BatchRun.Logging (LOGGING, LoggingF(..), info, debug, _logging)
import Data.Maybe (Maybe(..))
import Data.Array as Array
import Data.Either (Either(..))
import Data.Functor.Variant as V
import Data.String as String
import Effect (Effect)
import Effect.Aff (Aff, launchAff_, try)
import Effect.Class (liftEffect)
import Effect.Console as Console
import Partial.Unsafe (unsafeCrashWith)

-- | This program composes HTTP and LOGGING effects together!
-- | Notice how we use BOTH effects in the same program
composedProgram :: forall r. BatchRun (HTTP (LOGGING r)) String
composedProgram = do
  -- LOGGING effect
  info "Starting composed program with HTTP and LOGGING"
  debug "About to make parallel HTTP requests"

  -- HTTP effects (run IN PARALLEL via <*>)
  results <- (\u p -> u <> "\n" <> p)
    <$> get "https://jsonplaceholder.typicode.com/users/1"
    <*> get "https://jsonplaceholder.typicode.com/posts/1"

  -- LOGGING effect
  info $ "Successfully fetched " <> show (String.length results) <> " characters"
  debug "Composed program complete"

  pure results

impossibleHandler :: forall r x. V.VariantF r x -> Aff x
impossibleHandler _ = pure $ unsafeCrashWith "Impossible: all effects should be handled"

-- | Handler for LOGGING effects
handleLogging :: LoggingF ~> Aff
handleLogging (Log level msg next) = do
  liftEffect $ Console.log $ "[" <> show level <> "] " <> msg
  pure next

main :: Effect Unit
main = launchAff_ do
  liftEffect $ Console.log "=== Composed Effects Demo ==="
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Type signature:"
  liftEffect $ Console.log "  composedProgram :: forall r. BatchRun (HTTP (LOGGING r)) String"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "This program uses BOTH HTTP and LOGGING effects together!"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Running..."
  liftEffect $ Console.log ""

  -- Compose handlers: HTTP handler that delegates to LOGGING handler
  result <- try do
    runParallel
      (\v -> on _http handleHTTP
        (\v2 -> on _logging handleLogging impossibleHandler v2)
        v)
      composedProgram

  liftEffect $ Console.log ""
  liftEffect $ Console.log "---"
  case result of
    Left err -> do
      liftEffect $ Console.log $ "Error: " <> show err
    Right data_ -> do
      liftEffect $ Console.log $ "Success! Retrieved " <> show (String.length data_) <> " characters"

  liftEffect $ Console.log ""
  liftEffect $ Console.log "Key Features:"
  liftEffect $ Console.log "  ✓ Single program with multiple effects composed"
  liftEffect $ Console.log "  ✓ Type signature: BatchRun (HTTP (LOGGING r)) String"
  liftEffect $ Console.log "  ✓ Handlers compose via nesting"
  liftEffect $ Console.log "  ✓ Parallel HTTP execution via applicative"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Done!"

-- | HTTP effect handler
handleHTTP :: forall a. V.VariantF (http :: HttpF) a -> Aff a
handleHTTP v =
  on _http handleHttpF impossibleHandler v
  where
  handleHttpF (Get url cont) = do
    result <- Affjax.get ResponseFormat.string url
    case result of
      Left err -> pure $ cont $ "Error: " <> Affjax.printError err
      Right response -> pure $ cont response.body
  handleHttpF (Post url body cont) = do
    result <- Affjax.post ResponseFormat.string url (Just $ RequestBody.string body)
    case result of
      Left err -> pure $ cont $ "Error: " <> Affjax.printError err
      Right response -> pure $ cont response.body
