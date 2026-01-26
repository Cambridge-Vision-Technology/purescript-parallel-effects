-- | Portable delay effect for cross-backend testing
-- |
-- | This module provides a delay effect using raw Number (milliseconds)
-- | instead of Milliseconds newtype, making it compatible with both
-- | JavaScript (Aff) and Erlang (Effect) backends.
-- |
-- | For Aff-specific tests that use Data.Time.Duration.Milliseconds,
-- | see Test.Support.Delay instead.
module Test.Support.DelayPortable
  ( DelayF(..)
  , DELAY
  , _delay
  , delay
  ) where

import Prelude

import Control.Monad.Program as Program
import Type.Proxy as Type.Proxy

-- | Effect row alias for the delay effect
type DELAY r = (delay :: DelayF | r)

-- | Delay effect functor using raw Number for milliseconds
-- |
-- | Uses Number instead of Milliseconds for cross-backend compatibility.
-- | Erlang backends may not have Data.Time.Duration available.
data DelayF a = Delay Number a

derive instance Functor DelayF

-- | Proxy for the delay effect label
_delay :: Type.Proxy.Proxy "delay"
_delay = Type.Proxy.Proxy

-- | Lift a delay into Program
-- |
-- | The Number argument represents milliseconds to delay.
delay :: forall r. Number -> Program.Program (DELAY r) Unit
delay ms = Program.lift _delay (Delay ms unit)
