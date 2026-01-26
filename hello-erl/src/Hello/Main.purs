-- | Hello World module for testing purerl compilation
module Hello.Main where

import Prelude

import Effect (Effect)
import Effect.Console (log)

-- | Simple greeting function
greet :: String -> String
greet name = "Hello, " <> name <> "!"

-- | Main entry point
main :: Effect Unit
main = do
  log (greet "Erlang")
