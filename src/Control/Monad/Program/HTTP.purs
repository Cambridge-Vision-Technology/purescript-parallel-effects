module Control.Monad.Program.HTTP
  ( HttpF(..)
  , HTTP
  , _http
  , get
  , post
  , runHTTP
  , runHTTPAt
  ) where

import Prelude

import Affjax.Node as Affjax.Node
import Affjax.RequestBody as Affjax.RequestBody
import Affjax.ResponseFormat as Affjax.ResponseFormat
import Control.Applicative.Free as Control.Applicative.Free
import Control.Monad.Program as Control.Monad.Program
import Control.Parallel as Control.Parallel
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.HTTP.Method as Data.HTTP.Method
import Data.Maybe as Data.Maybe
import Data.Symbol (class IsSymbol)
import Effect.Aff as Effect.Aff
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

-- | HTTP effect row type - compose with other effects
-- | Example: Program (HTTP (STATE String r)) Unit
type HTTP r = (http :: HttpF | r)

data HttpF a
  = Get String (String -> a)
  | Post String String (String -> a)

derive instance Functor HttpF

_http :: Type.Proxy.Proxy "http"
_http = Type.Proxy.Proxy

-- | HTTP GET request
get :: forall r. String -> Control.Monad.Program.Program (HTTP r) String
get url = Control.Monad.Program.lift _http (Get url identity)

-- | HTTP POST request
post :: forall r. String -> String -> Control.Monad.Program.Program (HTTP r) String
post url body = Control.Monad.Program.lift _http (Post url body identity)

-- | Handle HTTP effects for programs with only HTTP (no other effects)
runHTTP :: forall a. Control.Monad.Program.Program (HTTP ()) a -> Effect.Aff.Aff a
runHTTP = runHTTPAt _http Control.Monad.Program.impossibleVariant

-- | Handle HTTP effects at a specific label
runHTTPAt
  :: forall sym q r a
   . IsSymbol sym
  => Prim.Row.Cons sym HttpF q r
  => Type.Proxy.Proxy sym
  -> (forall x. Data.Functor.Variant.VariantF q x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program r a
  -> Effect.Aff.Aff a
runHTTPAt sym handler prog =
  Control.Monad.Program.runParallel (\v -> Control.Monad.Program.on sym handleHTTP handler v) prog
  where
  handleHTTP :: HttpF ~> Effect.Aff.Aff
  handleHTTP (Get url cont) = do
    result <- Affjax.Node.get Affjax.ResponseFormat.string url
    case result of
      Data.Either.Left err -> pure $ cont $ "Error: " <> Affjax.Node.printError err
      Data.Either.Right response -> pure $ cont response.body

  handleHTTP (Post url body cont) = do
    result <- Affjax.Node.post Affjax.ResponseFormat.string url (Data.Maybe.Just $ Affjax.RequestBody.string body)
    case result of
      Data.Either.Left err -> pure $ cont $ "Error: " <> Affjax.Node.printError err
      Data.Either.Right response -> pure $ cont response.body
