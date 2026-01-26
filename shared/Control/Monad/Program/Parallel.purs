module Control.Monad.Program.Parallel
  ( par2
  , par3
  , gather
  , parTraverse
  , parTraverse_
  ) where

import Prelude

import Control.Monad.Program as Control.Monad.Program
import Data.Array as Data.Array
import Data.Tuple as Data.Tuple

-- | Execute two computations in parallel and return both results as a Tuple.
-- |
-- | This is a convenience wrapper around applicative composition that makes
-- | the intent of parallel execution explicit.
-- |
-- | Example:
-- | ```purescript
-- | result <- par2 (get "/users/1") (get "/posts/1")
-- | -- result :: Tuple User Post
-- | ```
par2
  :: forall r a b
   . Control.Monad.Program.Program r a
  -> Control.Monad.Program.Program r b
  -> Control.Monad.Program.Program r (Data.Tuple.Tuple a b)
par2 fa fb = Data.Tuple.Tuple <$> fa <*> fb

-- | Execute three computations in parallel and return all results as a 3-Tuple.
-- |
-- | Example:
-- | ```purescript
-- | result <- par3 (get "/users/1") (get "/posts/1") (get "/comments/1")
-- | -- result :: Tuple3 User Post Comment
-- | ```
par3
  :: forall r a b c
   . Control.Monad.Program.Program r a
  -> Control.Monad.Program.Program r b
  -> Control.Monad.Program.Program r c
  -> Control.Monad.Program.Program r (Data.Tuple.Tuple a (Data.Tuple.Tuple b c))
par3 fa fb fc = Data.Tuple.Tuple <$> fa <*> (Data.Tuple.Tuple <$> fb <*> fc)

-- | Execute an array of computations in parallel and gather all results.
-- |
-- | This runs all computations concurrently and collects their results in the
-- | same order as the input array.
-- |
-- | Example:
-- | ```purescript
-- | urls <- ["/users/1", "/users/2", "/users/3"]
-- | users <- gather (map get urls)
-- | -- users :: Array User
-- | ```
gather
  :: forall r a
   . Array (Control.Monad.Program.Program r a)
  -> Control.Monad.Program.Program r (Array a)
gather = Data.Array.foldr cons nil
  where
  nil = pure []
  cons x xs = Data.Array.cons <$> x <*> xs

-- | Map each element of an array to a computation and execute all in parallel.
-- |
-- | This is the parallel equivalent of `traverse`. It maps the function over
-- | the array and then executes all resulting computations concurrently.
-- |
-- | Example:
-- | ```purescript
-- | userIds <- [1, 2, 3]
-- | users <- parTraverse (\id -> get ("/users/" <> show id)) userIds
-- | -- users :: Array User
-- | ```
parTraverse
  :: forall r a b
   . (a -> Control.Monad.Program.Program r b)
  -> Array a
  -> Control.Monad.Program.Program r (Array b)
parTraverse f arr = gather (map f arr)

-- | Like `parTraverse` but discards the results.
-- |
-- | Useful when you only care about the effects, not the return values.
-- |
-- | Example:
-- | ```purescript
-- | urls <- ["/api/log/1", "/api/log/2", "/api/log/3"]
-- | parTraverse_ post urls
-- | ```
parTraverse_
  :: forall r a b
   . (a -> Control.Monad.Program.Program r b)
  -> Array a
  -> Control.Monad.Program.Program r Unit
parTraverse_ f arr = void (parTraverse f arr)
