module Control.Monad.BatchRun.Reader
  ( ReaderF(..)
  , READER
  , _reader
  , ask
  , runReader
  ) where

import Prelude

import Control.Monad.BatchRun (BatchRun, lift, runParallel)
import Data.Functor.Variant (VariantF, on)
import Effect.Aff (Aff)
import Type.Proxy (Proxy(..))

type READER e r = (reader :: ReaderF e | r)

data ReaderF e a = Ask (e -> a)

derive instance Functor (ReaderF e)

_reader :: Proxy "reader"
_reader = Proxy

ask :: forall e r. BatchRun (READER e r) e
ask = lift _reader (Ask identity)

runReader
  :: forall e r a
   . e
  -> (forall x. VariantF r x -> Aff x)
  -> BatchRun (READER e r) a
  -> Aff a
runReader env handler = runParallel handlers
  where
  handlers :: forall x. VariantF (READER e r) x -> Aff x
  handlers = on _reader handleReader handler

  handleReader :: ReaderF e ~> Aff
  handleReader (Ask cont) = pure $ cont env
