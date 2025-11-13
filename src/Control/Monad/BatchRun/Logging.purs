module Control.Monad.BatchRun.Logging
  ( LoggingF(..)
  , LOGGING
  , LogLevel(..)
  , _logging
  , log
  , debug
  , info
  , warn
  , error
  , runLogging
  , runLoggingAt
  ) where

import Prelude hiding (log)

import Control.Applicative.Free (FreeAp, foldFreeAp)
import Control.Monad.BatchRun (BatchRun, BatchF(..), lift, send, peel, on, runParallel)
import Control.Parallel (parallel, sequential)
import Data.Either (Either(..))
import Data.Functor.Variant as V
import Data.Symbol (class IsSymbol)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Console as Console
import Partial.Unsafe (unsafeCrashWith)
import Prim.Row as Row
import Type.Proxy (Proxy(..))

-- | LOGGING effect row type
-- | Example: BatchRun (LOGGING (FILE_SYSTEM r)) Unit
type LOGGING r = (logging :: LoggingF | r)

data LogLevel = Debug | Info | Warn | Error

derive instance Eq LogLevel
derive instance Ord LogLevel

instance Show LogLevel where
  show Debug = "DEBUG"
  show Info = "INFO"
  show Warn = "WARN"
  show Error = "ERROR"

data LoggingF a = Log LogLevel String a

derive instance Functor LoggingF

_logging :: Proxy "logging"
_logging = Proxy

-- | Generic log with level
log :: forall r. LogLevel -> String -> BatchRun (LOGGING r) Unit
log level msg = lift _logging (Log level msg unit)

-- | Debug level log
debug :: forall r. String -> BatchRun (LOGGING r) Unit
debug = log Debug

-- | Info level log
info :: forall r. String -> BatchRun (LOGGING r) Unit
info = log Info

-- | Warning level log
warn :: forall r. String -> BatchRun (LOGGING r) Unit
warn = log Warn

-- | Error level log
error :: forall r. String -> BatchRun (LOGGING r) Unit
error = log Error

impossibleHandler :: forall r x. V.VariantF r x -> Aff x
impossibleHandler _ = pure $ unsafeCrashWith "Impossible: all effects should be handled"

-- | Handle LOGGING effects for programs with only LOGGING (no other effects)
runLogging :: forall a. BatchRun (LOGGING ()) a -> Aff a
runLogging = runLoggingAt _logging impossibleHandler

-- | Handle LOGGING effects at a specific label
runLoggingAt
  :: forall sym q r a
   . IsSymbol sym
  => Row.Cons sym LoggingF q r
  => Proxy sym
  -> (forall x. V.VariantF q x -> Aff x)
  -> BatchRun r a
  -> Aff a
runLoggingAt sym handler prog =
  runParallel (\v -> on sym handleLogging handler v) prog
  where
  handleLogging :: LoggingF ~> Aff
  handleLogging (Log level msg next) = do
    liftEffect $ Console.log $ "[" <> show level <> "] " <> msg
    pure next
