-- | Erlang backend implementation of MonadConcurrent for Effect.
-- |
-- | NOTE: This module requires the purerl backend to compile.
-- | It will NOT compile with the standard JavaScript backend.
-- | Use this module only when building for Erlang/OTP targets.
-- |
-- | The implementation uses Erlang's spawn_monitor/1 to create
-- | monitored processes, and receives DOWN messages to detect
-- | process completion, errors, and cancellation.
-- |
-- | Usage:
-- | ```purescript
-- | import Control.Monad.Concurrent.Erl ()
-- | import Control.Monad.Concurrent.Class (fork, join, cancel)
-- |
-- | main :: Effect Unit
-- | main = do
-- |   fiber <- fork (pure 42)
-- |   result <- join fiber
-- |   -- result :: Either Error Int
-- | ```
module Control.Monad.Concurrent.Erl
  ( FiberErl
  , ErlFiberRaw
  , ExitReason
  , ErlAtom
  , spawnMonitor
  , awaitResult
  , exitProcess
  , spawnMonitorImpl
  , receiveDownImpl
  , exitProcessImpl
  , tupleSize
  , tupleElement
  , atomEqualsIfAtom
  , atomToString
  , stringToAtom
  , formatTerm
  , decodeExitReason
  ) where

import Prelude

import Control.Monad.Concurrent.Class as Control.Monad.Concurrent.Class
import Data.Either as Data.Either
import Data.Maybe as Data.Maybe
import Effect as Effect
import Effect.Exception as Effect.Exception
import Effect.Ref as Effect.Ref

-- | Internal representation of a fiber on the Erlang backend.
-- |
-- | This wraps an Erlang process ID and monitor reference,
-- | allowing us to:
-- | - Send messages to the process (for potential future use)
-- | - Receive DOWN messages when the process terminates
-- | - Exit the process for cancellation
-- |
-- | The structure is: { pid: Pid, monitorRef: Reference }
type FiberErl a =
  { erlFiber :: ErlFiberRaw a
  , resultRef :: Effect.Ref.Ref (Data.Maybe.Maybe (Data.Either.Either Effect.Exception.Error a))
  }

-- | Raw Erlang fiber representation (pid + monitor ref).
foreign import data ErlFiberRaw :: Type -> Type

-- | Opaque exit reason from Erlang DOWN message.
foreign import data ExitReason :: Type

-- | Opaque Erlang atom.
foreign import data ErlAtom :: Type

-- | Spawn a new monitored process that executes the given Effect.
foreign import spawnMonitorImpl :: forall a. Effect.Effect a -> Effect.Effect (ErlFiberRaw a)

-- | Wait for a DOWN message and return the exit reason.
foreign import receiveDownImpl :: forall a. ErlFiberRaw a -> Effect.Effect ExitReason

-- | Kill a process.
foreign import exitProcessImpl :: forall a. ErlFiberRaw a -> Effect.Effect Unit

-- | Get the size of a tuple (0 if not a tuple).
foreign import tupleSize :: ExitReason -> Int

-- | Get an element from a tuple (1-indexed).
foreign import tupleElement :: forall a. Int -> ExitReason -> a

-- | Check if a value is an atom and equals the given atom.
foreign import atomEqualsIfAtom :: ExitReason -> ErlAtom -> Boolean

-- | Convert an atom to a string.
foreign import atomToString :: ErlAtom -> String

-- | Convert a string to an atom.
foreign import stringToAtom :: String -> ErlAtom

-- | Format any Erlang term as a string for debugging.
foreign import formatTerm :: forall a. a -> String

-- | Convert FiberErl to the abstract Fiber type.
foreign import toFiber :: forall a. FiberErl a -> Control.Monad.Concurrent.Class.Fiber Effect.Effect a

-- | Convert the abstract Fiber type back to FiberErl.
foreign import fromFiber :: forall a. Control.Monad.Concurrent.Class.Fiber Effect.Effect a -> FiberErl a

-- | Atom constants for decoding exit reasons.
okAtom :: ErlAtom
okAtom = stringToAtom "ok"

errorAtom :: ErlAtom
errorAtom = stringToAtom "error"

killedAtom :: ErlAtom
killedAtom = stringToAtom "killed"

-- | Spawn a new process with a monitor attached.
-- |
-- | This uses Erlang's spawn_monitor/1 which atomically spawns
-- | a process and sets up a monitor. The spawned process will
-- | execute the given Effect and store its result.
-- |
-- | Returns a FiberErl containing both the Pid and MonitorRef.
spawnMonitor :: forall a. Effect.Effect a -> Effect.Effect (FiberErl a)
spawnMonitor thunk = do
  erlFiber <- spawnMonitorImpl thunk
  resultRef <- Effect.Ref.new Data.Maybe.Nothing
  pure { erlFiber, resultRef }

-- | Wait for a spawned process to complete and return its result.
-- |
-- | This blocks the current process until a DOWN message is received
-- | for the monitored process. Results are cached so subsequent calls
-- | return immediately.
-- |
-- | Returns Either Error a where:
-- | - Right a: Successful completion
-- | - Left Error: Process crashed or was cancelled
awaitResult :: forall a. FiberErl a -> Effect.Effect (Data.Either.Either Effect.Exception.Error a)
awaitResult fiber = do
  cached <- Effect.Ref.read fiber.resultRef
  case cached of
    Data.Maybe.Just result ->
      pure result
    Data.Maybe.Nothing -> do
      reason <- receiveDownImpl fiber.erlFiber
      let result = decodeExitReason reason
      Effect.Ref.write (Data.Maybe.Just result) fiber.resultRef
      pure result

-- | Decode an Erlang exit reason into an Either.
-- |
-- | Exit reasons from spawned processes:
-- | - {ok, Result} -> Right Result
-- | - killed -> Left "Cancelled"
-- | - {error, Class, Error, Stacktrace} -> Left with formatted error
-- | - Other -> Left with formatted term
decodeExitReason :: forall a. ExitReason -> Data.Either.Either Effect.Exception.Error a
decodeExitReason reason
  | tupleSize reason == 2 && atomEqualsIfAtom (tupleElement 1 reason) okAtom =
      Data.Either.Right (tupleElement 2 reason)
  | atomEqualsIfAtom reason killedAtom =
      Data.Either.Left (Effect.Exception.error "Cancelled")
  | tupleSize reason == 4 && atomEqualsIfAtom (tupleElement 1 reason) errorAtom =
      let
        errType = atomToString (tupleElement 2 reason)
        errReason = formatTerm (tupleElement 3 reason :: ExitReason)
        stacktrace = formatTerm (tupleElement 4 reason :: ExitReason)
        message = errType <> ": " <> errReason <> "\n" <> stacktrace
      in
        Data.Either.Left (Effect.Exception.error message)
  | otherwise =
      Data.Either.Left (Effect.Exception.error ("Process exited: " <> formatTerm reason))

-- | Cancel a running process by sending a kill signal.
-- |
-- | Uses Erlang's exit/2 with 'kill' to ensure immediate termination.
-- | After cancellation, awaitResult will return Left with a
-- | cancellation error.
exitProcess :: forall a. FiberErl a -> Effect.Effect Unit
exitProcess fiber = exitProcessImpl fiber.erlFiber
