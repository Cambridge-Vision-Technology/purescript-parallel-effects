module Control.Monad.Program
  ( Program
  , ProgramF(..)
  , Handler
  , lift
  , send
  , batch
  , peel
  , on
  , run
  , runPar
  , impossibleVariantM
  ) where

import Prelude

import Control.Applicative.Free as Control.Applicative.Free
import Control.Monad.Concurrent.Class as Control.Monad.Concurrent.Class
import Control.Monad.Error.Class as Control.Monad.Error.Class
import Control.Monad.Free as Control.Monad.Free
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol (class IsSymbol)
import Effect as Effect
import Effect.Exception as Effect.Exception
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

-- | Generic type-safe handler for empty effect rows in any Applicative
-- | Since VariantF () is uninhabited, this handler proves that no effects exist
-- | and can be used with any monad (Aff, Effect, Identity, etc.)
impossibleVariantM :: forall m x. Applicative m => Data.Functor.Variant.VariantF () x -> m x
impossibleVariantM = Data.Functor.Variant.match {}

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

-- | Type alias for effect handlers
type Handler r m = forall x. Data.Functor.Variant.VariantF r x -> m x

-- | Run a Program with parallel execution using MonadConcurrent
-- |
-- | This is the generic version that works with any monad that has a
-- | MonadConcurrent instance. Effects composed with `<*>` are forked
-- | and run in parallel using the MonadConcurrent fork/join primitives.
runPar
  :: forall r a m
   . Control.Monad.Concurrent.Class.MonadConcurrent m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => Control.Monad.Rec.Class.MonadRec m
  => Handler r m
  -> Program r a
  -> m a
runPar handler (Program free) =
  Control.Monad.Free.foldFree interpretBatch free
  where
  interpretBatch :: ProgramF r ~> m
  interpretBatch (Batch ap) = foldFreeApPar handler ap

-- | Fold a FreeAp structure using MonadConcurrent for parallel execution
-- |
-- | This is the key function that enables parallel execution. When encountering
-- | an Ap node (function application), it forks both branches, joins them,
-- | and applies the function to the argument.
foldFreeApPar
  :: forall f m a
   . Control.Monad.Concurrent.Class.MonadConcurrent m
  => Control.Monad.Error.Class.MonadThrow Effect.Exception.Error m
  => (f ~> m)
  -> Control.Applicative.Free.FreeAp f a
  -> m a
foldFreeApPar nat freeAp = matchFreeApView onPure onLift onAp freeAp
  where
  onPure :: a -> m a
  onPure a = pure a

  onLift :: f a -> m a
  onLift fa = nat fa

  onAp :: forall x. Control.Applicative.Free.FreeAp f (x -> a) -> Control.Applicative.Free.FreeAp f x -> m a
  onAp fab fa = do
    fiberFab <- Control.Monad.Concurrent.Class.fork (foldFreeApPar nat fab)
    fiberFa <- Control.Monad.Concurrent.Class.fork (foldFreeApPar nat fa)
    resultFab <- Control.Monad.Concurrent.Class.join fiberFab
    resultFa <- Control.Monad.Concurrent.Class.join fiberFa
    case resultFab, resultFa of
      Data.Either.Right f, Data.Either.Right a' ->
        pure (f a')
      Data.Either.Left err, _ ->
        Control.Monad.Error.Class.throwError err
      _, Data.Either.Left err ->
        Control.Monad.Error.Class.throwError err

-- | Pattern match on FreeAp structure using continuation-passing style
-- |
-- | FreeAp is opaque, but we can inspect its structure at runtime
-- | by checking the constructor names from the JS/Erlang representation.
-- |
-- | This uses FFI to inspect the internal structure of FreeAp
-- | which has constructors Pure, Lift, and Ap.
-- |
-- | The existential type variable `x` in the Ap case is handled via
-- | the rank-2 callback, avoiding the need for unsafeCoerce.
foreign import matchFreeApView
  :: forall f a r
   . (a -> r)
  -> (f a -> r)
  -> (forall x. Control.Applicative.Free.FreeAp f (x -> a) -> Control.Applicative.Free.FreeAp f x -> r)
  -> Control.Applicative.Free.FreeAp f a
  -> r

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
          join (batch (map (map f) apx))
    Data.Either.Left (Batch apf) ->
      case peel xx of
        Data.Either.Right x ->
          join (batch (map (\brF -> (\g -> g x) <$> brF) apf))
        Data.Either.Left (Batch apx) ->
          join (batch (((\brF -> \brX -> apBatch brF brX) <$> apf) <*> apx))
