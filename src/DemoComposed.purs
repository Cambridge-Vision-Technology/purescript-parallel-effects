module DemoComposed where

import Prelude

import Affjax.Node as Affjax.Node
import Affjax.RequestBody as Affjax.RequestBody
import Affjax.ResponseFormat as Affjax.ResponseFormat
import Control.Monad.Program as Control.Monad.Program
import Control.Monad.Program.HTTP as Control.Monad.Program.HTTP
import Control.Monad.Program.Logging as Control.Monad.Program.Logging
import Data.Array as Data.Array
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Maybe as Data.Maybe
import Data.String as Data.String
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Type.Row (type (+))

-- | This program composes HTTP and LOGGING effects together!
-- | Notice how we use BOTH effects in the same program with the + operator
composedProgram :: forall r. Control.Monad.Program.Program (Control.Monad.Program.HTTP.HTTP + Control.Monad.Program.Logging.LOGGING + r) String
composedProgram = do
  -- LOGGING effect
  Control.Monad.Program.Logging.info "Starting composed program with HTTP and LOGGING"
  Control.Monad.Program.Logging.debug "About to make parallel HTTP requests"

  -- HTTP effects (run IN PARALLEL via <*>)
  results <- (\u p -> u <> "\n" <> p)
    <$> Control.Monad.Program.HTTP.get "https://jsonplaceholder.typicode.com/users/1"
    <*> Control.Monad.Program.HTTP.get "https://jsonplaceholder.typicode.com/posts/1"

  -- LOGGING effect
  Control.Monad.Program.Logging.info $ "Successfully fetched " <> show (Data.String.length results) <> " characters"
  Control.Monad.Program.Logging.debug "Composed program complete"

  pure results

-- | HTTP GET with logging - demonstrates monadic sequencing within a single computation
-- | Each call to getWithLog creates a complete monadic sequence:
-- |   1. Log "Fetching: <url>"
-- |   2. Perform HTTP GET
-- |   3. Log "Received: <url>"
-- | These three steps always execute in order (sequentially) within each call.
getWithLog :: forall r. String -> Control.Monad.Program.Program (Control.Monad.Program.HTTP.HTTP + Control.Monad.Program.Logging.LOGGING + r) String
getWithLog url = do
  Control.Monad.Program.Logging.info $ "Fetching: " <> url
  result <- Control.Monad.Program.HTTP.get url
  Control.Monad.Program.Logging.info $ "Received response from: " <> url
  pure result

-- | Demonstrates monadic sequences within applicative parallelism
-- | Key insight: Each getWithLog call is a monadic sequence that runs in parallel with others
-- |
-- | Execution model:
-- |   Sequential: info "Starting parallel fetches with per-request logging"
-- |   Parallel:
-- |     Thread A: info "Fetching: users/1" → get → info "Received: users/1"
-- |     Thread B: info "Fetching: posts/1" → get → info "Received: posts/1"
-- |   Sequential: combine results
-- |   Sequential: info "All fetches complete"
-- |
-- | Note: Logs from different threads may interleave non-deterministically,
-- | but within each thread the order is guaranteed (Fetching → Received).
parallelWithLogging :: forall r. Control.Monad.Program.Program (Control.Monad.Program.HTTP.HTTP + Control.Monad.Program.Logging.LOGGING + r) String
parallelWithLogging = do
  Control.Monad.Program.Logging.info "Starting parallel fetches with per-request logging"

  -- Use applicative composition (<$> and <*>) to run getWithLog calls in parallel
  -- Each getWithLog is a complete monadic sequence that executes independently
  results <- (\u p -> u <> "\n" <> p)
    <$> getWithLog "https://jsonplaceholder.typicode.com/users/1"
    <*> getWithLog "https://jsonplaceholder.typicode.com/posts/1"

  Control.Monad.Program.Logging.info "All fetches complete"
  pure results

-- | Handler for LOGGING effects
handleLogging :: Control.Monad.Program.Logging.LoggingF ~> Effect.Aff.Aff
handleLogging (Control.Monad.Program.Logging.Log level msg next) = do
  Effect.Class.liftEffect $ Effect.Console.log $ "[" <> show level <> "] " <> msg
  pure next

