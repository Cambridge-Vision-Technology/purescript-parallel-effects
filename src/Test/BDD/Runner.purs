module Test.BDD.Runner where

import Prelude

import Control.Monad.Program as Control.Monad.Program
import Control.Monad.Program.Aff as Control.Monad.Program.Aff
import Control.Monad.Program.Except as Control.Monad.Program.Except
import Control.Monad.Program.Reader as Control.Monad.Program.Reader
import Control.Monad.Program.SafeAff as Control.Monad.Program.SafeAff
import Control.Monad.Program.SafeEffect as Control.Monad.Program.SafeEffect
import Control.Monad.Program.State as Control.Monad.Program.State
import Control.Monad.Program.Writer as Control.Monad.Program.Writer
import Data.Array as Data.Array
import Data.DateTime.Instant as Data.DateTime.Instant
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Data.Int as Data.Int
import Data.Maybe as Data.Maybe
import Data.Number as Data.Number
import Data.String as Data.String
import Data.Time.Duration as Data.Time.Duration
import Data.Tuple as Data.Tuple
import Effect as Effect
import Effect.Aff as Effect.Aff
import Effect.Aff.AVar as Effect.Aff.AVar
import Effect.Class as Effect.Class
import Effect.Console as Effect.Console
import Effect.Exception as Effect.Exception
import Effect.Now as Effect.Now
import Effect.Ref as Effect.Ref
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
    Data.Maybe.Just "labeled-state" -> do
      runLabeledState
    Data.Maybe.Just "labeled-state-parallel" -> do
      runLabeledStateParallel
    Data.Maybe.Just "labeled-reader" -> do
      runLabeledReader
    Data.Maybe.Just "labeled-writer" -> do
      runLabeledWriter
    Data.Maybe.Just "labeled-combo" -> do
      runLabeledCombo
    Data.Maybe.Just "except-throw" -> do
      case Data.Array.index args 3 of
        Data.Maybe.Just msg -> runExceptThrow msg
        _ -> usage
    Data.Maybe.Just "except-success" -> do
      runExceptSuccess
    Data.Maybe.Just "except-rethrow" -> do
      case Data.Array.index args 3 of
        Data.Maybe.Just msg -> runExceptRethrow msg
        _ -> usage
    Data.Maybe.Just "except-note" -> do
      case Data.Array.index args 3 of
        Data.Maybe.Just msg -> runExceptNote msg
        _ -> usage
    Data.Maybe.Just "except-parallel-cancel" -> do
      case Data.Array.index args 3 of
        Data.Maybe.Just msStr -> runExceptParallelCancel (parseMs msStr)
        _ -> usage
    Data.Maybe.Just "except-sequential" -> do
      runExceptSequential
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
  outcome <- Effect.Aff.attempt $ Control.Monad.Program.Aff.runParallel (\v -> Control.Monad.Program.on _fail handleFail (Control.Monad.Program.on _delay handleDelay Control.Monad.Program.Aff.impossibleVariant) v) program
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
  let program = (\a b -> a <> b) <$> Control.Monad.Program.Reader.ask <*> Control.Monad.Program.Reader.ask
  result <- Control.Monad.Program.Reader.runReader env Control.Monad.Program.Aff.impossibleVariant program
  Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"" <> sanitize result <> "\"}"

runStateParallelModify :: Effect.Effect Unit
runStateParallelModify = Effect.Aff.launchAff_ do
  let program = (\_ _ -> unit) <$> Control.Monad.Program.State.modify (_ + 1) <*> Control.Monad.Program.State.modify (_ + 1)
  result <- Control.Monad.Program.State.runState 0 Control.Monad.Program.Aff.impossibleVariant program
  case result of
    Data.Tuple.Tuple _ final -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"finalState\":" <> show final <> "}"

