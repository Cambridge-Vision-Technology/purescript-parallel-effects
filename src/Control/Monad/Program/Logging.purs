module Control.Monad.Program.Logging
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

import Prelude

import Control.Applicative.Free as Control.Applicative.Free
import Control.Monad.Program as Control.Monad.Program
import Control.Monad.Program.Aff as Control.Monad.Program.Aff
import Control.Parallel as Control.Parallel
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Symbol (class IsSymbol)
import Effect.Aff as Effect.Aff
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Prim.Row as Prim.Row
import Type.Proxy as Type.Proxy

-- | LOGGING effect row type
-- | Example: Program (LOGGING (FILE_SYSTEM r)) Unit
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

_logging :: Type.Proxy.Proxy "logging"
_logging = Type.Proxy.Proxy

-- | Generic log with level
log :: forall r. LogLevel -> String -> Control.Monad.Program.Program (LOGGING r) Unit
log level msg = Control.Monad.Program.lift _logging (Log level msg unit)

-- | Debug level log
debug :: forall r. String -> Control.Monad.Program.Program (LOGGING r) Unit
debug = log Debug

-- | Info level log
info :: forall r. String -> Control.Monad.Program.Program (LOGGING r) Unit
info = log Info

-- | Warning level log
warn :: forall r. String -> Control.Monad.Program.Program (LOGGING r) Unit
warn = log Warn

-- | Error level log
error :: forall r. String -> Control.Monad.Program.Program (LOGGING r) Unit
error = log Error

-- | Handle LOGGING effects for programs with only LOGGING (no other effects)
runLogging :: forall a. Control.Monad.Program.Program (LOGGING ()) a -> Effect.Aff.Aff a
runLogging = runLoggingAt _logging Control.Monad.Program.Aff.impossibleVariant

-- | Handle LOGGING effects at a specific label
runLoggingAt
  :: forall sym q r a
   . IsSymbol sym
  => Prim.Row.Cons sym LoggingF q r
  => Type.Proxy.Proxy sym
  -> (forall x. Data.Functor.Variant.VariantF q x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Program r a
  -> Effect.Aff.Aff a
runLoggingAt sym handler prog =
  Control.Monad.Program.Aff.runParallel (\v -> Control.Monad.Program.on sym handleLogging handler v) prog
  where
  handleLogging :: LoggingF ~> Effect.Aff.Aff
  handleLogging (Log level msg next) = do
    Effect.Class.liftEffect $ Effect.Console.log $ "[" <> show level <> "] " <> msg
    pure next
