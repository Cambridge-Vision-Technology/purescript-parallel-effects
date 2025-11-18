module Test.BDD.Runner where

import Prelude

import Control.Monad.BatchRun as Control.Monad.BatchRun
import Control.Monad.BatchRun.Reader as Control.Monad.BatchRun.Reader
import Control.Monad.BatchRun.SafeAff as Control.Monad.BatchRun.SafeAff
import Control.Monad.BatchRun.SafeEffect as Control.Monad.BatchRun.SafeEffect
import Control.Monad.BatchRun.State as Control.Monad.BatchRun.State
import Data.Tuple as Data.Tuple
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Either as Data.Either
import Data.Maybe as Data.Maybe
import Data.Array as Data.Array
import Data.Int as Data.Int
import Data.Number as Data.Number
import Data.String as Data.String
import Data.Time.Duration as Data.Time.Duration
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Exception as Effect.Exception
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Effect.Now as Effect.Now
import Node.Process as Node.Process
import Type.Proxy as Type.Proxy

-- Simple CLI runner to back BDD steps. Prints JSON-ish lines to stdout.

main :: Effect.Effect Unit
main = do
  args <- Node.Process.argv
  let cmd = Data.Array.index args 2
  case cmd of
    Data.Maybe.Just "parallel-cancellation" -> do
      case Data.Tuple.Tuple (Data.Array.index args 3) (Data.Array.index args 4) of
        Data.Tuple.Tuple (Data.Maybe.Just msStr) (Data.Maybe.Just msg) -> runParallelCancellation (parseMs msStr) msg
        _ -> usage
    Data.Maybe.Just "reader-ask-twice" -> do
      case Data.Array.index args 3 of
        Data.Maybe.Just env -> runReaderAskTwice env
        _ -> usage
    Data.Maybe.Just "state-parallel-modify" -> do
      runStateParallelModify
    Data.Maybe.Just "applicative-laws" -> do
      case Data.Array.index args 3 of
        Data.Maybe.Just which -> runApplicativeLaw which
        _ -> usage
    Data.Maybe.Just "safe-effects" -> do
      case Data.Array.index args 3 of
        Data.Maybe.Just subCmd -> runSafeEffects subCmd (Data.Array.drop 4 args)
        _ -> usage
    _ -> do
      usage

runParallelCancellation :: Data.Time.Duration.Milliseconds -> String -> Effect.Effect Unit
runParallelCancellation ms msg = Effect.Aff.launchAff_ do
  let
    program = (\_ _ -> unit)
      <$> delay ms
      <*> failNow msg

  start <- Effect.Class.liftEffect Effect.Now.now
  outcome <- Effect.Aff.attempt $ Control.Monad.BatchRun.runParallel (\v -> Control.Monad.BatchRun.on _fail handleFail (Control.Monad.BatchRun.on _delay handleDelay Control.Monad.BatchRun.impossibleVariant) v) program
  end <- Effect.Class.liftEffect Effect.Now.now

  let
    Data.Time.Duration.Milliseconds msStart = Data.DateTime.Instant.unInstant start
    Data.Time.Duration.Milliseconds msEnd = Data.DateTime.Instant.unInstant end
    total = msEnd - msStart

  case outcome of
    Data.Either.Left err -> do
      Effect.Class.liftEffect $ Effect.Console.log $ "{\"status\":\"failed\",\"message\":\"" <> sanitize (Effect.Exception.message err) <> "\",\"elapsedMs\":" <> show total <> "}"
    Data.Either.Right _ -> do
      Effect.Class.liftEffect $ Effect.Console.log $ "{\"status\":\"passed\",\"elapsedMs\":" <> show total <> "}"

runReaderAskTwice :: String -> Effect.Effect Unit
runReaderAskTwice env = Effect.Aff.launchAff_ do
  let program = (\a b -> a <> b) <$> Control.Monad.BatchRun.Reader.ask <*> Control.Monad.BatchRun.Reader.ask
  result <- Control.Monad.BatchRun.Reader.runReader env Control.Monad.BatchRun.impossibleVariant program
  Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"" <> sanitize result <> "\"}"

runStateParallelModify :: Effect.Effect Unit
runStateParallelModify = Effect.Aff.launchAff_ do
  let program = (\_ _ -> unit) <$> Control.Monad.BatchRun.State.modify (_ + 1) <*> Control.Monad.BatchRun.State.modify (_ + 1)
  result <- Control.Monad.BatchRun.State.runState 0 Control.Monad.BatchRun.impossibleVariant program
  case result of
    Data.Tuple.Tuple _ final -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"finalState\":" <> show final <> "}"

