module Control.Monad.Program.Writer
  ( WriterF(..)
  , WRITER
  , _writer
  , tell
  , tellAt
  , runWriter
  , runWriterAt
  ) where

import Prelude

import Control.Monad.Program as Control.Monad.Program
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol as Data.Symbol
import Data.Tuple as Data.Tuple
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Ref as Effect.Ref
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

type WRITER w r = (writer :: WriterF w | r)

data WriterF w a = Tell w a

derive instance Functor (WriterF w)

_writer :: Type.Proxy.Proxy "writer"
_writer = Type.Proxy.Proxy

-- | Labeled Writer operations (use these for multiple writer instances)

tellAt
  :: forall sym w r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (WriterF w) r1 r2
  => Type.Proxy.Proxy sym
  -> w
  -> Control.Monad.Program.Program r2 Unit
tellAt sym w = Control.Monad.Program.lift sym (Tell w unit)

runWriterAt
  :: forall sym w r1 r2 a
   . Data.Symbol.IsSymbol sym
  => Monoid w
  => Prim.Row.Cons sym (WriterF w) r1 r2
  => Type.Proxy.Proxy sym
  -> (forall x. Data.Functor.Variant.VariantF r1 x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program r2 a
  -> Effect.Aff.Aff (Data.Tuple.Tuple w a)
runWriterAt sym handler prog = do
  ref <- Effect.Class.liftEffect $ Effect.Ref.new mempty
  result <- Control.Monad.Program.runParallel (handlers ref) prog
  log <- Effect.Class.liftEffect $ Effect.Ref.read ref
  pure $ Data.Tuple.Tuple log result
  where
  handlers :: Effect.Ref.Ref w -> forall x. Data.Functor.Variant.VariantF r2 x -> Effect.Aff.Aff x
  handlers ref = Data.Functor.Variant.on sym (handleWriter ref) handler

  handleWriter :: Effect.Ref.Ref w -> WriterF w ~> Effect.Aff.Aff
  handleWriter ref (Tell w next) = do
    Effect.Class.liftEffect $ Effect.Ref.modify_ (_ <> w) ref
    pure next

-- | Default Writer operations (convenience functions using default "writer" label)

tell :: forall w r. w -> Control.Monad.Program.Program (WRITER w r) Unit
tell = tellAt _writer

runWriter
  :: forall w r a
   . Monoid w
  => (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program (WRITER w r) a
  -> Effect.Aff.Aff (Data.Tuple.Tuple w a)
runWriter = runWriterAt _writer
