module DemoComposition where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Control.Monad.BatchRun.HTTP as Control.Monad.BatchRun.HTTP
import Data.Array as Data.Array
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console

-- | This is the elegant composition syntax we wanted!
-- | Notice the HTTP r pattern - composes with other effects via row polymorphism
demoProgram :: forall r. String -> Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.HTTP.HTTP r) (Array String)
demoProgram baseUrl = do
  -- These three requests execute IN PARALLEL
  -- because they're combined with <*>
  results <- (\u p c -> [ u, p, c ])
    <$> Control.Monad.BatchRun.HTTP.get (baseUrl <> "/users/1")
    <*> Control.Monad.BatchRun.HTTP.get (baseUrl <> "/posts/1")
    <*> Control.Monad.BatchRun.HTTP.get (baseUrl <> "/comments/1")

  pure results

-- | Handler composition - peel off effects one by one
-- | runHTTP removes HTTP from the effect row
-- | extract requires () (empty effect row) and extracts the pure value
main :: Effect.Effect Unit
main = Effect.Aff.launchAff_ do
  Effect.Class.liftEffect $ Effect.Console.log "=== Elegant Effect Composition Demo ==="
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Type signature:"
  Effect.Class.liftEffect $ Effect.Console.log "  demoProgram :: forall r. String -> BatchRun (HTTP r) (Array String)"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Handler composition:"
  Effect.Class.liftEffect $ Effect.Console.log "  demoProgram baseUrl"
  Effect.Class.liftEffect $ Effect.Console.log "    # runHTTP     -- Removes HTTP, returns Aff (BatchRun r (Array String))"
  Effect.Class.liftEffect $ Effect.Console.log "    >>= extract   -- Requires r ~ (), returns Array String"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Row polymorphism enables elegant effect composition!"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Fetching from 3 APIs in parallel..."

  let baseUrl = "https://jsonplaceholder.typicode.com"

  -- Handler removes HTTP effect completely
  results <- Control.Monad.BatchRun.HTTP.runHTTP (demoProgram baseUrl)

  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log $ "Fetched " <> show (Data.Array.length results) <> " responses"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Key Features:"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Effect composition via row polymorphism"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Handlers remove effects from the row (Row.Cons)"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Parallel execution via applicative batching"
  Effect.Class.liftEffect $ Effect.Console.log "  ✓ Type-safe at compile time"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Just like purescript-run's elegant pattern!"
  Effect.Class.liftEffect $ Effect.Console.log ""
  Effect.Class.liftEffect $ Effect.Console.log "Done!"
