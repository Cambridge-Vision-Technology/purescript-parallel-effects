module Control.Monad.BatchRun.Reader
  ( ReaderF(..)
  , READER
  , _reader
  , ask
  , runReader
  ) where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Data.Functor.Variant as Data.Functor.Variant
import Effect.Aff as Effect.Aff
import Type.Proxy as Type.Proxy

type READER e r = (reader :: ReaderF e | r)

data ReaderF e a = Ask (e -> a)

derive instance Functor (ReaderF e)

_reader :: Type.Proxy.Proxy "reader"
_reader = Type.Proxy.Proxy

ask :: forall e r. Control.Monad.BatchRun.BatchRun (READER e r) e
ask = Control.Monad.BatchRun.lift _reader (Ask identity)

runReader
  :: forall e r a
   . e
  -> (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.BatchRun.BatchRun (READER e r) a
  -> Effect.Aff.Aff a
runReader env handler = Control.Monad.BatchRun.runParallel handlers
  where
  handlers :: forall x. Data.Functor.Variant.VariantF (READER e r) x -> Effect.Aff.Aff x
  handlers = Data.Functor.Variant.on _reader handleReader handler

  handleReader :: ReaderF e ~> Effect.Aff.Aff
  handleReader (Ask cont) = pure $ cont env
