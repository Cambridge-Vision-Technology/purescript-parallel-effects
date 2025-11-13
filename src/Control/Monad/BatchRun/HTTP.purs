module Control.Monad.BatchRun.HTTP
  ( HttpF(..)
  , HTTP
  , _http
  , get
  , post
  , runHTTP
  , runHTTPAt
  ) where

import Prelude

import Affjax.Node as Affjax
import Affjax.RequestBody as RequestBody
import Affjax.ResponseFormat as ResponseFormat
import Control.Applicative.Free (FreeAp, foldFreeAp)
import Control.Monad.BatchRun (BatchRun, BatchF(..), lift, send, peel, on)
import Control.Parallel (parallel, sequential)
import Data.Either (Either(..))
import Data.Functor.Variant as V
import Data.HTTP.Method (Method(..))
import Data.Maybe (Maybe(..))
import Data.Symbol (class IsSymbol)
import Effect.Aff (Aff)
import Partial.Unsafe (unsafeCrashWith)
import Prim.Row as Row
import Type.Proxy (Proxy(..))

-- | HTTP effect row type - compose with other effects
-- | Example: BatchRun (HTTP (STATE String r)) Unit
type HTTP r = (http :: HttpF | r)

data HttpF a
  = Get String (String -> a)
  | Post String String (String -> a)

derive instance Functor HttpF

_http :: Proxy "http"
_http = Proxy

-- | HTTP GET request
get :: forall r. String -> BatchRun (HTTP r) String
get url = lift _http (Get url identity)

-- | HTTP POST request
post :: forall r. String -> String -> BatchRun (HTTP r) String
post url body = lift _http (Post url body identity)

-- | Handle HTTP effects, removing them from the effect row
-- | Transforms: BatchRun (HTTP r) a -> BatchRun r a
runHTTP :: forall r a. BatchRun (HTTP r) a -> Aff (BatchRun r a)
runHTTP = runHTTPAt _http

-- | Handle HTTP effects at a specific label
runHTTPAt
  :: forall sym q r a
   . IsSymbol sym
  => Row.Cons sym HttpF q r
  => Proxy sym
  -> BatchRun r a
  -> Aff (BatchRun q a)
runHTTPAt sym = loop
  where
  handle = on sym Left Right

  loop :: BatchRun r a -> Aff (BatchRun q a)
  loop br = case peel br of
    Right a ->
      pure $ pure a
    Left (Batch ap) -> do
      -- Interpret the batch in parallel, handling HTTP effects
      batchResult <- sequential $ foldFreeAp interpretOne ap
      loop batchResult

  interpretOne :: forall x. V.VariantF r x -> Aff (BatchRun q x)
  interpretOne v = case handle v of
    Left httpEff -> do
      -- This is our HTTP effect - handle it
      result <- handleHTTP httpEff
      pure $ pure result
    Right otherEff ->
      -- Different effect - pass it through
      pure $ send otherEff

  handleHTTP :: HttpF ~> Aff
  handleHTTP (Get url cont) = do
    result <- Affjax.get ResponseFormat.string url
    case result of
      Left err -> pure $ cont $ "Error: " <> Affjax.printError err
      Right response -> pure $ cont response.body

  handleHTTP (Post url body cont) = do
    result <- Affjax.post ResponseFormat.string url (Just $ RequestBody.string body)
    case result of
      Left err -> pure $ cont $ "Error: " <> Affjax.printError err
      Right response -> pure $ cont response.body
