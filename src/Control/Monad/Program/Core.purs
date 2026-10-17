module Control.Monad.Program.Core
  ( Program
  , ProgramF(..)
  , lift
  , send
  , batch
  , peel
  , on
  , run
  ) where

import Prelude

import Control.Applicative.Free as Control.Applicative.Free
import Control.Monad.Free as Control.Monad.Free
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Newtype as Data.Newtype
import Data.Symbol as Data.Symbol
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

data ProgramF r a = Batch (Control.Applicative.Free.FreeAp (Data.Functor.Variant.VariantF r) a)

derive instance Functor (ProgramF r)

newtype Program r a = Program (Control.Monad.Free.Free (ProgramF r) a)

derive instance Data.Newtype.Newtype (Program r a) _
derive newtype instance Functor (Program r)
derive newtype instance Bind (Program r)
derive newtype instance Monad (Program r)

lift
  :: forall sym r r' f a
   . Prim.Row.Cons sym f r' r
  => Data.Symbol.IsSymbol sym
  => Functor f
  => Type.Proxy.Proxy sym
  -> f a
  -> Program r a
lift proxy fa = send $ Data.Functor.Variant.inj proxy fa

send :: forall r a. Data.Functor.Variant.VariantF r a -> Program r a
send v = batch $ Control.Applicative.Free.liftFreeAp v

batch :: forall r a. Control.Applicative.Free.FreeAp (Data.Functor.Variant.VariantF r) a -> Program r a
batch ap = Program $ Control.Monad.Free.liftF $ Batch ap

peel :: forall r a. Program r a -> Data.Either.Either (ProgramF r (Program r a)) a
peel (Program m) = case Control.Monad.Free.resume m of
  Data.Either.Left (Batch ap) -> Data.Either.Left (Batch (map Program ap))
  Data.Either.Right a -> Data.Either.Right a

on
  :: forall sym f r1 r2 a b
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym f r1 r2
  => Functor f
  => Type.Proxy.Proxy sym
  -> (f a -> b)
  -> (Data.Functor.Variant.VariantF r1 a -> b)
  -> Data.Functor.Variant.VariantF r2 a
  -> b
on = Data.Functor.Variant.on

run
  :: forall r m a
   . Control.Monad.Rec.Class.MonadRec m
  => (forall x. Data.Functor.Variant.VariantF r x -> m x)
  -> Program r a
  -> m a
run handler (Program free) = Control.Monad.Free.foldFree interpretBatch free
  where
  interpretBatch :: ProgramF r ~> m
  interpretBatch (Batch ap) = Control.Applicative.Free.foldFreeAp handler ap

instance applyProgram :: Apply (Program r) where
  apply = apBatch

instance applicativeProgram :: Applicative (Program r) where
  pure a = Program (pure a)

apBatch :: forall r a b. Program r (a -> b) -> Program r a -> Program r b
apBatch ff xx = case peel ff of
  Data.Either.Right f -> case peel xx of
    Data.Either.Right x -> pure (f x)
    Data.Either.Left (Batch apx) -> join (batch (map (map f) apx))
  Data.Either.Left (Batch apf) -> case peel xx of
    Data.Either.Right x -> join (batch (map (\brF -> (\g -> g x) <$> brF) apf))
    Data.Either.Left (Batch apx) -> join (batch (((\brF -> \brX -> apBatch brF brX) <$> apf) <*> apx))
