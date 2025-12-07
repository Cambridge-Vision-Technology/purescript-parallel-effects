module Control.Monad.Program.Except
  ( ExceptF(..)
  , EXCEPT
  , FAIL
  , _except
  , throw
  , throwAt
  , fail
  , failAt
  , runExcept
  , runExceptAt
  , rethrow
  , rethrowAt
  , note
  , noteAt
  , fromJust
  , fromJustAt
  ) where

import Prelude

import Control.Monad.Program as Control.Monad.Program
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Maybe as Data.Maybe
import Data.Symbol as Data.Symbol
import Effect.Aff as Effect.Aff
import Effect.Aff.AVar as Effect.Aff.AVar
import Effect.Exception as Effect.Exception
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

type EXCEPT e r = (except :: ExceptF e | r)

type FAIL r = (except :: ExceptF Unit | r)

newtype ExceptF e a = ExceptF e

derive instance Functor (ExceptF e)

_except :: Type.Proxy.Proxy "except"
_except = Type.Proxy.Proxy

-- | Labeled Except operations (use these for multiple exception types)

throwAt
  :: forall sym e a r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ExceptF e) r1 r2
  => Type.Proxy.Proxy sym
  -> e
  -> Control.Monad.Program.Program r2 a
throwAt sym e = Control.Monad.Program.lift sym (ExceptF e)

failAt
  :: forall sym a r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ExceptF Unit) r1 r2
  => Type.Proxy.Proxy sym
  -> Control.Monad.Program.Program r2 a
failAt sym = throwAt sym unit

runExceptAt
  :: forall sym e a r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ExceptF e) r1 r2
  => Type.Proxy.Proxy sym
  -> (forall x. Data.Functor.Variant.VariantF r1 x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program r2 a
  -> Effect.Aff.Aff (Data.Either.Either e a)
runExceptAt sym handler prog = do
  -- Create an empty AVar to store the exception value
  exceptVar <- Effect.Aff.AVar.empty

  -- Run the program with exception handling
  result <- Effect.Aff.attempt $ Control.Monad.Program.runParallel (handlers exceptVar) prog

  case result of
    Data.Either.Left err -> do
      -- An exception was thrown, check if we stored a value
      maybeExcept <- Effect.Aff.AVar.tryRead exceptVar
      case maybeExcept of
        Data.Maybe.Just e ->
          -- This was an Except exception
          pure $ Data.Either.Left e
        Data.Maybe.Nothing ->
          -- This was a real Aff error, re-throw
          Effect.Aff.throwError err
    Data.Either.Right a ->
      pure $ Data.Either.Right a
  where
  handlers :: Effect.Aff.AVar.AVar e -> forall x. Data.Functor.Variant.VariantF r2 x -> Effect.Aff.Aff x
  handlers exceptVar' = Data.Functor.Variant.on sym (handleExcept exceptVar') handler

  handleExcept :: Effect.Aff.AVar.AVar e -> ExceptF e ~> Effect.Aff.Aff
  handleExcept exceptVar' (ExceptF e) = do
    -- Store the exception value and throw
    _ <- Effect.Aff.AVar.tryPut e exceptVar'
    Effect.Aff.throwError (Effect.Exception.error "Program.Except")

rethrowAt
  :: forall sym e a r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ExceptF e) r1 r2
  => Type.Proxy.Proxy sym
  -> Data.Either.Either e a
  -> Control.Monad.Program.Program r2 a
rethrowAt sym = case _ of
  Data.Either.Left e -> throwAt sym e
  Data.Either.Right a -> pure a

noteAt
  :: forall sym e a r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ExceptF e) r1 r2
  => Type.Proxy.Proxy sym
  -> e
  -> Data.Maybe.Maybe a
  -> Control.Monad.Program.Program r2 a
noteAt sym e = case _ of
  Data.Maybe.Nothing -> throwAt sym e
  Data.Maybe.Just a -> pure a

fromJustAt
  :: forall sym a r1 r2
   . Data.Symbol.IsSymbol sym
  => Prim.Row.Cons sym (ExceptF Unit) r1 r2
  => Type.Proxy.Proxy sym
  -> Data.Maybe.Maybe a
  -> Control.Monad.Program.Program r2 a
fromJustAt sym = noteAt sym unit

-- | Default Except operations (convenience functions using default "except" label)

throw :: forall e a r. e -> Control.Monad.Program.Program (EXCEPT e r) a
throw = throwAt _except

fail :: forall a r. Control.Monad.Program.Program (FAIL r) a
fail = failAt _except

runExcept
  :: forall e a r
   . (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program (EXCEPT e r) a
  -> Effect.Aff.Aff (Data.Either.Either e a)
runExcept = runExceptAt _except

rethrow :: forall e a r. Data.Either.Either e a -> Control.Monad.Program.Program (EXCEPT e r) a
rethrow = rethrowAt _except

note :: forall e a r. e -> Data.Maybe.Maybe a -> Control.Monad.Program.Program (EXCEPT e r) a
note = noteAt _except

fromJust :: forall a r. Data.Maybe.Maybe a -> Control.Monad.Program.Program (FAIL r) a
fromJust = fromJustAt _except
