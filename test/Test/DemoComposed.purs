module Test.DemoComposed where

import Prelude

import Control.Monad.Program (Program, on)
import Control.Monad.Program.Aff (runParallel, impossibleVariant)
import Control.Monad.Program.HTTP (HTTP, HttpF(..), _http, get)
import Control.Monad.Program.Logging (LOGGING, LoggingF(..), _logging, info, debug)
import Data.Array as Array
import Data.Functor.Variant as V
import Data.String as String
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Effect.Ref as Ref
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (shouldContain, shouldEqual, shouldSatisfy)

spec :: Spec Unit
spec = describe "DemoComposed" do

  describe "composedProgram type" do
    it "composes HTTP and LOGGING effects" do
      logRef <- liftEffect $ Ref.new []
      httpRef <- liftEffect $ Ref.new []

      let
        handleLogging :: LoggingF ~> Aff
        handleLogging (Log level msg next) = do
          liftEffect $ Ref.modify_ (\logs -> Array.snoc logs msg) logRef
          pure next

      let
        handleHttpEffect :: HttpF ~> Aff
        handleHttpEffect (Get url cont) = do
          liftEffect $ Ref.modify_ (\urls -> Array.snoc urls url) httpRef
          pure $ cont $ "Mock response for: " <> url
        handleHttpEffect (Post url body cont) = do
          pure $ cont $ "Mock POST response"

      let
        handleBoth :: forall x. V.VariantF (http :: HttpF, logging :: LoggingF) x -> Aff x
        handleBoth v =
          on _http handleHttpEffect
            (\v2 -> on _logging handleLogging impossibleVariant v2)
            v

      -- Composed program using both effects
      let
        program :: Program (HTTP (LOGGING ())) String
        program = do
          info "Starting test"
          debug "Making request"
          result <- get "http://example.com/test"
          info "Request complete"
          pure result

      resultValue <- runParallel handleBoth program

      -- Check that HTTP was called
      httpCalls <- liftEffect $ Ref.read httpRef
      httpCalls `shouldEqual` [ "http://example.com/test" ]

      -- Check that logging happened
      logs <- liftEffect $ Ref.read logRef
      logs `shouldContain` "Starting test"
      logs `shouldContain` "Making request"
      logs `shouldContain` "Request complete"

      -- Check result
      resultValue `shouldSatisfy` (String.contains (String.Pattern "Mock response"))

  describe "parallel HTTP requests" do
    it "executes multiple HTTP requests with applicative" do
      httpRef <- liftEffect $ Ref.new []

      let
        handleHttpEffect :: HttpF ~> Aff
        handleHttpEffect (Get url cont) = do
          liftEffect $ Ref.modify_ (\urls -> Array.snoc urls url) httpRef
          pure $ cont $ "Data from " <> url
        handleHttpEffect (Post url body cont) = do
          pure $ cont "POST"

      let
        handleLogging :: LoggingF ~> Aff
        handleLogging (Log _ _ next) = pure next

      let
        handleBoth :: forall x. V.VariantF (http :: HttpF, logging :: LoggingF) x -> Aff x
        handleBoth v =
          on _http handleHttpEffect
            (\v2 -> on _logging handleLogging impossibleVariant v2)
            v

      -- Program with parallel requests
      let
        program :: Program (HTTP (LOGGING ())) String
        program = do
          info "Starting parallel requests"
          results <- (\a b -> a <> " | " <> b)
            <$> get "http://api1.com"
            <*> get "http://api2.com"
          pure results

      result <- runParallel handleBoth program

      -- Both URLs should have been called
      httpCalls <- liftEffect $ Ref.read httpRef
      Array.length httpCalls `shouldEqual` 2
      httpCalls `shouldContain` "http://api1.com"
      httpCalls `shouldContain` "http://api2.com"

      -- Result should combine both responses
      result `shouldSatisfy` (String.contains (String.Pattern "Data from"))
