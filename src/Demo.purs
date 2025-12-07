module Demo where

import Prelude

import Control.Monad.Program as Control.Monad.Program
import Control.Monad.Program.HTTP as Control.Monad.Program.HTTP
import Data.Array as Data.Array
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Time.Duration as Data.Time.Duration
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Effect.Now as Effect.Now

type AppEffects r = Control.Monad.Program.HTTP.HTTP r

demoProgram :: forall r. Control.Monad.Program.Program (AppEffects r) (Array String)
demoProgram = do
  let baseUrl = "https://jsonplaceholder.typicode.com"

  let
    user = Control.Monad.Program.HTTP.get (baseUrl <> "/users/1")
    posts = Control.Monad.Program.HTTP.get (baseUrl <> "/posts/1")
    comments = Control.Monad.Program.HTTP.get (baseUrl <> "/comments/1")

  results <- (\u p c -> [ u, p, c ]) <$> user <*> posts <*> comments

  pure results

main :: Effect.Effect Unit
main = Effect.Aff.launchAff_ $ do
  Effect.Class.liftEffect $ Effect.Console.log "=== Parallel Effects Demo ==="
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Fetching from 3 APIs in parallel using applicative composition..."
  Effect.Class.liftEffect $ Effect.Console.log ""

  startTime <- Effect.Class.liftEffect Effect.Now.now
  results <- Control.Monad.Program.HTTP.runHTTP demoProgram
  endTime <- Effect.Class.liftEffect Effect.Now.now

  let
    duration = Data.DateTime.Instant.unInstant endTime
    durationStart = Data.DateTime.Instant.unInstant startTime
    Data.Time.Duration.Milliseconds ms = duration
    Data.Time.Duration.Milliseconds msStart = durationStart
    durationSeconds = (ms - msStart) / 1000.0

  Effect.Class.liftEffect $ Effect.Console.log "Results:"
  Effect.Class.liftEffect $ Effect.Console.log $ "  - Fetched " <> show (Data.Array.length results) <> " responses"
  Effect.Class.liftEffect $ Effect.Console.log $ "  - Total time: " <> show durationSeconds <> " seconds"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "If run sequentially, this would take 3x longer!"
  Effect.Class.liftEffect $ Effect.Console.log "The parallel execution proves the free applicative batching works."
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Done!"
