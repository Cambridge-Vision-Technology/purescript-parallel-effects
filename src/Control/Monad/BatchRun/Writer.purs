module Control.Monad.BatchRun.Writer
  ( WriterF(..)
  , WRITER
  , _writer
  , tell
  , runWriter
  ) where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Data.Functor.Variant as Data.Functor.Variant
import Data.Tuple as Data.Tuple
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Ref as Effect.Ref
import Type.Proxy as Type.Proxy

type WRITER w r = (writer :: WriterF w | r)

data WriterF w a = Tell w a

derive instance Functor (WriterF w)

_writer :: Type.Proxy.Proxy "writer"
_writer = Type.Proxy.Proxy

-- | Write a value to the writer log
tell :: forall w r. w -> Control.Monad.BatchRun.BatchRun (WRITER w r) Unit
tell w = Control.Monad.BatchRun.lift _writer (Tell w unit)

-- | Run a Writer computation, collecting all written values via a Monoid
runWriter
  :: forall w r a
   . Monoid w
  => (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.BatchRun.BatchRun (WRITER w r) a
  -> Effect.Aff.Aff (Data.Tuple.Tuple w a)
runWriter handler prog = do
  ref <- Effect.Class.liftEffect $ Effect.Ref.new mempty
  result <- Control.Monad.BatchRun.runParallel (handlers ref) prog
  log <- Effect.Class.liftEffect $ Effect.Ref.read ref
  pure $ Data.Tuple.Tuple log result
  where
  handlers :: Effect.Ref.Ref w -> forall x. Data.Functor.Variant.VariantF (WRITER w r) x -> Effect.Aff.Aff x
  handlers ref = Data.Functor.Variant.on _writer (handleWriter ref) handler

  handleWriter :: Effect.Ref.Ref w -> WriterF w ~> Effect.Aff.Aff
  handleWriter ref (Tell w next) = do
    Effect.Class.liftEffect $ Effect.Ref.modify_ (_ <> w) ref
    pure next