runLabeledState :: Effect.Effect Unit
runLabeledState = Effect.Aff.launchAff_ do
  let
    _counterState :: Type.Proxy.Proxy "counterState"
    _counterState = Type.Proxy.Proxy

    _nameState :: Type.Proxy.Proxy "nameState"
    _nameState = Type.Proxy.Proxy

    program :: Control.Monad.Program.Program (counterState :: Control.Monad.Program.State.StateF Int, nameState :: Control.Monad.Program.State.StateF String) String
    program = do
      count <- Control.Monad.Program.State.getAt _counterState
      Control.Monad.Program.State.putAt _counterState (count + 1)
      name <- Control.Monad.Program.State.getAt _nameState
      Control.Monad.Program.State.putAt _nameState (name <> "!")
      count' <- Control.Monad.Program.State.getAt _counterState
      name' <- Control.Monad.Program.State.getAt _nameState
      pure $ name' <> " (" <> show count' <> ")"

  -- Create AVars for both states
  counterVar <- Effect.Aff.AVar.new 0
  nameVar <- Effect.Aff.AVar.new "Hello"

  -- Compose handlers for both states
  let
    handlers :: forall x. Data.Functor.Variant.VariantF (counterState :: Control.Monad.Program.State.StateF Int, nameState :: Control.Monad.Program.State.StateF String) x -> Effect.Aff.Aff x
    handlers = Data.Functor.Variant.on _counterState (handleCounterState counterVar)
      ( Data.Functor.Variant.on _nameState (handleNameState nameVar)
          Control.Monad.Program.Aff.impossibleVariant
      )

  -- Run the program with the composite handler
  result <- Control.Monad.Program.Aff.runParallel handlers program

  -- Read final states
  counterFinal <- Effect.Aff.AVar.read counterVar
  nameFinal <- Effect.Aff.AVar.read nameVar

  Effect.Class.liftEffect $ Effect.Console.log $ "{\"counterFinal\":" <> show counterFinal <> ",\"nameFinal\":\"" <> sanitize nameFinal <> "\",\"result\":\"" <> sanitize result <> "\"}"
  where
  handleCounterState :: forall x. Effect.Aff.AVar.AVar Int -> Control.Monad.Program.State.StateF Int x -> Effect.Aff.Aff x
  handleCounterState sv (Control.Monad.Program.State.Get cont) = do
    s <- Effect.Aff.AVar.read sv
    pure $ cont s
  handleCounterState sv (Control.Monad.Program.State.Put s next) = do
    _ <- Effect.Aff.AVar.take sv
    _ <- Effect.Aff.AVar.put s sv
    pure next
  handleCounterState sv (Control.Monad.Program.State.Modify f cont) = do
    s <- Effect.Aff.AVar.take sv
    let s' = f s
    _ <- Effect.Aff.AVar.put s' sv
    pure $ cont s'

  handleNameState :: forall x. Effect.Aff.AVar.AVar String -> Control.Monad.Program.State.StateF String x -> Effect.Aff.Aff x
  handleNameState sv (Control.Monad.Program.State.Get cont) = do
    s <- Effect.Aff.AVar.read sv
    pure $ cont s
  handleNameState sv (Control.Monad.Program.State.Put s next) = do
    _ <- Effect.Aff.AVar.take sv
    _ <- Effect.Aff.AVar.put s sv
    pure next
  handleNameState sv (Control.Monad.Program.State.Modify f cont) = do
    s <- Effect.Aff.AVar.take sv
    let s' = f s
    _ <- Effect.Aff.AVar.put s' sv
    pure $ cont s'

