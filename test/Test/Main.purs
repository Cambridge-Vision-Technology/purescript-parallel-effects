module Test.Main where

import Prelude

import Effect (Effect)
import Effect.Aff (launchAff_)
import Test.Control.Monad.BatchRun as BatchRunTests
import Test.DemoComposed as ComposedTests
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (runSpec)

main :: Effect Unit
main = launchAff_ $ runSpec [consoleReporter] do
  BatchRunTests.spec
  ComposedTests.spec
