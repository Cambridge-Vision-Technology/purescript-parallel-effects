module Test.Control.Monad.Program where

import Prelude

import Control.Monad.Program (Program, on)
import Control.Monad.Program.Aff (runParallel, impossibleVariant, runPure)
import Control.Monad.Program.Logging (LOGGING, LoggingF(..), _logging, info)
import Data.Array as Array
import Data.Functor.Variant as V
import Data.String as String
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldEqual)

spec :: Spec Unit
spec = describe "Control.Monad.Program" do

  describe "runPure" do
    it "returns pure values with empty effect row" do
      let
        program :: Program () Int
        program = pure 42

      result <- runPure program
      result `shouldEqual` 42

  describe "LOGGING effect" do
    it "handles logging effects" do
      logRef <- liftEffect $ Ref.new []

      let
        handleLogging :: LoggingF ~> Aff
        handleLogging (Log level msg next) = do
          liftEffect $ Ref.modify_ (\logs -> Array.snoc logs msg) logRef
          pure next

      let
        program :: Program (LOGGING ()) Unit
        program = do
          info "First message"
          info "Second message"
          info "Third message"

      _ <- runParallel (\v -> on _logging handleLogging impossibleVariant v) program

      logs <- liftEffect $ Ref.read logRef
      logs `shouldEqual` [ "First message", "Second message", "Third message" ]

  describe "Applicative batching" do
    it "allows applicative composition" do
      counterRef <- liftEffect $ Ref.new 0

      let
        handleLogging :: LoggingF ~> Aff
        handleLogging (Log level msg next) = do
          liftEffect $ Ref.modify_ (_ + 1) counterRef
          pure next

      let
        program :: Program (LOGGING ()) Unit
        program = info "A" *> info "B" *> info "C"

      _ <- runParallel (\v -> on _logging handleLogging impossibleVariant v) program

      count <- liftEffect $ Ref.read counterRef
      count `shouldEqual` 3
