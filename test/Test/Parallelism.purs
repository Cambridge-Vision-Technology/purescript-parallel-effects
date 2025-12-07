module Test.Parallelism where

import Prelude

import Control.Monad.Program (on, runParallel, impossibleVariant)
import Data.DateTime.Instant (unInstant)
import Data.Maybe (Maybe(..))
import Data.Time.Duration (Milliseconds(..))
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Now (now)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldSatisfy)
import Test.Support.Delay (DELAY, DelayF, _delay, delay, handleDelay)

spec :: Spec Unit
spec = describe "Parallelism timing" do
  it "sequential delays add up with do" do
    let
      program = do
        delay (Milliseconds 200.0)
        delay (Milliseconds 200.0)
        delay (Milliseconds 200.0)

    start <- liftEffect now
    _ <- runParallel (\v -> on _delay handleDelay impossibleVariant v) program
    end <- liftEffect now

    let
      Milliseconds msStart = unInstant start
      Milliseconds msEnd = unInstant end
      total = msEnd - msStart

    -- Expect roughly 600ms+, allow for small jitter
    total `shouldSatisfy` (_ >= 550.0)

  it "applicative delays should run in parallel with <*>" do
    let
      program = (\_ _ _ -> unit)
        <$> delay (Milliseconds 200.0)
        <*> delay (Milliseconds 200.0)
        <*> delay (Milliseconds 200.0)

    start <- liftEffect now
    _ <- runParallel (\v -> on _delay handleDelay impossibleVariant v) program
    end <- liftEffect now

    let
      Milliseconds msStart = unInstant start
      Milliseconds msEnd = unInstant end
      total = msEnd - msStart

    -- With true parallel batching, expect well below 600ms (e.g., < 350ms)
    total `shouldSatisfy` (_ < 350.0)

