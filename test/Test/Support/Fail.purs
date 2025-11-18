module Test.Support.Fail
  ( FailF(..)
  , FAIL
  , _fail
  , failNow
  , handleFail
  ) where

import Prelude

import Control.Monad.BatchRun (BatchRun, lift)
import Effect.Aff (Aff, throwError)
import Effect.Exception (error)
import Type.Proxy (Proxy(..))

-- Effect row alias
type FAIL r = (fail :: FailF | r)

-- Fail effect functor – immediately rejects the Aff with the provided message
data FailF a = Fail String a

derive instance Functor FailF

_fail :: Proxy "fail"
_fail = Proxy

-- Public operation
failNow :: forall r. String -> BatchRun (FAIL r) Unit
failNow msg = lift _fail (Fail msg unit)

-- Aff handler for FailF
handleFail :: forall x. FailF x -> Aff x
handleFail (Fail msg _) = throwError (error msg)

