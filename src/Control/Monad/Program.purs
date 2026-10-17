module Control.Monad.Program
  ( module Control.Monad.Program.Core
  , runParallel
  , runPure
  , impossibleVariant
  ) where

import Prelude

import Control.Applicative.Free as Control.Applicative.Free
import Control.Monad.Program.Core as Control.Monad.Program.Core
import Control.Monad.Rec.Class as Control.Monad.Rec.Class
import Control.Parallel as Control.Parallel
import Data.Either as Data.Either
import Data.Functor.Variant as Data.Functor.Variant
import Effect.Aff as Effect.Aff

impossibleVariant :: forall x. Data.Functor.Variant.VariantF () x -> Effect.Aff.Aff x
impossibleVariant = Data.Functor.Variant.match {}

runPure :: forall a. Control.Monad.Program.Core.Program () a -> Effect.Aff.Aff a
runPure = runParallel impossibleVariant

runParallel
  :: forall r a
   . (forall x. Data.Functor.Variant.VariantF r x -> Effect.Aff.Aff x)
  -> Control.Monad.Program.Core.Program r a
  -> Effect.Aff.Aff a
runParallel handler = Control.Monad.Rec.Class.tailRecM step
  where
  step program = case Control.Monad.Program.Core.peel program of
    Data.Either.Right value -> pure (Control.Monad.Rec.Class.Done value)
    Data.Either.Left (Control.Monad.Program.Core.Batch ap) ->
      Control.Monad.Rec.Class.Loop <$> Control.Parallel.sequential
        (Control.Applicative.Free.foldFreeAp (Control.Parallel.parallel <<< handler) ap)