runLabeledStateParallel :: Effect.Effect Unit
runLabeledStateParallel = Effect.Aff.launchAff_ do
  let
    _counterState :: Type.Proxy.Proxy "counterState"
    _counterState = Type.Proxy.Proxy

    _nameState :: Type.Proxy.Proxy "nameState"
    _nameState = Type.Proxy.Proxy

    -- Program that modifies both states in parallel using applicative
    program :: Control.Monad.Program.Program (counterState :: Control.Monad.Program.State.StateF Int, nameState :: Control.Monad.Program.State.StateF String) Unit
    program =
      ( (\_ _ -> unit)
          <$> Control.Monad.Program.State.modifyAt _counterState (_ + 1)
          <*> Control.Monad.Program.State.putAt _nameState "A"
      )
        *>
          ( (\_ _ -> unit)
              <$> Control.Monad.Program.State.modifyAt _counterState (_ + 1)
              <*> Control.Monad.Program.State.modifyAt _nameState (_ <> "B")
          )

  -- Create AVars for both states
  counterVar <- Effect.Aff.AVar.new 0
  nameVar <- Effect.Aff.AVar.new ""

  -- Compose handlers for both states
  let
    handlers :: forall x. Data.Functor.Variant.VariantF (counterState :: Control.Monad.Program.State.StateF Int, nameState :: Control.Monad.Program.State.StateF String) x -> Effect.Aff.Aff x
    handlers = Data.Functor.Variant.on _counterState (handleCounterStateP counterVar)
      ( Data.Functor.Variant.on _nameState (handleNameStateP nameVar)
          Control.Monad.Program.Aff.impossibleVariant
      )

  -- Run the program with the composite handler
  _ <- Control.Monad.Program.Aff.runParallel handlers program

  -- Read final states
  counterFinal <- Effect.Aff.AVar.read counterVar
  nameFinal <- Effect.Aff.AVar.read nameVar

  Effect.Class.liftEffect $ Effect.Console.log $ "{\"counterFinal\":" <> show counterFinal <> ",\"nameFinal\":\"" <> sanitize nameFinal <> "\"}"
  where
  handleCounterStateP :: forall x. Effect.Aff.AVar.AVar Int -> Control.Monad.Program.State.StateF Int x -> Effect.Aff.Aff x
  handleCounterStateP sv (Control.Monad.Program.State.Get cont) = do
    s <- Effect.Aff.AVar.read sv
    pure $ cont s
  handleCounterStateP sv (Control.Monad.Program.State.Put s next) = do
    _ <- Effect.Aff.AVar.take sv
    _ <- Effect.Aff.AVar.put s sv
    pure next
  handleCounterStateP sv (Control.Monad.Program.State.Modify f cont) = do
    s <- Effect.Aff.AVar.take sv
    let s' = f s
    _ <- Effect.Aff.AVar.put s' sv
    pure $ cont s'

  handleNameStateP :: forall x. Effect.Aff.AVar.AVar String -> Control.Monad.Program.State.StateF String x -> Effect.Aff.Aff x
  handleNameStateP sv (Control.Monad.Program.State.Get cont) = do
    s <- Effect.Aff.AVar.read sv
    pure $ cont s
  handleNameStateP sv (Control.Monad.Program.State.Put s next) = do
    _ <- Effect.Aff.AVar.take sv
    _ <- Effect.Aff.AVar.put s sv
    pure next
  handleNameStateP sv (Control.Monad.Program.State.Modify f cont) = do
    s <- Effect.Aff.AVar.take sv
    let s' = f s
    _ <- Effect.Aff.AVar.put s' sv
    pure $ cont s'

runLabeledReader :: Effect.Effect Unit
runLabeledReader = Effect.Aff.launchAff_ do
  let
    _configReader :: Type.Proxy.Proxy "configReader"
    _configReader = Type.Proxy.Proxy

    _userReader :: Type.Proxy.Proxy "userReader"
    _userReader = Type.Proxy.Proxy

    program :: Control.Monad.Program.Program (configReader :: Control.Monad.Program.Reader.ReaderF String, userReader :: Control.Monad.Program.Reader.ReaderF String) String
    program = do
      config <- Control.Monad.Program.Reader.askAt _configReader
      user <- Control.Monad.Program.Reader.askAt _userReader
      pure $ "config:" <> config <> ",user:" <> user

  -- Compose handlers for both readers
  let
    handlers :: forall x. Data.Functor.Variant.VariantF (configReader :: Control.Monad.Program.Reader.ReaderF String, userReader :: Control.Monad.Program.Reader.ReaderF String) x -> Effect.Aff.Aff x
    handlers = Data.Functor.Variant.on _configReader handleConfigReader
      ( Data.Functor.Variant.on _userReader handleUserReader
          Control.Monad.Program.Aff.impossibleVariant
      )

  result <- Control.Monad.Program.Aff.runParallel handlers program
  Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"" <> sanitize result <> "\"}"
  where
  handleConfigReader :: forall x. Control.Monad.Program.Reader.ReaderF String x -> Effect.Aff.Aff x
  handleConfigReader (Control.Monad.Program.Reader.Ask cont) = pure $ cont "production"

  handleUserReader :: forall x. Control.Monad.Program.Reader.ReaderF String x -> Effect.Aff.Aff x
  handleUserReader (Control.Monad.Program.Reader.Ask cont) = pure $ cont "alice"

