module Control.Monad.BatchRun.SafeEffect
  ( SafeEffectF(..)
  , SAFE_EFFECT
  , _safeEffect
  , liftSafeEffect
  , runSafeEffect
  , runSafeEffectAt
  ) where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol (class IsSymbol)
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Exception as Effect.Exception
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

-- | SAFE_EFFECT effect row type
-- | Provides safe Effect operations that return Either Error a
-- | Example: BatchRun (SAFE_EFFECT (LOGGING r)) (Either Error String)
type SAFE_EFFECT r = (safeEffect :: SafeEffectF | r)

-- | Safe Effect functor
-- | Wraps an Effect computation that will be executed with error handling
data SafeEffectF a = SafeEffectF (Effect.Effect a)

derive instance Functor SafeEffectF

_safeEffect :: Type.Proxy.Proxy "safeEffect"
_safeEffect = Type.Proxy.Proxy

-- | Lift an Effect computation into BatchRun with safe error handling
-- | The computation is wrapped with Effect.Exception.try to catch any errors
-- | Returns Either Error a, forcing the caller to handle errors explicitly
-- |
-- | Example:
-- | ```purescript
-- | result <- liftSafeEffect (readFile path)
-- | case result of
-- |   Right contents -> -- handle success
-- |   Left error -> -- handle error
-- | ```
liftSafeEffect
  :: forall r a
   . Effect.Effect a
  -> Control.Monad.BatchRun.BatchRun (SAFE_EFFECT r) (Data.Either.Either Effect.Exception.Error a)
liftSafeEffect eff = Control.Monad.BatchRun.lift _safeEffect (SafeEffectF (Effect.Exception.try eff))

-- | Handle SAFE_EFFECT effects for programs with only SAFE_EFFECT (no other effects)
runSafeEffect
  :: forall a
   . Control.Monad.BatchRun.BatchRun (SAFE_EFFECT ()) a
  -> Effect.Aff.Aff a
runSafeEffect = runSafeEffectAt _safeEffect Control.Monad.BatchRun.impossibleVariant

-- | Handle SAFE_EFFECT effects at a specific label
-- | Executes the wrapped Effect with Effect.Exception.try to catch errors
runSafeEffectAt
  :: forall sym q r a
   . IsSymbol sym
  => Prim.Row.Cons sym SafeEffectF q r
  => Type.Proxy.Proxy sym
  -> (forall x. Data.Functor.Variant.VariantF q x -> Effect.Aff.Aff x)
  -> Control.Monad.BatchRun.BatchRun r a
  -> Effect.Aff.Aff a
runSafeEffectAt sym handler prog =
  Control.Monad.BatchRun.runParallel (\v -> Control.Monad.BatchRun.on sym handleSafeEffect handler v) prog
  where
  handleSafeEffect :: SafeEffectF ~> Effect.Aff.Aff
  handleSafeEffect (SafeEffectF eff) = Effect.Class.liftEffect eff
