module Control.Monad.BatchRun
  ( BatchRun
  , BatchF(..)
  , lift
  , send
  , batch
  , peel
  , on
  , run
  , runParallel
  , extract
  ) where

import Prelude

import Control.Applicative.Free (FreeAp, liftFreeAp, foldFreeAp)
import Control.Monad.Free (Free, liftF, foldFree, resume)
import Control.Parallel (parallel, sequential)
import Data.Either (Either(..))
import Data.Functor.Variant (VariantF, inj, on) as V
import Data.Symbol (class IsSymbol)
import Effect (Effect)
import Effect.Aff (Aff)
import Partial.Unsafe (unsafeCrashWith)
import Prim.Row as Row
import Type.Proxy (Proxy(..))

data BatchF r a = Batch (FreeAp (V.VariantF r) a)

derive instance Functor (BatchF r)

newtype BatchRun r a = BatchRun (Free (BatchF r) a)

derive newtype instance Functor (BatchRun r)
derive newtype instance Apply (BatchRun r)
derive newtype instance Applicative (BatchRun r)
derive newtype instance Bind (BatchRun r)
derive newtype instance Monad (BatchRun r)

-- | Lift an effect functor into BatchRun at a specific label
lift
  :: forall sym r r' f a
   . Row.Cons sym f r' r
  => IsSymbol sym
  => Functor f
  => Proxy sym
  -> f a
  -> BatchRun r a
lift proxy fa = send $ V.inj proxy fa

-- | Send a VariantF directly into BatchRun
send :: forall r a. V.VariantF r a -> BatchRun r a
send v = batch $ liftFreeAp v

-- | Create a batch from a free applicative
batch :: forall r a. FreeAp (V.VariantF r) a -> BatchRun r a
batch ap = BatchRun $ liftF $ Batch ap

-- | Peel off the next effect from a BatchRun computation
peel :: forall r a. BatchRun r a -> Either (BatchF r (BatchRun r a)) a
peel (BatchRun m) = case resume m of
  Left (Batch ap) -> Left (Batch (map BatchRun ap))
  Right a -> Right a

-- | Pattern match on a specific effect in a VariantF
on
  :: forall sym f r1 r2 a b
   . IsSymbol sym
  => Row.Cons sym f r1 r2
  => Functor f
  => Proxy sym
  -> (f a -> b)
  -> (V.VariantF r1 a -> b)
  -> V.VariantF r2 a
  -> b
on = V.on

-- | Extract a pure value from BatchRun (requires empty effect row)
extract :: forall a. BatchRun () a -> a
extract (BatchRun m) = case resume m of
  Right a -> a
  Left _ -> unsafeCrashWith "BatchRun.extract: impossible - effect row should be empty"

run
  :: forall r a
   . (forall x. V.VariantF r x -> Effect x)
  -> BatchRun r a
  -> Effect a
run handler (BatchRun free) =
  foldFree interpretBatch free
  where
  interpretBatch :: BatchF r ~> Effect
  interpretBatch (Batch ap) = foldFreeAp handler ap

runParallel
  :: forall r a
   . (forall x. V.VariantF r x -> Aff x)
  -> BatchRun r a
  -> Aff a
runParallel handler (BatchRun free) =
  foldFree interpretBatch free
  where
  interpretBatch :: BatchF r ~> Aff
  interpretBatch (Batch ap) =
    sequential $ foldFreeAp (parallel <<< handler) ap