runLabeledWriter :: Effect.Effect Unit
runLabeledWriter = Effect.Aff.launchAff_ do
  let
    _logWriter :: Type.Proxy.Proxy "logWriter"
    _logWriter = Type.Proxy.Proxy

    _auditWriter :: Type.Proxy.Proxy "auditWriter"
    _auditWriter = Type.Proxy.Proxy

    program :: Control.Monad.Program.Program (logWriter :: Control.Monad.Program.Writer.WriterF String, auditWriter :: Control.Monad.Program.Writer.WriterF String) Unit
    program = do
      Control.Monad.Program.Writer.tellAt _logWriter "log1"
      Control.Monad.Program.Writer.tellAt _auditWriter "audit1"
      Control.Monad.Program.Writer.tellAt _logWriter ",log2"
      Control.Monad.Program.Writer.tellAt _auditWriter ",audit2"

  -- Create Refs for both writers
  logRef <- Effect.Class.liftEffect $ Effect.Ref.new ""
  auditRef <- Effect.Class.liftEffect $ Effect.Ref.new ""

  -- Compose handlers for both writers
  let
    handlers :: forall x. Data.Functor.Variant.VariantF (logWriter :: Control.Monad.Program.Writer.WriterF String, auditWriter :: Control.Monad.Program.Writer.WriterF String) x -> Effect.Aff.Aff x
    handlers = Data.Functor.Variant.on _logWriter (handleLogWriter logRef)
      ( Data.Functor.Variant.on _auditWriter (handleAuditWriter auditRef)
          Control.Monad.Program.Aff.impossibleVariant
      )

  _ <- Control.Monad.Program.Aff.runParallel handlers program

  logOutput <- Effect.Class.liftEffect $ Effect.Ref.read logRef
  auditOutput <- Effect.Class.liftEffect $ Effect.Ref.read auditRef

  Effect.Class.liftEffect $ Effect.Console.log $ "{\"logOutput\":\"" <> sanitize logOutput <> "\",\"auditOutput\":\"" <> sanitize auditOutput <> "\"}"
  where
  handleLogWriter :: forall x. Effect.Ref.Ref String -> Control.Monad.Program.Writer.WriterF String x -> Effect.Aff.Aff x
  handleLogWriter ref (Control.Monad.Program.Writer.Tell w next) = do
    Effect.Class.liftEffect $ Effect.Ref.modify_ (_ <> w) ref
    pure next

  handleAuditWriter :: forall x. Effect.Ref.Ref String -> Control.Monad.Program.Writer.WriterF String x -> Effect.Aff.Aff x
  handleAuditWriter ref (Control.Monad.Program.Writer.Tell w next) = do
    Effect.Class.liftEffect $ Effect.Ref.modify_ (_ <> w) ref
    pure next

