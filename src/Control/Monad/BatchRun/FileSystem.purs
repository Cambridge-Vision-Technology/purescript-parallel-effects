module Control.Monad.BatchRun.FileSystem
  ( FileSystemF(..)
  , FILE_SYSTEM
  , _filesystem
  , readFile
  , writeFile
  , deleteFile
  , fileExists
  , runFileSystem
  , runFileSystemAt
  ) where

import Prelude

import Control.Applicative.Free (FreeAp, foldFreeAp)
import Control.Monad.BatchRun (BatchRun, BatchF(..), lift, send, peel, on, runParallel)
import Control.Parallel (parallel, sequential)
import Data.Either (Either(..))
import Data.Functor.Variant as V
import Data.Symbol (class IsSymbol)
import Effect.Aff (Aff)
import Node.Encoding (Encoding(..))
import Node.FS.Aff as FS
import Partial.Unsafe (unsafeCrashWith)
import Prim.Row as Row
import Type.Proxy (Proxy(..))

-- | FILE_SYSTEM effect row type
-- | Example: BatchRun (FILE_SYSTEM (LOGGING r)) Unit
type FILE_SYSTEM r = (filesystem :: FileSystemF | r)

data FileSystemF a
  = ReadFile String (String -> a)
  | WriteFile String String (Unit -> a)
  | DeleteFile String (Unit -> a)
  | FileExists String (Boolean -> a)

derive instance Functor FileSystemF

_filesystem :: Proxy "filesystem"
_filesystem = Proxy

-- | Read file contents
readFile :: forall r. String -> BatchRun (FILE_SYSTEM r) String
readFile path = lift _filesystem (ReadFile path identity)

-- | Write file contents
writeFile :: forall r. String -> String -> BatchRun (FILE_SYSTEM r) Unit
writeFile path contents = lift _filesystem (WriteFile path contents identity)

-- | Delete a file
deleteFile :: forall r. String -> BatchRun (FILE_SYSTEM r) Unit
deleteFile path = lift _filesystem (DeleteFile path identity)

-- | Check if file exists
fileExists :: forall r. String -> BatchRun (FILE_SYSTEM r) Boolean
fileExists path = lift _filesystem (FileExists path identity)

impossibleHandler :: forall r x. V.VariantF r x -> Aff x
impossibleHandler _ = pure $ unsafeCrashWith "Impossible: all effects should be handled"

-- | Handle FILE_SYSTEM effects for programs with only FILE_SYSTEM (no other effects)
runFileSystem :: forall a. BatchRun (FILE_SYSTEM ()) a -> Aff a
runFileSystem = runFileSystemAt _filesystem impossibleHandler

-- | Handle FILE_SYSTEM effects at a specific label
runFileSystemAt
  :: forall sym q r a
   . IsSymbol sym
  => Row.Cons sym FileSystemF q r
  => Proxy sym
  -> (forall x. V.VariantF q x -> Aff x)
  -> BatchRun r a
  -> Aff a
runFileSystemAt sym handler prog =
  runParallel (\v -> on sym handleFileSystem handler v) prog
  where
  handleFileSystem :: FileSystemF ~> Aff
  handleFileSystem (ReadFile path cont) = do
    contents <- FS.readTextFile UTF8 path
    pure $ cont contents

  handleFileSystem (WriteFile path contents cont) = do
    FS.writeTextFile UTF8 path contents
    pure $ cont unit

  handleFileSystem (DeleteFile path cont) = do
    FS.unlink path
    pure $ cont unit

  handleFileSystem (FileExists path cont) = do
    exists <- FS.exists path
    pure $ cont exists
