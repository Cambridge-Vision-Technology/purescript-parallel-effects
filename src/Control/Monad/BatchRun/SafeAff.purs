module Control.Monad.BatchRun.SafeAff
  ( SafeAffF(..)
  , SAFE_AFF
  , _safeAff
  , liftSafeAff
  , runSafeAff
  , runSafeAffAt
  ) where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol (class IsSymbol)
import Effect.Aff as Effect.Aff
import Effect.Exception as Effect.Exception
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

-- | SAFE_AFF effect row type
-- | Provides safe Aff operations that return Either Error a
-- | Example: BatchRun (SAFE_AFF (LOGGING r)) (Either Error String)
type SAFE_AFF r = (safeAff :: SafeAffF | r)

-- | Safe Aff effect functor
-- | Wraps an Aff computation that will be executed with error handling
data SafeAffF a = SafeAffF (Effect.Aff.Aff a)

derive instance Functor SafeAffF

_safeAff :: Type.Proxy.Proxy "safeAff"
_safeAff = Type.Proxy.Proxy

-- | Lift an Aff computation into BatchRun with safe error handling
-- | The computation is wrapped with Effect.Aff.attempt to catch any errors
-- | Returns Either Error a, forcing the caller to handle errors explicitly
-- |
-- | Example:
-- | ```purescript
-- | result <- liftSafeAff (Affjax.get url)
-- | case result of
-- |   Right response -> -- handle success
-- |   Left error -> -- handle error
-- | ```
liftSafeAff
  :: forall r a
   . Effect.Aff.Aff a
  -> Control.Monad.BatchRun.BatchRun (SAFE_AFF r) (Data.Either.Either Effect.Exception.Error a)
liftSafeAff aff = Control.Monad.BatchRun.lift _safeAff (SafeAffF (Effect.Aff.attempt aff))

-- | Handle SAFE_AFF effects for programs with only SAFE_AFF (no other effects)
runSafeAff
  :: forall a
   . Control.Monad.BatchRun.BatchRun (SAFE_AFF ()) a
  -> Effect.Aff.Aff a
runSafeAff = runSafeAffAt _safeAff Control.Monad.BatchRun.impossibleVariant

-- | Handle SAFE_AFF effects at a specific label
-- | Executes the wrapped Aff with Effect.Aff.attempt to catch errors
runSafeAffAt
  :: forall sym q r a
   . IsSymbol sym
  => Prim.Row.Cons sym SafeAffF q r
  => Type.Proxy.Proxy sym
  -> (forall x. Data.Functor.Variant.VariantF q x -> Effect.Aff.Aff x)
  -> Control.Monad.BatchRun.BatchRun r a
  -> Effect.Aff.Aff a
runSafeAffAt sym handler prog =
  Control.Monad.BatchRun.runParallel (\v -> Control.Monad.BatchRun.on sym handleSafeAff handler v) prog
  where
  handleSafeAff :: SafeAffF ~> Effect.Aff.Aff
  handleSafeAff (SafeAffF aff) = aff