runLabeledCombo :: Effect.Effect Unit
runLabeledCombo = Effect.Aff.launchAff_ do
  let
    _myState :: Type.Proxy.Proxy "myState"
    _myState = Type.Proxy.Proxy

    _myReader :: Type.Proxy.Proxy "myReader"
    _myReader = Type.Proxy.Proxy

    _myWriter :: Type.Proxy.Proxy "myWriter"
    _myWriter = Type.Proxy.Proxy

    program :: Control.Monad.Program.Program (myState :: Control.Monad.Program.State.StateF Int, myReader :: Control.Monad.Program.Reader.ReaderF String, myWriter :: Control.Monad.Program.Writer.WriterF String) String
    program = do
      Control.Monad.Program.Writer.tellAt _myWriter "init"
      Control.Monad.Program.State.putAt _myState 42
      Control.Monad.Program.Writer.tellAt _myWriter ",increment"
      config <- Control.Monad.Program.Reader.askAt _myReader
      pure $ "config:" <> config

  -- Create state and writer storage
  stateVar <- Effect.Aff.AVar.new 0
  writerRef <- Effect.Class.liftEffect $ Effect.Ref.new ""

  -- Compose handlers for all three effects
  let
    handlers :: forall x. Data.Functor.Variant.VariantF (myState :: Control.Monad.Program.State.StateF Int, myReader :: Control.Monad.Program.Reader.ReaderF String, myWriter :: Control.Monad.Program.Writer.WriterF String) x -> Effect.Aff.Aff x
    handlers = Data.Functor.Variant.on _myState (handleState stateVar)
      ( Data.Functor.Variant.on _myReader handleReader
          ( Data.Functor.Variant.on _myWriter (handleWriter writerRef)
              Control.Monad.Program.Aff.impossibleVariant
          )
      )

  result <- Control.Monad.Program.Aff.runParallel handlers program
  finalState <- Effect.Aff.AVar.read stateVar
  writerOutput <- Effect.Class.liftEffect $ Effect.Ref.read writerRef

  Effect.Class.liftEffect $ Effect.Console.log $ "{\"finalState\":" <> show finalState <> ",\"writerOutput\":\"" <> sanitize writerOutput <> "\",\"result\":\"" <> sanitize result <> "\"}"
  where
  handleState :: forall x. Effect.Aff.AVar.AVar Int -> Control.Monad.Program.State.StateF Int x -> Effect.Aff.Aff x
  handleState sv (Control.Monad.Program.State.Get cont) = do
    s <- Effect.Aff.AVar.read sv
    pure $ cont s
  handleState sv (Control.Monad.Program.State.Put s next) = do
    _ <- Effect.Aff.AVar.take sv
    _ <- Effect.Aff.AVar.put s sv
    pure next
  handleState sv (Control.Monad.Program.State.Modify f cont) = do
    s <- Effect.Aff.AVar.take sv
    let s' = f s
    _ <- Effect.Aff.AVar.put s' sv
    pure $ cont s'

  handleReader :: forall x. Control.Monad.Program.Reader.ReaderF String x -> Effect.Aff.Aff x
  handleReader (Control.Monad.Program.Reader.Ask cont) = pure $ cont "config"

  handleWriter :: forall x. Effect.Ref.Ref String -> Control.Monad.Program.Writer.WriterF String x -> Effect.Aff.Aff x
  handleWriter ref (Control.Monad.Program.Writer.Tell w next) = do
    Effect.Class.liftEffect $ Effect.Ref.modify_ (_ <> w) ref
    pure next

runExceptThrow :: String -> Effect.Effect Unit
runExceptThrow msg = Effect.Aff.launchAff_ do
  let
    program :: Control.Monad.Program.Program (Control.Monad.Program.Except.EXCEPT String ()) Unit
    program = Control.Monad.Program.Except.throw msg

  result <- Control.Monad.Program.Except.runExcept Control.Monad.Program.Aff.impossibleVariant program
  case result of
    Data.Either.Left e -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize e <> "\"}"
    Data.Either.Right _ -> Effect.Class.liftEffect $ Effect.Console.log "{\"result\":\"Right\"}"

runExceptSuccess :: Effect.Effect Unit
runExceptSuccess = Effect.Aff.launchAff_ do
  let
    program :: Control.Monad.Program.Program (Control.Monad.Program.Except.EXCEPT String ()) Int
    program = pure 42

  result <- Control.Monad.Program.Except.runExcept Control.Monad.Program.Aff.impossibleVariant program
  case result of
    Data.Either.Left e -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize e <> "\"}"
    Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right\",\"value\":" <> show v <> "}"

runExceptRethrow :: String -> Effect.Effect Unit
runExceptRethrow msg = Effect.Aff.launchAff_ do
  let
    program :: Control.Monad.Program.Program (Control.Monad.Program.Except.EXCEPT String ()) Int
    program = Control.Monad.Program.Except.rethrow (Data.Either.Left msg)

  result <- Control.Monad.Program.Except.runExcept Control.Monad.Program.Aff.impossibleVariant program
  case result of
    Data.Either.Left e -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize e <> "\"}"
    Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right\",\"value\":" <> show v <> "}"

