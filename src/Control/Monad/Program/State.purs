module Control.Monad.Program.State
  ( StateF(..)
  , STATE
  , _state
  , get
  , getAt
  , put
  , putAt
  , modify
  , modifyAt
  , runState
  , runStateAt
  ) where

import Prelude

import Control.Monad.Program as Control.Monad.Program
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol as Data.Symbol
import Data.Tuple as Data.Tuple
import Effect.Aff as Effect.Aff
import Effect.Aff.AVar as Effect.Aff.AVar
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

type STATE s r = (state :: StateF s | r)

data StateF s a
  = Get (s -> a)
  | Put s a
  | Modify (s -> s) (s -> a)

derive instance Functor (StateF s)

_state :: Type.Proxy.Proxy "state"
_state = Type.Proxy.Proxy

-- | Labeled State operations (use these for multiple state instances)

getAt
  :: forall sym s r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (StateF s) r1 r2
  => Type.Proxy.Proxy sym
  -> Control.Monad.Program.Program r2 s
getAt sym = Control.Monad.Program.lift sym (Get identity)

putAt
  :: forall sym s r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (StateF s) r1 r2
  => Type.Proxy.Proxy sym
  -> s
  -> Control.Monad.Program.Program r2 Unit
putAt sym s = Control.Monad.Program.lift sym (Put s unit)

modifyAt
  :: forall sym s r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (StateF s) r1 r2
  => Type.Proxy.Proxy sym
  -> (s -> s)
  -> Control.Monad.Program.Program r2 s
modifyAt sym f = Control.Monad.Program.lift sym (Modify f identity)

runStateAt
  :: forall sym s r1 r2 a
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (StateF s) r1 r2
  => Type.Proxy.Proxy sym
  -> s
  -> (forall x. Data.Functor.Variant.VariantF r1 x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program r2 a
  -> Effect.Aff.Aff (Data.Tuple.Tuple a s)
runStateAt sym initialState handler prog = do
  stateVar <- Effect.Aff.AVar.new initialState
  result <- Control.Monad.Program.runParallel (\v -> Data.Functor.Variant.on sym (handleStateOp stateVar) handler v) prog
  finalState <- Effect.Aff.AVar.read stateVar
  pure $ Data.Tuple.Tuple result finalState

-- | Default State operations (convenience functions using default "state" label)

get :: forall s r. Control.Monad.Program.Program (STATE s r) s
get = getAt _state

put :: forall s r. s -> Control.Monad.Program.Program (STATE s r) Unit
put = putAt _state

modify :: forall s r. (s -> s) -> Control.Monad.Program.Program (STATE s r) s
modify = modifyAt _state

runState
  :: forall s r a
   . s
  -> (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program (STATE s r) a
  -> Effect.Aff.Aff (Data.Tuple.Tuple a s)
runState = runStateAt _state

-- | Internal handler for State operations

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
