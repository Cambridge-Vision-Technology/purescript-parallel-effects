module Control.Monad.Program.Reader
  ( ReaderF(..)
  , READER
  , _reader
  , ask
  , askAt
  , asks
  , asksAt
  , runReader
  , runReaderAt
  ) where

import Prelude

import Control.Monad.Program as Control.Monad.Program
import Control.Monad.Program.Aff as Control.Monad.Program.Aff
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol as Data.Symbol
import Effect.Aff as Effect.Aff
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

type READER e r = (reader :: ReaderF e | r)

data ReaderF e a = Ask (e -> a)

derive instance Functor (ReaderF e)

_reader :: Type.Proxy.Proxy "reader"
_reader = Type.Proxy.Proxy

-- | Labeled Reader operations (use these for multiple reader instances)

askAt
  :: forall sym e r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ReaderF e) r1 r2
  => Type.Proxy.Proxy sym
  -> Control.Monad.Program.Program r2 e
askAt sym = Control.Monad.Program.lift sym (Ask identity)

asksAt
  :: forall sym e r1 r2 a
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ReaderF e) r1 r2
  => Type.Proxy.Proxy sym
  -> (e -> a)
  -> Control.Monad.Program.Program r2 a
asksAt sym f = Control.Monad.Program.lift sym (Ask f)

runReaderAt
  :: forall sym e r1 r2 a
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ReaderF e) r1 r2
  => Type.Proxy.Proxy sym
  -> e
  -> (forall x. Data.Functor.Variant.VariantF r1 x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program r2 a
  -> Effect.Aff.Aff a
runReaderAt sym env handler = Control.Monad.Program.Aff.runParallel handlers
  where
  handlers :: forall x. Data.Functor.Variant.VariantF r2 x -> Effect.Aff.Aff x
  handlers = Data.Functor.Variant.on sym handleReader handler

  handleReader :: ReaderF e ~> Effect.Aff.Aff
  handleReader (Ask cont) = pure $ cont env

-- | Default Reader operations (convenience functions using default "reader" label)

ask :: forall e r. Control.Monad.Program.Program (READER e r) e
ask = askAt _reader

asks :: forall e r a. (e -> a) -> Control.Monad.Program.Program (READER e r) a
asks = asksAt _reader

runReader
  :: forall e r a
   . e
  -> (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program (READER e r) a
  -> Effect.Aff.Aff a
runReader = runReaderAt _reader
