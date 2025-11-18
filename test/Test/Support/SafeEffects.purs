module Test.Support.SafeEffects where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Control.Monad.BatchRun.SafeAff as Control.Monad.BatchRun.SafeAff
import Control.Monad.BatchRun.SafeEffect as Control.Monad.BatchRun.SafeEffect
import Data.Either as Data.Either
import Data.String as Data.String
import Data.Time.Duration as Data.Time.Duration
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Exception as Effect.Exception

-- | Create a successful Aff computation
successAff :: forall a. a -> Effect.Aff.Aff a
successAff = pure

-- | Create a failing Aff computation
failAff :: forall a. String -> Effect.Aff.Aff a
failAff msg = Effect.Aff.throwError (Effect.Exception.error msg)

-- | Create a successful Effect computation
successEffect :: forall a. a -> Effect.Effect a
successEffect = pure

-- | Create a failing Effect computation
failEffect :: forall a. String -> Effect.Effect a
failEffect msg = Effect.Exception.throwException (Effect.Exception.error msg)

-- | Create a delayed Aff that succeeds after a given duration
delayedSuccessAff :: forall a. Data.Time.Duration.Milliseconds -> a -> Effect.Aff.Aff a
delayedSuccessAff ms value = do
  Effect.Aff.delay ms
  pure value

-- | Lift a safe Aff that succeeds
liftSafeAffSuccess
  :: forall r a
   . a
  -> Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.SafeAff.SAFE_AFF r) (Data.Either.Either Effect.Exception.Error a)
liftSafeAffSuccess value = Control.Monad.BatchRun.SafeAff.liftSafeAff (successAff value)

-- | Lift a safe Aff that fails
liftSafeAffFailure
  :: forall r a
   . String
  -> Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.SafeAff.SAFE_AFF r) (Data.Either.Either Effect.Exception.Error a)
liftSafeAffFailure msg = Control.Monad.BatchRun.SafeAff.liftSafeAff (failAff msg)

-- | Lift a delayed safe Aff that succeeds
liftSafeAffDelayed
  :: forall r a
   . Data.Time.Duration.Milliseconds
  -> a
  -> Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.SafeAff.SAFE_AFF r) (Data.Either.Either Effect.Exception.Error a)
liftSafeAffDelayed ms value = Control.Monad.BatchRun.SafeAff.liftSafeAff (delayedSuccessAff ms value)

-- | Lift a safe Effect that succeeds
liftSafeEffectSuccess
  :: forall r a
   . a
  -> Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.SafeEffect.SAFE_EFFECT r) (Data.Either.Either Effect.Exception.Error a)
liftSafeEffectSuccess value = Control.Monad.BatchRun.SafeEffect.liftSafeEffect (successEffect value)

-- | Lift a safe Effect that fails
liftSafeEffectFailure
  :: forall r a
   . String
  -> Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.SafeEffect.SAFE_EFFECT r) (Data.Either.Either Effect.Exception.Error a)
liftSafeEffectFailure msg = Control.Monad.BatchRun.SafeEffect.liftSafeEffect (failEffect msg)

-- | Check if an Either is Right with the expected value
isRightWith :: forall e a. Eq a => Data.Either.Either e a -> a -> Boolean
isRightWith (Data.Either.Right actual) expected = actual == expected
isRightWith (Data.Either.Left _) _ = false

-- | Check if an Either is Left
isLeft :: forall e a. Data.Either.Either e a -> Boolean
isLeft (Data.Either.Left _) = true
isLeft (Data.Either.Right _) = false

-- | Check if an Either is Left with error message containing substring
isLeftWithMessage :: forall a. Data.Either.Either Effect.Exception.Error a -> String -> Boolean
isLeftWithMessage (Data.Either.Left err) substring =
  Data.String.contains (Data.String.Pattern substring) (Effect.Exception.message err)
isLeftWithMessage (Data.Either.Right _) _ = false
