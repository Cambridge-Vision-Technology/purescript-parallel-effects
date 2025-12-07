module Test.Main where

import Prelude

import Effect (Effect)
import Test.Control.Monad.Program as ProgramTests
import Test.Control.Monad.Program.Parallel as ParallelTests
import Test.DemoComposed as ComposedTests
import Test.Parallelism as Parallelism
import Test.Spec.Runner.Node (runSpecAndExitProcess)
import Test.Spec.Reporter.Console (consoleReporter)

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ] do
  ProgramTests.spec
  ParallelTests.spec
  ComposedTests.spec
  Parallelism.spec
