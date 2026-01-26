module Test.Main where

import Prelude

import Effect (Effect)
import Test.Control.Monad.Concurrent as ConcurrentTests
import Test.Control.Monad.Program as ProgramTests
import Test.Control.Monad.Program.Parallel as ParallelTests
import Test.Control.Monad.Program.RunPar as RunParTests
import Test.DemoComposed as ComposedTests
import Test.MonadConcurrent.PortableSpec as MonadConcurrentPortableTests
import Test.Orchestration as OrchestrationTests
import Test.Orchestration.PortableSpec as OrchestrationPortableTests
import Test.Parallel.PortableSpec as ParallelPortableTests
import Test.Parallelism as Parallelism
import Test.Program.PortableSpec as ProgramPortableTests
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner.Node (runSpecAndExitProcess)

main :: Effect Unit
main = runSpecAndExitProcess [ consoleReporter ] do
  ProgramTests.spec
  ParallelTests.spec
  RunParTests.spec
  ComposedTests.spec
  Parallelism.spec
  ConcurrentTests.spec
  OrchestrationTests.spec
  MonadConcurrentPortableTests.spec
  ProgramPortableTests.spec
  ParallelPortableTests.spec
  OrchestrationPortableTests.spec
