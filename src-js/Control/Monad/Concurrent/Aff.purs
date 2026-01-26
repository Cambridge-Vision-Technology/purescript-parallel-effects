-- | MonadConcurrent instance for Aff (JavaScript backend).
-- |
-- | This module provides the MonadConcurrent instance for ConcurrentAff,
-- | a newtype wrapper around Aff that enables concurrent execution
-- | on the JavaScript/Node.js backend.
-- |
-- | Usage:
-- | ```purescript
-- | import Control.Monad.Concurrent.Aff (ConcurrentAff(..), runConcurrentAff)
-- | import Control.Monad.Concurrent.Class (fork, join, parTuple)
-- |
-- | myProgram :: ConcurrentAff Int
-- | myProgram = do
-- |   fiber <- fork (delay (Milliseconds 100.0) *> pure 42)
-- |   result <- join fiber
-- |   pure (fromRight 0 result)
-- |
-- | main = launchAff_ (runConcurrentAff myProgram)
-- | ```
module Control.Monad.Concurrent.Aff
  ( ConcurrentAff(..)
  , runConcurrentAff
  , module Control.Monad.Concurrent.Class
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Control.Monad.Concurrent.Class
import Control.Monad.Error.Class as Control.Monad.Error.Class
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Either as Data.Either
import Data.Newtype as Data.Newtype
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Aff.Class as Effect.Aff.Class
import Effect.Class as Effect.Class
import Effect.Exception as Effect.Exception

-- | A newtype wrapper around Aff that provides MonadConcurrent.
-- |
-- | This wrapper is necessary to satisfy PureScript's orphan instance rules.
-- | Use `ConcurrentAff` to wrap Aff computations that need concurrent execution,
-- | and `runConcurrentAff` to unwrap them back to Aff.
newtype ConcurrentAff a = ConcurrentAff (Effect.Aff.Aff a)

derive instance Data.Newtype.Newtype (ConcurrentAff a) _
derive newtype instance Functor ConcurrentAff
derive newtype instance Apply ConcurrentAff
derive newtype instance Applicative ConcurrentAff
derive newtype instance Bind ConcurrentAff
derive newtype instance Monad ConcurrentAff
derive newtype instance Effect.Class.MonadEffect ConcurrentAff
derive newtype instance Effect.Aff.Class.MonadAff ConcurrentAff
derive newtype instance Control.Monad.Error.Class.MonadThrow Effect.Exception.Error ConcurrentAff
derive newtype instance Control.Monad.Error.Class.MonadError Effect.Exception.Error ConcurrentAff
derive newtype instance Control.Monad.Rec.Class.MonadRec ConcurrentAff

-- | Unwrap a ConcurrentAff computation to run it as Aff.
runConcurrentAff :: forall a. ConcurrentAff a -> Effect.Aff.Aff a
runConcurrentAff (ConcurrentAff aff) = aff

-- | MonadConcurrent instance for ConcurrentAff.
-- |
-- | This implementation uses Aff's built-in fiber system for concurrent execution.
-- |
-- | - fork: Uses Aff.forkAff to spawn a concurrent fiber
-- | - join: Uses Aff.joinFiber wrapped with attempt to return Either Error a
-- | - cancel: Uses Aff.killFiber to terminate the fiber
instance Control.Monad.Concurrent.Class.MonadConcurrent ConcurrentAff where
  fork (ConcurrentAff ma) = ConcurrentAff do
    affFiber <- Effect.Aff.forkAff ma
    Effect.Class.liftEffect (suppressRethrow affFiber)
    pure (toFiber affFiber)

  join fiber = ConcurrentAff do
    Effect.Aff.attempt (Effect.Aff.joinFiber (fromFiber fiber))

  cancel fiber = ConcurrentAff do
    Effect.Aff.killFiber (Effect.Exception.error "Cancelled") (fromFiber fiber)

-- | Convert an Aff.Fiber to our abstract Fiber type.
-- | These are structurally identical at runtime - this is an identity function
-- | implemented via FFI to avoid using unsafeCoerce.
foreign import toFiber :: forall a. Effect.Aff.Fiber a -> Control.Monad.Concurrent.Class.Fiber ConcurrentAff a

-- | Convert our abstract Fiber type back to Aff.Fiber.
-- | These are structurally identical at runtime - this is an identity function
-- | implemented via FFI to avoid using unsafeCoerce.
foreign import fromFiber :: forall a. Control.Monad.Concurrent.Class.Fiber ConcurrentAff a -> Effect.Aff.Fiber a

-- | Suppress the "rethrow on unjoined error" behavior for a fiber.
-- |
-- | Aff fibers by default will rethrow errors if they complete with an error
-- | before being joined. We suppress this because we want errors to be
-- | delivered through join() as Left values, not thrown as exceptions.
-- |
-- | This must be called immediately after forking to ensure errors are
-- | delivered through join() rather than being thrown as uncaught exceptions.
foreign import suppressRethrow :: forall a. Effect.Aff.Fiber a -> Effect.Effect Unit
