module Control.Monad.Program.Aff
  ( module Control.Monad.Program
  , impossibleVariant
  , runPure
  , runParallel
  ) where

import Prelude

import Control.Monad.Concurrent.Aff as Control.Monad.Concurrent.Aff
import Control.Monad.Program as Control.Monad.Program
import Data.Functor.Variant as Data.Functor.Variant
import Effect.Aff as Effect.Aff

-- | Type-safe handler for empty effect rows (Aff-specific)
-- | Since VariantF () is uninhabited, this handler proves that no effects exist
impossibleVariant :: forall x. Data.Functor.Variant.VariantF () x -> Effect.Aff.Aff x
impossibleVariant = Data.Functor.Variant.match {}

-- | Type-safe way to run Program with no effects
-- | This is the recommended way to execute Program () computations
runPure :: forall a. Control.Monad.Program.Program () a -> Effect.Aff.Aff a
runPure = runParallel impossibleVariant

-- | Run a Program with parallel execution (backward-compatible alias)
-- |
-- | This function is kept for backward compatibility. New code should
-- | use `runPar` directly with `ConcurrentAff`.
-- |
-- | Note: This wraps Aff handlers in ConcurrentAff internally.
runParallel
  :: forall r a
   . (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program r a
  -> Effect.Aff.Aff a
runParallel handler program =
  Control.Monad.Concurrent.Aff.runConcurrentAff
    (Control.Monad.Program.runPar wrappedHandler program)
  where
  wrappedHandler :: Control.Monad.Program.Handler r Control.Monad.Concurrent.Aff.ConcurrentAff
  wrappedHandler v = Control.Monad.Concurrent.Aff.ConcurrentAff (handler v)