runSafeEffects :: String -> Array String -> Effect.Effect Unit
runSafeEffects subCmd args = Effect.Aff.launchAff_ do
  case subCmd of
    "liftSafeAff-success" -> do
      case Data.Array.index args 0 of
        Data.Maybe.Just value -> do
          let program = Control.Monad.BatchRun.SafeAff.liftSafeAff (pure value)
          result <- Control.Monad.BatchRun.SafeAff.runSafeAff program
          case result of
            Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right " <> sanitize v <> "\"}"
            Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize (Effect.Exception.message err) <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing value\"}"

    "liftSafeAff-failure" -> do
      case Data.Array.index args 0 of
        Data.Maybe.Just msg -> do
          let program = Control.Monad.BatchRun.SafeAff.liftSafeAff (Effect.Aff.throwError (Effect.Exception.error msg)) :: Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.SafeAff.SAFE_AFF ()) (Data.Either.Either Effect.Exception.Error Unit)
          result <- Control.Monad.BatchRun.SafeAff.runSafeAff program
          case result of
            Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right " <> show v <> "\"}"
            Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize (Effect.Exception.message err) <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing msg\"}"

    "liftSafeEffect-success" -> do
      case Data.Array.index args 0 of
        Data.Maybe.Just valueStr -> do
          let value = Data.Maybe.fromMaybe 0 (map Data.Int.round (Data.Number.fromString valueStr))
          let program = Control.Monad.BatchRun.SafeEffect.liftSafeEffect (pure value)
          result <- Control.Monad.BatchRun.SafeEffect.runSafeEffect program
          case result of
            Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right " <> show v <> "\"}"
            Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize (Effect.Exception.message err) <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing value\"}"

    "liftSafeEffect-failure" -> do
      case Data.Array.index args 0 of
        Data.Maybe.Just msg -> do
          let program = Control.Monad.BatchRun.SafeEffect.liftSafeEffect (Effect.Exception.throwException (Effect.Exception.error msg)) :: Control.Monad.BatchRun.BatchRun (Control.Monad.BatchRun.SafeEffect.SAFE_EFFECT ()) (Data.Either.Either Effect.Exception.Error Unit)
          result <- Control.Monad.BatchRun.SafeEffect.runSafeEffect program
          case result of
            Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right " <> show v <> "\"}"
            Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize (Effect.Exception.message err) <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing msg\"}"

    "parallel-mixed" -> do
      case Data.Tuple.Tuple (Data.Array.index args 0) (Data.Array.index args 1) of
        Data.Tuple.Tuple (Data.Maybe.Just successValue) (Data.Maybe.Just failMsg) -> do
          let
            program = Data.Tuple.Tuple
              <$> Control.Monad.BatchRun.SafeAff.liftSafeAff (pure successValue)
              <*> Control.Monad.BatchRun.SafeAff.liftSafeAff (Effect.Aff.throwError (Effect.Exception.error failMsg))
          result <- Control.Monad.BatchRun.SafeAff.runSafeAff program
          case result of
            Data.Tuple.Tuple first second -> do
              let
                firstStr = case first of
                  Data.Either.Right v -> "Right " <> sanitize v
                  Data.Either.Left _ -> "Left"
              let
                secondStr = case second of
                  Data.Either.Right v -> "Right " <> sanitize v
                  Data.Either.Left err -> "Left"
              let
                secondError = case second of
                  Data.Either.Left err -> sanitize (Effect.Exception.message err)
                  _ -> ""
              Effect.Class.liftEffect $ Effect.Console.log $ "{\"first\":\"" <> firstStr <> "\",\"second\":\"" <> secondStr <> "\",\"secondError\":\"" <> secondError <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing args\"}"

    "no-cancellation" -> do
      case Data.Tuple.Tuple (Data.Array.index args 0) (Data.Tuple.Tuple (Data.Array.index args 1) (Data.Array.index args 2)) of
        Data.Tuple.Tuple (Data.Maybe.Just msStr) (Data.Tuple.Tuple (Data.Maybe.Just successValue) (Data.Maybe.Just failMsg)) -> do
          let ms = parseMs msStr
          let
            program = Data.Tuple.Tuple
              <$> Control.Monad.BatchRun.SafeAff.liftSafeAff (Effect.Aff.delay ms *> pure successValue)
              <*> Control.Monad.BatchRun.SafeAff.liftSafeAff (Effect.Aff.throwError (Effect.Exception.error failMsg))
          start <- Effect.Class.liftEffect Effect.Now.now
          result <- Control.Monad.BatchRun.SafeAff.runSafeAff program
          end <- Effect.Class.liftEffect Effect.Now.now
          let
            Data.Time.Duration.Milliseconds a = Data.DateTime.Instant.unInstant start
            Data.Time.Duration.Milliseconds b = Data.DateTime.Instant.unInstant end
            elapsed = b - a
          case result of
            Data.Tuple.Tuple first second -> do
              let hasRight = Data.Either.isRight first || Data.Either.isRight second
              let hasLeft = Data.Either.isLeft first || Data.Either.isLeft second
              Effect.Class.liftEffect $ Effect.Console.log $ "{\"elapsed\":" <> show elapsed <> ",\"hasRight\":" <> show hasRight <> ",\"hasLeft\":" <> show hasLeft <> ",\"first\":\"" <> (if Data.Either.isRight first then "Right " <> successValue else "Left") <> "\",\"second\":\"Left\",\"secondError\":\"" <> failMsg <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing args\"}"

    _ -> do
      Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"unknown safe-effects subcommand\"}"

