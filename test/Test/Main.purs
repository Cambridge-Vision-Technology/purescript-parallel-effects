module Test.Main where

import Prelude

import Effect (Effect)
import Test.Control.Monad.BatchRun as BatchRunTests
import Test.DemoComposed as ComposedTests
import Test.Parallelism as Parallelism
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.Spec.Reporter.Console (consoleReporter)

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ] do
  BatchRunTests.spec
  ComposedTests.spec
  Parallelism.spec
