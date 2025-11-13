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

import Control.Monad.BatchRun (BatchRun, lift, runParallel)
import Data.Functor.Variant (VariantF, on)
import Data.Tuple (Tuple(..))
import Effect.Aff (Aff)
import Effect.Aff.AVar (AVar)
import Effect.Aff.AVar as AVar
import Type.Proxy (Proxy(..))

type STATE s r = (state :: StateF s | r)

data StateF s a
  = Get (s -> a)
  | Put s a
  | Modify (s -> s) (s -> a)

derive instance Functor (StateF s)

_state :: Proxy "state"
_state = Proxy

get :: forall s r. BatchRun (STATE s r) s
get = lift _state (Get identity)

put :: forall s r. s -> BatchRun (STATE s r) Unit
put s = lift _state (Put s unit)

modify :: forall s r. (s -> s) -> BatchRun (STATE s r) s
modify f = lift _state (Modify f identity)

runState
  :: forall s r a
   . s
  -> (forall x. VariantF r x -> Aff x)
  -> BatchRun (STATE s r) a
  -> Aff (Tuple a s)
runState initialState handler prog = do
  stateVar <- AVar.new initialState
  result <- runParallel (\v -> on _state (handleStateOp stateVar) handler v) prog
  finalState <- AVar.read stateVar
  pure $ Tuple result finalState

handleStateOp :: forall s x. AVar s -> StateF s x -> Aff x
handleStateOp sv (Get cont) = do
  s <- AVar.read sv
  pure $ cont s
handleStateOp sv (Put s next) = do
  _ <- AVar.take sv
  _ <- AVar.put s sv
  pure next
handleStateOp sv (Modify f cont) = do
  s <- AVar.take sv
  let s' = f s
  _ <- AVar.put s' sv
  pure $ cont s'