-- | Compose handlers: HTTP handler that delegates to LOGGING handler
handleBoth :: forall x. Data.Functor.Variant.VariantF (http :: Control.Monad.Program.HTTP.HttpF, logging :: Control.Monad.Program.Logging.LoggingF) x -> Effect.Aff.Aff x
handleBoth v =
  Control.Monad.Program.on Control.Monad.Program.HTTP._http handleHttpEffect
    (\v2 -> Control.Monad.Program.on Control.Monad.Program.Logging._logging handleLogging Control.Monad.Program.impossibleVariant v2)
    v
  where
  handleHttpEffect :: Control.Monad.Program.HTTP.HttpF ~> Effect.Aff.Aff
  handleHttpEffect (Control.Monad.Program.HTTP.Get url cont) = do
    result <- Affjax.Node.get Affjax.ResponseFormat.string url
    case result of
      Data.Either.Left err -> pure $ cont $ "Error: " <> Affjax.Node.printError err
      Data.Either.Right response -> pure $ cont response.body
  handleHttpEffect (Control.Monad.Program.HTTP.Post url body cont) = do
    result <- Affjax.Node.post Affjax.ResponseFormat.string url (Data.Maybe.Just $ Affjax.RequestBody.string body)
    case result of
      Data.Either.Left err -> pure $ cont $ "Error: " <> Affjax.Node.printError err
      Data.Either.Right response -> pure $ cont response.body

main :: Effect.Effect Unit
main = Effect.Aff.launchAff_ do
  Effect.Class.liftEffect $ Effect.Console.log "=== Composed Effects Demo ==="
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Demonstrating two patterns of effect composition:"
  Effect.Class.liftEffect $ Effect.Console.log ""

  -- Demo 1: Basic parallel HTTP with external logging
  Effect.Class.liftEffect $ Effect.Console.log "━━━ Demo 1: Basic Parallel HTTP ━━━"
  Effect.Class.liftEffect $ Effect.Console.log "Type: Program (HTTP + LOGGING + r) String"
  Effect.Class.liftEffect $ Effect.Console.log "Pattern: Logging outside, HTTP calls in parallel"
  Effect.Class.liftEffect $ Effect.Console.log ""

  result1 <- Effect.Aff.try do
    Control.Monad.Program.runParallel handleBoth composedProgram

  Effect.Class.liftEffect $ Effect.Console.log ""
  case result1 of
    Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "Error: " <> show err
    Data.Either.Right data_ -> Effect.Class.liftEffect $ Effect.Console.log $ "✓ Retrieved " <> show (Data.String.length data_) <> " characters"

  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Effect.Class.liftEffect $ Effect.Console.log ""

  -- Demo 2: Monadic sequences within applicative parallelism
  Effect.Class.liftEffect $ Effect.Console.log "━━━ Demo 2: Monadic Sequences in Parallel ━━━"
  Effect.Class.liftEffect $ Effect.Console.log "Type: Program (HTTP + LOGGING + r) String"
  Effect.Class.liftEffect $ Effect.Console.log "Pattern: Each parallel branch is its own monadic sequence"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Key insight: getWithLog uses 'do' notation internally,"
  Effect.Class.liftEffect $ Effect.Console.log "then we compose multiple getWithLog calls with <*>"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Execution model:"
  Effect.Class.liftEffect $ Effect.Console.log "  Thread A: info → get → info (sequential within thread)"
  Effect.Class.liftEffect $ Effect.Console.log "  Thread B: info → get → info (sequential within thread)"
  Effect.Class.liftEffect $ Effect.Console.log "  Threads A and B run in parallel"
  Effect.Class.liftEffect $ Effect.Console.log ""

  result2 <- Effect.Aff.try do
    Control.Monad.Program.runParallel handleBoth parallelWithLogging

  Effect.Class.liftEffect $ Effect.Console.log ""
  case result2 of
    Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "Error: " <> show err
    Data.Either.Right data_ -> Effect.Class.liftEffect $ Effect.Console.log $ "✓ Retrieved " <> show (Data.String.length data_) <> " characters"

  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Key Takeaways:"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Use + operator for clean effect composition (like purescript-run)"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Monadic (do) creates sequential effects within a computation"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Applicative (<*>) creates parallel execution across computations"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Combine both: monadic sequences that execute in parallel"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Done!"
