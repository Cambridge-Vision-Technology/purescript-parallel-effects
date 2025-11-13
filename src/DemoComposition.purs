module DemoComposition where

import Prelude

import Control.Monad.BatchRun (BatchRun, extract)
import Control.Monad.BatchRun.HTTP (HTTP, get, runHTTP)
import Data.Array as Array
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Console as Console

-- | This is the elegant composition syntax we wanted!
-- | Notice the HTTP r pattern - composes with other effects via row polymorphism
demoProgram :: forall r. String -> BatchRun (HTTP r) (Array String)
demoProgram baseUrl = do
  -- These three requests execute IN PARALLEL
  -- because they're combined with <*>
  results <- (\u p c -> [u, p, c])
    <$> get (baseUrl <> "/users/1")
    <*> get (baseUrl <> "/posts/1")
    <*> get (baseUrl <> "/comments/1")

  pure results

-- | Handler composition - peel off effects one by one
-- | runHTTP removes HTTP from the effect row
-- | extract requires () (empty effect row) and extracts the pure value
main :: Effect Unit
main = launchAff_ do
  liftEffect $ Console.log "=== Elegant Effect Composition Demo ==="
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Type signature:"
  liftEffect $ Console.log "  demoProgram :: forall r. String -> BatchRun (HTTP r) (Array String)"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Handler composition:"
  liftEffect $ Console.log "  demoProgram baseUrl"
  liftEffect $ Console.log "    # runHTTP     -- Removes HTTP, returns Aff (BatchRun r (Array String))"
  liftEffect $ Console.log "    >>= extract   -- Requires r ~ (), returns Array String"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Row polymorphism enables elegant effect composition!"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Fetching from 3 APIs in parallel..."

  let baseUrl = "https://jsonplaceholder.typicode.com"

  -- Handler composition: remove HTTP effect, then extract pure value
  batchRunResult <- runHTTP (demoProgram baseUrl)
  let results = extract batchRunResult

  liftEffect $ Console.log ""
  liftEffect $ Console.log $ "Fetched " <> show (Array.length results) <> " responses"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Key Features:"
  liftEffect $ Console.log "  ✓ Effect composition via row polymorphism"
  liftEffect $ Console.log "  ✓ Handlers remove effects from the row (Row.Cons)"
  liftEffect $ Console.log "  ✓ Parallel execution via applicative batching"
  liftEffect $ Console.log "  ✓ Type-safe at compile time"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Just like purescript-run's elegant pattern!"
  liftEffect $ Console.log ""
  liftEffect $ Console.log "Done!"
