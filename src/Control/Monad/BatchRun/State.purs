module Control.Monad.BatchRun.State
  ( StateF(..)
  , STATE
  , _state
  , get
  , put
  , modify
  , runState
  ) where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Data.Functor.Variant as Data.Functor.Variant
import Data.Tuple as Data.Tuple
import Effect.Aff as Effect.Aff
import Effect.Aff.AVar as Effect.Aff.AVar
import Type.Proxy as Type.Proxy

type STATE s r = (state :: StateF s | r)

data StateF s a
  = Get (s -> a)
  | Put s a
  | Modify (s -> s) (s -> a)

derive instance Functor (StateF s)

_state :: Type.Proxy.Proxy "state"
_state = Type.Proxy.Proxy

get :: forall s r. Control.Monad.BatchRun.BatchRun (STATE s r) s
get = Control.Monad.BatchRun.lift _state (Get identity)

put :: forall s r. s -> Control.Monad.BatchRun.BatchRun (STATE s r) Unit
put s = Control.Monad.BatchRun.lift _state (Put s unit)

modify :: forall s r. (s -> s) -> Control.Monad.BatchRun.BatchRun (STATE s r) s
modify f = Control.Monad.BatchRun.lift _state (Modify f identity)

runState
  :: forall s r a
   . s
  -> (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.BatchRun.BatchRun (STATE s r) a
  -> Effect.Aff.Aff (Data.Tuple.Tuple a s)
runState initialState handler prog = do
  stateVar <- Effect.Aff.AVar.new initialState
  result <- Control.Monad.BatchRun.runParallel (\v -> Data.Functor.Variant.on _state (handleStateOp stateVar) handler v) prog
  finalState <- Effect.Aff.AVar.read stateVar
  pure $ Data.Tuple.Tuple result finalState

handleStateOp :: forall s x. Effect.Aff.AVar.AVar s -> StateF s x -> Effect.Aff.Aff x
handleStateOp sv (Get cont) = do
  s <- Effect.Aff.AVar.read sv
  pure $ cont s
handleStateOp sv (Put s next) = do
  _ <- Effect.Aff.AVar.take sv
  _ <- Effect.Aff.AVar.put s sv
  pure next
handleStateOp sv (Modify f cont) = do
  s <- Effect.Aff.AVar.take sv
  let s' = f s
  _ <- Effect.Aff.AVar.put s' sv
  pure $ cont s'