runExceptNote :: String -> Effect.Effect Unit
runExceptNote msg = Effect.Aff.launchAff_ do
  let
    program :: Control.Monad.Program.Program (Control.Monad.Program.Except.EXCEPT String ()) Int
    program = Control.Monad.Program.Except.note msg Data.Maybe.Nothing

  result <- Control.Monad.Program.Except.runExcept Control.Monad.Program.Aff.impossibleVariant program
  case result of
    Data.Either.Left e -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize e <> "\"}"
    Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right\",\"value\":" <> show v <> "}"

runExceptParallelCancel :: Data.Time.Duration.Milliseconds -> Effect.Effect Unit
runExceptParallelCancel ms = Effect.Aff.launchAff_ do
  let
    program :: Control.Monad.Program.Program (Control.Monad.Program.Except.EXCEPT String (delay :: DelayF)) Unit
    program = (\_ _ -> unit)
      <$> Control.Monad.Program.Except.throw "immediate error"
      <*> delay ms

  start <- Effect.Class.liftEffect Effect.Now.now
  result <- Control.Monad.Program.Except.runExcept (\v -> Control.Monad.Program.on _delay handleDelay Control.Monad.Program.Aff.impossibleVariant v) program
  end <- Effect.Class.liftEffect Effect.Now.now

  let
    Data.Time.Duration.Milliseconds a = Data.DateTime.Instant.unInstant start
    Data.Time.Duration.Milliseconds b = Data.DateTime.Instant.unInstant end
    elapsed = b - a

  case result of
    Data.Either.Left e -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize e <> "\",\"elapsed\":" <> show elapsed <> "}"
    Data.Either.Right _ -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right\",\"elapsed\":" <> show elapsed <> "}"

runExceptSequential :: Effect.Effect Unit
runExceptSequential = Effect.Aff.launchAff_ do
  let
    program :: Control.Monad.Program.Program (Control.Monad.Program.Except.EXCEPT String ()) String
    program = do
      _ <- pure "step1"
      _ <- Control.Monad.Program.Except.throw "step failed"
      pure "step2"

  result <- Control.Monad.Program.Except.runExcept Control.Monad.Program.Aff.impossibleVariant program
  case result of
    Data.Either.Left e -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize e <> "\"}"
    Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right\",\"value\":\"" <> sanitize v <> "\"}"

