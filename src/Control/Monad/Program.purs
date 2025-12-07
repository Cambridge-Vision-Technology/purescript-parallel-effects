module Control.Monad.Program
  ( Program
  , ProgramF(..)
  , lift
  , send
  , batch
  , peel
  , on
  , run
  , runParallel
  , runPure
  , impossibleVariant
  ) where

import Prelude

import Control.Applicative.Free as Control.Applicative.Free
import Control.Monad.Free as Control.Monad.Free
import Control.Parallel as Control.Parallel
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol (class IsSymbol)
import Effect as Effect
import Effect.Aff as Effect.Aff
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

data ProgramF r a = Batch (Control.Applicative.Free.FreeAp (Data.Functor.Variant.VariantF r) a)

derive instance Functor (ProgramF r)

newtype Program r a = Program (Control.Monad.Free.Free (ProgramF r) a)

derive newtype instance Functor (Program r)
derive newtype instance Bind (Program r)
derive newtype instance Monad (Program r)

-- | Lift an effect functor into Program at a specific label
lift
  :: forall sym r r' f a
   . Prim.Row.Cons sym f r' r
  => IsSymbol sym
  => Functor f
  => Type.Proxy.Proxy sym
  -> f a
  -> Program r a
lift proxy fa = send $ Data.Functor.Variant.inj proxy fa

-- | Send a VariantF directly into Program
send :: forall r a. Data.Functor.Variant.VariantF r a -> Program r a
send v = batch $ Control.Applicative.Free.liftFreeAp v

-- | Create a batch from a free applicative
batch :: forall r a. Control.Applicative.Free.FreeAp (Data.Functor.Variant.VariantF r) a -> Program r a
batch ap = Program $ Control.Monad.Free.liftF $ Batch ap

-- | Peel off the next effect from a Program computation
peel :: forall r a. Program r a -> Data.Either.Either (ProgramF r (Program r a)) a
peel (Program m) = case Control.Monad.Free.resume m of
  Data.Either.Left (Batch ap) -> Data.Either.Left (Batch (map Program ap))
  Data.Either.Right a -> Data.Either.Right a

-- | Pattern match on a specific effect in a VariantF
on
  :: forall sym f r1 r2 a b
   . IsSymbol sym
  => Prim.Row.Cons sym f r1 r2
  => Functor f
  => Type.Proxy.Proxy sym
  -> (f a -> b)
  -> (Data.Functor.Variant.VariantF r1 a -> b)
  -> Data.Functor.Variant.VariantF r2 a
  -> b
on = Data.Functor.Variant.on

-- | Type-safe handler for empty effect rows
-- | Since VariantF () is uninhabited, this handler proves that no effects exist
impossibleVariant :: forall x. Data.Functor.Variant.VariantF () x -> Effect.Aff.Aff x
impossibleVariant = Data.Functor.Variant.match {}

-- | Type-safe way to run Program with no effects
-- | This is the recommended way to execute Program () computations
runPure :: forall a. Program () a -> Effect.Aff.Aff a
runPure = runParallel impossibleVariant

run
  :: forall r a
   . (forall x. Data.Functor.Variant.VariantF r x -> Effect.Effect x)
  -> Program r a
  -> Effect.Effect a
run handler (Program free) =
  Control.Monad.Free.foldFree interpretBatch free
  where
  interpretBatch :: ProgramF r ~> Effect.Effect
  interpretBatch (Batch ap) = Control.Applicative.Free.foldFreeAp handler ap

runParallel
  :: forall r a
   . (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Program r a
  -> Effect.Aff.Aff a
runParallel handler (Program free) =
  Control.Monad.Free.foldFree interpretBatch free
  where
  interpretBatch :: ProgramF r ~> Effect.Aff.Aff
  interpretBatch (Batch ap) =
    Control.Parallel.sequential $ Control.Applicative.Free.foldFreeAp (Control.Parallel.parallel <<< handler) ap

-- Custom Apply/Applicative to merge adjacent batches when using <*>.
-- This ensures independent effects composed applicatively run in parallel.

instance applyProgram :: Apply (Program r) where
  apply = apBatch

instance applicativeProgram :: Applicative (Program r) where
  pure a = Program (pure a)

apBatch
  :: forall r a b
   . Program r (a -> b)
  -> Program r a
  -> Program r b
apBatch ff xx =
  case peel ff of
    Data.Either.Right f ->
      case peel xx of
        Data.Either.Right x ->
          pure (f x)
        Data.Either.Left (Batch apx) ->
          -- Map pure function over the inner Program produced by the batch,
          -- then flatten the nested Program.
          join (batch (map (map f) apx))
    Data.Either.Left (Batch apf) ->
      case peel xx of
        Data.Either.Right x ->
          -- Apply each produced function to the known argument, then flatten.
          join (batch (map (\brF -> (\g -> g x) <$> brF) apf))
        Data.Either.Left (Batch apx) ->
          -- Combine both batches into one, then continue recursively, flattening.
          join (batch (((\brF -> \brX -> apBatch brF brX) <$> apf) <*> apx))
