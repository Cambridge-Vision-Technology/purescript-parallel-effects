module Main where

import Prelude

import Effect as Effect
import Effect.Console as Effect.Console

main :: Effect.Effect Unit
main = Effect.Console.log "PureScript Parallel Effects Library - use 'nix run .#demo' to see the demo"
