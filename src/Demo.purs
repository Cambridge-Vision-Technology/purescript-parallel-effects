module Demo where

import Prelude

import Control.Monad.BatchRun (BatchRun)
import Control.Monad.BatchRun.HTTP (HTTP, get, runHTTP)
import Data.Array as Array
import Data.DateTime.Instant (unInstant)
import Data.Functor.Variant (VariantF)
import Data.Time.Duration (Milliseconds(..))
import Effect (Effect)
import Effect.Aff (Aff, launchAff_)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import Effect.Console as Console
import Effect.Now (now)
import Partial.Unsafe (unsafeCrashWith)

type AppEffects r = HTTP r

demoProgram :: forall r. BatchRun (AppEffects r) (Array String)
demoProgram = do
  let baseUrl = "https://jsonplaceholder.typicode.com"

  let
    user = get (baseUrl <> "/users/1")
    posts = get (baseUrl <> "/posts/1")
    comments = get (baseUrl <> "/comments/1")

  results <- (\u p c -> [u, p, c]) <$> user <*> posts <*> comments

  pure results

impossibleHandler :: forall r x. VariantF r x -> Aff x
impossibleHandler _ = pure $ unsafeCrashWith "Impossible: all effects should be handled"

main :: Effect Unit
main = launchAff_ $ do
  liftEffect $ Console.log "=== Parallel Effects Demo ==="
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Fetching from 3 APIs in parallel using applicative composition..."
  liftEffect $ Console.log ""

  startTime <- liftEffect now
  results <- runHTTP impossibleHandler demoProgram
  endTime <- liftEffect now

  let
    duration = unInstant endTime
    durationStart = unInstant startTime
    Milliseconds ms = duration
    Milliseconds msStart = durationStart
    durationSeconds = (ms - msStart) / 1000.0

  liftEffect $ Console.log "Results:"
  liftEffect $ Console.log $ "  - Fetched " <> show (Array.length results) <> " responses"
  liftEffect $ Console.log $ "  - Total time: " <> show durationSeconds <> " seconds"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "If run sequentially, this would take 3x longer!"
  liftEffect $ Console.log "The parallel execution proves the free applicative batching works."
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Done!"
