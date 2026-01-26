-- | Shared test infrastructure for portable tests
-- |
-- | This module provides common types and helpers for platform-agnostic tests
-- | that can run on both JavaScript (Aff) and Erlang (Effect) backends.
module Test.Support.Portable
  ( TestResult(..)
  , assert
  , assertWithMsg
  , isPassing
  , logResults
  ) where

import Prelude

import Data.Array as Data.Array
import Data.Traversable as Data.Traversable
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console

-- | Result of a single test case
data TestResult
  = Pass String
  | Fail String String

derive instance Eq TestResult

instance Show TestResult where
  show (Pass name) = "[PASS] " <> name
  show (Fail name msg) = "[FAIL] " <> name <> ": " <> msg

-- | A simple assertion helper
assert :: forall m. Applicative m => String -> Boolean -> m TestResult
assert name condition =
  pure
    if condition then Pass name
    else Fail name "Assertion failed"

-- | Assert with a custom error message
assertWithMsg :: forall m. Applicative m => String -> String -> Boolean -> m TestResult
assertWithMsg name msg condition =
  pure
    if condition then Pass name
    else Fail name msg

-- | Check if a test result is passing
isPassing :: TestResult -> Boolean
isPassing (Pass _) = true
isPassing (Fail _ _) = false

-- | Log test results to console and return whether all passed
-- |
-- | This helper logs each result, prints a summary, and returns a boolean
-- | indicating overall success.
logResults
  :: forall m
   . Effect.Class.MonadEffect m
  => String
  -> Array TestResult
  -> m Boolean
logResults suiteName results = do
  Effect.Class.liftEffect (Effect.Console.log ("Running " <> suiteName <> "..."))
  Effect.Class.liftEffect (Effect.Console.log "")
  _ <- Data.Traversable.for_ results \result -> do
    Effect.Class.liftEffect (Effect.Console.log (show result))
  let
    passed = Data.Array.length (Data.Array.filter isPassing results)
    total = Data.Array.length results
    allPassed = passed == total
  Effect.Class.liftEffect (Effect.Console.log "")
  Effect.Class.liftEffect
    ( Effect.Console.log
        ( "Results: "
            <> show passed
            <> "/"
            <> show total
            <> " tests passed"
        )
    )
  pure allPassed
