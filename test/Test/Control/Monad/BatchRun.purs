module Test.Control.Monad.BatchRun where

import Prelude

import Control.Monad.BatchRun (BatchRun, extract, on, runParallel)
import Control.Monad.BatchRun.Logging (LOGGING, LoggingF(..), _logging, info)
import Data.Array as Array
import Data.Functor.Variant as V
import Data.String as String
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Partial.Unsafe (unsafeCrashWith)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

impossibleHandler :: forall r x. V.VariantF r x -> Aff x
impossibleHandler _ = pure $ unsafeCrashWith "Impossible: all effects should be handled"

spec :: Spec Unit
spec = describe "Control.Monad.BatchRun" do

  describe "extract" do
    it "extracts pure values from empty effect row" do
      let program :: BatchRun () Int
          program = pure 42

      extract program `shouldEqual` 42

  describe "LOGGING effect" do
    it "handles logging effects" do
      logRef <- liftEffect $ Ref.new []

      let handleLogging :: LoggingF ~> Aff
          handleLogging (Log level msg next) = do
            liftEffect $ Ref.modify_ (\logs -> Array.snoc logs msg) logRef
            pure next

      let program :: BatchRun (LOGGING ()) Unit
          program = do
            info "First message"
            info "Second message"
            info "Third message"

      _ <- runParallel (\v -> on _logging handleLogging impossibleHandler v) program

      logs <- liftEffect $ Ref.read logRef
      logs `shouldEqual` ["First message", "Second message", "Third message"]

  describe "Applicative batching" do
    it "allows applicative composition" do
      counterRef <- liftEffect $ Ref.new 0

      let handleLogging :: LoggingF ~> Aff
          handleLogging (Log level msg next) = do
            liftEffect $ Ref.modify_ (_ + 1) counterRef
            pure next

      let program :: BatchRun (LOGGING ()) String
          program = (\a b c -> a <> b <> c)
            <$> info "A"
            <*> info "B"
            <*> info "C"

      _ <- runParallel (\v -> on _logging handleLogging impossibleHandler v) program

      count <- liftEffect $ Ref.read counterRef
      count `shouldEqual` 3
