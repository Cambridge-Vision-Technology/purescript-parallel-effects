-- | MonadConcurrent type class for structured concurrency.
-- |
-- | This module defines the abstract interface for concurrent operations.
-- | It is designed to be portable across JavaScript (Aff) and Erlang (Effect) backends.
-- |
-- | For the Aff instance (JavaScript), import Control.Monad.Concurrent.Aff
-- | For the Effect instance (Erlang), import Control.Monad.Concurrent.Effect
module Control.Monad.Concurrent.Class
  ( Fiber
  , class MonadConcurrent
  , fork
  , join
  , cancel
  , parTuple
  , parTraverseM
  ) where

import Prelude

import Data.Either as Data.Either
import Data.Traversable as Data.Traversable
import Data.Tuple as Data.Tuple
import Effect.Exception as Effect.Exception

-- | A fiber represents a concurrent computation running in monad `m`
-- | that will eventually produce a value of type `a`.
-- |
-- | This is an abstract type - concrete implementations will provide
-- | the actual representation (e.g., Aff.Fiber for Aff, Process for Erlang).
foreign import data Fiber :: (Type -> Type) -> Type -> Type

-- | The MonadConcurrent type class provides structured concurrency primitives
-- | for monads that support parallel execution.
-- |
-- | Laws:
-- | - fork-join identity: `fork ma >>= join = ma` (for successful computations)
-- | - cancel terminates: `fork ma >>= cancel` terminates the computation
-- |
-- | Minimal complete definition: `fork`, `join`, `cancel`
class Monad m <= MonadConcurrent m where
  -- | Fork a computation to run concurrently, returning a Fiber handle.
  -- |
  -- | The forked computation begins execution immediately and runs
  -- | independently of the parent computation.
  fork :: forall a. m a -> m (Fiber m a)

  -- | Wait for a fiber to complete and return its result.
  -- |
  -- | If the fiber completed successfully, returns `Right a`.
  -- | If the fiber failed with an error, returns `Left Error`.
  -- | If the fiber was cancelled, returns `Left Error` with a cancellation error.
  join :: forall a. Fiber m a -> m (Data.Either.Either Effect.Exception.Error a)

  -- | Cancel a running fiber.
  -- |
  -- | After cancellation, joining the fiber will return a cancellation error.
  -- | Cancellation is cooperative - the fiber may complete its current
  -- | operation before being terminated.
  cancel :: forall a. Fiber m a -> m Unit

-- | Run two computations in parallel and return both results as a tuple.
-- |
-- | Both computations run concurrently. If either fails, the error is returned.
-- |
-- | Example:
-- | ```purescript
-- | result <- parTuple (fetchUser 1) (fetchPosts 1)
-- | case result of
-- |   Right (Tuple user posts) -> -- both succeeded
-- |   Left err -> -- one or both failed
-- | ```
parTuple
  :: forall m a b
   . MonadConcurrent m
  => m a
  -> m b
  -> m (Data.Either.Either Effect.Exception.Error (Data.Tuple.Tuple a b))
parTuple ma mb = do
  fiberA <- fork ma
  fiberB <- fork mb
  resultA <- join fiberA
  resultB <- join fiberB
  pure case resultA, resultB of
    Data.Either.Right a, Data.Either.Right b -> Data.Either.Right (Data.Tuple.Tuple a b)
    Data.Either.Left err, _ -> Data.Either.Left err
    _, Data.Either.Left err -> Data.Either.Left err

-- | Traverse an array with a monadic function, running all computations in parallel.
-- |
-- | This is the concurrent equivalent of `traverse`. All computations are forked
-- | simultaneously, then all results are collected.
-- |
-- | Example:
-- | ```purescript
-- | results <- parTraverseM fetchUser [1, 2, 3]
-- | -- results :: Either Error (Array User)
-- | ```
parTraverseM
  :: forall m a b
   . MonadConcurrent m
  => (a -> m b)
  -> Array a
  -> m (Data.Either.Either Effect.Exception.Error (Array b))
parTraverseM f arr = do
  fibers <- Data.Traversable.traverse (fork <<< f) arr
  results <- Data.Traversable.traverse join fibers
  pure (Data.Traversable.sequence results)