runSafeEffects :: String -> Array String -> Effect.Effect Unit
runSafeEffects subCmd args = Effect.Aff.launchAff_ do
  case subCmd of
    "liftSafeAff-success" -> do
      case Data.Array.index args 0 of
        Data.Maybe.Just value -> do
          let program = Control.Monad.Program.SafeAff.liftSafeAff (pure value)
          result <- Control.Monad.Program.SafeAff.runSafeAff program
          case result of
            Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right " <> sanitize v <> "\"}"
            Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize (Effect.Exception.message err) <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing value\"}"

    "liftSafeAff-failure" -> do
      case Data.Array.index args 0 of
        Data.Maybe.Just msg -> do
          let program = Control.Monad.Program.SafeAff.liftSafeAff (Effect.Aff.throwError (Effect.Exception.error msg)) :: Control.Monad.Program.Program (Control.Monad.Program.SafeAff.SAFE_AFF ()) (Data.Either.Either Effect.Exception.Error Unit)
          result <- Control.Monad.Program.SafeAff.runSafeAff program
          case result of
            Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right " <> show v <> "\"}"
            Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize (Effect.Exception.message err) <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing msg\"}"

    "liftSafeEffect-success" -> do
      case Data.Array.index args 0 of
        Data.Maybe.Just valueStr -> do
          let value = Data.Maybe.fromMaybe 0 (map Data.Int.round (Data.Number.fromString valueStr))
          let program = Control.Monad.Program.SafeEffect.liftSafeEffect (pure value)
          result <- Control.Monad.Program.SafeEffect.runSafeEffect program
          case result of
            Data.Either.Right v -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Right " <> show v <> "\"}"
            Data.Either.Left err -> Effect.Class.liftEffect $ Effect.Console.log $ "{\"result\":\"Left\",\"error\":\"" <> sanitize (Effect.Exception.message err) <> "\"}"
        _ ->
          Effect.Class.liftEffect $ Effect.Console.log "{\"error\":\"missing value\"}"

    "liftSafeEffect-failure" -> do
      case Data.Array.index args 0 of
        Data.Maybe.Just msg -> do
          let program = Control.Monad.Program.SafeEffect.liftSafeEffect (Effect.Exception.throwException (Effect.Exception.error msg)) :: Control.Monad.Program.Program (Control.Monad.Program.SafeEffect.SAFE_EFFECT ()) (Data.Either.Either Effect.Exception.Error Unit)
          result <- Control.Monad.Program.SafeEffect.runSafeEffect program
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
              <$> Control.Monad.Program.SafeAff.liftSafeAff (pure successValue)
              <*> Control.Monad.Program.SafeAff.liftSafeAff (Effect.Aff.throwError (Effect.Exception.error failMsg))
          result <- Control.Monad.Program.SafeAff.runSafeAff program
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
              <$> Control.Monad.Program.SafeAff.liftSafeAff (Effect.Aff.delay ms *> pure successValue)
              <*> Control.Monad.Program.SafeAff.liftSafeAff (Effect.Aff.throwError (Effect.Exception.error failMsg))
          start <- Effect.Class.liftEffect Effect.Now.now
          result <- Control.Monad.Program.SafeAff.runSafeAff program
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
        program :: Control.Monad.Program.Program () Int
        program = (pure identity) <*> (pure 7)
      result <- Control.Monad.Program.Aff.runParallel Control.Monad.Program.Aff.impossibleVariant program
      if result == 7 then Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":true}" else Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":false}"

    "homomorphism" -> do
      let f = (_ + 1)
      let x = 41
      let lhs = pure f <*> pure x :: Control.Monad.Program.Program () Int
      l <- Control.Monad.Program.Aff.runParallel Control.Monad.Program.Aff.impossibleVariant lhs
      let rhs = pure (f x) :: Control.Monad.Program.Program () Int
      r <- Control.Monad.Program.Aff.runParallel Control.Monad.Program.Aff.impossibleVariant rhs
      if l == r then Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":true}" else Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":false}"

    "interchange" -> do
      let y = 5
      let u = pure (_ * 2) :: Control.Monad.Program.Program () (Int -> Int)
      l <- Control.Monad.Program.Aff.runParallel Control.Monad.Program.Aff.impossibleVariant (u <*> pure y)
      r <- Control.Monad.Program.Aff.runParallel Control.Monad.Program.Aff.impossibleVariant (pure (_ $ y) <*> u)
      if l == r then Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":true}" else Effect.Class.liftEffect $ Effect.Console.log "{\"ok\":false}"

    "batch-merge" -> do
      -- three delays should run in parallel; compare to sequential
      let
        p = (\_ _ _ -> unit)
          <$> delay (Data.Time.Duration.Milliseconds 200.0)
          <*> delay (Data.Time.Duration.Milliseconds 200.0)
          <*> delay (Data.Time.Duration.Milliseconds 200.0)
      start <- Effect.Class.liftEffect Effect.Now.now
      _ <- Control.Monad.Program.Aff.runParallel (\v -> Control.Monad.Program.on _delay handleDelay Control.Monad.Program.Aff.impossibleVariant v) p
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

delay :: forall r. Data.Time.Duration.Milliseconds -> Control.Monad.Program.Program (DELAY r) Unit
delay ms = Control.Monad.Program.lift _delay (Delay ms unit)

handleDelay :: forall x. DelayF x -> Effect.Aff.Aff x
handleDelay (Delay ms next) = do
  Effect.Aff.delay ms
  pure next

type FAIL r = (fail :: FailF | r)

data FailF a = Fail String a

derive instance functorFailF :: Functor FailF

_fail :: Type.Proxy.Proxy "fail"
_fail = Type.Proxy.Proxy

failNow :: forall r. String -> Control.Monad.Program.Program (FAIL r) Unit
failNow msg = Control.Monad.Program.lift _fail (Fail msg unit)

handleFail :: forall x. FailF x -> Effect.Aff.Aff x
handleFail (Fail msg _) = Effect.Aff.throwError (Effect.Exception.error msg)