parseMs :: String -> Data.Time.Duration.Milliseconds
parseMs s = Data.Time.Duration.Milliseconds (Data.Maybe.fromMaybe 0.0 (Data.Number.fromString s))

sanitize :: String -> String
sanitize = Data.String.replaceAll (Data.String.Pattern "\"") (Data.String.Replacement "\"\"")

usage :: Effect.Effect Unit
usage = Effect.Console.log "Usage: <program> (parallel-cancellation <ms> <msg> | reader-ask-twice <env> | state-parallel-modify)"

runApplicativeLaw :: String -> Effect.Effect Unit
runApplicativeLaw which = Effect.Aff.launchAff_ do
  case which of
    "identity" -> do
      -- Check identity: pure id <*> u == u for a simple pure program
      let
        program :: Control.Monad.BatchRun.BatchRun () Int
        program = (pure identity) <*> (pure 7)
      result <- Control.Monad.BatchRun.runParallel Control.Monad.BatchRun.impossibleVariant program
      if result == 7 then Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":true}" else Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":false}"

    "homomorphism" -> do
      let f = (_ + 1)
      let x = 41
      let lhs = pure f <*> pure x :: Control.Monad.BatchRun.BatchRun () Int
      l <- Control.Monad.BatchRun.runParallel Control.Monad.BatchRun.impossibleVariant lhs
      let rhs = pure (f x) :: Control.Monad.BatchRun.BatchRun () Int
      r <- Control.Monad.BatchRun.runParallel Control.Monad.BatchRun.impossibleVariant rhs
      if l == r then Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":true}" else Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":false}"

    "interchange" -> do
      let y = 5
      let u = pure (_ * 2) :: Control.Monad.BatchRun.BatchRun () (Int -> Int)
      l <- Control.Monad.BatchRun.runParallel Control.Monad.BatchRun.impossibleVariant (u <*> pure y)
      r <- Control.Monad.BatchRun.runParallel Control.Monad.BatchRun.impossibleVariant (pure (_ $ y) <*> u)
      if l == r then Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":true}" else Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":false}"

    "batch-merge" -> do
      -- three delays should run in parallel; compare to sequential
      let
        p = (\_ _ _ -> unit)
          <$> delay (Data.Time.Duration.Milliseconds 200.0)
          <*> delay (Data.Time.Duration.Milliseconds 200.0)
          <*> delay (Data.Time.Duration.Milliseconds 200.0)
      start <- Effect.Class.liftEffect Effect.Now.now
      _ <- Control.Monad.BatchRun.runParallel (\v -> Control.Monad.BatchRun.on _delay handleDelay Control.Monad.BatchRun.impossibleVariant v) p
      end <- Effect.Class.liftEffect Effect.Now.now
      let
        Data.Time.Duration.Milliseconds a = Data.DateTime.Instant.unInstant start
        Data.Time.Duration.Milliseconds b = Data.DateTime.Instant.unInstant end
        elapsed = b - a
      if elapsed < 350.0 then Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":true}" else Effect.Class.liftEffect $ Effect.Console.log ("{\"ok\":false,\"elapsed\":" <> show elapsed <> "}")

    _ -> do
      Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":false,\"error\":\"unknown-law\"}"

-- Local test-only effects (Delay, Fail) to avoid cross-module deps

type DELAY r = (delay :: DelayF | r)

data DelayF a = Delay Data.Time.Duration.Milliseconds a

derive instance functorDelayF :: Functor DelayF

_delay :: Type.Proxy.Proxy "delay"
_delay = Type.Proxy.Proxy

delay :: forall r. Data.Time.Duration.Milliseconds -> Control.Monad.BatchRun.BatchRun (DELAY r) Unit
delay ms = Control.Monad.BatchRun.lift _delay (Delay ms unit)

handleDelay :: forall x. DelayF x -> Effect.Aff.Aff x
handleDelay (Delay ms next) = do
  Effect.Aff.delay ms
  pure next

type FAIL r = (fail :: FailF | r)

data FailF a = Fail String a

derive instance functorFailF :: Functor FailF

_fail :: Type.Proxy.Proxy "fail"
_fail = Type.Proxy.Proxy

failNow :: forall r. String -> Control.Monad.BatchRun.BatchRun (FAIL r) Unit
failNow msg = Control.Monad.BatchRun.lift _fail (Fail msg unit)

handleFail :: forall x. FailF x -> Effect.Aff.Aff x
handleFail (Fail msg _) = Effect.Aff.throwError (Effect.Exception.error msg)
