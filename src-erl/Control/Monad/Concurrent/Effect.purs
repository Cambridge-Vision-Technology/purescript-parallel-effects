-- | MonadConcurrent instance for Effect (Erlang backend).
-- |
-- | This module provides the MonadConcurrent instance for ConcurrentEffect,
-- | a newtype wrapper around Effect that enables concurrent execution
-- | using Erlang processes on the purerl backend.
-- |
-- | Usage:
-- | ```purescript
-- | import Control.Monad.Concurrent.Effect (ConcurrentEffect(..), runConcurrentEffect)
-- | import Control.Monad.Concurrent.Class (fork, join, parTuple)
-- |
-- | myProgram :: ConcurrentEffect Int
-- | myProgram = do
-- |   fiber <- fork (pure 42)
-- |   result <- join fiber
-- |   pure (fromRight 0 result)
-- |
-- | main = runConcurrentEffect myProgram
-- | ```
module Control.Monad.Concurrent.Effect
  ( ConcurrentEffect(..)
  , runConcurrentEffect
  , module Control.Monad.Concurrent.Class
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Control.Monad.Concurrent.Class
import Control.Monad.Concurrent.Erl as Erl
import Control.Monad.Error.Class as Control.Monad.Error.Class
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Either as Data.Either
import Data.Newtype as Data.Newtype
import Effect as Effect
import Effect.Class as Effect.Class
import Effect.Exception as Effect.Exception

-- | A newtype wrapper around Effect that provides MonadConcurrent.
-- |
-- | This wrapper is necessary to satisfy PureScript's orphan instance rules.
-- | Use `ConcurrentEffect` to wrap Effect computations that need concurrent execution,
-- | and `runConcurrentEffect` to unwrap them back to Effect.
newtype ConcurrentEffect a = ConcurrentEffect (Effect.Effect a)

derive instance Data.Newtype.Newtype (ConcurrentEffect a) _
derive newtype instance Functor ConcurrentEffect
derive newtype instance Apply ConcurrentEffect
derive newtype instance Applicative ConcurrentEffect
derive newtype instance Bind ConcurrentEffect
derive newtype instance Monad ConcurrentEffect
derive newtype instance Effect.Class.MonadEffect ConcurrentEffect

-- | MonadThrow instance for ConcurrentEffect.
-- | Throws errors via the Erlang exception mechanism.
instance Control.Monad.Error.Class.MonadThrow Effect.Exception.Error ConcurrentEffect where
  throwError e = ConcurrentEffect (Effect.Exception.throwException e)

-- | MonadError instance for ConcurrentEffect.
-- | Provides error catching via the Erlang exception mechanism.
instance Control.Monad.Error.Class.MonadError Effect.Exception.Error ConcurrentEffect where
  catchError (ConcurrentEffect eff) handler =
    ConcurrentEffect (Effect.Exception.catchException (\e -> runConcurrentEffect (handler e)) eff)

-- | MonadRec instance for ConcurrentEffect.
-- | Uses trampolining to enable stack-safe recursion.
instance Control.Monad.Rec.Class.MonadRec ConcurrentEffect where
  tailRecM f a = ConcurrentEffect (Control.Monad.Rec.Class.tailRecM (\x -> runConcurrentEffect (f x)) a)

-- | Unwrap a ConcurrentEffect computation to run it as Effect.
runConcurrentEffect :: forall a. ConcurrentEffect a -> Effect.Effect a
runConcurrentEffect (ConcurrentEffect eff) = eff

-- | Convert an Erl.FiberErl to the abstract Fiber ConcurrentEffect type.
toFiberConcurrent :: forall a. Erl.FiberErl a -> Control.Monad.Concurrent.Class.Fiber ConcurrentEffect a
toFiberConcurrent = toFiberConcurrentImpl

-- | Convert the abstract Fiber ConcurrentEffect type back to Erl.FiberErl.
fromFiberConcurrent :: forall a. Control.Monad.Concurrent.Class.Fiber ConcurrentEffect a -> Erl.FiberErl a
fromFiberConcurrent = fromFiberConcurrentImpl

foreign import toFiberConcurrentImpl :: forall a. Erl.FiberErl a -> Control.Monad.Concurrent.Class.Fiber ConcurrentEffect a

foreign import fromFiberConcurrentImpl :: forall a. Control.Monad.Concurrent.Class.Fiber ConcurrentEffect a -> Erl.FiberErl a

-- | MonadConcurrent instance for ConcurrentEffect (Erlang backend).
-- |
-- | This implementation uses Erlang processes with monitors to provide
-- | concurrent execution. Each forked computation runs in its own
-- | Erlang process, and we use monitors to detect completion.
-- |
-- | Uses the battle-tested Erl module's implementation internally.
instance Control.Monad.Concurrent.Class.MonadConcurrent ConcurrentEffect where
  fork :: forall a. ConcurrentEffect a -> ConcurrentEffect (Control.Monad.Concurrent.Class.Fiber ConcurrentEffect a)
  fork (ConcurrentEffect ma) = ConcurrentEffect do
    erlFiber <- Erl.spawnMonitor ma
    pure (toFiberConcurrent erlFiber)

  join :: forall a. Control.Monad.Concurrent.Class.Fiber ConcurrentEffect a -> ConcurrentEffect (Data.Either.Either Effect.Exception.Error a)
  join fiber = ConcurrentEffect (Erl.awaitResult (fromFiberConcurrent fiber))

  cancel :: forall a. Control.Monad.Concurrent.Class.Fiber ConcurrentEffect a -> ConcurrentEffect Unit
  cancel fiber = ConcurrentEffect (Erl.exitProcess (fromFiberConcurrent fiber))
