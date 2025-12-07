module Test.Support.Delay
  ( DelayF(..)
  , DELAY
  , _delay
  , delay
  , handleDelay
  ) where

import Prelude

import Control.Monad.Program (Program, lift)
import Data.Time.Duration (Milliseconds(..))
import Effect.Aff (Aff, delay) as Aff
import Type.Proxy (Proxy(..))

-- Effect row alias
type DELAY r = (delay :: DelayF | r)

-- Delay effect functor
data DelayF a = Delay Milliseconds a

derive instance Functor DelayF

_delay :: Proxy "delay"
_delay = Proxy

-- Public operation
delay :: forall r. Milliseconds -> Program (DELAY r) Unit
delay ms = lift _delay (Delay ms unit)

-- Aff handler for DelayF
handleDelay :: forall x. DelayF x -> Aff.Aff x
handleDelay (Delay ms next) = do
  Aff.delay ms
  pure next

